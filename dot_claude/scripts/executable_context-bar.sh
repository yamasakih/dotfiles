#!/bin/bash

# Color theme: gold (default)
COLOR="green"

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_BAR_EMPTY='\033[38;5;238m'
case "$COLOR" in
    orange)   C_ACCENT='\033[38;5;173m' ;;
    blue)     C_ACCENT='\033[38;5;74m' ;;
    teal)     C_ACCENT='\033[38;5;66m' ;;
    green)    C_ACCENT='\033[38;5;71m' ;;
    lavender) C_ACCENT='\033[38;5;139m' ;;
    rose)     C_ACCENT='\033[38;5;132m' ;;
    gold)     C_ACCENT='\033[38;5;136m' ;;
    slate)    C_ACCENT='\033[38;5;60m' ;;
    cyan)     C_ACCENT='\033[38;5;37m' ;;
    *)        C_ACCENT="$C_GRAY" ;;
esac

input=$(cat)

# Extract model, directory, and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Get git branch only
branch=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
    # ブランチ名のみを取得（差分や同期状態の計算はすべてカット）
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
fi

# Context calculation (transcript processing)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
max_k=$((max_context / 1000))

if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_length=$(jq -s 'map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) | last | if . then (.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0) else 0 end' < "$transcript_path")
    baseline=20000
    bar_width=10
    if [[ "$context_length" -gt 0 ]]; then
        pct=$((context_length * 100 / max_context))
        pct_prefix=""
    else
        pct=$((baseline * 100 / max_context))
        pct_prefix="~"
    fi
    [[ $pct -gt 100 ]] && pct=100
    bar=""
    for ((i=0; i<bar_width; i++)); do
        progress=$((pct - i*10))
        if [[ $progress -ge 8 ]]; then bar+="${C_ACCENT}█${C_RESET}"
        elif [[ $progress -ge 3 ]]; then bar+="${C_ACCENT}▄${C_RESET}"
        else bar+="${C_BAR_EMPTY}░${C_RESET}"; fi
    done
    ctx="${bar} ${C_GRAY}${pct_prefix}${pct}% of ${max_k}k"
else
    ctx="${C_GRAY}---% of ${max_k}k"
fi

# Build output: Model | Dir | Branch | Context
output="${C_ACCENT}${model}${C_GRAY} | 📁${dir}"
# ブランチが存在する場合のみ、アイコンと一緒に表示
[[ -n "$branch" ]] && output+=" | 🔀${branch}"
output+=" | ${ctx}${C_RESET}"

printf '%b\n' "$output"

# Last user message display
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    max_len=50 
    last_user_msg=$(jq -rs '[.[] | select(.type == "user") | select(.message.content | type == "string" or (type == "array" and any(.[]; .type == "text")))] | reverse | map(.message.content | if type == "string" then . else [.[] | select(.type == "text") | .text] | join(" ") end | gsub("\n"; " ") | gsub("  +"; " ")) | map(select(startswith("[Request") | not)) | first // ""' < "$transcript_path" 2>/dev/null)
    if [[ -n "$last_user_msg" ]]; then
        if [[ ${#last_user_msg} -gt $max_len ]]; then echo "💬 ${last_user_msg:0:$((max_len - 3))}..."
        else echo "💬 ${last_user_msg}"; fi
    fi
fi
