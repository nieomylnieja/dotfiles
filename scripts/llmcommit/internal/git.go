package internal

import (
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"

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

// GetStagedFiles returns the list of staged file paths.
func (g *GitClient) GetStagedFiles() ([]string, error) {
	filesOutput, err := exec.Command("git", "diff", "--cached", "--diff-algorithm=minimal", "--name-only").
		Output()
	if err != nil {
		return nil, err
	}

	filesStr := strings.TrimSpace(string(filesOutput))
	if filesStr == "" {
		return nil, fmt.Errorf(
			"no staged changes found. stage your changes with 'git add' first",
		)
	}

	return strings.Split(filesStr, "\n"), nil
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
			args := append([]string{"diff", "--cached", "--diff-algorithm=minimal", "--"}, files...)
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

// CommitChanges commits the given files with the provided message.
func (g *GitClient) CommitChanges(message string, files []string) error {
	args := append([]string{"commit", "-m", message, "--"}, files...)
	cmd := exec.Command("git", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to commit changes. %v", err)
	}

	return nil
}
