---
name: repo-analyzer
description: Clone and analyze Git repositories to find specific information. Use this skill whenever the user wants to investigate a GitHub/GitLab/Git repository, analyze code from a remote repo, find specific information in a codebase by URL, clone and examine a project, or understand how something works in an external repository. Handles both public and private repos (using user's git credentials), manages a standardized clone location, and delegates analysis to a subagent.
allowed-tools: Bash(*scripts/clone_repo.sh *) Read(~/.local/share/claude/repositories/**)
---

# Repository Analyzer

This skill clones Git repositories to a standardized location and uses a subagent to analyze them and find specific information.

## What This Skill Does

When a user provides a repository URL and a query about that repository, this skill:

1. Parses the repo URL to extract the organization/owner and repository name
2. Sets up an XDG-compliant clone directory
3. Clones the repository (if not already present) or updates it (if already cloned)
4. Optionally checks out a specific branch
5. Launches a subagent to analyze the repository and answer the query
6. Returns the subagent's findings

## Directory Structure

Repositories are cloned to: `$XDG_DATA_HOME/claude/repositories/{platform}/{org}/{repo}`

- `$XDG_DATA_HOME` defaults to `~/.local/share` if not set
- `{platform}` is extracted from the URL (e.g., "github.com", "gitlab.com")
- `{org}` is the repository owner/organization
- `{repo}` is the repository name

**Example:** `https://github.com/torvalds/linux` → `~/.local/share/claude/repositories/github.com/torvalds/linux`

## Step-by-Step Workflow

### Step 1: Clone or Update Repository

Use the provided `clone_repo.sh` script to handle all git operations. This script:

- Parses the repository URL (supports HTTPS, SSH, and short form `owner/repo`)
- Sets up XDG-compliant directory structure
- Clones the repository (if not present) or updates it (if already cloned)
- Optionally checks out a specific branch
- Returns the repository path

**Usage:**

```bash
# Basic usage (clone/update without branch)
skills/repo-analyzer/scripts/clone_repo.sh --url "$REPO_URL"

# With specific branch
scripts/clone_repo.sh --url "$REPO_URL" --branch "$BRANCH"
```

**Examples:**

```bash
# HTTPS URL
scripts/clone_repo.sh --url "https://github.com/torvalds/linux"

# Short form (assumes GitHub)
scripts/clone_repo.sh --url "BurntSushi/ripgrep"

# With branch
scripts/clone_repo.sh --url "tiangolo/fastapi" --branch "dev"
```

**What the script does:**

- Parses URL to extract platform (github.com, gitlab.com, etc.), org, and repo name
- Creates directory at `$XDG_DATA_HOME/claude/repositories/{platform}/{org}/{repo}`
- Uses `git clone --depth 1` for shallow clones (faster, less disk space)
- Updates existing repos with `git fetch` and `git pull`
- Handles authentication via user's git credentials (SSH keys, credential helpers)
- Gracefully continues if pull fails (e.g., detached HEAD, local changes)
- Returns the full repository path to stdout

### Step 2: Launch Subagent for Analysis

Now that the repository is ready, launch a general-purpose subagent to analyze it.
Pass the repository path and the user's query.

Use the Task tool with `subagent_type="general-purpose"`:

**Prompt structure:**

```text
Analyze the repository at: {REPO_PATH}

User's query: {USER_QUERY}

Please explore the codebase and provide a comprehensive answer to the user's question.
You have access to all files in the repository.
Use Read, Glob, and Grep tools to navigate and understand the codebase.
```

The subagent will have full access to read files,
search for patterns, and explore the repository structure.
It should return findings that directly answer the user's query.

### Step 3: Return Findings

Once the subagent completes, present its findings to the user. Include:

- A summary of what was found
- Relevant file paths and line numbers (using the `file:line` format)
- Any code snippets or examples that answer the query
- The repository location for reference: `Repository cloned to: {REPO_PATH}`

This gives the user both the answer and the ability to explore the repository themselves if needed.

## Example Invocations

### Example 1: Analyzing a GitHub repo

```text
User: "Analyze https://github.com/anthropics/anthropic-sdk-python and tell me how to use the messages API"

1. Parse URL → github.com/anthropics/anthropic-sdk-python
2. Clone to ~/.local/share/claude/repositories/github.com/anthropics/anthropic-sdk-python
3. Launch subagent with query: "How to use the messages API"
4. Return findings with examples and file references
```

### Example 2: Checking a specific branch

```text
User: "Look at the 'dev' branch of myorg/myrepo on GitHub and find the new authentication code"

1. Parse URL → github.com/myorg/myrepo
2. Clone/update repo
3. Checkout 'dev' branch
4. Launch subagent with query: "Find the new authentication code"
5. Return findings
```

### Example 3: Short form URL

```text
User: "Investigate django/django and explain how their ORM query optimization works"

1. Assume GitHub → github.com/django/django
2. Clone to ~/.local/share/claude/repositories/github.com/django/django
3. Launch subagent with query: "Explain how ORM query optimization works"
4. Return findings
```

## Error Handling

Handle common failure cases gracefully:

- **Invalid URL format:** Inform user and ask for a valid Git URL
- **Clone failure:** Report the git error (e.g., repo doesn't exist, authentication failed)
- **Branch doesn't exist:** Report error and list available branches if possible
- **Subagent timeout:** If analysis takes too long, inform user and suggest narrowing the query

## Tips for Better Results

- Be specific with queries: "How does authentication work?" is better than "Explain the code"
- Mention specific files or directories if known: "Analyze the src/api/ directory"
- For large repos, narrow the scope: "Focus on the payment processing module"
- If the first analysis isn't enough, the user can ask follow-up questions (repo is already cloned)
