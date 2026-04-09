package internal

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/huh/spinner"
	"github.com/fatih/color"
)

//go:embed base-system-prompt.md
var baseSystemPrompt string

// LLMClient is an interface for LLM providers
type LLMClient interface {
	GenerateCommitMessage(ctx context.Context, diff string, relatedFiles []string) (string, error)
	// ModelName returns the name of the model used for generation.
	ModelName() string
}

const geminiModel = "gemini-2.5-flash"

// GeminiClient implements LLMClient using Gemini CLI
type GeminiClient struct {
	systemPrompt string
}

func NewGeminiClient() *GeminiClient {
	systemPrompt := baseSystemPrompt

	if overview := loadSkillOverview(); overview != "" {
		systemPrompt = systemPrompt + "\n\n" + overview
	}

	return &GeminiClient{
		systemPrompt: systemPrompt,
	}
}

// ModelName returns the name of the model used for generation.
func (c *GeminiClient) ModelName() string {
	return geminiModel
}

// GenerateCommitMessage creates a commit message using Gemini CLI
func (c *GeminiClient) GenerateCommitMessage(
	ctx context.Context,
	diff string,
	relatedFiles []string,
) (string, error) {
	userPrompt := c.buildUserPrompt(diff, relatedFiles)

	messageChan := make(chan string, 1)
	errChan := make(chan error, 1)

	if err := spinner.New().
		Title(fmt.Sprintf("%s is analyzing your changes", geminiModel)).
		Action(func() {
			message, err := c.callGeminiCLI(userPrompt)
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

// buildUserPrompt constructs the full prompt including system instructions
func (c *GeminiClient) buildUserPrompt(diff string, relatedFiles []string) string {
	var prompt strings.Builder

	prompt.WriteString(c.systemPrompt)
	prompt.WriteString("\n\n---\n\n")
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

type geminiResponse struct {
	Response string `json:"response"`
}

// callGeminiCLI invokes the gemini CLI command and parses JSON output
func (c *GeminiClient) callGeminiCLI(prompt string) (string, error) {
	cmd := exec.Command("gemini", "-p", prompt, "-m", geminiModel, "-o", "json")
	cmd.Stderr = nil

	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("calling gemini CLI: %w\nOutput: %s", err, string(output))
	}

	jsonStart := strings.Index(string(output), "{")
	if jsonStart < 0 {
		return "", fmt.Errorf("no JSON found in gemini output: %s", string(output))
	}

	var resp geminiResponse
	if err := json.Unmarshal(output[jsonStart:], &resp); err != nil {
		return "", fmt.Errorf("parsing gemini JSON response: %w\nOutput: %s", err, string(output))
	}

	message := c.cleanResponse(resp.Response)
	return message, nil
}

// cleanResponse removes markdown code blocks and extra whitespace
func (c *GeminiClient) cleanResponse(response string) string {
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

// loadSkillOverview reads the Overview section from the git-commit skill file
func loadSkillOverview() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	skillPath := filepath.Join(home, ".dotfiles", "config", "agents", "skills", "git-commit", "SKILL.md")
	content, err := os.ReadFile(skillPath)
	if err != nil {
		return ""
	}
	return extractOverviewSection(string(content))
}

// extractOverviewSection extracts the ## Overview section and all its subsections
func extractOverviewSection(content string) string {
	lines := strings.Split(content, "\n")
	var result []string
	inOverview := false

	for _, line := range lines {
		if strings.HasPrefix(line, "## Overview") {
			inOverview = true
			result = append(result, line)
			continue
		}
		if inOverview && strings.HasPrefix(line, "## ") && !strings.HasPrefix(line, "## Overview") {
			break
		}
		if inOverview {
			result = append(result, line)
		}
	}

	return strings.TrimSpace(strings.Join(result, "\n"))
}
