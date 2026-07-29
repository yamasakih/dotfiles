#!/bin/bash
# Blocks Bash commands that send data to external hosts.
# Inspects the ENTIRE command string (not just the first word) to catch
# piped usage like: cat file | curl ...
# Also catches python/node/ruby one-liners that import networking libs.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$CMD" ] && exit 0

# Allowlist: commands that contain these patterns are OK even if they
# match below (e.g., `grep curl`, `git log --grep=wget`, `npm install curl-like-pkg`)
# Also allow herdr commands (they communicate locally).
if printf '%s' "$CMD" | grep -qE '^(grep|rg|ag|ack|git log|git show|git diff|herdr)\b'; then
  exit 0
fi

# Network-sending commands to detect anywhere in the command string
NETWORK_CMDS='curl|wget|nc\b|ncat\b|netcat\b|socat\b|ssh\b|scp\b|rsync\b|sftp\b|ftp\b|telnet\b|nmap\b'

# Python/Node/Ruby networking modules
SCRIPT_NET='urllib|requests\.get|requests\.post|requests\.put|requests\.patch|http\.client|httpx|aiohttp|fetch\(|axios|node-fetch|Net::HTTP|open-uri'

BLOCKED=""

if printf '%s' "$CMD" | grep -qE "(^|[|;&\`\$\([:space:]])($NETWORK_CMDS)"; then
  BLOCKED=$(printf '%s' "$CMD" | grep -oE "($NETWORK_CMDS)" | head -1)
fi

if [ -z "$BLOCKED" ] && printf '%s' "$CMD" | grep -qE "$SCRIPT_NET"; then
  BLOCKED=$(printf '%s' "$CMD" | grep -oE "($SCRIPT_NET)" | head -1)
fi

if [ -n "$BLOCKED" ]; then
  jq -n --arg reason "外部へのデータ送信が検出されました (${BLOCKED})。sandbox ポリシーにより、外部通信を含むコマンドはブロックされます。本当に必要な場合はユーザーに確認してください。" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
