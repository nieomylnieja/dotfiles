package internal

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
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
	defaultOpenCodeModel = "openai/gpt-5.3-codex"
	opencodeConfigName   = "opencode.json"
	opencodePromptName   = "commit-prompt.md"
	opencodeRunMessage   = "Read the attached file and respond with only the commit message text."
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

// OpenCodeClient implements LLMClient through an isolated opencode CLI invocation.
type OpenCodeClient struct {
	model    string
	overview string
}

type openCodeRuntime struct {
	rootDir    string
	workDir    string
	configHome string
	configDir  string
	dataHome   string
	stateHome  string
	configPath string
	promptPath string
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
	underline.Println("\nChanges analyzed!")

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
	runtime, err := newOpenCodeRuntime(c.model, prompt)
	if err != nil {
		return "", err
	}
	defer func() {
		_ = os.RemoveAll(runtime.rootDir)
	}()

	cmd := exec.CommandContext(ctx, "opencode", runtime.commandArgs(c.model)...)
	cmd.Dir = runtime.workDir
	cmd.Env = runtime.commandEnv()

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

func newOpenCodeRuntime(model string, prompt string) (*openCodeRuntime, error) {
	timestamp := time.Now().UTC().Format("20060102T150405Z")
	rootDir, err := os.MkdirTemp("", "llmcommit-opencode-"+timestamp+"-")
	if err != nil {
		return nil, fmt.Errorf("creating temporary opencode runtime: %w", err)
	}

	runtime := &openCodeRuntime{
		rootDir:    rootDir,
		workDir:    filepath.Join(rootDir, "workdir"),
		configHome: filepath.Join(rootDir, "config"),
		configDir:  filepath.Join(rootDir, "config-dir"),
		dataHome:   filepath.Join(rootDir, "data"),
		stateHome:  filepath.Join(rootDir, "state"),
		configPath: filepath.Join(rootDir, opencodeConfigName),
		promptPath: filepath.Join(rootDir, opencodePromptName),
	}

	if err := runtime.prepare(model, prompt); err != nil {
		_ = os.RemoveAll(rootDir)
		return nil, err
	}

	return runtime, nil
}

func (r *openCodeRuntime) prepare(model string, prompt string) error {
	for _, dir := range []string{
		r.workDir,
		r.configHome,
		r.configDir,
		r.dataHome,
		r.stateHome,
	} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			return fmt.Errorf("creating opencode directory %s: %w", dir, err)
		}
	}

	configBody, err := bareOpenCodeConfig(model)
	if err != nil {
		return err
	}
	if err := os.WriteFile(r.configPath, configBody, 0o600); err != nil {
		return fmt.Errorf("writing opencode config: %w", err)
	}
	if err := os.WriteFile(r.promptPath, []byte(prompt), 0o600); err != nil {
		return fmt.Errorf("writing opencode prompt: %w", err)
	}
	if err := copyOpenCodeAuth(r.dataHome); err != nil {
		return err
	}

	return nil
}

func (r *openCodeRuntime) commandArgs(model string) []string {
	return []string{
		"run",
		"--pure",
		"--agent",
		"build",
		"--model",
		model,
		opencodeRunMessage,
		"--file",
		r.promptPath,
	}
}

func (r *openCodeRuntime) commandEnv() []string {
	return append(
		os.Environ(),
		"HOME="+r.rootDir,
		"XDG_CONFIG_HOME="+r.configHome,
		"XDG_DATA_HOME="+r.dataHome,
		"XDG_STATE_HOME="+r.stateHome,
		"OPENCODE_CONFIG="+r.configPath,
		"OPENCODE_CONFIG_DIR="+r.configDir,
		"OPENCODE_DISABLE_CLAUDE_CODE=1",
		"OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1",
		"OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1",
		"OPENCODE_DISABLE_DEFAULT_PLUGINS=1",
	)
}

func bareOpenCodeConfig(model string) ([]byte, error) {
	config := map[string]any{
		"$schema":       "https://opencode.ai/config.json",
		"autoupdate":    false,
		"default_agent": "build",
		"instructions":  []string{},
		"mcp":           map[string]any{},
		"model":         model,
		"plugin":        []string{},
		"share":         "disabled",
		"snapshot":      false,
		"tools": map[string]bool{
			"skill": false,
		},
	}
	if providerConfig := bareProviderConfig(model); providerConfig != nil {
		config["provider"] = providerConfig
	}

	body, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("encoding opencode config: %w", err)
	}

	return append(body, '\n'), nil
}

func bareProviderConfig(model string) map[string]any {
	providerID, modelID, ok := strings.Cut(model, "/")
	if !ok {
		return nil
	}

	switch providerID {
	case "openai":
		return map[string]any{
			"openai": map[string]any{
				"models": map[string]any{
					modelID: map[string]any{
						"options": map[string]string{
							"reasoningEffort": "high",
							"textVerbosity":   "low",
						},
					},
				},
			},
		}
	default:
		return nil
	}
}

func copyOpenCodeAuth(targetDataHome string) error {
	sourcePath, err := sourceOpenCodeAuthPath()
	if err != nil {
		return err
	}
	if sourcePath == "" {
		return nil
	}

	content, err := os.ReadFile(sourcePath)
	if err != nil {
		return fmt.Errorf("reading opencode auth from %s: %w", sourcePath, err)
	}

	targetPath := filepath.Join(targetDataHome, "opencode", "auth.json")
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o700); err != nil {
		return fmt.Errorf("creating opencode auth directory: %w", err)
	}
	if err := os.WriteFile(targetPath, content, 0o600); err != nil {
		return fmt.Errorf("writing opencode auth file: %w", err)
	}

	return nil
}

func sourceOpenCodeAuthPath() (string, error) {
	dataHome := strings.TrimSpace(os.Getenv("XDG_DATA_HOME"))
	if dataHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolving home dir for opencode auth: %w", err)
		}
		dataHome = filepath.Join(home, ".local", "share")
	}

	sourcePath := filepath.Join(dataHome, "opencode", "auth.json")
	if _, err := os.Stat(sourcePath); err != nil {
		if os.IsNotExist(err) {
			return "", nil
		}
		return "", fmt.Errorf("checking opencode auth file %s: %w", sourcePath, err)
	}

	return sourcePath, nil
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
