# Ralphy

![Ralphy](assets/ralphy.jpeg)

An autonomous AI coding loop that runs AI assistants (Claude Code, OpenCode, Codex, or Cursor) to work through tasks until everything is complete.

**This fork adds [`create-prd.sh`](#create-prd) - a script that generates PRD files using AI before running Ralphy.**

## Installation

```bash
# Clone this repo
git clone https://github.com/AliMejbar/ralphy.git ~/ai-scripts

# Make scripts executable
chmod +x ~/ai-scripts/ralphy.sh ~/ai-scripts/create-prd.sh

# Add to PATH (add this to your ~/.zshrc)
export PATH="$HOME/ai-scripts:$PATH"

# Reload shell
source ~/.zshrc

# Now use from any project
create-prd.sh "Add user authentication with OAuth"
ralphy.sh
```

Or run the install script:
```bash
~/ai-scripts/install.sh
```

---

## Create-PRD

Generate a PRD file using AI before running Ralphy.

### Usage

```bash
# Basic usage - generates PRD.md in current directory
create-prd.sh "Add user authentication with OAuth support"

# With a feature name (used for branch naming)
create-prd.sh --feature auth "Add user authentication"

# Use a specific AI engine
create-prd.sh --opencode "Add dashboard analytics"
create-prd.sh --cursor "Build API endpoints"
create-prd.sh --codex "Create database models"

# Skip branch creation
create-prd.sh --no-branch "Quick feature"

# Custom output paths
create-prd.sh --prd tasks.md --progress log.txt "My feature"
```

### What It Does

1. **Creates a feature branch** (e.g., `feature/add-user-authentication`)
2. **Analyzes your codebase** to understand file structure and patterns
3. **Generates a structured PRD** with:
   - Phased tasks with checkboxes
   - Absolute file paths for each task
   - Key file references
   - Important patterns to follow
4. **Creates a blank `progress.txt`** for Ralphy to log progress

### Options

| Flag | Description |
|------|-------------|
| `--claude` | Use Claude Code (default) |
| `--opencode` | Use OpenCode |
| `--cursor` | Use Cursor agent |
| `--codex` | Use Codex CLI |
| `--prompt TEXT` | Feature prompt (can also be passed as argument) |
| `--feature NAME` | Short feature name for branch slug |
| `--branch NAME` | Specific branch name to use/create |
| `--no-branch` | Skip branch checks/creation |
| `--prd PATH` | PRD output path (default: PRD.md) |
| `--progress PATH` | Progress file path (default: progress.txt) |

### Example Workflow

```bash
# Step 1: Generate the PRD
cd ~/my-project
create-prd.sh "Add a dark mode toggle to the settings page"

# Step 2: Review the generated PRD
cat PRD.md

# Step 3: Run Ralphy to implement it
ralphy.sh
```

---

## Ralphy

An autonomous AI coding loop that runs AI assistants to work through tasks.

### What It Does

1. Reads tasks from a PRD file, YAML file, or GitHub Issues
2. Sends each task to an AI assistant
3. The AI implements the feature, writes tests, and commits changes
4. Repeats until all tasks are done

### Quick Start

```bash
# Create a PRD file with tasks (or use create-prd.sh)
cat > PRD.md << 'EOF'
# My Project

## Tasks
- [ ] Create user authentication
- [ ] Add dashboard page
- [ ] Build API endpoints
EOF

# Run Ralphy
ralphy.sh
```

That's it. Ralphy will work through each task autonomously.

### Requirements

**Required:**
- One of: [Claude Code CLI](https://github.com/anthropics/claude-code), [OpenCode CLI](https://opencode.ai/docs/), Codex CLI, or [Cursor](https://cursor.com) (with `agent` in PATH)
- `jq` (for JSON parsing)

**Optional:**
- `yq` - only if using YAML task files
- `gh` - only if using GitHub Issues or `--create-pr`
- `bc` - for cost calculation

### Task Sources

#### Markdown (default)

```bash
ralphy.sh --prd PRD.md
```

Format your PRD like this:
```markdown
## Tasks
- [ ] First task
- [ ] Second task
- [x] Completed task (will be skipped)
```

#### YAML

```bash
ralphy.sh --yaml tasks.yaml
```

Format:
```yaml
tasks:
  - title: First task
    completed: false
  - title: Second task
    completed: false
```

#### GitHub Issues

```bash
ralphy.sh --github owner/repo
ralphy.sh --github owner/repo --github-label "ready"
```

Uses open issues from the repo. Issues are closed automatically when done.

### Parallel Mode

Run multiple AI agents simultaneously, each in its own isolated git worktree:

```bash
ralphy.sh --parallel                    # 3 agents (default)
ralphy.sh --parallel --max-parallel 5   # 5 agents
```

#### How It Works

Each agent gets:
- Its own git worktree (separate directory)
- Its own branch (`ralphy/agent-1-task-name`, `ralphy/agent-2-task-name`, etc.)
- Complete isolation from other agents

```
Agent 1 ─► worktree: /tmp/xxx/agent-1 ─► branch: ralphy/agent-1-create-user-model
Agent 2 ─► worktree: /tmp/xxx/agent-2 ─► branch: ralphy/agent-2-add-api-endpoints
Agent 3 ─► worktree: /tmp/xxx/agent-3 ─► branch: ralphy/agent-3-setup-database
```

#### After Completion

**Without `--create-pr`:** Branches are automatically merged back to your base branch. If there are merge conflicts, AI will attempt to resolve them.

**With `--create-pr`:** Each completed task gets its own pull request. Branches are kept for review.

```bash
ralphy.sh --parallel --create-pr          # Create PRs for each task
ralphy.sh --parallel --create-pr --draft-pr  # Create draft PRs
```

#### YAML Parallel Groups

Control which tasks can run together:

```yaml
tasks:
  - title: Create User model
    parallel_group: 1
  - title: Create Post model
    parallel_group: 1  # Runs with User model (same group)
  - title: Add relationships
    parallel_group: 2  # Runs after group 1 completes
```

Tasks without `parallel_group` default to group `0` and run before higher-numbered groups.

### Branch Workflow

Create a separate branch for each task:

```bash
ralphy.sh --branch-per-task                        # Create feature branches
ralphy.sh --branch-per-task --base-branch main     # Branch from main
ralphy.sh --branch-per-task --create-pr            # Create PRs automatically
ralphy.sh --branch-per-task --create-pr --draft-pr # Create draft PRs
```

Branch naming: `ralphy/<task-name-slug>`

Example: "Add user authentication" becomes `ralphy/add-user-authentication`

### AI Engine

```bash
ralphy.sh              # Claude Code (default)
ralphy.sh --codex      # Codex CLI
ralphy.sh --opencode   # OpenCode
ralphy.sh --cursor     # Cursor agent
```

#### Engine Details

| Engine | CLI Command | Permissions Flag | Output |
|--------|-------------|------------------|--------|
| Claude Code | `claude` | `--dangerously-skip-permissions` | Token usage + cost estimate |
| OpenCode | `opencode` | `OPENCODE_PERMISSION='{"*":"allow"}'` | Token usage + actual cost |
| Codex | `codex` | N/A | Token usage (if provided) |
| Cursor | `agent` | `--force` | API duration (no token counts) |

**Note:** Cursor's CLI doesn't expose token usage, so Ralphy tracks total API duration instead.

### All Options

#### AI Engine
| Flag | Description |
|------|-------------|
| `--claude` | Use Claude Code (default) |
| `--codex` | Use Codex CLI |
| `--opencode` | Use OpenCode |
| `--cursor`, `--agent` | Use Cursor agent |

#### Task Source
| Flag | Description |
|------|-------------|
| `--prd FILE` | PRD file path (default: PRD.md) |
| `--yaml FILE` | Use YAML task file |
| `--github REPO` | Fetch from GitHub issues (owner/repo) |
| `--github-label TAG` | Filter GitHub issues by label |

#### Parallel Execution
| Flag | Description |
|------|-------------|
| `--parallel` | Run tasks in parallel |
| `--max-parallel N` | Max concurrent agents (default: 3) |

#### Git Branches
| Flag | Description |
|------|-------------|
| `--branch-per-task` | Create a branch for each task |
| `--base-branch NAME` | Base branch (default: current branch) |
| `--create-pr` | Create pull requests |
| `--draft-pr` | Create PRs as drafts |

#### Workflow
| Flag | Description |
|------|-------------|
| `--no-tests` | Skip tests |
| `--no-lint` | Skip linting |
| `--fast` | Skip both tests and linting |

#### Execution Control
| Flag | Description |
|------|-------------|
| `--max-iterations N` | Stop after N tasks (0 = unlimited) |
| `--max-retries N` | Retries per task on failure (default: 3) |
| `--retry-delay N` | Seconds between retries (default: 5) |
| `--dry-run` | Preview without executing |

#### Other
| Flag | Description |
|------|-------------|
| `-v, --verbose` | Debug output |
| `-h, --help` | Show help |
| `--version` | Show version |

### Examples

```bash
# Basic usage
ralphy.sh

# Basic usage with Codex
ralphy.sh --codex

# Fast mode with OpenCode
ralphy.sh --opencode --fast

# Use Cursor agent
ralphy.sh --cursor

# Cursor with parallel execution
ralphy.sh --cursor --parallel --max-parallel 4

# Parallel with 4 agents and auto-PRs
ralphy.sh --parallel --max-parallel 4 --create-pr

# GitHub issues with parallel execution
ralphy.sh --github myorg/myrepo --parallel

# Feature branch workflow
ralphy.sh --branch-per-task --create-pr --base-branch main

# Limited iterations with draft PRs
ralphy.sh --max-iterations 5 --branch-per-task --create-pr --draft-pr

# Preview what would happen
ralphy.sh --dry-run --verbose
```

### Progress Display

While running, you'll see:
- A spinner with the current step (Thinking, Reading, Implementing, Testing, Committing)
- The current task name
- Elapsed time

In parallel mode:
- Number of agents setting up, running, done, and failed
- Final results with branch names
- Error logs for any failed agents

### Cost Tracking

At completion, Ralphy shows different metrics depending on the AI engine:

| Engine | Metrics Shown |
|--------|---------------|
| Claude Code | Input/output tokens, estimated cost |
| OpenCode | Input/output tokens, actual cost |
| Codex | Input/output tokens (if provided) |
| Cursor | Total API duration (tokens not available) |

All engines show branches created (if using `--branch-per-task`).

---

## Keeping in Sync with Upstream

This fork tracks the original [michaelshimeles/ralphy](https://github.com/michaelshimeles/ralphy). To get updates:

```bash
cd ~/ai-scripts
git fetch upstream
git merge upstream/main
git push origin main
```

---

## Changelog

### Fork Changes
- Added `create-prd.sh` for PRD generation before running Ralphy
- Added `install.sh` for easy global installation
- Updated documentation with both scripts

### v3.1.0
- Added Cursor agent support (`--cursor` or `--agent` flag)
- Cursor uses `--print --force` flags for non-interactive execution
- Track API duration for Cursor (token counts not available in Cursor CLI)
- Improved task completion verification (checks actual PRD state, not just AI output)
- Fixed display issues with task counts

### v3.0.1
- Parallel agents now run in isolated git worktrees
- Auto-merge branches when not using `--create-pr`
- AI-powered merge conflict resolution
- Real-time parallel status display (setup/running/done/failed)
- Show error logs for failed agents
- Improved worktree creation with detailed logging

### v3.0.0
- Added parallel task execution (`--parallel`, `--max-parallel`)
- Added git branch per task (`--branch-per-task`, `--create-pr`, `--draft-pr`)
- Added multiple PRD formats (Markdown, YAML, GitHub Issues)
- Added YAML parallel groups

### v2.0.0
- Added OpenCode support (`--opencode`)
- Added retry logic
- Added `--max-iterations`, `--dry-run`, `--verbose`
- Cross-platform notifications

### v1.0.0
- Initial release

## License

MIT
