package internal

import (
	"context"
	"fmt"

	"github.com/fatih/color"
)

type RootHandler struct {
	git         *GitClient
	llm         LLMProvider
	interaction *Interaction
}

func NewRootHandler() *RootHandler {
	return &RootHandler{
		git:         NewGitClient(),
		llm:         NewClaudeClient(),
		interaction: NewInteraction(),
	}
}

func (h *RootHandler) Run(ctx context.Context) error {
	return h.run(ctx)
}

func (h *RootHandler) run(ctx context.Context) error {
	if err := h.git.VerifyGitInstallation(); err != nil {
		return err
	}
	if err := h.git.VerifyGitRepository(); err != nil {
		return err
	}

	data, err := h.git.DetectStagedChanges()
	if err != nil {
		return err
	}

	h.interaction.DisplayDetectedFiles(data.Files)

	var message string
	for {
		// Generate commit message if not already generated
		if message == "" {
			generatedMessage, err := h.llm.GenerateCommitMessage(
				ctx,
				data.Diff,
				data.RelatedFiles,
			)
			if err != nil {
				return fmt.Errorf("error generating commit message: %v", err)
			}
			message = generatedMessage
		}

		// Get user action
		selectedAction, finalMessage, err := h.interaction.HandleUserAction(message)
		if err != nil {
			return err
		}

		switch selectedAction {
		case ActionConfirm:
			// Commit with the message
			if err := h.git.CommitChanges(finalMessage); err != nil {
				return err
			}
			color.New(color.FgGreen).Println("✔ Successfully committed!")
			return nil
		case ActionRegenerate:
			// Clear message and regenerate
			message = ""
			continue
		default:
			color.New(color.FgYellow).Println("Commit cancelled")
			return nil
		}
	}
}
