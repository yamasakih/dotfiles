#!/bin/bash
# init-worktree-memory.sh
# 親リポジトリの Claude Code auto-memory を新しく作成された worktree にコピーする

set -euo pipefail

# 1. パスの確定 (migrate側と統一)
RAW_PATH="${1:-.}"
[ -e "$RAW_PATH" ] || { echo "Error: Path $RAW_PATH does not exist."; exit 1; }
WORKTREE_PATH=$(realpath "$RAW_PATH")

# 2. 親リポジトリのルートパスを Worktree 構造から取得 (migrate側と統一)
COMMON_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir 2>/dev/null || echo "")
[ -z "$COMMON_DIR" ] && { echo "Error: Not a git repository or worktree."; exit 1; }

if [[ "$COMMON_DIR" != /* ]]; then
    PARENT_GIT_DIR=$(realpath "$WORKTREE_PATH/$COMMON_DIR")
else
    PARENT_GIT_DIR=$(realpath "$COMMON_DIR")
fi
PARENT_ROOT=$(dirname "$PARENT_GIT_DIR")

# 同一パス（Worktreeではない場合）はスキップ
[ "$WORKTREE_PATH" = "$PARENT_ROOT" ] && { echo "Same path as parent. Skipping."; exit 0; }

# 3. Claude プロジェクト ID 特定関数 (migrate側の get_claude_id ロジックをインライン化)
encode_path() {
    local target_path="$1"
    # Claude の命名規則: 先頭 / を含め、/._ を - に置換
    echo "$target_path" | sed 's|^/|-|' | tr '/._' '-'
}

WT_ID=$(encode_path "$WORKTREE_PATH")
PARENT_ID=$(encode_path "$PARENT_ROOT")

WORKTREE_MEM_DIR="$HOME/.claude/projects/$WT_ID/memory"
PARENT_MEM_DIR="$HOME/.claude/projects/$PARENT_ID/memory"

# 4. 実行
# 親のメモリが存在しない場合は終了
if [ ! -d "$PARENT_MEM_DIR" ]; then
    echo "No parent memory found at $PARENT_MEM_DIR. Skipping."
    exit 0
fi

# Worktree 用のディレクトリを作成
mkdir -p "$WORKTREE_MEM_DIR"

# MEMORY.md をコピー
if [ -f "$PARENT_MEM_DIR/MEMORY.md" ]; then
    cp "$PARENT_MEM_DIR/MEMORY.md" "$WORKTREE_MEM_DIR/MEMORY.md"
    echo "✅ Inherited MEMORY.md from parent: $PARENT_ID"
fi

# SESSION_HANDOFF.md もコピー (作業コンテキストを引き継ぐため)
if [ -f "$PARENT_MEM_DIR/SESSION_HANDOFF.md" ]; then
    cp "$PARENT_MEM_DIR/SESSION_HANDOFF.md" "$WORKTREE_MEM_DIR/SESSION_HANDOFF.md"
    echo "✅ Inherited SESSION_HANDOFF.md from parent."
fi

