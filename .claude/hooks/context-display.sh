#!/bin/bash
# Context Display Hook - UserPromptSubmit時にコンテキスト情報を表示
# (警告閾値を20%引き下げたバージョン)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$SCRIPT_DIR/../tmp/hooks"
LOG_FILE="$TMP_DIR/context-display-error.log"
mkdir -p "$TMP_DIR"

log_debug() {
  if [[ "${HOOK_DEBUG:-0}" == "1" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [context-display] $*" >> "$LOG_FILE"
  fi
}
log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [context-display] ERROR: $*" >> "$LOG_FILE"
}

# stdinからJSON入力を読み取り
INPUT=$(cat)
log_debug "Script called (UserPromptSubmit)"

if [[ "${HOOK_DEBUG:-0}" == "1" ]]; then
  echo "$INPUT" > "$TMP_DIR/hook-input-debug.json"
fi

# stdoutをClaudeのコンテキスト用に出力し、stderrをログ用にする
exec 3>&1
node_output=$(node -e "const fs = require('fs');
const DEBUG = process.env.HOOK_DEBUG === '1';
const logFile = process.argv[3];
function logDebug(msg) {
  if (DEBUG && logFile) {
    const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
    fs.appendFileSync(logFile, '[' + timestamp + '] [context-display:node] ' + msg + '\n');
  }
}
try {
  const hookInput = JSON.parse(process.argv[1]);
  const sessionId = hookInput.session_id || 'default';
  const tmpDir = process.argv[2];
  const contextFile = tmpDir + '/context-' + sessionId + '.json';
  
  if (!fs.existsSync(contextFile)) process.exit(0);
  
  const data = JSON.parse(fs.readFileSync(contextFile, 'utf8'));
  const ctx = data.context_window;
  if (!ctx) process.exit(0);
  
  const windowSize = ctx.context_window_size || 200000;
  const usage = ctx.current_usage || {};
  const total = (usage.input_tokens || 0) + (usage.cache_creation_input_tokens || 0) + (usage.cache_read_input_tokens || 0);
  const percent = Math.round(total * 100 / windowSize);
  
  // 閾値を60%から40%に変更
  if (percent < 40) process.exit(0);
  
  const barLength = 20;
  const filled = Math.round(percent / 100 * barLength);
  const bar = '\u2588'.repeat(filled) + '\u2591'.repeat(barLength - filled);
  const contextBar = '[Context] ' + bar + ' ' + percent + '% (' + total.toLocaleString() + ' / ' + windowSize.toLocaleString() + ' tokens)';
  
  let urgency, question, options;
  // 閾値を全体的に20%引き下げ (75->55, 70->50)
  if (percent >= 55) {
    urgency = 'CRITICAL';
    question = '\u26a0\ufe0f コンテキスト使用率が ' + percent + '% に達しています。早めの /compact をお勧めします（自動compactは77%）。';
    options = [
      { label: '/compact を入力する（推奨）', desc: '次のプロンプトで /compact と入力してコンテキストを整理します' },
      { label: 'このまま続行', desc: '作業を継続します' }
    ];
  } else if (percent >= 50) {
    urgency = 'WARNING';
    question = '\u26a0\ufe0f コンテキスト使用率が ' + percent + '% です。自動compact(77%)まで残り約 ' + (77 - percent) + '% です。';
    options = [
      { label: '/compact を入力する（推奨）', desc: '次のプロンプトで /compact と入力してコンテキストを整理します' },
      { label: 'このまま続行', desc: '作業を継続します' }
    ];
  } else {
    urgency = 'NOTICE';
    question = 'コンテキスト使用率が ' + percent + '% です。自動compact(77%)まで残り約 ' + (77 - percent) + '% です。';
    options = [
      { label: 'このまま続行', desc: 'まだ余裕があります。作業を継続します' },
      { label: '/compact を入力する', desc: '今のうちにコンテキストを整理します' }
    ];
  }
  
  console.log('【Claude への必須指示】ユーザーの指示を実行する前に、以下の内容でAskUserQuestionツールを使用して確認してください:\n');
  console.log('header: \"Context ' + urgency + '\"');
  console.log('question: \"' + question + '\"\noptions:');
  options.forEach(opt => console.log('  - label: \"' + opt.label + '\", description: \"' + opt.desc + '\"'));
  console.log('\ncontextBar: ' + contextBar);
  
  console.error('OK: ' + urgency + ' message output');
} catch (e) {
  console.error('FAIL: ' + e.message);
  process.exit(1);
}" "$INPUT" "$TMP_DIR" "$LOG_FILE" 2>&1 >&3)
exec 3>&-

node_exit_code=$?
if [[ $node_exit_code -ne 0 ]]; then
  log_error "Node.js failed: $node_output"
fi
exit 0

