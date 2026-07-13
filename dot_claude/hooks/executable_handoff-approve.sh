#!/bin/bash
# Rewrite handoff/memp bookkeeping commands to remove shell command substitution.
#
# Claude Code's permission matcher can NEVER auto-approve Bash commands that
# contain $(date ...) or $$ via the allowlist — it's a deliberate safeguard.
# Returning permissionDecision:"allow" from a hook alone is also insufficient
# when the original command contains command substitution.
#
# This hook REWRITES the offending commands to equivalent python3 one-liners
# that produce identical output without using $() or $$. The rewritten command
# has no command substitution, so it passes the blanket Bash allowlist check.
# Returns permissionDecision:"allow" + updatedInput.

command -v jq &>/dev/null || exit 0

# Locate python3 by absolute path — Claude Code's hook PATH may not include
# non-standard dirs like /home/linuxbrew/.linuxbrew/bin.
PY=""
for _p in \
  /home/linuxbrew/.linuxbrew/bin/python3 \
  /usr/bin/python3 \
  /usr/local/bin/python3 \
  /opt/homebrew/bin/python3; do
  [ -x "$_p" ] && PY="$_p" && break
done

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# Debug log — remove once confirmed working
LOG=/tmp/handoff-hook-debug.log
printf '%s HANDOFF-HOOK invoked. PY=%s CMD=%s\n' "$(date '+%H:%M:%S')" "$PY" "$CMD" >> "$LOG" 2>&1

# Normalize multiline/multi-space to single space for pattern matching
NORM=$(printf '%s' "$CMD" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')

emit_rewrite() {
  local new_cmd="$1"
  local orig_input updated_input
  orig_input=$(printf '%s' "$INPUT" | jq -c '.tool_input')
  updated_input=$(printf '%s' "$orig_input" | jq --arg c "$new_cmd" '.command = $c')
  jq -n --argjson u "$updated_input" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "handoff/memp: rewritten to remove command substitution",
      updatedInput: $u
    }
  }'
  exit 0
}

# Handoff step 1: mkdir ~/.claude/handoff + echo with $(date) and $$
# Matches both && and newline variants (NORM collapses them to spaces)
if printf '%s' "$NORM" | grep -qF 'mkdir -p ~/.claude/handoff' \
   && printf '%s' "$NORM" | grep -qF 'echo "$(date '"'"'+%Y-%m-%d-%H-%M-%S'"'"')-$$.md"'; then
  if [ -n "$PY" ]; then
    emit_rewrite "mkdir -p ~/.claude/handoff && $PY -c \"import datetime,os; print(datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')+'-'+str(os.getpid())+'.md')\""
  fi
  printf 'HANDOFF-HOOK: matched step1 but PY empty\n' >> "$LOG" 2>&1
fi

# memp episodes: mkdir + ls with $(date +%Y%m%d)
if printf '%s' "$NORM" | grep -qF '~/.memp/episodes' \
   && printf '%s' "$NORM" | grep -qF '$(date +%Y%m%d)'; then
  if [ -n "$PY" ]; then
    emit_rewrite "$PY -c \"import os,glob,datetime; os.makedirs(os.path.expanduser('~/.memp/episodes'),exist_ok=True); d=datetime.datetime.now().strftime('%Y%m%d'); files=sorted(glob.glob(os.path.expanduser('~/.memp/episodes/ep-'+d+'*.md'))); print(files[-1] if files else '')\""
  fi
fi

# memp memories: mkdir + ls with $(date +%Y%m%d)
if printf '%s' "$NORM" | grep -qF '~/.memp/memories' \
   && printf '%s' "$NORM" | grep -qF '$(date +%Y%m%d)'; then
  if [ -n "$PY" ]; then
    emit_rewrite "$PY -c \"import os,glob,datetime; os.makedirs(os.path.expanduser('~/.memp/memories'),exist_ok=True); d=datetime.datetime.now().strftime('%Y%m%d'); files=sorted(glob.glob(os.path.expanduser('~/.memp/memories/mem-'+d+'*.md'))); print(files[-1] if files else '')\""
  fi
fi
