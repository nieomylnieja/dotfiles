package internal

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"charm.land/huh/v2/spinner"
	"github.com/fatih/color"
)

//go:embed base-system-prompt.md
var baseSystemPromptRaw string

var baseSystemPrompt = template.Must(
	template.New("system-prompt").Parse(baseSystemPromptRaw),
)

// promptData holds all template variables for the system prompt.
type promptData struct {
	Overview     string
	Diff         string
	RelatedFiles string
}

// LLMClient is an interface for LLM providers
type LLMClient interface {
	GenerateCommitMessage(ctx context.Context, diff string, relatedFiles []string) (string, error)
	// ModelName returns the name of the model used for generation.
	ModelName() string
}

const geminiModel = "gemini-2.5-flash"

const geminiGenerateURL = "https://generativelanguage.googleapis.com/v1beta/models/" + geminiModel + ":generateContent"

// GeminiClient implements LLMClient using Gemini API.
type GeminiClient struct {
	overview string
	http     *RetryClient
}

// NewGeminiClient creates a GeminiClient.
func NewGeminiClient() *GeminiClient {
	return &GeminiClient{
		overview: loadSkillOverview(),
		http:     NewRetryClient(nil),
	}
}

// ModelName returns the name of the model used for generation.
func (c *GeminiClient) ModelName() string {
	return geminiModel
}

// GenerateCommitMessage creates a commit message using Gemini API
func (c *GeminiClient) GenerateCommitMessage(
	ctx context.Context,
	diff string,
	relatedFiles []string,
) (string, error) {
	userPrompt, err := c.renderPrompt(diff, relatedFiles)
	if err != nil {
		return "", err
	}

	var (
		message   string
		actionErr error
	)

	s := spinner.New().
		Title(fmt.Sprintf("%s is analyzing your changes", geminiModel))
	c.http.onStatus = func(status string) {
		s.Title(status)
	}
	s.Action(func() {
		message, actionErr = c.callGeminiAPI(ctx, userPrompt)
	})
	if err := s.Run(); err != nil {
		return "", err
	}
	if actionErr != nil {
		return "", actionErr
	}
	underline := color.New(color.Underline)
	underline.Println("\nChanges analyzed!")
	message = strings.TrimSpace(message)
	if message == "" {
		return "", fmt.Errorf("no commit message was generated. try again")
	}
	return message, nil
}

// renderPrompt executes the system prompt template with the given data.
func (c *GeminiClient) renderPrompt(diff string, relatedFiles []string) (string, error) {
	data := promptData{
		Overview: c.overview,
		Diff:     diff,
	}
	if len(relatedFiles) > 0 {
		data.RelatedFiles = strings.Join(relatedFiles, ", ")
	}

	var buf bytes.Buffer
	if err := baseSystemPrompt.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("rendering system prompt template: %w", err)
	}
	return buf.String(), nil
}

type geminiGenerateRequest struct {
	Contents []geminiContent `json:"contents"`
}

type geminiContent struct {
	Parts []geminiPart `json:"parts"`
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiGenerateResponse struct {
	Candidates []geminiCandidate `json:"candidates"`
}

type geminiCandidate struct {
	Content geminiContent `json:"content"`
}

// callGeminiAPI invokes the Gemini HTTP API and parses the response.
// Retries on 5xx are handled by the underlying RetryClient.
func (c *GeminiClient) callGeminiAPI(ctx context.Context, prompt string) (string, error) {
	apiKey, err := readGeminiAPIKey()
	if err != nil {
		return "", err
	}

	body, err := json.Marshal(geminiGenerateRequest{
		Contents: []geminiContent{{
			Parts: []geminiPart{{Text: prompt}},
		}},
	})
	if err != nil {
		return "", fmt.Errorf("encoding gemini request: %w", err)
	}

	bodyReader := bytes.NewReader(body)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, geminiGenerateURL, bodyReader)
	if err != nil {
		return "", fmt.Errorf("creating gemini request: %w", err)
	}
	req.GetBody = func() (io.ReadCloser, error) {
		_, _ = bodyReader.Seek(0, io.SeekStart)
		return io.NopCloser(bodyReader), nil
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", apiKey)

	resp, err := c.http.Do(ctx, req)
	if err != nil {
		return "", fmt.Errorf("calling gemini API: %w", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("reading gemini response: %w", err)
	}

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", fmt.Errorf("gemini API request failed: status %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}

	var parsed geminiGenerateResponse
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return "", fmt.Errorf("parsing gemini JSON response: %w\nResponse: %s", err, string(respBody))
	}

	if len(parsed.Candidates) == 0 || len(parsed.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("gemini API returned no candidates: %s", strings.TrimSpace(string(respBody)))
	}

	message := c.cleanResponse(parsed.Candidates[0].Content.Parts[0].Text)
	return message, nil
}

func readGeminiAPIKey() (string, error) {
	if key := strings.TrimSpace(os.Getenv("GEMINI_API_KEY")); key != "" {
		return key, nil
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolving home dir for gemini API key: %w", err)
	}

	path := filepath.Join(home, ".password-store", "gemini_api_key")
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("reading gemini API key from %s: %w", path, err)
	}

	key := strings.TrimSpace(string(data))
	if key == "" {
		return "", fmt.Errorf("gemini API key file is empty: %s", path)
	}

	return key, nil
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
