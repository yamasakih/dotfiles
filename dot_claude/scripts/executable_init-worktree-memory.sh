#!/bin/bash
# init-worktree-memory.sh
# 親リポジトリの Claude Code auto-memory を新しく作成された worktree にコピーする
#
# Usage: init-worktree-memory.sh <worktree-path>

set -euo pipefail

WORKTREE_PATH="${1:-.}"
# 絶対パスに変換
WORKTREE_PATH=$(cd "$WORKTREE_PATH" && pwd)

# .git がファイルかどうか確認 (worktree 判定)
GIT_FILE="$WORKTREE_PATH/.git"
if [ ! -f "$GIT_FILE" ]; then
    echo "Error: $WORKTREE_PATH is not a git worktree." >&2
    exit 1
fi

# gitdir パスを取得
GIT_DIR=$(sed 's/^gitdir: //' "$GIT_FILE" | tr -d '\n')

# commondir ファイルから親 .git ディレクトリを特定
COMMON_DIR_FILE="$GIT_DIR/commondir"
if [ ! -f "$COMMON_DIR_FILE" ]; then
    echo "Error: Could not find commondir. Is this a standalone repo?" >&2
    exit 1
fi

COMMON_REL=$(tr -d '\n' < "$COMMON_DIR_FILE")

# 相対パスを絶対パスに変換
if [[ "$COMMON_REL" == /* ]]; then
  COMMON_ABS="$COMMON_REL"
else
  COMMON_ABS="$(cd "$GIT_DIR" && cd "$COMMON_REL" && pwd)"
fi

PARENT_ROOT="$(dirname "$COMMON_ABS")"

# パスエンコード関数 (Claude Code の規則: / . _ を - に変換)
encode_path() { echo "$1" | tr '/._' '-'; }

WORKTREE_ENC=$(encode_path "$WORKTREE_PATH")
PARENT_ENC=$(encode_path "$PARENT_ROOT")

WORKTREE_MEM_DIR="$HOME/.claude/projects/$WORKTREE_ENC/memory"
PARENT_MEM_DIR="$HOME/.claude/projects/$PARENT_ENC/memory"

# 親のメモリが存在しない場合は終了
if [ ! -d "$PARENT_MEM_DIR" ]; then
    echo "No parent memory found at $PARENT_MEM_DIR. Skipping."
    exit 0
fi

# Worktree 用のディレクトリを作成
mkdir -p "$WORKTREE_MEM_DIR"

# MEMORY.md をコピー (既存の場合は上書きせずバックアップするか検討が必要だが、初期化用なので基本コピー)
if [ -f "$PARENT_MEM_DIR/MEMORY.md" ]; then
    cp "$PARENT_MEM_DIR/MEMORY.md" "$WORKTREE_MEM_DIR/MEMORY.md"
    echo "Inherited MEMORY.md from parent repository."
fi

# SESSION_HANDOFF.md も必要であればコピー (直近のタスク状況を引き継ぐ場合)
if [ -f "$PARENT_MEM_DIR/SESSION_HANDOFF.md" ]; then
    cp "$PARENT_MEM_DIR/SESSION_HANDOFF.md" "$WORKTREE_MEM_DIR/SESSION_HANDOFF.md"
    echo "Inherited SESSION_HANDOFF.md from parent repository."
fi

