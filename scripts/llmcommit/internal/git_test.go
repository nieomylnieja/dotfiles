package internal

import (
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestGitClient_GetStagedFiles_filtersPaths(t *testing.T) {
	initGitRepo(t)
	files := []string{"scope/a.txt", "scope/nested/b.txt", "scope-extra/c.txt", "sp ace/d.txt", "odd\nname.txt", "-dash.txt"}
	for _, file := range files {
		writeTestFile(t, file, "staged\n")
	}
	runGit(t, "add", "--", ".")
	writeTestFile(t, "scope/untracked.txt", "untracked\n")
	slices.Sort(files)

	tests := []struct {
		name  string
		dir   string
		paths []string
		want  []string
	}{
		{name: "all", want: files},
		{name: "directory", paths: []string{"scope"}, want: []string{"scope/a.txt", "scope/nested/b.txt"}},
		{name: "trailing slash", paths: []string{"scope/"}, want: []string{"scope/a.txt", "scope/nested/b.txt"}},
		{name: "file", paths: []string{"scope/a.txt"}, want: []string{"scope/a.txt"}},
		{name: "multiple paths", paths: []string{"scope/a.txt", "sp ace"}, want: []string{"scope/a.txt", "sp ace/d.txt"}},
		{name: "leading dash", paths: []string{"-dash.txt"}, want: []string{"-dash.txt"}},
		{name: "newline", paths: []string{"odd\nname.txt"}, want: []string{"odd\nname.txt"}},
		{name: "nested current directory", dir: "scope", paths: []string{"."}, want: []string{"a.txt", "nested/b.txt"}},
		{name: "parent directory", dir: "scope", paths: []string{"../sp ace"}, want: []string{"../sp ace/d.txt"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.dir != "" {
				t.Chdir(tt.dir)
			}
			got, err := NewGitClient().GetStagedFiles(tt.paths...)
			if err != nil {
				t.Fatal(err)
			}
			if !slices.Equal(got, tt.want) {
				t.Errorf("GetStagedFiles() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestRootHandler_Run_noMatchingStagedPaths(t *testing.T) {
	initGitRepo(t)
	writeTestFile(t, "other/file.txt", "staged\n")
	runGit(t, "add", ".")
	writeTestFile(t, "scope/file.txt", "untracked\n")

	handler := &RootHandler{git: NewGitClient()}
	err := handler.Run(t.Context(), "scope")
	if err == nil || !strings.Contains(err.Error(), "no staged changes match the supplied paths") {
		t.Fatalf("Run() error = %v, want no matching staged changes", err)
	}
}

func TestGitClient_CommitChanges_preservesStagedAndUnstagedContents(t *testing.T) {
	for _, dir := range []string{".", "scope"} {
		t.Run(dir, func(t *testing.T) {
			initGitRepo(t)
			for _, file := range []string{"scope/partial.txt", "scope/deleted.txt", "other.txt"} {
				writeTestFile(t, file, "base\n")
			}
			runGit(t, "add", ".")
			runGit(t, "commit", "-m", "initial")
			writeTestFile(t, "scope/partial.txt", "staged\n")
			writeTestFile(t, "scope/a[1].txt", "literal filename\n")
			writeTestFile(t, "scope/binary", "\x00\x01\xff")
			writeTestFile(t, "other.txt", "other staged\n")
			runGit(t, "add", ".")
			runGit(t, "rm", "--cached", "scope/deleted.txt")
			writeTestFile(t, "scope/partial.txt", "unstaged\n")
			runGit(t, "config", "diff.noprefix", "true")
			runGit(t, "config", "color.diff", "always")
			t.Chdir(dir)
			path := "scope"
			if dir == "scope" {
				path = "."
			}
			client := NewGitClient()
			files, err := client.GetStagedFiles(path)
			if err != nil {
				t.Fatal(err)
			}
			if err := client.CommitChanges("fix: selected changes", files); err != nil {
				t.Fatal(err)
			}
			for file, want := range map[string]string{
				"scope/partial.txt": "staged\n",
				"scope/a[1].txt":    "literal filename\n",
				"scope/binary":      "\x00\x01\xff",
				"other.txt":         "base\n",
			} {
				if got := runGit(t, "show", "HEAD:"+file); got != want {
					t.Errorf("committed %s = %q, want %q", file, got, want)
				}
			}
			if err := exec.Command("git", "cat-file", "-e", "HEAD:scope/deleted.txt").Run(); err == nil {
				t.Fatal("staged deletion was not committed")
			}
			if got := runGit(t, "diff", "--cached", "--name-only", "--no-relative"); got != "other.txt\n" {
				t.Errorf("remaining staged files = %q, want other.txt", got)
			}
			content, err := os.ReadFile(filepath.Join(path, "partial.txt"))
			if err != nil {
				t.Fatal(err)
			}
			if string(content) != "unstaged\n" {
				t.Errorf("working file = %q, want unstaged content", content)
			}
		})
	}
}

func TestGitClient_CommitChanges_subsetOfInitialCommit(t *testing.T) {
	initGitRepo(t)
	writeTestFile(t, "selected.txt", "selected\n")
	writeTestFile(t, "other.txt", "other\n")
	runGit(t, "add", ".")
	if err := NewGitClient().CommitChanges("feat: initial subset", []string{"selected.txt"}); err != nil {
		t.Fatal(err)
	}
	if got := runGit(t, "ls-tree", "--name-only", "HEAD"); got != "selected.txt\n" {
		t.Errorf("committed files = %q, want selected.txt", got)
	}
	if got := runGit(t, "diff", "--cached", "--name-only"); got != "other.txt\n" {
		t.Errorf("remaining staged files = %q, want other.txt", got)
	}
}

func TestGitClient_CommitChanges_preservesStagedSubmoduleUpdate(t *testing.T) {
	for _, format := range []string{"short", "log", "diff"} {
		t.Run(format, func(t *testing.T) {
			initGitRepo(t)
			writeTestFile(t, "selected.txt", "base\n")
			runGit(t, "add", ".")
			runGit(t, "commit", "-m", "first")
			first := strings.TrimSpace(runGit(t, "rev-parse", "HEAD"))
			runGit(t, "update-index", "--add", "--cacheinfo", "160000,"+first+",module")
			runGit(t, "commit", "-m", "add gitlink")
			second := strings.TrimSpace(runGit(t, "rev-parse", "HEAD"))
			runGit(t, "update-index", "--cacheinfo", "160000,"+second+",module")
			writeTestFile(t, "selected.txt", "selected\n")
			writeTestFile(t, "other.txt", "other\n")
			runGit(t, "add", "selected.txt", "other.txt")
			runGit(t, "config", "diff.submodule", format)
			if err := NewGitClient().CommitChanges("chore: selected", []string{"module", "selected.txt"}); err != nil {
				t.Fatal(err)
			}
			if got := strings.TrimSpace(runGit(t, "rev-parse", "HEAD:module")); got != second {
				t.Errorf("committed gitlink = %q, want %q", got, second)
			}
			if got := runGit(t, "diff", "--cached", "--name-only"); got != "other.txt\n" {
				t.Errorf("remaining staged paths = %q, want other.txt", got)
			}
		})
	}
}

func TestGitClient_CommitChanges_failedHookPreservesIndex(t *testing.T) {
	initGitRepo(t)
	for _, file := range []string{"selected.txt", "other.txt"} {
		writeTestFile(t, file, "base\n")
	}
	runGit(t, "add", ".")
	runGit(t, "commit", "-m", "initial")
	writeTestFile(t, "selected.txt", "selected staged\n")
	writeTestFile(t, "other.txt", "other staged\n")
	runGit(t, "add", ".")
	writeTestFile(t, "selected.txt", "unstaged\n")
	beforeHead := runGit(t, "rev-parse", "HEAD")
	beforeIndex := runGit(t, "diff", "--cached", "--binary")
	hookDir := t.TempDir()
	runGit(t, "config", "core.hooksPath", hookDir)
	if err := os.WriteFile(filepath.Join(hookDir, "pre-commit"), []byte("#!/bin/sh\nexit 1\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	indexDir := t.TempDir()
	t.Setenv("TMPDIR", indexDir)

	if err := NewGitClient().CommitChanges("fix: selected", []string{"selected.txt"}); err == nil {
		t.Fatal("CommitChanges() succeeded despite a failed pre-commit hook")
	}
	if got := runGit(t, "rev-parse", "HEAD"); got != beforeHead {
		t.Errorf("HEAD changed from %q to %q", beforeHead, got)
	}
	if got := runGit(t, "diff", "--cached", "--binary"); got != beforeIndex {
		t.Errorf("staged diff changed after failure:\n%s", got)
	}
	entries, err := os.ReadDir(indexDir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Errorf("temporary index was not removed: %v", entries)
	}
}

func TestGitClient_CommitChanges_retainsHookChanges(t *testing.T) {
	initGitRepo(t)
	writeTestFile(t, "selected.txt", "selected\n")
	writeTestFile(t, "other.txt", "other\n")
	runGit(t, "add", ".")
	hookDir := t.TempDir()
	runGit(t, "config", "core.hooksPath", hookDir)
	script := "#!/bin/sh\nprintf 'hook\\n' > selected.txt\ngit add -- selected.txt\n"
	if err := os.WriteFile(filepath.Join(hookDir, "pre-commit"), []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := NewGitClient().CommitChanges("feat: selected", []string{"selected.txt"}); err != nil {
		t.Fatal(err)
	}
	if got := runGit(t, "show", "HEAD:selected.txt"); got != "hook\n" {
		t.Errorf("committed selected.txt = %q, want hook content", got)
	}
	if got := runGit(t, "diff", "--cached", "--name-only"); got != "other.txt\n" {
		t.Errorf("remaining staged files = %q, want other.txt", got)
	}
}

func TestGitClient_CommitChanges_rejectsSubsetDuringGitOperation(t *testing.T) {
	for _, state := range []string{"MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD"} {
		t.Run(state, func(t *testing.T) {
			initGitRepo(t)
			writeTestFile(t, "selected.txt", "selected\n")
			writeTestFile(t, "other.txt", "other\n")
			runGit(t, "add", ".")
			beforeIndex := runGit(t, "diff", "--cached", "--binary")
			writeTestFile(t, filepath.Join(".git", state), "pending operation\n")
			err := NewGitClient().CommitChanges("fix: selected", []string{"selected.txt"})
			if err == nil || !strings.Contains(err.Error(), state) {
				t.Fatalf("CommitChanges() error = %v, want %s state error", err, state)
			}
			if got := runGit(t, "diff", "--cached", "--binary"); got != beforeIndex {
				t.Errorf("staged diff changed during %s:\n%s", state, got)
			}
		})
	}
}

func TestGitClient_CommitChanges_commitsStagedRemovalWhenFileStillExists(t *testing.T) {
	initGitRepo(t)

	if err := os.WriteFile("tracked.txt", []byte("one\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	runGit(t, "add", "tracked.txt")
	runGit(t, "commit", "-m", "initial")
	runGit(t, "rm", "--cached", "tracked.txt")

	client := NewGitClient()
	staged, err := client.GetStagedFiles()
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(staged, "\x00") != "tracked.txt" {
		t.Fatalf("staged files = %#v, want tracked.txt", staged)
	}

	if err := client.CommitChanges("remove tracked file", staged); err != nil {
		t.Fatal(err)
	}

	if err := exec.Command("git", "cat-file", "-e", "HEAD:tracked.txt").Run(); err == nil {
		t.Fatal("tracked.txt is still present in HEAD")
	}
	if _, err := os.Stat("tracked.txt"); err != nil {
		t.Fatalf("tracked.txt should remain in the working tree: %v", err)
	}
}

func writeTestFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}

func initGitRepo(t *testing.T) {
	t.Helper()

	t.Chdir(t.TempDir())
	runGit(t, "init")
	runGit(t, "config", "user.email", "test@example.com")
	runGit(t, "config", "user.name", "Test User")
}

func runGit(t *testing.T, args ...string) string {
	t.Helper()

	output, err := exec.Command("git", args...).CombinedOutput()
	if err != nil {
		t.Fatalf("git %s failed: %v\n%s", strings.Join(args, " "), err, output)
	}

	return string(output)
}
