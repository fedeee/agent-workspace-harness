#!/usr/bin/env bash
# Tests for scripts/adopt.sh. Run: bash tests/test_adopt.sh
# Two tests need jq. They are skipped when jq is not installed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADOPT="$ROOT/scripts/adopt.sh"

PASS_COUNT=0
FAIL_COUNT=0
# One parent survives command substitutions and owns every test directory.
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/adopt-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

make_repo() {
  local dir
  dir="$(mktemp -d "$TEST_ROOT/repo.XXXXXX")"
  git -C "$dir" init -q
  printf '%s' "$dir"
}

make_dir() {
  mktemp -d "$TEST_ROOT/dir.XXXXXX"
}

report_ok() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok   %s\n' "$1"
}

report_bad() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL %s\n' "$1"
}

report_skip() {
  printf 'skip %s (%s)\n' "$1" "$2"
}

run_case() {
  local name="$1" out
  shift
  if out="$("$@" 2>&1)"; then
    report_ok "$name"
  else
    report_bad "$name"
    if [[ -n "$out" ]]; then
      printf '%s\n' "$out" | sed 's/^/     /'
    fi
  fi
}

expect_refused() {
  # $1 = expected exit code, rest = command. Succeeds when the command
  # fails with that code.
  local want="$1" code
  shift
  "$@" >/dev/null 2>&1 && return 1
  code=$?
  [[ "$code" -eq "$want" ]]
}

test_help_exits_zero() {
  bash "$ADOPT" --help >/dev/null
}

test_refuses_harness_source_tree() {
  expect_refused 2 bash "$ADOPT" "$ROOT" --yes --agents cursor
}

test_refuses_non_git_directory() {
  local dir
  dir="$(make_dir)"
  expect_refused 2 bash "$ADOPT" "$dir" --yes --agents cursor
}

test_refuses_subdirectory_of_repo() {
  local dir
  dir="$(make_repo)"
  mkdir -p "$dir/sub"
  expect_refused 2 bash "$ADOPT" "$dir/sub" --yes --agents cursor
}

test_rejects_unknown_agent() {
  local dir
  dir="$(make_repo)"
  expect_refused 2 bash "$ADOPT" "$dir" --yes --agents windsurf
}

test_requires_target_when_not_interactive() {
  expect_refused 2 bash "$ADOPT" --yes </dev/null
}

test_accepts_numbers_and_names() {
  local dir
  dir="$(make_repo)"
  bash "$ADOPT" "$dir" --yes --agents 1,claude >/dev/null || return 1
  [[ -f "$dir/.cursor/rules/agent-harness.mdc" ]] || return 1
  [[ -f "$dir/.claude/agents/reviewer.md" ]]
}

test_cursor_only_copies_cursor_files_not_eval() {
  local dir
  dir="$(make_repo)"
  bash "$ADOPT" "$dir" --yes --agents cursor \
    --no-eval --no-sidecar --no-mcp --no-hooks >/dev/null || return 1
  [[ -f "$dir/AGENTS.md" ]] || return 1
  [[ -f "$dir/.cursor/rules/agent-harness.mdc" ]] || return 1
  [[ -f "$dir/.cursor/skills/create-plan/SKILL.md" ]] || return 1
  [[ -f "$dir/.claude/skills/create-plan/SKILL.md" ]] || return 1
  [[ -f "$dir/.claude/prompt-snippets/session-execution.md" ]] || return 1
  [[ -f "$dir/scripts/worktree_agent.sh" ]] || return 1
  [[ -x "$dir/scripts/worktree_agent.sh" ]] || return 1
  [[ -f "$dir/_plans/DECISIONS.md" ]] || return 1
  [[ -f "$dir/CLAUDE.md" ]] || return 1
  [[ ! -e "$dir/_eval" ]] || return 1
  [[ ! -e "$dir/.cursor/skills/eval-loop" ]] || return 1
  [[ ! -e "$dir/.cursor/hooks.json" ]] || return 1
  grep -qF '_worktrees/' "$dir/.gitignore"
}

test_preserves_existing_decisions_and_appends_agents() {
  local dir
  dir="$(make_repo)"
  mkdir -p "$dir/_plans"
  printf 'keep this ledger\n' > "$dir/_plans/DECISIONS.md"
  printf '# Existing agents\n' > "$dir/AGENTS.md"
  bash "$ADOPT" "$dir" --yes --agents cursor >/dev/null || return 1
  [[ "$(cat "$dir/_plans/DECISIONS.md")" == "keep this ledger" ]] || return 1
  grep -qF '# Existing agents' "$dir/AGENTS.md" || return 1
  grep -qF '<!-- agent-workspace-harness -->' "$dir/AGENTS.md"
}

test_second_run_skips_existing_files() {
  local dir
  dir="$(make_repo)"
  bash "$ADOPT" "$dir" --yes --agents cursor >/dev/null || return 1
  printf 'my notes\n' >> "$dir/_plans/DECISIONS.md"
  bash "$ADOPT" "$dir" --yes --agents cursor >/dev/null || return 1
  grep -qF 'my notes' "$dir/_plans/DECISIONS.md"
}

test_dry_run_writes_nothing() {
  local dir
  dir="$(make_repo)"
  bash "$ADOPT" "$dir" --yes --agents cursor --dry-run >/dev/null || return 1
  [[ ! -e "$dir/AGENTS.md" ]] || return 1
  [[ ! -e "$dir/_plans" ]]
}

