package internal

import (
	"bytes"
	"errors"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"charm.land/huh/v2/spinner"
)

type GitClient struct{}

// PreCommitData contains data about the changes to be committed
type PreCommitData struct {
	Files        []string
	Diff         string
	RelatedFiles []string
}

func NewGitClient() *GitClient {
	return &GitClient{}
}

func (g *GitClient) VerifyGitInstallation() error {
	if err := exec.Command("git", "--version").Run(); err != nil {
		return fmt.Errorf("git is not installed. %v", err)
	}
	return nil
}

func (g *GitClient) VerifyGitRepository() error {
	if err := exec.Command("git", "rev-parse", "--show-toplevel").Run(); err != nil {
		return fmt.Errorf(
			"the current directory must be a git repository. %v",
			err,
		)
	}
	return nil
}

// GetStagedFiles returns staged paths relative to the current directory.
// Optional Git pathspecs limit the results. Renames appear as a deletion and an addition.
func (g *GitClient) GetStagedFiles(paths ...string) ([]string, error) {
	args := []string{"diff", "--cached", "--diff-algorithm=minimal", "--name-only", "--no-renames", "--no-relative", "-z", "--"}
	filesOutput, err := exec.Command("git", append(args, paths...)...).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("list staged files: %w: %s", err, bytes.TrimSpace(filesOutput))
	}

	if len(filesOutput) == 0 {
		if len(paths) > 0 {
			return nil, fmt.Errorf("no staged changes match the supplied paths: %q", paths)
		}
		return nil, fmt.Errorf(
			"no staged changes found. stage your changes with 'git add' first",
		)
	}

	prefix, err := exec.Command("git", "rev-parse", "--show-prefix").Output()
	if err != nil {
		return nil, fmt.Errorf("resolve repository prefix: %w", err)
	}
	files := strings.Split(strings.TrimSuffix(string(filesOutput), "\x00"), "\x00")
	for i, file := range files {
		files[i], err = filepath.Rel(strings.TrimSuffix(string(prefix), "\n"), file)
		if err != nil {
			return nil, fmt.Errorf("resolve staged path %q: %w", file, err)
		}
	}
	return files, nil
}

// BuildCommitData gets the diff and related files for the given file paths.
func (g *GitClient) BuildCommitData(files []string) (*PreCommitData, error) {
	var (
		diff string
		err  error
	)

	if spinErr := spinner.New().
		WithTheme(spinnerThemeNord()).
		Title("Detecting changes").
		Action(func() {
			args := append([]string{"--literal-pathspecs", "diff", "--cached", "--diff-algorithm=minimal", "--no-renames", "--"}, files...)
			out, cmdErr := exec.Command("git", args...).Output()
			if cmdErr != nil {
				err = cmdErr
				return
			}
			diff = string(out)
		}).
		Run(); spinErr != nil {
		return nil, spinErr
	}
	if err != nil {
		return nil, err
	}

	return &PreCommitData{
		Files:        files,
		Diff:         diff,
		RelatedFiles: g.getRelatedFiles(files),
	}, nil
}

// getRelatedFiles discovers related files in the same directories
func (g *GitClient) getRelatedFiles(files []string) []string {
	relatedFilesMap := make(map[string]bool)
	visitedDirs := make(map[string]bool)

	for _, file := range files {
		dir := filepath.Dir(file)
		if !visitedDirs[dir] {
			lsEntry, err := os.ReadDir(dir)
			if err == nil {
				for _, entry := range lsEntry {
					relatedFilesMap[filepath.Join(dir, entry.Name())] = true
				}
				visitedDirs[dir] = true
			}
		}
	}

	return slices.Collect(maps.Keys(relatedFilesMap))
}

// CommitChanges commits the staged contents of files and preserves other staged changes.
func (g *GitClient) CommitChanges(message string, files []string) error {
	if len(files) == 0 {
		return fmt.Errorf("no files selected")
	}
	stagedFiles, err := g.GetStagedFiles()
	if err != nil {
		return fmt.Errorf("failed to inspect staged changes. %v", err)
	}
	if !sameFileSet(files, stagedFiles) {
		return g.commitSelected(message, files)
	}

	cmd := exec.Command("git", "commit", "-m", message)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to commit changes. %v", err)
	}

	return nil
}

func (g *GitClient) commitSelected(message string, files []string) error {
	for _, state := range []string{"MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD"} {
		path, err := exec.Command("git", "rev-parse", "--git-path", state).Output()
		if err != nil {
			return fmt.Errorf("locate Git state %s: %w", state, err)
		}
		if _, err := os.Stat(strings.TrimSuffix(string(path), "\n")); err == nil {
			return fmt.Errorf("cannot commit a subset of staged files while %s exists", state)
		} else if !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("inspect Git state %s: %w", state, err)
		}
	}

	args := append([]string{
		"--literal-pathspecs", "diff", "--cached", "--binary", "--full-index",
		"--no-renames", "--no-ext-diff", "--no-textconv", "--no-relative", "--no-color",
		"--submodule=short", "--src-prefix=a/", "--dst-prefix=b/", "--",
	}, files...)
	patch, err := exec.Command("git", args...).Output()
	if err != nil {
		return fmt.Errorf("read selected staged changes: %w", err)
	}

	indexDir, err := os.MkdirTemp("", "llmcommit-index-"+time.Now().UTC().Format("20060102T150405Z")+"-*")
	if err != nil {
		return fmt.Errorf("create temporary commit index: %w", err)
	}
	defer func() {
		if err := os.RemoveAll(indexDir); err != nil {
			fmt.Fprintf(os.Stderr, "remove temporary commit index: %v\n", err)
		}
	}()
	env := append(os.Environ(), "GIT_INDEX_FILE="+filepath.Join(indexDir, "index"))

	head, err := exec.Command("git", "rev-parse", "--verify", "--quiet", "HEAD").Output()
	base := strings.TrimSpace(string(head))
	if err != nil {
		var exitErr *exec.ExitError
		if !errors.As(err, &exitErr) || exitErr.ExitCode() != 1 {
			return fmt.Errorf("resolve commit base: %w", err)
		}
		base = "--empty"
	}
	cmd := exec.Command("git", "read-tree", base)
	cmd.Env = env
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("initialize commit index: %w: %s", err, bytes.TrimSpace(output))
	}

	// Apply the staged patch to a separate index so working-tree edits stay out of the commit.
	root, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return fmt.Errorf("resolve repository root: %w", err)
	}
	cmd = exec.Command("git", "apply", "--cached", "--binary", "--whitespace=nowarn")
	cmd.Dir = strings.TrimSuffix(string(root), "\n")
	cmd.Env = env
	cmd.Stdin = bytes.NewReader(patch)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("prepare selected changes: %w: %s", err, bytes.TrimSpace(output))
	}
	cmd = exec.Command("git", "commit", "-m", message)
	cmd.Env = env
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("commit selected changes: %w", err)
	}

	// Hooks can change selected entries in the temporary index. Update those entries in the real index.
	args = append([]string{"--literal-pathspecs", "reset", "--quiet", "HEAD", "--"}, files...)
	if output, err := exec.Command("git", args...).CombinedOutput(); err != nil {
		return fmt.Errorf("commit created, but index update failed: %w: %s", err, bytes.TrimSpace(output))
	}
	return nil
}

func sameFileSet(left []string, right []string) bool {
	if len(left) != len(right) {
		return false
	}

	files := make(map[string]struct{}, len(left))
	for _, file := range left {
		files[file] = struct{}{}
	}
	for _, file := range right {
		if _, ok := files[file]; !ok {
			return false
		}
	}

	return true
}
