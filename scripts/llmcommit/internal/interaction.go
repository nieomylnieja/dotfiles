package internal

import (
	"fmt"
	"os"
	"os/exec"

	"charm.land/bubbles/v2/key"
	"charm.land/huh/v2"
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
	maxVisibleFiles         = 12
)

// SelectFiles presents a multi-select of staged files with all selected by default.
// Returns the user's selection.
func (i *Interaction) SelectFiles(files []string) ([]string, error) {
	if len(files) == 1 {
		i.printSelectedFiles(files)
		return files, nil
	}

	options := make([]huh.Option[string], len(files))
	for idx, file := range files {
		options[idx] = huh.NewOption(file, file).Selected(true)
	}

	var selected []string
	listHeight := min(len(files), maxVisibleFiles)
	title := fmt.Sprintf("Select files to commit (%d total)", len(files))
	if len(files) > listHeight {
		title = fmt.Sprintf("Select files to commit (%d total, more below: scroll with ↑/↓)", len(files))
	}

	keymap := huh.NewDefaultKeyMap()
	keymap.MultiSelect.Toggle = key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "toggle"))
	keymap.MultiSelect.Next = key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "confirm"))
	keymap.MultiSelect.SelectNone = key.NewBinding(key.WithKeys("shift+tab"), key.WithHelp("shift+tab", "deselect all"))

	field := huh.NewMultiSelect[string]().
		Title(title).
		Height(listHeight + 1).
		Options(options...).
		Value(&selected)

	err := huh.NewForm(huh.NewGroup(field)).
		WithTheme(themeNord()).
		WithKeyMap(keymap).
		WithShowHelp(true).
		Run()
	if err != nil {
		return nil, err
	}

	if len(selected) == 0 {
		return nil, fmt.Errorf("no files selected")
	}

	i.printSelectedFiles(selected)

	return selected, nil
}

func (i *Interaction) printSelectedFiles(files []string) {
	if len(files) == 1 {
		color.New(color.FgCyan, color.Bold).Printf("\nSelected %s file.\n\n", files[0])
		return
	}
	color.New(color.FgCyan, color.Bold).Printf("\nSelected %d files:\n", len(files))
	for i := range files {
		fmt.Printf("  %d. %s\n", i+1, files[i])
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
	color.New(color.FgGreen, color.Bold).Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

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
