#!/usr/bin/env bash
set -euo pipefail

AI_ENGINE="claude"
PRD_FILE="PRD.md"
PROGRESS_FILE="progress.txt"
PROMPT=""
FEATURE_NAME=""
BRANCH_NAME=""
CREATE_BRANCH=true
REPO_ROOT=""
STDIN_SOURCE=""

log_info() {
  echo "[INFO] $*"
}

log_warn() {
  echo "[WARN] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

usage() {
  cat <<'EOF'
Usage: scripts/create-prd.sh [options] -- "feature prompt"

Options:
  --claude           Use Claude Code (default)
  --opencode         Use OpenCode
  --cursor           Use Cursor agent
  --codex            Use Codex CLI
  --prompt TEXT      Feature prompt (if omitted, read from args/stdin)
  --feature NAME     Short feature name for branch slug
  --branch NAME      Branch name to use/create
  --no-branch        Skip branch checks/creation
  --prd PATH         PRD output path (default: PRD.md)
  --progress PATH    Progress file path (default: progress.txt)
  -h, --help         Show this help
EOF
}

resolve_stdin_source() {
  if [[ -r /dev/tty ]] && { [[ -t 0 ]] || [[ -t 1 ]] || [[ -t 2 ]]; }; then
    STDIN_SOURCE="/dev/tty"
  else
    STDIN_SOURCE="/dev/null"
  fi
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c1-50
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --claude)
        AI_ENGINE="claude"
        shift
        ;;
      --opencode)
        AI_ENGINE="opencode"
        shift
        ;;
      --cursor)
        AI_ENGINE="cursor"
        shift
        ;;
      --codex)
        AI_ENGINE="codex"
        shift
        ;;
      --prompt)
        PROMPT="${2:-}"
        shift 2
        ;;
      --feature|--name)
        FEATURE_NAME="${2:-}"
        shift 2
        ;;
      --branch)
        BRANCH_NAME="${2:-}"
        shift 2
        ;;
      --no-branch)
        CREATE_BRANCH=false
        shift
        ;;
      --prd)
        PRD_FILE="${2:-PRD.md}"
        shift 2
        ;;
      --progress)
        PROGRESS_FILE="${2:-progress.txt}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        if [[ -z "$PROMPT" ]]; then
          PROMPT="$*"
        fi
        break
        ;;
      *)
        if [[ -z "$PROMPT" ]]; then
          PROMPT="$1"
        else
          PROMPT="$PROMPT $1"
        fi
        shift
        ;;
    esac
  done
}

check_requirements() {
  case "$AI_ENGINE" in
    opencode)
      command -v opencode >/dev/null 2>&1 || {
        log_error "OpenCode CLI not found."
        exit 1
      }
      ;;
    cursor)
      command -v agent >/dev/null 2>&1 || {
        log_error "Cursor agent CLI not found."
        exit 1
      }
      ;;
    codex)
      command -v codex >/dev/null 2>&1 || {
        log_error "Codex CLI not found."
        exit 1
      }
      ;;
    *)
      command -v claude >/dev/null 2>&1 || {
        log_error "Claude Code CLI not found."
        exit 1
      }
      ;;
  esac

  if [[ "$AI_ENGINE" != "codex" ]]; then
    command -v jq >/dev/null 2>&1 || {
      log_error "jq is required for parsing $AI_ENGINE output."
      exit 1
    }
  fi
}

