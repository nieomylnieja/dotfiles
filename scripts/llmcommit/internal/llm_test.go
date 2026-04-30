package internal

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_isolatedOpenCodeEnv(t *testing.T) {
	t.Parallel()

	sandboxPath := filepath.Join(t.TempDir(), "opencode")
	base := []string{
		"HOME=/home/mh",
		"OPENAI_API_KEY=keep",
		"OPENCODE_CONFIG=/home/mh/.config/opencode/opencode.json",
		"OPENCODE_CONFIG_CONTENT={\"mcp\":{\"bad\":{\"enabled\":true}}}",
		"OPENCODE_CONFIG_DIR=/home/mh/.opencode",
		"OPENCODE_PERMISSION={\"bash\":\"allow\"}",
		"XDG_CONFIG_HOME=/home/mh/.config",
		"XDG_DATA_HOME=/home/mh/.local/share",
		"XDG_STATE_HOME=/home/mh/.local/state",
		"XDG_CACHE_HOME=/home/mh/.cache",
	}

	got := envMap(isolatedOpenCodeEnv(base, sandboxPath))

	if got["OPENAI_API_KEY"] != "keep" {
		t.Fatalf("expected provider credentials to be preserved, got %q", got["OPENAI_API_KEY"])
	}
	for key := range got {
		if strings.HasPrefix(key, "OPENCODE_") && !allowedIsolatedOpenCodeKey(key) {
			t.Fatalf("unexpected inherited opencode env var %s=%q", key, got[key])
		}
	}

	expected := map[string]string{
		"XDG_CONFIG_HOME":                  filepath.Join(sandboxPath, "config"),
		"XDG_DATA_HOME":                    filepath.Join(sandboxPath, "data"),
		"XDG_STATE_HOME":                   filepath.Join(sandboxPath, "state"),
		"XDG_CACHE_HOME":                   "/home/mh/.cache",
		"OPENCODE_TEST_HOME":               filepath.Join(sandboxPath, "home"),
		"OPENCODE_MODELS_PATH":             "/home/mh/.cache/opencode/models.json",
		"OPENCODE_DISABLE_DEFAULT_PLUGINS": "1",
		"OPENCODE_DISABLE_PROJECT_CONFIG":  "1",
		"OPENCODE_DISABLE_EXTERNAL_SKILLS": "1",
		"OPENCODE_DISABLE_CLAUDE_CODE":     "1",
		"OPENCODE_DISABLE_LSP_DOWNLOAD":    "1",
		"OPENCODE_DISABLE_AUTOUPDATE":      "1",
		"OPENCODE_DISABLE_AUTOCOMPACT":     "1",
		"OPENCODE_DISABLE_PRUNE":           "1",
		"OPENCODE_PURE":                    "1",
	}
	for key, want := range expected {
		if got[key] != want {
			t.Fatalf("%s = %q, want %q", key, got[key], want)
		}
	}
}