test_sidecar_adds_postgres_mcp_without_docs_servers() {
  local dir
  dir="$(make_repo)"
  mkdir -p "$dir/.cursor"
  printf '%s\n' '{"mcpServers": {"custom": {"command": "echo"}}}' \
    > "$dir/.cursor/mcp.json"
  bash "$ADOPT" "$dir" --yes --agents cursor --sidecar --no-mcp >/dev/null \
    || return 1
  jq -e '.mcpServers
    | has("custom") and has("postgres") and (has("context7") | not)' \
    "$dir/.cursor/mcp.json" >/dev/null || return 1
  [[ -f "$dir/.claude/skills/mount-production-db/SKILL.md" ]] || return 1
  [[ -f "$dir/_local/eval.env.example" ]]
}

test_eval_and_hooks_for_claude() {
  local dir
  dir="$(make_repo)"
  bash "$ADOPT" "$dir" --yes --agents claude --eval --hooks --mcp >/dev/null \
    || return 1
  [[ -f "$dir/CLAUDE.md" ]] || return 1
  [[ -f "$dir/_eval/GOLD.csv" ]] || return 1
  [[ -f "$dir/.claude/skills/eval-loop/SKILL.md" ]] || return 1
  [[ ! -e "$dir/.cursor/skills/create-plan" ]] || return 1
  [[ -f "$dir/.cursor/hooks/deny-shell.py" ]] || return 1
  [[ -f "$dir/.claude/settings.json" ]] || return 1
  jq -e '.mcpServers | has("context7") and (has("postgres") | not)' \
    "$dir/.mcp.json" >/dev/null
}

# Prompt tests source adopt.sh in a subshell and feed answers on stdin.

test_prompt_yes_no_empty_takes_default_yes() (
  source "$ADOPT"
  prompt_yes_no "ok?" 1 <<< ''
)

test_prompt_yes_no_empty_takes_default_no() (
  source "$ADOPT"
  if prompt_yes_no "ok?" 0 <<< ''; then
    return 1
  fi
)

test_prompt_yes_no_accepts_y_and_n() (
  source "$ADOPT"
  prompt_yes_no "ok?" 0 <<< 'Y' || return 1
  if prompt_yes_no "ok?" 1 <<< 'no'; then
    return 1
  fi
)

test_prompt_eof_fails_with_code_2() {
  # fail() exits the subshell, so check its exit code from outside.
  (
    source "$ADOPT"
    prompt_yes_no "ok?" 1 </dev/null
  )
  [[ $? -eq 2 ]]
}

test_prompt_agents_empty_takes_detected_default() (
  source "$ADOPT"
  prompt_agents "cursor" <<< '' >/dev/null
  [[ "$AGENTS_SELECTED" == cursor ]]
)

test_prompt_agents_maps_numbers() (
  source "$ADOPT"
  prompt_agents "" <<< '2,3' >/dev/null
  [[ "$AGENTS_SELECTED" == "claude copilot" ]]
)

test_install_sh_local_source_adopts() {
  local dir
  dir="$(make_repo)"
  HARNESS_SRC="$ROOT" bash "$ROOT/install.sh" "$dir" \
    --yes --agents cursor --no-eval --no-sidecar --no-mcp --no-hooks \
    </dev/null >/dev/null || return 1
  [[ -f "$dir/AGENTS.md" ]] || return 1
  [[ -f "$dir/.cursor/rules/agent-harness.mdc" ]]
}

main() {
  run_case "help exits zero" test_help_exits_zero
  run_case "refuses harness source tree" test_refuses_harness_source_tree
  run_case "refuses non-git directory" test_refuses_non_git_directory
  run_case "refuses subdirectory of repo" test_refuses_subdirectory_of_repo
  run_case "rejects unknown agent" test_rejects_unknown_agent
  run_case "requires target when not interactive" \
    test_requires_target_when_not_interactive
  run_case "accepts numbers and names" test_accepts_numbers_and_names
  run_case "cursor only copies cursor files, not eval" \
    test_cursor_only_copies_cursor_files_not_eval
  run_case "preserves decisions, appends agents" \
    test_preserves_existing_decisions_and_appends_agents
  run_case "second run skips existing files" test_second_run_skips_existing_files
  run_case "dry run writes nothing" test_dry_run_writes_nothing
  run_case "prompt: empty answer takes default yes" \
    test_prompt_yes_no_empty_takes_default_yes
  run_case "prompt: empty answer takes default no" \
    test_prompt_yes_no_empty_takes_default_no
  run_case "prompt: accepts y and n" test_prompt_yes_no_accepts_y_and_n
  run_case "prompt: eof fails with code 2" test_prompt_eof_fails_with_code_2
  run_case "prompt: agents empty takes detected default" \
    test_prompt_agents_empty_takes_detected_default
  run_case "prompt: agents maps numbers" test_prompt_agents_maps_numbers
  run_case "install.sh adopts from a local source" \
    test_install_sh_local_source_adopts
  if command -v jq >/dev/null 2>&1; then
    run_case "sidecar adds postgres mcp without docs servers" \
      test_sidecar_adds_postgres_mcp_without_docs_servers
    run_case "eval and hooks for claude" test_eval_and_hooks_for_claude
  else
    report_skip "sidecar adds postgres mcp without docs servers" \
      "jq not installed"
    report_skip "eval and hooks for claude" "jq not installed"
  fi
  printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  [[ "$FAIL_COUNT" -eq 0 ]]
}

main