branch_related() {
  local current=$1
  local slug=$2

  [[ -z "$slug" ]] && return 0
  [[ "$current" == *"$slug"* ]] && return 0

  local trimmed="${current#*/}"
  [[ "$slug" == *"$trimmed"* ]] && return 0

  IFS='-' read -r -a tokens <<< "$slug"
  for token in "${tokens[@]}"; do
    if [[ ${#token} -ge 4 && "$current" == *"$token"* ]]; then
      return 0
    fi
  done

  return 1
}

unique_branch_name() {
  local name=$1
  if git show-ref --verify --quiet "refs/heads/$name"; then
    local i=2
    local candidate="${name}-${i}"
    while git show-ref --verify --quiet "refs/heads/$candidate"; do
      ((i++))
      candidate="${name}-${i}"
    done
    name="$candidate"
  fi
  echo "$name"
}

ensure_branch() {
  local prompt=$1

  if ! command -v git >/dev/null 2>&1; then
    log_warn "git not found, skipping branch checks."
    return
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_warn "Not inside a git repository, skipping branch checks."
    return
  fi

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  local slug_source="$FEATURE_NAME"
  if [[ -z "$slug_source" ]]; then
    slug_source=$(printf '%s' "$prompt" | head -1)
  fi
  local slug
  slug=$(slugify "$slug_source")
  [[ -z "$slug" ]] && slug="feature"

  local desired_branch="$BRANCH_NAME"
  if [[ -z "$desired_branch" ]]; then
    desired_branch="feature/$slug"
  fi

  if [[ "$current_branch" == "$desired_branch" ]]; then
    log_info "Already on branch $current_branch"
    return
  fi

  if [[ "$current_branch" == "main" || "$current_branch" == "master" || "$current_branch" == "HEAD" ]]; then
    local new_branch
    new_branch=$(unique_branch_name "$desired_branch")
    git checkout -b "$new_branch"
    log_info "Created branch $new_branch"
    return
  fi

  if branch_related "$current_branch" "$slug"; then
    log_info "Using existing branch $current_branch"
    return
  fi

  local new_branch
  new_branch=$(unique_branch_name "$desired_branch")
  git checkout -b "$new_branch"
  log_info "Created branch $new_branch"
}

build_ai_prompt() {
  local repo_root=$1

  cat <<EOF
You are generating a PRD for the repository at:
$repo_root

Use the exact structure shown in this template (headings, ordering, separators, and bullet style):

## Tasks

### Phase 1: <Phase Title>

- [ ] **1.1 <Task Title>**
  - File: \`/absolute/path/to/file.ts\`
  - Reference: \`/absolute/path/to/other-file.ts\`
  - Notes: <constraints or behaviors>

### Phase 2: <Phase Title>

- [ ] **2.1 <Task Title>**
  - File: \`/absolute/path/to/file.ts\`
  - Notes: <constraints or behaviors>

---

## Key File References

### <Group Name>
- \`/absolute/path/to/file.ts\`

---

## Important Patterns to Follow

1. <Pattern or rule>
2. <Pattern or rule>

User request:
$PROMPT

Rules:
- Output only the PRD markdown content, no commentary or code fences.
- Use absolute file paths for all file references.
- If file names are mentioned (by the user or implied), locate them in the repo and resolve to full paths.
- You are responsible for finding files using repo search (rg/find) before writing references.
- Only search within $repo_root (do not scan outside the repository).
- Keep phases and tasks clear, sequential, and actionable.
EOF
}

run_ai_command() {
  local prompt=$1
  local output_file=$2
  local stdin_source="${STDIN_SOURCE:-/dev/null}"

  case "$AI_ENGINE" in
    opencode)
      if ! OPENCODE_PERMISSION='{"*":"allow"}' opencode run \
        --format json \
        "$prompt" < "$stdin_source" > "$output_file" 2>&1; then
        return 1
      fi
      ;;
    cursor)
      if ! agent --print --force \
        --output-format stream-json \
        "$prompt" < "$stdin_source" > "$output_file" 2>&1; then
        return 1
      fi
      ;;
    codex)
      CODEX_LAST_MESSAGE_FILE="${output_file}.last"
      rm -f "$CODEX_LAST_MESSAGE_FILE"
      if ! codex exec --full-auto \
        --cd "$REPO_ROOT" \
        --json \
        --output-last-message "$CODEX_LAST_MESSAGE_FILE" \
        "$prompt" < "$stdin_source" > "$output_file" 2>&1; then
        return 1
      fi
      ;;
    *)
      if ! claude --dangerously-skip-permissions \
        --output-format stream-json \
        -p "$prompt" < "$stdin_source" > "$output_file" 2>&1; then
        return 1
      fi
      ;;
  esac
}

parse_ai_response() {
  local output_file=$1
  local response=""

  case "$AI_ENGINE" in
    opencode)
      response=$(jq -rs 'map(select(.type=="text") | .part.text // "") | join("")' "$output_file" 2>/dev/null || echo "")
      ;;
    cursor)
      response=$(jq -r 'select(.type=="result") | .result' "$output_file" 2>/dev/null | tail -1)
      if [[ -z "$response" || "$response" == "null" ]]; then
        response=$(jq -r 'select(.type=="assistant") | .message.content[0].text // .message.content' "$output_file" 2>/dev/null | tail -1)
      fi
      ;;
    codex)
      if [[ -n "${CODEX_LAST_MESSAGE_FILE:-}" && -f "$CODEX_LAST_MESSAGE_FILE" ]]; then
        response=$(cat "$CODEX_LAST_MESSAGE_FILE")
        response=$(printf '%s' "$response" | sed '1{/^Task completed successfully\.[[:space:]]*$/d;}')
      fi
      ;;
    *)
      response=$(jq -r 'select(.type=="result") | .result' "$output_file" 2>/dev/null | tail -1)
      ;;
  esac

  printf '%s' "$response"
}

main() {
  parse_args "$@"

  if [[ -z "$PROMPT" ]]; then
    if [[ -t 0 ]]; then
      read -r -p "Enter feature prompt: " PROMPT
    else
      PROMPT=$(cat)
    fi
  fi

  if [[ -z "$PROMPT" ]]; then
    log_error "Feature prompt is required."
    exit 1
  fi

  check_requirements

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  cd "$repo_root"
  REPO_ROOT="$repo_root"
  resolve_stdin_source

  if [[ "$CREATE_BRANCH" == true ]]; then
    ensure_branch "$PROMPT"
  fi

  local ai_prompt
  ai_prompt=$(build_ai_prompt "$repo_root")

  local output_file
  output_file=$(mktemp)
  log_info "Running $AI_ENGINE to generate PRD (this may take a while)."
  if ! run_ai_command "$ai_prompt" "$output_file"; then
    log_error "AI command failed. Check $output_file for details."
    exit 1
  fi

  local response
  response=$(parse_ai_response "$output_file")

  if [[ -z "$response" ]]; then
    log_error "AI response was empty. Check $output_file for details."
    exit 1
  fi

  rm -f "$output_file" "${output_file}.last" 2>/dev/null || true

  printf '%s\n' "$response" > "$PRD_FILE"
  : > "$PROGRESS_FILE"

  log_info "Wrote PRD to $repo_root/$PRD_FILE"
  log_info "Created blank $repo_root/$PROGRESS_FILE"
}

main "$@"
