#!/usr/bin/env bash
# secret-scan.sh — pre-commit secret gate. Blocks commits that stage secrets.
#
# Works in BOTH of these modes with the same file:
#
#   1) As a plain git pre-commit hook:
#        cp .claude/hooks/secret-scan.sh .git/hooks/pre-commit
#        chmod +x .git/hooks/pre-commit
#      Non-zero exit refuses the commit.
#
#   2) As a Claude Code PreToolUse hook (blocks the agent's `git commit`
#      before it runs). Add to .claude/settings.json:
#
#      {
#        "hooks": {
#          "PreToolUse": [
#            { "matcher": "Bash",
#              "hooks": [ { "type": "command",
#                "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/secret-scan.sh" } ] }
#          ]
#        }
#      }
#
#      Exit 2 blocks the tool call; stderr is fed back to Claude (documented
#      hook exit-code semantics). Non-commit Bash commands pass through
#      untouched (exit 0).
#
# What it scans: files staged in the git index (git diff --cached).
# Allowlist: add path patterns (one per line, grep -E syntax) to
# .secretscanignore at the repo root to exempt e.g. test fixtures.
#
# Requires: git, grep. jq is used in mode 2 if available (falls back to a
# conservative grep of the hook JSON).

set -u

# ---------- secret patterns (grep -E, case sensitive unless noted) ----------
PATTERNS=(
  'AKIA[0-9A-Z]{16}'                                          # AWS access key ID
  '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}'                     # GitHub token
  'github_pat_[A-Za-z0-9_]{22,}'                              # GitHub fine-grained PAT
  'xox[baprs]-[A-Za-z0-9-]{10,}'                              # Slack token
  'sk-ant-[A-Za-z0-9_-]{20,}'                                 # Anthropic API key
  'AIza[0-9A-Za-z_-]{35}'                                     # Google API key
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'                        # PEM private key
  '[aA][wW][sS].{0,20}['\''"][0-9a-zA-Z/+]{40}['\''"]'        # AWS secret key near "aws"
)

scan_staged() {
  # Nothing staged (or not a git repo) -> nothing to block.
  git rev-parse --git-dir >/dev/null 2>&1 || return 0

  local ignore_file findings=0 f
  ignore_file="$(git rev-parse --show-toplevel 2>/dev/null)/.secretscanignore"

  while IFS= read -r -d '' f; do
    # skip allowlisted paths
    if [ -f "$ignore_file" ]; then
      if printf '%s\n' "$f" | grep -Eq -f "$ignore_file" 2>/dev/null; then
        continue
      fi
    fi
    # skip files git itself considers binary (numstat shows "-" for them)
    if git diff --cached --numstat -- "$f" | grep -q '^-'; then
      continue
    fi
    # scan the STAGED content of the file, not the working tree
    local content
    content=$(git show ":$f" 2>/dev/null) || continue
    local p
    for p in "${PATTERNS[@]}"; do
      local hit
      hit=$(printf '%s\n' "$content" | grep -En -e "$p" | head -3)
      if [ -n "$hit" ]; then
        findings=1
        printf 'SECRET-SCAN: %s matches /%s/\n' "$f" "$p" >&2
        printf '%s\n' "$hit" | sed 's/^/    line /' >&2
      fi
    done
  done < <(git diff --cached --name-only --diff-filter=ACM -z)

  if [ "$findings" -eq 1 ]; then
    printf 'SECRET-SCAN: commit blocked. Remove the secret(s), or allowlist fixture paths in .secretscanignore.\n' >&2
    return 2
  fi
  return 0
}

# ---------- mode detection ----------
if [ -t 0 ]; then
  # stdin is a terminal: running as a git pre-commit hook
  scan_staged
  exit $?
fi

INPUT=$(cat)

if [ -z "$INPUT" ]; then
  # empty stdin: also git-hook territory
  scan_staged
  exit $?
fi

# Claude Code PreToolUse mode: only act on Bash commands that commit.
if command -v jq >/dev/null 2>&1; then
  TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  TOOL=$(printf '%s' "$INPUT" | grep -o '"tool_name"[^,}]*' | head -1)
  CMD=$(printf '%s' "$INPUT" | grep -o '"command"[^,}]*' | head -1)
fi

case "$TOOL" in
  *Bash*) : ;;
  *) exit 0 ;;
esac

case "$CMD" in
  *"git commit"*|*"git-commit"*)
    scan_staged
    exit $?
    ;;
  *)
    exit 0
    ;;
esac
