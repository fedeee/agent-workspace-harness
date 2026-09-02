#!/usr/bin/env bash
# Create or remove an isolated worktree of this git tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="create"

usage() {
  cat <<'EOF'
Usage:
  scripts/worktree_agent.sh <branch>
  scripts/worktree_agent.sh --clean <branch>

Examples:
  scripts/worktree_agent.sh experiment/crawler-probe
  scripts/worktree_agent.sh --clean experiment/crawler-probe

This harness is one git repository. Do not pass a repos/ name.
EOF
}

fail() {
  printf 'worktree_agent: %s\n' "$1" >&2
  exit 1
}

absolute_git_common_dir() {
  local repo_path="$1"
  local common
  common="$(git -C "$repo_path" rev-parse --git-common-dir)"
  if [[ "$common" != /* ]]; then
    common="$(cd "$repo_path/$common" && pwd -P)"
  else
    common="$(cd "$common" && pwd -P)"
  fi
  printf '%s\n' "$common"
}

if [[ "${1:-}" == "--clean" ]]; then
  MODE="clean"
  shift
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

BRANCH="$1"
command -v git >/dev/null 2>&1 || fail "git is required"
git check-ref-format --branch "$BRANCH" >/dev/null 2>&1 ||
  fail "invalid branch name: $BRANCH"

# scripts/ lives in the checkout that contains this file (main tree or a copy).
REPO_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"
GIT_ROOT="$(git -C "$REPO_PATH" rev-parse --show-toplevel 2>/dev/null)" ||
  fail "target is not a Git repository: $REPO_PATH"
GIT_ROOT="$(cd "$GIT_ROOT" && pwd -P)"
[[ "$GIT_ROOT" == "$REPO_PATH" ]] ||
  fail "target is not a standalone Git repository: $REPO_PATH (Git root: $GIT_ROOT)"

COMMON_GIT="$(absolute_git_common_dir "$REPO_PATH")"
MAIN_ROOT="$(dirname "$COMMON_GIT")"
REPO_NAME="$(basename "$MAIN_ROOT")"
BRANCH_SLUG="${BRANCH//\//-}"
BRANCH_SLUG="${BRANCH_SLUG// /-}"
WORKTREE_ROOT="$MAIN_ROOT/_worktrees"
WORKTREE_PATH="$WORKTREE_ROOT/${REPO_NAME}-${BRANCH_SLUG}"

if [[ "$MODE" == "clean" ]]; then
  [[ -e "$WORKTREE_PATH" ]] ||
    fail "worktree path does not exist: $WORKTREE_PATH"
  git -C "$MAIN_ROOT" worktree remove "$WORKTREE_PATH"
  git -C "$MAIN_ROOT" worktree prune
  printf 'Removed worktree: %s\n' "$WORKTREE_PATH"
  printf 'Branch remains: %s\n' "$BRANCH"
  exit 0
fi

[[ ! -e "$WORKTREE_PATH" ]] ||
  fail "worktree path already exists: $WORKTREE_PATH"
mkdir -p "$WORKTREE_ROOT"

if git -C "$MAIN_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git -C "$MAIN_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH"
else
  git -C "$MAIN_ROOT" worktree add -b "$BRANCH" "$WORKTREE_PATH" HEAD
fi

ENV_FILES=(
  ".env"
  "_local/eval.env"
)

for relative_path in "${ENV_FILES[@]}"; do
  source_path="$MAIN_ROOT/$relative_path"
  target_path="$WORKTREE_PATH/$relative_path"
  [[ -f "$source_path" ]] || continue
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    printf 'Skipped existing environment path: %s\n' "$target_path" >&2
    continue
  fi
  mkdir -p "$(dirname "$target_path")"
  cp "$source_path" "$target_path"
  printf 'Copied environment file (edits stay in this worktree): %s\n' "$relative_path"
done

printf 'Created worktree: %s\n' "$WORKTREE_PATH"
printf 'Branch: %s\n' "$BRANCH"
printf 'Cleanup: %s --clean %q\n' "$0" "$BRANCH"
