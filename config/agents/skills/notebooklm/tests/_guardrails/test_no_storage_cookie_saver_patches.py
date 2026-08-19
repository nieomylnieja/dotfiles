"""Keep ``save_cookies_to_storage`` callable, but never use it as a test patch seam.

The public compatibility wrapper remains legal to import, call, assert about,
inject explicitly, or name in a standalone fixture string. What this guard
rejects is mutation of an attribute named
``save_cookies_to_storage``: monkeypatch/setattr/delattr/setitem, unittest.mock
patch forms, and direct assignment/deletion. It scans every Python file under
``tests/`` (including conftest, helpers, fixtures, and this guard itself).

Alias resolution is deliberately bounded and static. Imports, direct
same-scope name/attribute aliases, and literal string constants are propagated
through module, class, function, and lambda scopes. Values passed through
calls/containers, dynamic ``getattr``, and control-flow-dependent reassignments
are outside the proof. Those dynamic spellings are not sanctioned alternatives;
the bounded model keeps this repository lint deterministic without executing
test code.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from pathlib import Path

import pytest

pytestmark = pytest.mark.repo_lint

_REPO_ROOT = Path(__file__).resolve().parents[2]
_TESTS_ROOT = _REPO_ROOT / "tests"
_SAVER = "save_cookies_to_storage"


@dataclass(frozen=True, order=True)
class _Finding:
    path: str
    line: int
    column: int
    kind: str


def _expression_path(node: ast.AST, symbols: dict[str, str]) -> str | None:
    if isinstance(node, ast.Name):
        return symbols.get(node.id, node.id)
    if isinstance(node, ast.Attribute):
        base = _expression_path(node.value, symbols)
        return f"{base}.{node.attr}" if base else None
    return None


def _static_string(node: ast.AST | None, strings: dict[str, str]) -> str | None:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.Name):
        return strings.get(node.id)
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        left = _static_string(node.left, strings)
        right = _static_string(node.right, strings)
        return left + right if left is not None and right is not None else None
    if isinstance(node, ast.JoinedStr):
        parts: list[str] = []
        for value in node.values:
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                parts.append(value.value)
            elif isinstance(value, ast.FormattedValue):
                resolved = _static_string(value.value, strings)
                if resolved is None:
                    return None
                parts.append(resolved)
            else:
                return None
        return "".join(parts)
    return None


class _DeclarationCollector(ast.NodeVisitor):
    """Find names Python treats as local, without entering child scopes."""

    def __init__(self) -> None:
        self.bound: set[str] = set()
        self.global_names: set[str] = set()
        self.nonlocal_names: set[str] = set()

    def _bind_target(self, target: ast.AST) -> None:
        if isinstance(target, ast.Name):
            self.bound.add(target.id)
        elif isinstance(target, (ast.Tuple, ast.List)):
            for element in target.elts:
                self._bind_target(element)

    def visit_Import(self, node: ast.Import) -> None:
        self.bound.update(alias.asname or alias.name.split(".", 1)[0] for alias in node.names)

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        self.bound.update(alias.asname or alias.name for alias in node.names if alias.name != "*")

    def visit_Assign(self, node: ast.Assign) -> None:
        for target in node.targets:
            self._bind_target(target)
        self.visit(node.value)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        self._bind_target(node.target)
        if node.value is not None:
            self.visit(node.value)

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        self._bind_target(node.target)
        self.visit(node.value)

    def visit_NamedExpr(self, node: ast.NamedExpr) -> None:
        self._bind_target(node.target)
        self.visit(node.value)

    def visit_For(self, node: ast.For) -> None:
        self._bind_target(node.target)
        self.generic_visit(node)

    visit_AsyncFor = visit_For

    def visit_With(self, node: ast.With) -> None:
        for item in node.items:
            if item.optional_vars is not None:
                self._bind_target(item.optional_vars)
        self.generic_visit(node)

    visit_AsyncWith = visit_With

    def visit_ExceptHandler(self, node: ast.ExceptHandler) -> None:
        if node.name is not None:
            self.bound.add(node.name)
        self.generic_visit(node)

    def visit_Global(self, node: ast.Global) -> None:
        self.global_names.update(node.names)

    def visit_Nonlocal(self, node: ast.Nonlocal) -> None:
        self.nonlocal_names.update(node.names)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self.bound.add(node.name)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self.bound.add(node.name)

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        self.bound.add(node.name)

    def visit_Lambda(self, node: ast.Lambda) -> None:
        return


def _arguments(node: ast.arguments) -> list[ast.arg]:
    return [
        *node.posonlyargs,
        *node.args,
        *node.kwonlyargs,
        *([node.vararg] if node.vararg is not None else []),
        *([node.kwarg] if node.kwarg is not None else []),
    ]


class _MutationVisitor(ast.NodeVisitor):
    def __init__(self, path: str) -> None:
        self.path = path
        self.symbols: dict[str, str] = {}
        self.strings: dict[str, str] = {}
        self.findings: set[_Finding] = set()
        self._class_closure: tuple[dict[str, str], dict[str, str]] | None = None
        self._function_closure_override: tuple[dict[str, str], dict[str, str]] | None = None

    def _record(self, node: ast.AST, kind: str) -> None:
        self.findings.add(
            _Finding(self.path, node.lineno, node.col_offset + 1, kind)  # type: ignore[attr-defined]
        )

    def _clear_name(self, name: str) -> None:
        self.symbols.pop(name, None)
        self.strings.pop(name, None)

    def _clear_target(self, target: ast.AST) -> None:
        if isinstance(target, ast.Name):
            self._clear_name(target.id)
        elif isinstance(target, (ast.Tuple, ast.List)):
            for element in target.elts:
                self._clear_target(element)

    def _bind(self, target: ast.AST, value: ast.AST) -> None:
        if not isinstance(target, ast.Name):
            self._clear_target(target)
            return
        resolved_path = _expression_path(value, self.symbols)
        resolved_string = _static_string(value, self.strings)
        self._clear_name(target.id)
        if resolved_path is not None:
            self.symbols[target.id] = resolved_path
        if resolved_string is not None:
            self.strings[target.id] = resolved_string

    def _visit_scope(
        self,
        body: list[ast.stmt],
        arguments: ast.arguments | None = None,
        *,
        base: tuple[dict[str, str], dict[str, str]] | None = None,
    ) -> None:
        previous_symbols, previous_strings = self.symbols, self.strings
        source_symbols, source_strings = base or (previous_symbols, previous_strings)
        self.symbols = dict(source_symbols)
        self.strings = dict(source_strings)
        if arguments is not None:
            declarations = _DeclarationCollector()
            for statement in body:
                declarations.visit(statement)
            local_names = (
                declarations.bound - declarations.global_names - declarations.nonlocal_names
            )
            for name in local_names:
                self._clear_name(name)
            for argument in _arguments(arguments):
                self._clear_name(argument.arg)
                if argument.arg == "monkeypatch":
                    self.symbols[argument.arg] = "monkeypatch"
        for statement in body:
            self.visit(statement)
        self.symbols, self.strings = previous_symbols, previous_strings

    def visit_Module(self, node: ast.Module) -> None:
        self._visit_scope(node.body)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        for decorator in node.decorator_list:
            self.visit(decorator)
        for default in (*node.args.defaults, *node.args.kw_defaults):
            if default is not None:
                self.visit(default)
        closure = (
            self._function_closure_override or self._class_closure or (self.symbols, self.strings)
        )
        previous_override = self._function_closure_override
        previous_class_closure = self._class_closure
        self._function_closure_override = None
        self._class_closure = None
        self._visit_scope(node.body, node.args, base=closure)
        self._function_closure_override = previous_override
        self._class_closure = previous_class_closure
        self._clear_name(node.name)

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        for expression in (*node.decorator_list, *node.bases):
            self.visit(expression)
        for keyword in node.keywords:
            self.visit(keyword.value)
        outer_symbols, outer_strings = self.symbols, self.strings
        method_closure = self._class_closure or (dict(outer_symbols), dict(outer_strings))
        previous_class_closure = self._class_closure
        self._class_closure = method_closure
        self.symbols = dict(outer_symbols)
        self.strings = dict(outer_strings)
        for statement in node.body:
            if isinstance(statement, (ast.FunctionDef, ast.AsyncFunctionDef)):
                previous_override = self._function_closure_override
                self._function_closure_override = method_closure
                self.visit(statement)
                self._function_closure_override = previous_override
            else:
                self.visit(statement)
        self.symbols, self.strings = outer_symbols, outer_strings
        self._class_closure = previous_class_closure
        self._clear_name(node.name)

    def visit_Lambda(self, node: ast.Lambda) -> None:
        previous_symbols, previous_strings = self.symbols, self.strings
        self.symbols = dict(previous_symbols)
        self.strings = dict(previous_strings)
        for argument in _arguments(node.args):
            self.symbols.pop(argument.arg, None)
            self.strings.pop(argument.arg, None)
            if argument.arg == "monkeypatch":
                self.symbols[argument.arg] = "monkeypatch"
        self.visit(node.body)
        self.symbols, self.strings = previous_symbols, previous_strings

    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            bound = alias.asname or alias.name.split(".", 1)[0]
            self._clear_name(bound)
            self.symbols[bound] = alias.name if alias.asname else bound

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        if node.module is None:
            return
        for alias in node.names:
            if alias.name == "*":
                continue
            bound = alias.asname or alias.name
            self._clear_name(bound)
            self.symbols[bound] = f"{node.module}.{alias.name}"

    def _argument(self, node: ast.Call, position: int, *names: str) -> ast.AST | None:
        if position < len(node.args):
            return node.args[position]
        return next((kw.value for kw in node.keywords if kw.arg in names), None)

    def _is_saver_name(self, node: ast.AST | None) -> bool:
        return _static_string(node, self.strings) == _SAVER

    def _is_saver_string_target(self, node: ast.AST | None) -> bool:
        target = _static_string(node, self.strings)
        return target == _SAVER or bool(target and target.endswith(f".{_SAVER}"))

    def visit_Call(self, node: ast.Call) -> None:
        callee = _expression_path(node.func, self.symbols) or ""
        target = self._argument(node, 0, "target")
        name = self._argument(node, 1, "name", "attribute")

        if callee in {"setattr", "builtins.setattr", "delattr", "builtins.delattr"}:
            if self._is_saver_name(name):
                self._record(node, callee.rsplit(".", 1)[-1])
        elif callee in {"monkeypatch.setattr", "monkeypatch.delattr"}:
            if self._is_saver_name(name) or self._is_saver_string_target(target):
                self._record(node, callee)
        elif callee == "monkeypatch.setitem":
            target = self._argument(node, 0, "dic", "target")
            container = _expression_path(target, self.symbols)
            key = self._argument(node, 1, "name", "key")
            if container and container.endswith(".__dict__") and self._is_saver_name(key):
                self._record(node, callee)
        elif callee in {"unittest.mock.patch", "mock.patch"}:
            if self._is_saver_string_target(target):
                self._record(node, "patch")
        elif callee in {"unittest.mock.patch.object", "mock.patch.object"}:
            if self._is_saver_name(name):
                self._record(node, "patch.object")

        self.generic_visit(node)

    def _check_assignment_target(self, node: ast.AST, kind: str) -> None:
        if isinstance(node, ast.Attribute) and node.attr == _SAVER:
            self._record(node, kind)
        elif isinstance(node, ast.Subscript):
            container = _expression_path(node.value, self.symbols)
            if container and container.endswith(".__dict__") and self._is_saver_name(node.slice):
                self._record(node, f"{kind} via __dict__")
        elif isinstance(node, (ast.Tuple, ast.List)):
            for element in node.elts:
                self._check_assignment_target(element, kind)

    def visit_Assign(self, node: ast.Assign) -> None:
        self.visit(node.value)
        for target in node.targets:
            self._check_assignment_target(target, "assignment")
            self._bind(target, node.value)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        self._check_assignment_target(node.target, "assignment")
        self.visit(node.annotation)
        if node.value is not None:
            self.visit(node.value)
            self._bind(node.target, node.value)
        else:
            self._clear_target(node.target)

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        self._check_assignment_target(node.target, "assignment")
        self.visit(node.value)
        self._clear_target(node.target)

    def visit_Delete(self, node: ast.Delete) -> None:
        for target in node.targets:
            self._check_assignment_target(target, "deletion")
            self._clear_target(target)

    def visit_NamedExpr(self, node: ast.NamedExpr) -> None:
        self.visit(node.value)
        self._bind(node.target, node.value)

    def _visit_comprehension(
        self,
        generators: list[ast.comprehension],
        values: tuple[ast.AST, ...],
    ) -> None:
        previous_symbols, previous_strings = self.symbols, self.strings
        self.symbols = dict(previous_symbols)
        self.strings = dict(previous_strings)
        for generator in generators:
            self.visit(generator.iter)
            self._clear_target(generator.target)
            for condition in generator.ifs:
                self.visit(condition)
        for value in values:
            self.visit(value)
        self.symbols, self.strings = previous_symbols, previous_strings

    def visit_ListComp(self, node: ast.ListComp) -> None:
        self._visit_comprehension(node.generators, (node.elt,))

    visit_SetComp = visit_ListComp
    visit_GeneratorExp = visit_ListComp

    def visit_DictComp(self, node: ast.DictComp) -> None:
        self._visit_comprehension(node.generators, (node.key, node.value))


def _find_mutations(source: str, path: str = "<source>") -> list[_Finding]:
    tree = ast.parse(source, filename=path)
    visitor = _MutationVisitor(path)
    visitor.visit(tree)
    return sorted(visitor.findings)


@pytest.mark.parametrize(
    "source",
    [
        'def f(monkeypatch, storage, fake):\n monkeypatch.setattr(storage, "save_cookies_to_storage", fake)',
        'def f(monkeypatch, storage, fake):\n monkeypatch.setattr(target=storage, name="save_cookies_to_storage", value=fake)',
        'def f(monkeypatch, storage, fake):\n mp = monkeypatch\n mp.setattr(storage, "save_cookies_to_storage", fake)',
        'def f(monkeypatch, storage, fake):\n setter = monkeypatch.setattr\n setter(storage, "save_cookies_to_storage", fake)',
        'from unittest.mock import patch as p\nTARGET = "notebooklm._auth.storage.save_cookies_to_storage"\np(TARGET)',
        'from unittest.mock import patch\npatch.object(storage, attribute="save_cookies_to_storage")',
        'from unittest import mock as m\nm.patch.object(holder._auth_storage, "save_cookies_to_storage")',
        'setattr(storage, "save_cookies_to_storage", fake)',
        "storage.save_cookies_to_storage = fake",
        "del storage.save_cookies_to_storage",
        'def f(monkeypatch):\n monkeypatch.delattr("notebooklm._auth.storage.save_cookies_to_storage")',
        'def f(monkeypatch, storage, fake):\n monkeypatch.setitem(storage.__dict__, "save_cookies_to_storage", fake)',
        'def f(monkeypatch, storage, fake):\n monkeypatch.setitem(dic=storage.__dict__, name="save_cookies_to_storage", value=fake)',
        'def f(monkeypatch, storage, fake):\n monkeypatch.setitem(storage.__dict__, name="save_cookies_to_storage", value=fake)',
        'NAME = "save_cookies_to_storage"\nTARGET = "notebooklm._auth.storage." + NAME\nfrom unittest.mock import patch\npatch(target=TARGET)',
        'storage.__dict__["save_cookies_to_storage"] = fake',
        'del storage.__dict__["save_cookies_to_storage"]',
        'from unittest.mock import patch\npatch("notebooklm._auth.storage.save_cookies_to_storage")\npatch = harmless',
        'from unittest.mock import patch\nclass Example:\n patch = harmless\n def method(self):\n  patch("notebooklm._auth.storage.save_cookies_to_storage")',
        'from unittest.mock import patch\nclass Example:\n patch = harmless\n if True:\n  def method(self):\n   patch("notebooklm._auth.storage.save_cookies_to_storage")',
        'from unittest.mock import patch\nclass Example:\n patch = harmless\n try:\n  def method(self):\n   patch("notebooklm._auth.storage.save_cookies_to_storage")\n except Exception:\n  pass',
    ],
)
def test_guard_detects_every_supported_mutation_spelling(source: str) -> None:
    assert _find_mutations(source), source


@pytest.mark.parametrize(
    "source",
    [
        "storage.save_cookies_to_storage(jar, path)",
        "from notebooklm._auth.storage import save_cookies_to_storage",
        "assert storage.save_cookies_to_storage is expected",
        'TARGET = "notebooklm._auth.storage.save_cookies_to_storage"',
        "cookie_persistence._save_v0_callback(jar, save_cookies_to_storage=writer)",
        'def patch(target): return target\npatch("save_cookies_to_storage")',
        'def f(monkeypatch, storage, fake):\n monkeypatch.setattr(storage, "other", fake)',
        'setattr(storage, "other", fake)',
        'from unittest.mock import patch\n[patch("not a target") for patch in callbacks]',
        'from unittest.mock import patch\npatch.object(storage.save_cookies_to_storage, "__name__", "wrapped")',
        'setattr(storage.save_cookies_to_storage, "__doc__", "text")',
    ],
)
def test_guard_allows_nonmutation_compatibility_uses(source: str) -> None:
    assert _find_mutations(source) == []


def test_repository_has_no_storage_cookie_saver_patch_sites() -> None:
    findings: list[_Finding] = []
    for path in sorted(_TESTS_ROOT.rglob("*.py")):
        relative = path.relative_to(_REPO_ROOT).as_posix()
        findings.extend(_find_mutations(path.read_text(encoding="utf-8"), relative))
    assert not findings, "forbidden save_cookies_to_storage mutations:\n" + "\n".join(
        f"{finding.path}:{finding.line}:{finding.column}: {finding.kind}" for finding in findings
    )
