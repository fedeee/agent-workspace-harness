#!/usr/bin/env bash
# Fetch the Agent Workspace Harness and run scripts/adopt.sh.
#
# One line, from inside your app repository:
#
#   curl -fsSL https://raw.githubusercontent.com/fedeee/agent-workspace-harness/main/install.sh | bash
#
# With no arguments, the harness is adopted into the current directory.
# Pass a target path and any adopt.sh flags to override:
#
#   bash install.sh /path/to/your-app --yes --agents cursor
#
# Overrides:
#   HARNESS_REPO_URL  Git URL to clone. Default: the public GitHub repo.
#   HARNESS_SRC       Local harness checkout to copy instead of cloning.
#                     For tests and development.
set -euo pipefail

HARNESS_REPO_URL="${HARNESS_REPO_URL:-https://github.com/fedeee/agent-workspace-harness.git}"

fail() {
  printf 'install: %s\n' "$1" >&2
  exit "${2:-1}"
}

if ! command -v git >/dev/null 2>&1; then
  fail "git is required"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

if [[ -n "${HARNESS_SRC:-}" ]]; then
  cp -R "$HARNESS_SRC" "$TMP/harness"
else
  printf 'Fetching the harness from %s\n' "$HARNESS_REPO_URL"
  if ! git clone --quiet --depth 1 "$HARNESS_REPO_URL" "$TMP/harness"; then
    fail "clone failed. Check the URL and your access."
  fi
fi

# Default target: the current directory.
if [[ $# -eq 0 ]]; then
  set -- .
fi

# Read prompt answers from the terminal even when piped through curl.
# Opening /dev/tty fails when there is no controlling terminal.
# Scope stderr redirection to the probe, not the rest of the installer.
if { exec 3< /dev/tty; } 2>/dev/null; then
  bash "$TMP/harness/scripts/adopt.sh" "$@" <&3
else
  bash "$TMP/harness/scripts/adopt.sh" "$@"
fi
