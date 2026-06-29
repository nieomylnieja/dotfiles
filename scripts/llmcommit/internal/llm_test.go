package internal

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

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
		`printf 'commit: direct opencode path\n'`,
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
	if got != "commit: direct opencode path" {
		t.Fatalf("callOpenCode() = %q, want %q", got, "commit: direct opencode path")
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
