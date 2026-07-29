#!/bin/bash
# Blocks `git push` (including `rtk git push` after rtk-rewrite.sh) when the
# push's ACTUAL resolved destination is main/master.
#
# Why not just pattern-match the command text for "main"? Because the
# 2026-07-08 sol-common-infra-aws incident was `git push -u origin
# feat/some-branch` -- a command that never mentions "main" at all, yet
# resolved to origin/main due to upstream tracking + push.default config.
# The only reliable way to catch that is to ask git itself where the push
# would actually land, via `git push --dry-run`.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')

[ -z "$CMD" ] && exit 0

# Only act on commands that actually invoke `git push` (directly or via the
# `rtk git push` rewrite -- the substring survives either way).
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push\b' || exit 0

if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  cd "$CWD" || exit 0
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Reconstruct a clean, real `git push --dry-run <args>` using plain git --
# not whatever wrapper (rtk, env prefixes, etc.) the original command used --
# so the verification step is predictable regardless of rewriting.
PUSH_ARGS=$(printf '%s' "$CMD" | sed -E 's/^.*git[[:space:]]+push\b//')

DRY_OUT=$(eval "git push --dry-run $PUSH_ARGS" 2>&1)

# Normal update: "<old>..<new>  <src> -> <dst>"
DEST=$(printf '%s' "$DRY_OUT" | grep -oE '\->[[:space:]]+[^[:space:]]+' | tail -n1 | sed -E 's/^->[[:space:]]+//; s#^refs/heads/##')

# Deletion: " - [deleted]         <dst>"
if [ -z "$DEST" ]; then
  DEST=$(printf '%s' "$DRY_OUT" | grep -E '\[deleted\]' | tail -n1 | awk '{print $NF}' | sed -E 's#^refs/heads/##')
fi

if [ "$DEST" = "main" ] || [ "$DEST" = "master" ]; then
  jq -n --arg reason "このpushは ${DEST} に直接反映されます(dry-run結果より判定)。PR経由で変更してください。本当に直接pushが必要な場合は理由を明示した上でユーザーに確認してください。" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
