#!/usr/bin/env python3
"""Measure skill selection through an explicitly configured runner."""

import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from threading import Event

from scripts.runner import add_runner_arguments, call_runner
from scripts.utils import parse_skill_md


def validate_eval_set(eval_set: list[dict]) -> None:
    if not isinstance(eval_set, list) or not eval_set:
        raise ValueError("eval set must be a nonempty list")
    seen = set()
    for item in eval_set:
        if not isinstance(item, dict) or not isinstance(item.get("query"), str) or not item["query"].strip():
            raise ValueError("each eval requires a nonempty query")
        if type(item.get("should_trigger")) is not bool:
            raise ValueError("each eval requires a boolean should_trigger")
        if item["query"] in seen:
            raise ValueError("eval queries must be unique")
        seen.add(item["query"])


def run_single_query(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: float,
    project_root: Path,
    runner: list[str],
    skill_path: Path,
    model: str | None = None,
    cancelled: Event | None = None,
) -> bool:
    response = call_runner(
        runner,
        {
            "operation": "evaluate",
            "model": model,
            "query": query,
            "skill_name": skill_name,
            "skill_path": str(skill_path.resolve()),
            "description": skill_description,
        },
        timeout=timeout,
        cwd=project_root,
        cancelled=cancelled,
    )
    if type(response.get("triggered")) is not bool:
        raise ValueError("evaluate runner must return a boolean triggered field")
    return response["triggered"]


def run_eval(
    eval_set: list[dict],
    skill_name: str,
    description: str,
    num_workers: int,
    timeout: float,
    project_root: Path,
    runner: list[str],
    skill_path: Path,
    runs_per_query: int = 1,
    trigger_threshold: float = 0.5,
    model: str | None = None,
) -> dict:
    """Return scores only when every run produced a valid observation."""
    validate_eval_set(eval_set)
    if num_workers < 1 or runs_per_query < 1 or timeout <= 0:
        raise ValueError("workers, runs per query, and timeout must be positive")
    if not 0 < trigger_threshold <= 1:
        raise ValueError("trigger threshold must be greater than 0 and at most 1")
    query_triggers = {item["query"]: [] for item in eval_set}
    cancelled = Event()
    with ThreadPoolExecutor(max_workers=num_workers) as executor:
        futures = {}
        try:
            for item in eval_set:
                for _ in range(runs_per_query):
                    future = executor.submit(
                        run_single_query, item["query"], skill_name, description,
                        timeout, project_root, runner, skill_path, model, cancelled,
                    )
                    futures[future] = item["query"]
            for future in as_completed(futures):
                query_triggers[futures[future]].append(future.result())
        except BaseException:
            cancelled.set()
            for pending in futures:
                pending.cancel()
            raise

    results = []
    for item in eval_set:
        triggers = query_triggers[item["query"]]
        trigger_rate = sum(triggers) / len(triggers)
        did_trigger = trigger_rate >= trigger_threshold
        results.append({
            "query": item["query"],
            "should_trigger": item["should_trigger"],
            "trigger_rate": trigger_rate,
            "triggers": sum(triggers),
            "runs": len(triggers),
            "pass": did_trigger == item["should_trigger"],
        })

    passed = sum(r["pass"] for r in results)
    return {
        "skill_name": skill_name,
        "description": description,
        "results": results,
        "summary": {
            "total": len(results),
            "passed": passed,
            "failed": len(results) - passed,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Run trigger evaluation for a skill description")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON file")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--description", default=None, help="Override description to test")
    parser.add_argument("--num-workers", type=int, default=10, help="Number of parallel workers")
    parser.add_argument("--timeout", type=float, default=30, help="Timeout per query in seconds")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Trigger rate threshold")
    add_runner_arguments(parser)
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    try:
        eval_set = json.loads(Path(args.eval_set).read_text())
        skill_path = Path(args.skill_path).resolve()
        name, original_description, _ = parse_skill_md(skill_path)
        description = args.description or original_description
        output = run_eval(
            eval_set=eval_set,
            skill_name=name,
            description=description,
            num_workers=args.num_workers,
            timeout=args.timeout,
            project_root=args.project_root.resolve(),
            runner=args.runner,
            skill_path=skill_path,
            runs_per_query=args.runs_per_query,
            trigger_threshold=args.trigger_threshold,
            model=args.model,
        )
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"Error: {error}\n")

    if args.verbose:
        summary = output["summary"]
        print(f"Results: {summary['passed']}/{summary['total']} passed", file=sys.stderr)
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
