package internal

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

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
