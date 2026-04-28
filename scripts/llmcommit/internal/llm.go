package internal

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
	"time"

	"charm.land/huh/v2/spinner"
	"github.com/fatih/color"
)

//go:embed base-system-prompt.md
var baseSystemPromptRaw string

var baseSystemPrompt = template.Must(
	template.New("system-prompt").Parse(baseSystemPromptRaw),
)

const (
	defaultOpenCodeModel = "openai/gpt-5.5"
	opencodePromptName   = "commit-prompt.md"
	opencodeRunMessage   = "Read the attached file and respond with only the commit message text."
)

var isolatedOpenCodeFlags = []string{
	"OPENCODE_DISABLE_AUTOUPDATE=1",
	"OPENCODE_DISABLE_AUTOCOMPACT=1",
	"OPENCODE_DISABLE_CLAUDE_CODE=1",
	"OPENCODE_DISABLE_DEFAULT_PLUGINS=1",
	"OPENCODE_DISABLE_EXTERNAL_SKILLS=1",
	"OPENCODE_DISABLE_LSP_DOWNLOAD=1",
	"OPENCODE_DISABLE_PROJECT_CONFIG=1",
	"OPENCODE_DISABLE_PRUNE=1",
	"OPENCODE_PURE=1",
}

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

// OpenCodeClient implements LLMClient through an isolated opencode CLI invocation.
type OpenCodeClient struct {
	model    string
	overview string
}

// NewOpenCodeClient creates an OpenCodeClient.
func NewOpenCodeClient() *OpenCodeClient {
	return &OpenCodeClient{
		model:    resolveOpenCodeModel(),
		overview: loadSkillOverview(),
	}
}

// ModelName returns the name of the model used for generation.
func (c *OpenCodeClient) ModelName() string {
	return fmt.Sprintf("opencode (%s)", c.model)
}

// GenerateCommitMessage creates a commit message using opencode in bare mode.
func (c *OpenCodeClient) GenerateCommitMessage(
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
		WithTheme(spinnerThemeNord()).
		Title(fmt.Sprintf("%s is analyzing your changes", c.ModelName()))
	s.Action(func() {
		message, actionErr = c.callOpenCode(ctx, userPrompt)
	})
	if err := s.Run(); err != nil {
		return "", err
	}
	if actionErr != nil {
		return "", actionErr
	}

	underline := color.New(color.Underline)
	_, _ = underline.Println("\nChanges analyzed!")

	message = strings.TrimSpace(message)
	if message == "" {
		return "", fmt.Errorf("no commit message was generated. try again")
	}

	return message, nil
}

// renderPrompt executes the system prompt template with the given data.
func (c *OpenCodeClient) renderPrompt(diff string, relatedFiles []string) (string, error) {
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

func (c *OpenCodeClient) callOpenCode(ctx context.Context, prompt string) (string, error) {
	promptPath, err := writePromptFile(prompt)
	if err != nil {
		return "", err
	}
	defer func() {
		_ = os.Remove(promptPath)
	}()

	sandboxPath, err := createOpenCodeSandbox()
	if err != nil {
		return "", err
	}
	defer func() {
		_ = os.RemoveAll(sandboxPath)
	}()

	baseEnv := os.Environ()
	env := isolatedOpenCodeEnv(baseEnv, sandboxPath)
	if err := copyOpenCodeAuth(baseEnv, env); err != nil {
		return "", err
	}
	if err := validateOpenCodeCredentials(c.model, env); err != nil {
		return "", err
	}

	cmd := exec.CommandContext(ctx, "opencode", opencodeArgs(c.model, promptPath)...)
	cmd.Env = env

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return "", formatOpenCodeError(err, stdout.String(), stderr.String())
	}

	message := c.cleanResponse(stdout.String())
	if message == "" {
		return "", formatOpenCodeError(
			fmt.Errorf("opencode returned an empty response"),
			stdout.String(),
			stderr.String(),
		)
	}

	return message, nil
}