func Test_validateOpenCodeCredentials(t *testing.T) {
	t.Parallel()

	authDir := filepath.Join(t.TempDir(), "share", "opencode")
	if err := os.MkdirAll(authDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(authDir, "auth.json"), []byte(`{"openai":{"type":"api","key":"test"}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	otherAuthDir := filepath.Join(t.TempDir(), "share", "opencode")
	if err := os.MkdirAll(otherAuthDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(otherAuthDir, "auth.json"), []byte(`{"anthropic":{"type":"api","key":"test"}}`), 0o600); err != nil {
		t.Fatal(err)
	}

	tests := map[string]struct {
		model   string
		env     []string
		wantErr bool
	}{
		"openai with key": {
			model:   "openai/gpt-5.5",
			env:     []string{"OPENAI_API_KEY=secret"},
			wantErr: false,
		},
		"openai with saved auth": {
			model:   "openai/gpt-5.5",
			env:     []string{"XDG_DATA_HOME=" + filepath.Dir(authDir)},
			wantErr: false,
		},
		"openai with different saved auth": {
			model:   "openai/gpt-5.5",
			env:     []string{"XDG_DATA_HOME=" + filepath.Dir(otherAuthDir)},
			wantErr: true,
		},
		"openai without credentials": {
			model:   "openai/gpt-5.5",
			env:     nil,
			wantErr: true,
		},
		"non provider model": {
			model:   "gpt-5.5",
			env:     nil,
			wantErr: false,
		},
	}

	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			err := validateOpenCodeCredentials(tt.model, tt.env)
			if tt.wantErr && err == nil {
				t.Fatalf("expected error")
			}
			if !tt.wantErr && err != nil {
				t.Fatalf("expected no error, got %v", err)
			}
		})
	}
}

func Test_copyOpenCodeAuth(t *testing.T) {
	t.Parallel()

	baseData := filepath.Join(t.TempDir(), "source")
	sourceDir := filepath.Join(baseData, "opencode")
	if err := os.MkdirAll(sourceDir, 0o700); err != nil {
		t.Fatal(err)
	}
	sourceContent := []byte(`{"openai":{"type":"api","key":"test"}}`)
	if err := os.WriteFile(filepath.Join(sourceDir, "auth.json"), sourceContent, 0o600); err != nil {
		t.Fatal(err)
	}

	targetData := filepath.Join(t.TempDir(), "target")
	err := copyOpenCodeAuth(
		[]string{"XDG_DATA_HOME=" + baseData},
		[]string{"XDG_DATA_HOME=" + targetData},
	)
	if err != nil {
		t.Fatal(err)
	}

	targetPath := filepath.Join(targetData, "opencode", "auth.json")
	got, err := os.ReadFile(targetPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(sourceContent) {
		t.Fatalf("copied auth content = %q, want %q", got, sourceContent)
	}

	info, err := os.Stat(targetPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("copied auth permissions = %v, want 0600", info.Mode().Perm())
	}
}

func Test_writeOpenCodeConfig(t *testing.T) {
	t.Parallel()

	configHome := filepath.Join(t.TempDir(), "config")
	err := writeOpenCodeConfig(
		[]string{"XDG_CONFIG_HOME=" + configHome},
		"openai/gpt-5.5",
	)
	if err != nil {
		t.Fatal(err)
	}

	configPath := filepath.Join(configHome, "opencode", "opencode.json")
	content, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}

	var config map[string]any
	if err := json.Unmarshal(content, &config); err != nil {
		t.Fatal(err)
	}

	provider := config["provider"].(map[string]any)["openai"].(map[string]any)
	model := provider["models"].(map[string]any)["gpt-5.5"].(map[string]any)
	options := model["options"].(map[string]any)
	if options["textVerbosity"] != "medium" {
		t.Fatalf("textVerbosity = %q, want medium", options["textVerbosity"])
	}

	variant := model["variants"].(map[string]any)["low"].(map[string]any)
	if variant["reasoningEffort"] != "low" {
		t.Fatalf("reasoningEffort = %q, want low", variant["reasoningEffort"])
	}
	if variant["textVerbosity"] != "medium" {
		t.Fatalf("variant textVerbosity = %q, want medium", variant["textVerbosity"])
	}
}

func Test_writeOpenCodeConfig_skipsNonOpenAIGPT5Models(t *testing.T) {
	t.Parallel()

	configHome := filepath.Join(t.TempDir(), "config")
	err := writeOpenCodeConfig(
		[]string{"XDG_CONFIG_HOME=" + configHome},
		"anthropic/claude-sonnet-4-5",
	)
	if err != nil {
		t.Fatal(err)
	}

	configPath := filepath.Join(configHome, "opencode", "opencode.json")
	if _, err := os.Stat(configPath); !os.IsNotExist(err) {
		t.Fatalf("expected no config file, got err %v", err)
	}
}

func Test_opencodeArgs(t *testing.T) {
	t.Parallel()

	got := opencodeArgs("openai/gpt-5.5", "/tmp/prompt.md")
	want := []string{
		"run",
		"--pure",
		"--model",
		"openai/gpt-5.5",
		"--variant",
		"low",
		opencodeRunMessage,
		"--file",
		"/tmp/prompt.md",
	}
	if strings.Join(got, "\x00") != strings.Join(want, "\x00") {
		t.Fatalf("opencodeArgs = %#v, want %#v", got, want)
	}

	got = opencodeArgs("anthropic/claude-sonnet-4-5", "/tmp/prompt.md")
	for _, arg := range got {
		if arg == "--variant" {
			t.Fatalf("expected no variant for non-OpenAI GPT-5 model, got %#v", got)
		}
	}
}

func envMap(env []string) map[string]string {
	result := make(map[string]string, len(env))
	for _, item := range env {
		key, value, ok := strings.Cut(item, "=")
		if ok {
			result[key] = value
		}
	}
	return result
}

func allowedIsolatedOpenCodeKey(key string) bool {
	for _, item := range isolatedOpenCodeFlags {
		flagKey, _, _ := strings.Cut(item, "=")
		if key == flagKey {
			return true
		}
	}
	return key == "OPENCODE_TEST_HOME" || key == "OPENCODE_MODELS_PATH"
}
