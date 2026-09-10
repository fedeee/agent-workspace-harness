#!/usr/bin/env bash
# Copy this harness into an existing git repository.
# Core adoption needs Bash and Git. Codex MCP merges use Python 3.11+.
#
# MCP server config is merged with jq. If jq is missing, the MCP step
# is skipped with a warning. All other steps need only bash and git.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

AGENT_NAMES="cursor claude copilot codex"
CORE_SKILLS="create-plan implement-plan commit update-all-md-docs"
PLAN_FILES="_plans/README.md _plans/DECISIONS.md _plans/DECISIONS.example.md _plans/EXAMPLE.plan.md"
EVAL_FILES="_eval/README.md _eval/GOLD.md _eval/GOLD.csv _eval/GOLD.example.md _eval/GOLD.example.csv _eval/BACKLOG.md _eval/BACKLOG.example.md _eval/CYCLE.md _eval/EXAMPLE.cycle.md"
LOCAL_FILES="_local/README.md _local/eval.env.example"
HARNESS_MARKER="<!-- agent-workspace-harness -->"

GITIGNORE_BLOCK='# Agent Workspace Harness
_worktrees/
_scratch/
.playwright-mcp/
.claude/settings.local.json
_local/eval.env
_local/*.env
!_local/*.env.example'

# Flags. An empty string means "not set by the user".
TARGET=""
AGENTS_FLAG=""
EVAL_FLAG=""
SIDECAR_FLAG=""
MCP_FLAG=""
HOOKS_FLAG=""
YES=0
DRY_RUN=0
VERBOSE=0

# Resolved config.
AGENTS_SELECTED=""
INCLUDE_EVAL=0
INCLUDE_SIDECAR=0
INCLUDE_MCP=0
INCLUDE_HOOKS=0

# Action log.
ACTION_KIND=()
ACTION_DEST=()
ACTION_DETAIL=()
COUNT_COPY=0
COUNT_MERGE=0
COUNT_SKIP=0

fail() {
  local message="$1" code="${2:-2}"
  printf 'adopt: %s\n' "$message" >&2
  exit "$code"
}

usage() {
  cat <<'EOF'
Usage: adopt.sh [options] [target]

Copy this harness into an existing git repository.

Cursor, Claude Code, GitHub Copilot, and Codex are supported. The CLI asks
which agents the target repo uses, then copies matching skills, rules,
and MCP files. It does not overwrite _plans/DECISIONS.md or existing
instruction files.

Arguments:
  target                 Path to the existing git repository root

Options:
  --agents LIST          Comma-separated list: cursor, claude, copilot, codex
  --eval, --no-eval      Copy _eval and the /eval-loop skill
  --sidecar, --no-sidecar
                         Copy /mount-production-db and _local/eval.env.example
  --mcp, --no-mcp        Install Context7 and Playwright MCP servers (needs jq)
  --hooks, --no-hooks    Install the deny-push / deny-ssh hook
  --yes                  Do not prompt. Use flags and defaults.
  --dry-run              Print actions. Write nothing.
  --verbose              List every copied file.
  -h, --help             Show this help.
EOF
}

set_target() {
  if [[ -n "$TARGET" ]]; then
    fail "too many arguments: $1"
  fi
  TARGET="$1"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agents)
        shift
        AGENTS_FLAG="${1:-}"
        if [[ -z "$AGENTS_FLAG" ]]; then
          fail "--agents needs a value"
        fi
        ;;
      --agents=*) AGENTS_FLAG="${1#*=}" ;;
      --eval) EVAL_FLAG=1 ;;
      --no-eval) EVAL_FLAG=0 ;;
      --sidecar) SIDECAR_FLAG=1 ;;
      --no-sidecar) SIDECAR_FLAG=0 ;;
      --mcp) MCP_FLAG=1 ;;
      --no-mcp) MCP_FLAG=0 ;;
      --hooks) HOOKS_FLAG=1 ;;
      --no-hooks) HOOKS_FLAG=0 ;;
      --yes) YES=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --verbose) VERBOSE=1 ;;
      -h|--help) usage; exit 0 ;;
      -*) fail "unknown option: $1" ;;
      *) set_target "$1" ;;
    esac
    shift
  done
}

has_agent() {
  case " $AGENTS_SELECTED " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

parse_agents() {
  # $1 = raw user input. Sets PARSED_AGENTS.
  local raw="$1" part key name
  PARSED_AGENTS=""
  for part in ${raw//,/ }; do
    key="$(printf '%s' "$part" | tr '[:upper:]' '[:lower:]')"
    case "$key" in
      "") continue ;;
      1|cursor) name=cursor ;;
      2|claude|claude-code) name=claude ;;
      3|copilot|github|github-copilot) name=copilot ;;
      4|codex|openai-codex) name=codex ;;
      *) fail "unknown agent '$part'. Use cursor, claude, copilot, or codex." ;;
    esac
    case " $PARSED_AGENTS " in
      *" $name "*) ;;
      *) PARSED_AGENTS="${PARSED_AGENTS:+$PARSED_AGENTS }$name" ;;
    esac
  done
  if [[ -z "$PARSED_AGENTS" ]]; then
    fail "select at least one agent: cursor, claude, copilot, codex"
  fi
}

detect_agents() {
  # $1 = target. Sets DETECTED_AGENTS.
  local target="$1"
  DETECTED_AGENTS=""
  if [[ -d "$target/.cursor" ]]; then
    DETECTED_AGENTS="cursor"
  fi
  if [[ -d "$target/.claude" || -f "$target/CLAUDE.md" ]]; then
    DETECTED_AGENTS="${DETECTED_AGENTS:+$DETECTED_AGENTS }claude"
  fi
  if [[ -f "$target/.github/copilot-instructions.md" || -d "$target/.github/agents" ]]; then
    DETECTED_AGENTS="${DETECTED_AGENTS:+$DETECTED_AGENTS }copilot"
  fi
  if [[ -d "$target/.codex" || -d "$target/.agents/skills" || -f "$target/AGENTS.md" ]]; then
    DETECTED_AGENTS="${DETECTED_AGENTS:+$DETECTED_AGENTS }codex"
  fi
}

prompt_line() {
  # $1 = question, $2 = default (optional). Sets REPLY_LINE.
  local question="$1" default="${2:-}" suffix=""
  if [[ -n "$default" ]]; then
    suffix=" [$default]"
  fi
  printf '%s%s: ' "$question" "$suffix"
  if ! IFS= read -r REPLY_LINE; then
    fail "no input on stdin. Pass --yes and flags, or use a terminal."
  fi
  # Trim leading and trailing whitespace.
  REPLY_LINE="${REPLY_LINE#"${REPLY_LINE%%[![:space:]]*}"}"
  REPLY_LINE="${REPLY_LINE%"${REPLY_LINE##*[![:space:]]}"}"
}

prompt_yes_no() {
  # $1 = question, $2 = default (0 or 1). Returns 0 for yes, 1 for no.
  local question="$1" default="$2" hint="y/N"
  if [[ "$default" == 1 ]]; then
    hint="Y/n"
  fi
  prompt_line "$question [$hint]"
  if [[ -z "$REPLY_LINE" ]]; then
    if [[ "$default" == 1 ]]; then
      return 0
    fi
    return 1
  fi
  case "$(printf '%s' "$REPLY_LINE" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_agents() {
  # $1 = detected agents (space-separated). Sets AGENTS_SELECTED.
  local detected="$1" default_names="$1" default="" det="" name
  if [[ -z "$default_names" ]]; then
    default_names="cursor claude"
  fi
  for name in $AGENT_NAMES; do
    case " $default_names " in
      *" $name "*) default="${default:+$default,}$name" ;;
    esac
  done
  printf 'Which coding agents does this repository use?\n'
  printf '  1) Cursor\n'
  printf '  2) Claude Code\n'
  printf '  3) GitHub Copilot\n'
  printf '  4) Codex\n'
  if [[ -n "$detected" ]]; then
    for name in $AGENT_NAMES; do
      case " $detected " in
        *" $name "*) det="${det:+$det, }$name" ;;
      esac
    done
    printf 'Detected: %s\n' "$det"
  fi
  prompt_line "Enter numbers or names, comma-separated" "$default"
  if [[ -z "$REPLY_LINE" ]]; then
    REPLY_LINE="$default"
  fi
  parse_agents "$REPLY_LINE"
  AGENTS_SELECTED="$PARSED_AGENTS"
}

record() {
  # $1 = kind (copy|merge|skip), $2 = absolute dest, $3 = detail.
  local kind="$1" dest="$2" detail="${3:-}"
  local parent="$dest"
  while [[ "$parent" != "$TARGET" && "$parent" != / ]]; do
    [[ ! -L "$parent" ]] || fail "refusing a symbolic-link destination: $parent"
    parent="$(dirname "$parent")"
  done
  ACTION_KIND+=("$kind")
  ACTION_DEST+=("${dest#"$TARGET"/}")
  ACTION_DETAIL+=("$detail")
  case "$kind" in
    copy) COUNT_COPY=$((COUNT_COPY + 1)) ;;
    merge) COUNT_MERGE=$((COUNT_MERGE + 1)) ;;
    skip) COUNT_SKIP=$((COUNT_SKIP + 1)) ;;
  esac
}

copy_file() {
  # Never overwrites an existing file.
  local src="$1" dest="$2"
  if [[ -e "$dest" || -L "$dest" ]]; then
    record skip "$dest" "already exists"
    return
  fi
  record copy "$dest"
  if [[ "$DRY_RUN" == 1 ]]; then
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
  if [[ "$dest" == *.sh ]]; then
    chmod +x "$dest"
  fi
}

copy_tree() {
  local src="$1" dest="$2" path
  if [[ ! -e "$src" ]]; then
    fail "missing harness path: $src"
  fi
  if [[ -f "$src" ]]; then
    copy_file "$src" "$dest"
    return
  fi
  while IFS= read -r path; do
    copy_file "$path" "$dest/${path#"$src"/}"
  done < <(find "$src" -type f -not -name '.DS_Store' | sort)
}

copy_named() {
  # $1 = path relative to the harness root.
  copy_tree "$ROOT/$1" "$TARGET/$1"
}

merge_gitignore() {
  local dest="$TARGET/.gitignore" existing=""
  if [[ -f "$dest" ]] && grep -qF '# Agent Workspace Harness' "$dest"; then
    record skip "$dest" "harness block present"
    return
  fi
  record merge "$dest" "gitignore"
  if [[ "$DRY_RUN" == 1 ]]; then
    return
  fi
  if [[ -f "$dest" ]]; then
    existing="$(cat "$dest")"
  fi
  {
    if [[ -n "$existing" ]]; then
      printf '%s\n\n' "$existing"
    fi
    printf '%s\n' "$GITIGNORE_BLOCK"
  } > "$dest"
}

appendix_markdown() {
  # Sets APPENDIX.
  APPENDIX="$HARNESS_MARKER

## Agent Workspace Harness

This repository uses the Agent Workspace Harness.
Agents read \`_plans/DECISIONS.md\` before they design.
Specs live in \`_plans/\`.
Do not run \`git push\`. Do not open SSH.

Skills live in \`.claude/skills/\` and \`.cursor/skills/\`.
Codex skills live in \`.agents/skills/\`. Read \`CLAUDE.md\` and its linked rules.
Isolated worktrees: \`scripts/worktree_agent.sh <branch>\`."
  if [[ "$INCLUDE_EVAL" == 1 ]]; then
    APPENDIX="$APPENDIX
Score \`_eval/GOLD.csv\`. Do not score the example gold file.
Classifier evaluation requires at least 20 labels: \`in_class\` or \`out_class\`. \`unsure\` does not count."
  fi
  if [[ "$INCLUDE_HOOKS" == 1 ]]; then
    APPENDIX="$APPENDIX
Review the installed hooks. Codex hooks require trust through \`/hooks\`."
  fi
}

merge_or_copy_text() {
  # Copy an instruction file. If one exists, append a harness section.
  local src="$1" dest="$2" existing
  if [[ ! -e "$dest" ]]; then
    copy_file "$src" "$dest"
    return
  fi
  if grep -qF "$HARNESS_MARKER" "$dest" || grep -qF "Agent Workspace Harness" "$dest"; then
    record skip "$dest" "harness section present"
    return
  fi
  record merge "$dest" "append harness section"
  if [[ "$DRY_RUN" == 1 ]]; then
    return
  fi
  appendix_markdown
  existing="$(cat "$dest")"
  {
    printf '%s\n\n' "$existing"
    printf '%s\n' "$APPENDIX"
  } > "$dest"
}

mcp_servers_json() {
  # Sets MCP_SERVERS_JSON to the selected servers object, or empty.
  local keys=() keys_json
  MCP_SERVERS_JSON=""
  if [[ "$INCLUDE_MCP" == 1 ]]; then
    keys+=("context7" "playwright")
  fi
  if [[ "$INCLUDE_SIDECAR" == 1 ]]; then
    keys+=("postgres")
  fi
  if [[ ${#keys[@]} -eq 0 ]]; then
    return
  fi
  if [[ ! -f "$ROOT/.mcp.json" ]]; then
    fail "missing harness path: $ROOT/.mcp.json"
  fi
  keys_json="$(printf '%s\n' "${keys[@]}" | jq -Rn '[inputs]')"
  MCP_SERVERS_JSON="$(jq -c --argjson keys "$keys_json" \
    '.mcpServers // {} | with_entries(select(.key as $k | $keys | index($k)))' \
    "$ROOT/.mcp.json")"
}

merge_mcp_file() {
  # Add selected servers. Existing entries win. Never removes entries.
  local dest="$1" key="${2:-mcpServers}" added tmp
  if [[ -f "$dest" ]]; then
    added="$(jq -r --arg key "$key" --argjson new "$MCP_SERVERS_JSON" \
      '(($new | keys) - ((.[$key] // {}) | keys)) | join(", ")' "$dest")"
    if [[ -z "$added" ]]; then
      record skip "$dest" "mcp servers present"
      return
    fi
    record merge "$dest" "add $added"
    if [[ "$DRY_RUN" == 1 ]]; then
      return
    fi
    tmp="$(mktemp "${TMPDIR:-/tmp}/adopt-mcp.XXXXXX")"
    jq --arg key "$key" --argjson new "$MCP_SERVERS_JSON" \
      '.[$key] = ($new + (.[$key] // {}))' "$dest" > "$tmp"
    mv "$tmp" "$dest"
    return
  fi
  record copy "$dest" "mcp"
  if [[ "$DRY_RUN" == 1 ]]; then
    return
  fi
  mkdir -p "$(dirname "$dest")"
  jq -n --arg key "$key" --argjson servers "$MCP_SERVERS_JSON" '{($key): $servers}' > "$dest"
}

install_mcp() {
  local dests=() dest
  if [[ "$INCLUDE_MCP" != 1 && "$INCLUDE_SIDECAR" != 1 ]]; then
    return
  fi
  if has_agent claude || [[ "$INCLUDE_SIDECAR" == 1 ]]; then
    dests+=("$TARGET/.mcp.json")
  fi
  if has_agent cursor; then
    dests+=("$TARGET/.cursor/mcp.json")
  fi
  if has_agent copilot; then
    dests+=("$TARGET/.vscode/mcp.json")
  fi
  if [[ ${#dests[@]} -eq 0 ]] && ! has_agent codex; then
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'adopt: jq is needed to merge MCP server config. Skipping MCP.\n' >&2
    printf 'adopt: install jq and re-run, or add the servers by hand.\n' >&2
    return
  fi
  mcp_servers_json
  if [[ -z "$MCP_SERVERS_JSON" || "$MCP_SERVERS_JSON" == "{}" ]]; then
    return
  fi
  for dest in ${dests[@]+"${dests[@]}"}; do
    if [[ "$dest" == "$TARGET/.vscode/mcp.json" ]]; then
      merge_mcp_file "$dest" servers
    else
      merge_mcp_file "$dest"
    fi
  done
  if has_agent codex; then
    local content python="${HARNESS_PYTHON:-python3}"
    dest="$TARGET/.codex/config.toml"
    if ! content="$(printf '%s' "$MCP_SERVERS_JSON" | "$python" "$ROOT/scripts/codex_mcp.py" "$dest")"; then
      fail "Codex MCP merge failed. Set HARNESS_PYTHON to Python 3.11 or newer. Existing config is unchanged."
    fi
    if [[ -z "$content" ]]; then
      record skip "$dest" "mcp servers present"
    else
      record merge "$dest" "Codex MCP; existing entries win"
      if [[ "$DRY_RUN" != 1 ]]; then
        mkdir -p "$(dirname "$dest")"
        printf '%s\n' "$content" > "$dest"
      fi
    fi
  fi
}

install_skills() {
  local skills="$CORE_SKILLS" name
  if [[ "$INCLUDE_EVAL" == 1 ]]; then
    skills="$skills eval-loop"
  fi
  if [[ "$INCLUDE_SIDECAR" == 1 ]]; then
    skills="$skills mount-production-db"
  fi
  for name in $skills; do
    copy_named ".claude/skills/$name"
    if has_agent cursor; then
      copy_named ".cursor/skills/$name"
    fi
    if has_agent codex; then
      copy_tree "$ROOT/.claude/skills/$name" "$TARGET/.agents/skills/$name"
    fi
  done
}

install_instruction_files() {
  merge_or_copy_text "$ROOT/CLAUDE.md" "$TARGET/CLAUDE.md"
  merge_or_copy_text "$ROOT/AGENTS.md" "$TARGET/AGENTS.md"
  if has_agent copilot; then
    merge_or_copy_text \
      "$ROOT/.github/copilot-instructions.md" \
      "$TARGET/.github/copilot-instructions.md"
    copy_named ".github/agents"
  fi
  if has_agent claude; then
    copy_named ".claude/agents"
  fi
}

install_hooks() {
  if [[ "$INCLUDE_HOOKS" != 1 ]]; then
    return
  fi
  copy_named ".cursor/hooks/deny-shell.py"
  if has_agent cursor; then
    merge_hooks "$ROOT/.cursor/hooks.json" "$TARGET/.cursor/hooks.json"
  fi
  if has_agent claude; then
    merge_hooks "$ROOT/.claude/settings.json" "$TARGET/.claude/settings.json"
  fi
  if has_agent codex; then
    merge_hooks "$ROOT/.claude/settings.json" "$TARGET/.codex/hooks.json"
  fi
}

merge_hooks() {
  local src="$1" dest="$2" content
  if [[ ! -e "$dest" ]]; then
    copy_file "$src" "$dest"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    record skip "$dest" "install jq to merge existing hooks"
    return
  fi
  content="$(jq -s '
    .[0] as $old | .[1] as $new |
    reduce ($new.hooks | keys[]) as $event
      ($new * $old; .hooks[$event] =
        (($old.hooks[$event] // []) + $new.hooks[$event] | unique))
  ' "$dest" "$src")"
  if [[ "$(jq -S . "$dest")" == "$(printf '%s' "$content" | jq -S .)" ]]; then
    record skip "$dest" "hooks present"
    return
  fi
  record merge "$dest" "preserve existing hooks and settings"
  if [[ "$DRY_RUN" != 1 ]]; then
    printf '%s\n' "$content" > "$dest"
  fi
}

adopt_all() {
  local rel
  for rel in $PLAN_FILES; do
    copy_named "$rel"
  done
  copy_named "scripts/worktree_agent.sh"
  copy_named ".claude/prompt-snippets"
  if has_agent cursor; then
    copy_named ".cursor/rules"
  fi
  install_skills
  install_instruction_files
  install_hooks
  if [[ "$INCLUDE_EVAL" == 1 ]]; then
    copy_named "scripts/eval_score.py"
    for rel in $EVAL_FILES; do
      copy_named "$rel"
    done
  fi
  if [[ "$INCLUDE_SIDECAR" == 1 ]]; then
    for rel in $LOCAL_FILES; do
      copy_named "$rel"
    done
  fi
  install_mcp
  merge_gitignore
}

print_report() {
  local i kind suffix show_copies=0 summary="" part
  if [[ "$VERBOSE" == 1 || "$DRY_RUN" == 1 ]]; then
    show_copies=1
  fi
  for i in "${!ACTION_KIND[@]}"; do
    kind="${ACTION_KIND[$i]}"
    if [[ "$kind" == copy && "$show_copies" == 0 ]]; then
      continue
    fi
    suffix=""
    if [[ -n "${ACTION_DETAIL[$i]}" ]]; then
      suffix=" (${ACTION_DETAIL[$i]})"
    fi
    printf '  %-5s %s%s\n' "$kind" "${ACTION_DEST[$i]}" "$suffix"
  done
  if [[ "$COUNT_COPY" -gt 0 && "$show_copies" == 0 ]]; then
    printf '  copy  %d files. Pass --verbose to list them.\n' "$COUNT_COPY"
  fi
  printf '\n'
  if [[ "$COUNT_COPY" -gt 0 ]]; then
    summary="$COUNT_COPY copy"
  fi
  if [[ "$COUNT_MERGE" -gt 0 ]]; then
    summary="${summary:+$summary, }$COUNT_MERGE merge"
  fi
  if [[ "$COUNT_SKIP" -gt 0 ]]; then
    summary="${summary:+$summary, }$COUNT_SKIP skip"
  fi
  printf 'Summary: %s\n' "$summary"
  if [[ "$DRY_RUN" == 1 ]]; then
    printf 'Dry run. No files written.\n'
    return
  fi
  printf 'Installed into %s\n' "$TARGET"
  if has_agent cursor; then
    printf 'Open the app in Cursor. Run /create-plan for a small change.\n'
  elif has_agent claude; then
    printf 'Open the app in Claude Code. Run /create-plan for a small change.\n'
  fi
  if has_agent codex; then
    printf 'Open the repo in Codex. Use $create-plan for a small change.\n'
    printf 'Trust project config to load MCP. Review and trust hooks through /hooks.\n'
  fi
  if [[ "$INCLUDE_EVAL" == 1 ]]; then
    printf 'Classifier evaluation needs 20 labelled rows in _eval/GOLD.csv.\n'
  fi
  printf 'Review the copy. Commit it. You push.\n'
}

yes_no() {
  if [[ "$1" == 1 ]]; then
    printf 'yes'
  else
    printf 'no'
  fi
}

flag_or_prompt() {
  # $1 = flag value ("" / 0 / 1), $2 = question, $3 = default,
  # $4 = interactive. Sets FLAG_RESULT.
  local value="$1" question="$2" default="$3" interactive="$4"
  if [[ -n "$value" ]]; then
    FLAG_RESULT="$value"
    return
  fi
  if [[ "$interactive" == 1 ]]; then
    if prompt_yes_no "$question" "$default"; then
      FLAG_RESULT=1
    else
      FLAG_RESULT=0
    fi
    return
  fi
  FLAG_RESULT="$default"
}

resolve_config() {
  local interactive=0 target_raw="$TARGET" toplevel
  if [[ -t 0 && "$YES" == 0 ]]; then
    interactive=1
  fi

  if [[ -z "$target_raw" ]]; then
    if [[ "$interactive" == 0 ]]; then
      fail "target path is required. Pass the repo root or run in a terminal."
    fi
    prompt_line "Path to the existing git repository"
    target_raw="$REPLY_LINE"
  fi
  if [[ -z "$target_raw" ]]; then
    fail "target path is required"
  fi
  target_raw="${target_raw/#\~/$HOME}"
  if [[ ! -d "$target_raw" ]]; then
    fail "not a directory: $target_raw"
  fi
  TARGET="$(cd "$target_raw" && pwd -P)"
  if [[ "$TARGET" == "$ROOT" ]]; then
    fail "refusing to install into the harness source tree"
  fi
  if ! toplevel="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)"; then
    fail "not a git repository: $TARGET"
  fi
  toplevel="$(cd "$toplevel" && pwd -P)"
  if [[ "$toplevel" != "$TARGET" ]]; then
    fail "use the git root, not a subdirectory. Root is $toplevel"
  fi

  detect_agents "$TARGET"
  if [[ -n "$AGENTS_FLAG" ]]; then
    parse_agents "$AGENTS_FLAG"
    AGENTS_SELECTED="$PARSED_AGENTS"
  elif [[ "$interactive" == 1 ]]; then
    prompt_agents "$DETECTED_AGENTS"
  else
    AGENTS_SELECTED="$DETECTED_AGENTS"
    if [[ -z "$AGENTS_SELECTED" ]]; then
      AGENTS_SELECTED="cursor claude"
    fi
  fi

  flag_or_prompt "$EVAL_FLAG" \
    "Include the offline eval loop (_eval, /eval-loop)?" 0 "$interactive"
  INCLUDE_EVAL="$FLAG_RESULT"
  flag_or_prompt "$SIDECAR_FLAG" \
    "Include the production-dump Postgres sidecar (/mount-production-db)?" 0 "$interactive"
  INCLUDE_SIDECAR="$FLAG_RESULT"
  flag_or_prompt "$MCP_FLAG" \
    "Install Context7 and Playwright MCP servers?" 0 "$interactive"
  INCLUDE_MCP="$FLAG_RESULT"
  flag_or_prompt "$HOOKS_FLAG" \
    "Install the deny-push / deny-ssh hook?" 0 "$interactive"
  INCLUDE_HOOKS="$FLAG_RESULT"

  if [[ "$interactive" == 1 && "$DRY_RUN" == 0 ]]; then
    local ordered="" name mcp_label="no"
    for name in $AGENT_NAMES; do
      if has_agent "$name"; then
        ordered="${ordered:+$ordered, }$name"
      fi
    done
    if [[ "$INCLUDE_MCP" == 1 ]]; then
      mcp_label="yes"
    elif [[ "$INCLUDE_SIDECAR" == 1 ]]; then
      mcp_label="postgres only (sidecar)"
    fi
    printf '\n'
    printf 'Target:  %s\n' "$TARGET"
    printf 'Agents:  %s\n' "$ordered"
    printf 'Eval:    %s\n' "$(yes_no "$INCLUDE_EVAL")"
    printf 'Sidecar: %s\n' "$(yes_no "$INCLUDE_SIDECAR")"
    printf 'MCP:     %s\n' "$mcp_label"
    printf 'Hooks:   %s\n' "$(yes_no "$INCLUDE_HOOKS")"
    if ! prompt_yes_no "Copy files into that repository?" 1; then
      fail "aborted" 1
    fi
    printf '\n'
  fi
}

main() {
  parse_args "$@"
  resolve_config
  adopt_all
  print_report
}

# Let tests source this file to call functions directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