func (c *OpenCodeClient) cleanResponse(response string) string {
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

func resolveOpenCodeModel() string {
	if model := strings.TrimSpace(os.Getenv("LLMCOMMIT_OPENCODE_MODEL")); model != "" {
		return model
	}
	return defaultOpenCodeModel
}

func writePromptFile(prompt string) (string, error) {
	timestamp := time.Now().UTC().Format("20060102T150405Z")
	pattern := fmt.Sprintf("llmcommit-%s-*-%s", timestamp, opencodePromptName)
	file, err := os.CreateTemp("", pattern)
	if err != nil {
		return "", fmt.Errorf("creating temporary prompt file: %w", err)
	}
	path := file.Name()
	if _, err := file.WriteString(prompt); err != nil {
		_ = file.Close()
		_ = os.Remove(path)
		return "", fmt.Errorf("writing temporary prompt file: %w", err)
	}
	if err := file.Close(); err != nil {
		_ = os.Remove(path)
		return "", fmt.Errorf("closing temporary prompt file: %w", err)
	}

	return path, nil
}

func createOpenCodeSandbox() (string, error) {
	path, err := os.MkdirTemp("", "llmcommit-opencode-*")
	if err != nil {
		return "", fmt.Errorf("creating temporary opencode sandbox: %w", err)
	}
	return path, nil
}

func isolatedOpenCodeEnv(base []string, sandboxPath string) []string {
	env := make([]string, 0, len(base)+len(isolatedOpenCodeFlags)+5)

	for _, item := range base {
		key, _, _ := strings.Cut(item, "=")
		switch {
		case strings.HasPrefix(key, "OPENCODE_"):
			continue
		case key == "XDG_CONFIG_HOME":
			continue
		case key == "XDG_DATA_HOME":
			continue
		case key == "XDG_STATE_HOME":
			continue
		}
		env = append(env, item)
	}

	env = append(env,
		"XDG_CONFIG_HOME="+filepath.Join(sandboxPath, "config"),
		"XDG_DATA_HOME="+filepath.Join(sandboxPath, "data"),
		"XDG_STATE_HOME="+filepath.Join(sandboxPath, "state"),
		"OPENCODE_MODELS_PATH="+filepath.Join(openCodeCacheDir(base), "opencode", "models.json"),
		"OPENCODE_TEST_HOME="+filepath.Join(sandboxPath, "home"),
	)
	env = append(env, isolatedOpenCodeFlags...)

	return env
}

func copyOpenCodeAuth(base []string, isolated []string) error {
	sourcePath := filepath.Join(openCodeDataDir(base), "opencode", "auth.json")
	source, err := os.Open(sourcePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("opening opencode auth file: %w", err)
	}
	defer func() {
		_ = source.Close()
	}()

	targetPath := filepath.Join(envValue(isolated, "XDG_DATA_HOME"), "opencode", "auth.json")
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o700); err != nil {
		return fmt.Errorf("creating isolated opencode auth directory: %w", err)
	}

	target, err := os.OpenFile(targetPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return fmt.Errorf("creating isolated opencode auth file: %w", err)
	}
	defer func() {
		_ = target.Close()
	}()

	if _, err := io.Copy(target, source); err != nil {
		return fmt.Errorf("copying opencode auth file: %w", err)
	}

	return nil
}

func validateOpenCodeCredentials(model string, env []string) error {
	provider, _, ok := strings.Cut(model, "/")
	if !ok {
		return nil
	}

	switch provider {
	case "openai":
		if envValue(env, "OPENAI_API_KEY") == "" && !hasOpenCodeAuthProvider(env, provider) {
			return fmt.Errorf(
				"running opencode in isolated mode with %s requires OPENAI_API_KEY or saved opencode auth",
				model,
			)
		}
	}

	return nil
}

func hasOpenCodeAuthProvider(env []string, provider string) bool {
	authPath := filepath.Join(envValue(env, "XDG_DATA_HOME"), "opencode", "auth.json")
	content, err := os.ReadFile(authPath)
	if err != nil {
		return false
	}

	var auth map[string]json.RawMessage
	if err := json.Unmarshal(content, &auth); err != nil {
		return false
	}

	_, ok := auth[provider]
	return ok
}

func openCodeDataDir(env []string) string {
	if dataDir := envValue(env, "XDG_DATA_HOME"); dataDir != "" {
		return dataDir
	}
	if home := envValue(env, "HOME"); home != "" {
		return filepath.Join(home, ".local", "share")
	}
	return filepath.Join(os.TempDir(), "share")
}

func openCodeCacheDir(env []string) string {
	if cacheDir := envValue(env, "XDG_CACHE_HOME"); cacheDir != "" {
		return cacheDir
	}
	if home := envValue(env, "HOME"); home != "" {
		return filepath.Join(home, ".cache")
	}
	if cacheDir, err := os.UserCacheDir(); err == nil {
		return cacheDir
	}
	return filepath.Join(os.TempDir(), "cache")
}

func envValue(env []string, key string) string {
	prefix := key + "="
	for _, item := range env {
		if strings.HasPrefix(item, prefix) {
			return strings.TrimPrefix(item, prefix)
		}
	}
	return ""
}

func opencodeArgs(model string, promptPath string) []string {
	return []string{
		"run",
		"--pure",
		"--model",
		model,
		opencodeRunMessage,
		"--file",
		promptPath,
	}
}

func formatOpenCodeError(err error, stdout string, stderr string) error {
	var details []string

	if trimmed := strings.TrimSpace(stdout); trimmed != "" {
		details = append(details, "stdout:\n"+trimmed)
	}
	if trimmed := strings.TrimSpace(stderr); trimmed != "" {
		details = append(details, "stderr:\n"+trimmed)
	}
	if len(details) == 0 {
		return fmt.Errorf("running opencode: %w", err)
	}

	return fmt.Errorf("running opencode: %w\n%s", err, strings.Join(details, "\n"))
}

// loadSkillOverview reads the Overview section from the git-commit skill file.
func loadSkillOverview() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	skillPath := filepath.Join(
		home,
		".dotfiles",
		"config",
		"agents",
		"skills",
		"git-commit",
		"SKILL.md",
	)
	content, err := os.ReadFile(skillPath)
	if err != nil {
		return ""
	}

	return extractOverviewSection(string(content))
}

// extractOverviewSection extracts the ## Overview section and all its subsections.
func extractOverviewSection(content string) string {
	lines := strings.Split(content, "\n")
	var result []string
	inOverview := false

	for _, line := range lines {
		if strings.HasPrefix(line, "## Overview") {
			inOverview = true
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
