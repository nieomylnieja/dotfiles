package internal

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_OpenCodeClientRenderPrompt_includesSemanticCommitRules(t *testing.T) {
	t.Parallel()

	client := &OpenCodeClient{model: defaultOpenCodeModel}
	diff := "diff --git a/config.nix b/config.nix\n+new setting"
	prompt, err := client.renderPrompt(diff, []string{"flake.nix", "flake.lock"})
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"<type>: <description>",
		"`feat`", "`fix`", "`docs`", "`style`", "`refactor`", "`perf`",
		"`test`", "`build`", "`ci`", "`chore`", "`revert`",
		diff,
		"flake.nix, flake.lock",
	} {
		if !strings.Contains(prompt, want) {
			t.Errorf("renderPrompt() is missing %q", want)
		}
	}
}

func Test_OpenCodeClientCallOpenCode_requiresSemanticSubject(t *testing.T) {
	binDir := t.TempDir()
	script := "#!/bin/sh\nprintf '%s\\n' \"$LLMCOMMIT_TEST_RESPONSE\"\n"
	if err := os.WriteFile(filepath.Join(binDir, "opencode"), []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", binDir+string(os.PathListSeparator)+os.Getenv("PATH"))

	client := &OpenCodeClient{model: defaultOpenCodeModel}
	type testCase struct {
		name    string
		message string
		wantErr bool
	}
	tests := []testCase{
		{name: "missing type", message: "Add writing-for-agents skill", wantErr: true},
		{name: "unknown type", message: "commit: update settings", wantErr: true},
		{name: "missing separator space", message: "chore:update settings", wantErr: true},
		{name: "empty description", message: "fix: ", wantErr: true},
		{name: "body cannot replace description", message: "fix: \n\nrestore prefix", wantErr: true},
		{name: "prefix only in body", message: "Update settings\n\nchore: update settings", wantErr: true},
		{name: "body", message: "fix: restore semantic commits\n\nKeep message rules in the embedded prompt."},
	}
	for _, commitType := range []string{
		"feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert",
	} {
		tests = append(tests, testCase{name: commitType, message: commitType + ": update settings"})
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Setenv("LLMCOMMIT_TEST_RESPONSE", tt.message)
			got, err := client.callOpenCode(t.Context(), "prompt")
			if tt.wantErr {
				if err == nil {
					t.Fatalf("callOpenCode() accepted invalid subject %q", tt.message)
				}
				if got != "" {
					t.Errorf("callOpenCode() returned invalid message %q", got)
				}
				if !strings.Contains(err.Error(), "semantic commit subject") {
					t.Errorf("callOpenCode() error = %v, want semantic commit subject error", err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if got != tt.message {
				t.Errorf("callOpenCode() = %q, want %q", got, tt.message)
			}
		})
	}
}

func Test_opencodeArgs(t *testing.T) {
	t.Parallel()

	got := opencodeArgs("openai/gpt-5.4", "/tmp/prompt.md")
	want := []string{
		"run",
		"--pure",
		"--model",
		"openai/gpt-5.4",
		"--variant",
		"low",
		opencodeRunMessage,
		"--file",
		"/tmp/prompt.md",
	}
	if strings.Join(got, "\x00") != strings.Join(want, "\x00") {
		t.Fatalf("opencodeArgs = %#v, want %#v", got, want)
	}

	got = opencodeArgs("gpt-5.4-fast", "/tmp/prompt.md")
	want[3] = "gpt-5.4-fast"
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

func Test_OpenCodeClientCallOpenCode_usesDirectOpencodeInvocation(t *testing.T) {
	tempDir := t.TempDir()
	binDir := filepath.Join(tempDir, "bin")
	if err := os.MkdirAll(binDir, 0o700); err != nil {
		t.Fatal(err)
	}

	argsPath := filepath.Join(tempDir, "args")
	envPath := filepath.Join(tempDir, "env")
	script := strings.Join([]string{
		"#!/bin/sh",
		`printf '%s\n' "$@" > "$LLMCOMMIT_CAPTURE_ARGS"`,
		`env > "$LLMCOMMIT_CAPTURE_ENV"`,
		`printf 'chore: direct opencode path\n'`,
	}, "\n")
	if err := os.WriteFile(filepath.Join(binDir, "opencode"), []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}

	t.Setenv("PATH", binDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("LLMCOMMIT_CAPTURE_ARGS", argsPath)
	t.Setenv("LLMCOMMIT_CAPTURE_ENV", envPath)
	t.Setenv("OPENCODE_DISABLE_PROJECT_CONFIG", "")
	t.Setenv("OPENCODE_MODELS_PATH", "")
	t.Setenv("OPENCODE_TEST_HOME", "")

	client := &OpenCodeClient{model: defaultOpenCodeModel}
	got, err := client.callOpenCode(t.Context(), "prompt")
	if err != nil {
		t.Fatal(err)
	}
	if got != "chore: direct opencode path" {
		t.Fatalf("callOpenCode() = %q, want %q", got, "chore: direct opencode path")
	}

	content, err := os.ReadFile(argsPath)
	if err != nil {
		t.Fatal(err)
	}
	args := strings.Split(strings.TrimSpace(string(content)), "\n")
	model, ok := argAfter(args, "--model")
	if !ok {
		t.Fatalf("expected --model arg, got %#v", args)
	}
	if model != defaultOpenCodeModel {
		t.Fatalf("--model = %q, want %q", model, defaultOpenCodeModel)
	}
	variant, ok := argAfter(args, "--variant")
	if !ok {
		t.Fatalf("expected --variant arg, got %#v", args)
	}
	if variant != defaultOpenCodeReasoningEffort {
		t.Fatalf("--variant = %q, want %q", variant, defaultOpenCodeReasoningEffort)
	}

	env, err := os.ReadFile(envPath)
	if err != nil {
		t.Fatal(err)
	}
	for _, unwanted := range []string{
		"OPENCODE_DISABLE_PROJECT_CONFIG=1",
		"OPENCODE_MODELS_PATH=" + tempDir,
		"OPENCODE_TEST_HOME=" + tempDir,
	} {
		if strings.Contains(string(env), unwanted) {
			t.Fatalf("callOpenCode set unwanted env %q in:\n%s", unwanted, env)
		}
	}
}

func Test_OpenCodeClientCleanResponse(t *testing.T) {
	t.Parallel()

	client := &OpenCodeClient{}
	got := client.cleanResponse(strings.Join([]string{
		"commit: keep this",
		"```",
		"drop this",
		"```",
		"",
	}, "\n"))

	if got != "commit: keep this" {
		t.Fatalf("cleanResponse() = %q, want %q", got, "commit: keep this")
	}
}

func argAfter(args []string, key string) (string, bool) {
	for i, arg := range args {
		if arg == key && i+1 < len(args) {
			return args[i+1], true
		}
	}
	return "", false
}
