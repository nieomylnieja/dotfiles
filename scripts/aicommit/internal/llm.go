package internal

import (
	"context"
	_ "embed"
	"fmt"
	"os/exec"
	"strings"

	"github.com/charmbracelet/huh/spinner"
	"github.com/fatih/color"
)

//go:embed git-commit-rules.md
var systemPrompt string

// LLMProvider is an interface for LLM providers
type LLMProvider interface {
	GenerateCommitMessage(ctx context.Context, diff string, relatedFiles []string) (string, error)
}

// ClaudeClient implements LLMProvider using ClaudeClient CLI
type ClaudeClient struct {
	systemPrompt string
}

func NewClaudeClient() *ClaudeClient {
	return &ClaudeClient{
		systemPrompt: systemPrompt,
	}
}

// GenerateCommitMessage creates a commit message using Claude CLI
func (c *ClaudeClient) GenerateCommitMessage(
	ctx context.Context,
	diff string,
	relatedFiles []string,
) (string, error) {
	userPrompt := c.buildUserPrompt(diff, relatedFiles)

	messageChan := make(chan string, 1)
	errChan := make(chan error, 1)

	if err := spinner.New().
		Title("AI is analyzing your changes").
		Action(func() {
			message, err := c.callClaudeCLI(c.systemPrompt, userPrompt)
			if err != nil {
				errChan <- err
				messageChan <- ""
			} else {
				errChan <- nil
				messageChan <- message
			}
		}).
		Run(); err != nil {
		return "", err
	}

	if err := <-errChan; err != nil {
		return "", err
	}

	message := <-messageChan
	underline := color.New(color.Underline)
	underline.Println("\nChanges analyzed!")
	message = strings.TrimSpace(message)
	if message == "" {
		return "", fmt.Errorf("no commit message was generated. try again")
	}
	return message, nil
}

// buildUserPrompt constructs the prompt sent to the LLM
func (c *ClaudeClient) buildUserPrompt(diff string, relatedFiles []string) string {
	var prompt strings.Builder

	prompt.WriteString("Code diff:\n")
	prompt.WriteString(diff)
	prompt.WriteString("\n\n")

	if len(relatedFiles) > 0 {
		prompt.WriteString("Neighboring files:\n")
		prompt.WriteString(strings.Join(relatedFiles, ", "))
		prompt.WriteString("\n")
	}

	return prompt.String()
}

// callClaudeCLI invokes the claude CLI command
func (c *ClaudeClient) callClaudeCLI(systemPrompt, userPrompt string) (string, error) {
	// Call claude with system prompt and user input (using haiku model for speed/cost)
	cmd := exec.Command("claude", "--model", "haiku", "--system-prompt", systemPrompt)
	cmd.Stdin = strings.NewReader(userPrompt)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("error calling claude CLI: %v\nOutput: %s", err, string(output))
	}

	message := c.cleanResponse(string(output))
	return message, nil
}

// cleanResponse removes markdown code blocks and extra whitespace
func (c *ClaudeClient) cleanResponse(response string) string {
	lines := strings.Split(response, "\n")
	var cleanedLines []string
	inCodeBlock := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "```") {
			inCodeBlock = !inCodeBlock
			continue
		}
		if !inCodeBlock {
			cleanedLines = append(cleanedLines, line)
		}
	}

	return strings.TrimSpace(strings.Join(cleanedLines, "\n"))
}
