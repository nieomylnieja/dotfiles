package internal

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/charmbracelet/huh"
	"github.com/fatih/color"
)

type Interaction struct{}

func NewInteraction() *Interaction {
	return &Interaction{}
}

// Action represents user's choice for what to do with the generated commit message
type Action string

const (
	ActionConfirm    Action = "confirm"
	ActionRegenerate Action = "regenerate"
	ActionEdit       Action = "edit"
	ActionCancel     Action = "cancel"
)

// DisplayDetectedFiles shows the list of changed files
func (i *Interaction) DisplayDetectedFiles(files []string) {
	cyan := color.New(color.FgCyan)
	cyan.Printf("\nDetected %d file(s):\n", len(files))
	for idx, file := range files {
		fmt.Printf("  %d. %s\n", idx+1, file)
	}
	fmt.Println()
}

// HandleUserAction presents the commit message and gets user's choice
func (i *Interaction) HandleUserAction(message string) (Action, string, error) {
	// Display the generated commit message
	color.New(color.FgGreen, color.Bold).Println("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	color.New(color.FgGreen, color.Bold).Println("Generated Commit Message:")
	color.New(color.FgGreen, color.Bold).Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println(message)
	color.New(color.FgGreen, color.Bold).Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	var selectedAction Action

	// Ask user what to do
	err := huh.NewSelect[Action]().
		Title("Use this commit message?").
		Options(
			huh.NewOption("Yes", ActionConfirm),
			huh.NewOption("Regenerate", ActionRegenerate),
			huh.NewOption("Edit", ActionEdit),
			huh.NewOption("Cancel", ActionCancel),
		).
		Value(&selectedAction).
		Run()
	if err != nil {
		return ActionCancel, "", err
	}

	switch selectedAction {
	case ActionConfirm:
		return ActionConfirm, message, nil
	case ActionRegenerate:
		return ActionRegenerate, "", nil
	case ActionEdit:
		// Open message in editor
		editedMessage, err := i.editInEditor(message)
		if err != nil {
			return ActionCancel, "", err
		}
		return ActionConfirm, editedMessage, nil
	default:
		return ActionCancel, "", nil
	}
}

// editInEditor opens the commit message in an external editor
func (i *Interaction) editInEditor(message string) (string, error) {
	// Create a temporary file
	tmpFile, err := os.CreateTemp("", "COMMIT_EDITMSG_*")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %v", err)
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)

	// Write the message to the temp file
	if _, err := tmpFile.WriteString(message); err != nil {
		tmpFile.Close()
		return "", fmt.Errorf("failed to write to temp file: %v", err)
	}
	tmpFile.Close()

	// Determine which editor to use (prefer nvim, then $EDITOR, then vi)
	editor := os.Getenv("EDITOR")
	if editor == "" {
		// Check if nvim is available
		if _, err := exec.LookPath("nvim"); err == nil {
			editor = "nvim"
		} else {
			editor = "vi"
		}
	}

	// Open the editor
	cmd := exec.Command(editor, tmpPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("editor exited with error: %v", err)
	}

	// Read the edited content
	editedContent, err := os.ReadFile(tmpPath)
	if err != nil {
		return "", fmt.Errorf("failed to read edited file: %v", err)
	}

	return string(editedContent), nil
}
