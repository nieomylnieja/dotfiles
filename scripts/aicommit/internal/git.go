package internal

import (
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"

	"github.com/charmbracelet/huh/spinner"
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

// DetectStagedChanges gets the staged changes from git
func (g *GitClient) DetectStagedChanges() (*PreCommitData, error) {
	filesChan := make(chan []string, 1)
	diffChan := make(chan string, 1)

	if err := spinner.New().
		Title("Detecting changes").
		Action(func() {
			files, diff, err := g.getStagedDiff()
			if err != nil {
				filesChan <- []string{}
				diffChan <- ""
				return
			}

			filesChan <- files
			diffChan <- diff
		}).
		Run(); err != nil {
		return nil, err
	}

	files := <-filesChan
	diff := <-diffChan

	if len(files) == 0 {
		return nil, fmt.Errorf(
			"no staged changes found. stage your changes with 'git add' first",
		)
	}

	relatedFiles := g.getRelatedFiles(files)

	return &PreCommitData{
		Files:        files,
		Diff:         diff,
		RelatedFiles: relatedFiles,
	}, nil
}

// getStagedDiff gets the diff of staged changes
func (g *GitClient) getStagedDiff() ([]string, string, error) {
	// Get list of staged files
	filesOutput, err := exec.Command("git", "diff", "--cached", "--diff-algorithm=minimal", "--name-only").
		Output()
	if err != nil {
		return nil, "", err
	}

	filesStr := strings.TrimSpace(string(filesOutput))
	if filesStr == "" {
		return nil, "", fmt.Errorf("nothing to analyze")
	}

	files := strings.Split(filesStr, "\n")

	// Get the actual diff
	diff, err := exec.Command("git", "diff", "--cached", "--diff-algorithm=minimal").
		Output()
	if err != nil {
		return nil, "", err
	}

	return files, string(diff), nil
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

// CommitChanges commits the staged changes with the given message
func (g *GitClient) CommitChanges(message string) error {
	cmd := exec.Command("git", "commit", "-m", message)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to commit changes. %v", err)
	}

	return nil
}
