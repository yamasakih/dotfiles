# Issue Tracker

## Improvements

### Improvement #1: `alias cat='bat'` のパイプライン互換性 (PR #2 レビュー指摘)

**対象ファイル**:
- `dot_zshrc`

**現状**:
`alias cat='bat'` により、パイプライン内で `cat` を使うスクリプトで予期しない動作になる可能性がある。bat はデフォルトでページャー付き・カラー出力を行う。

**改善案**:
bat 自体は `TERM=dumb` やパイプ検出で自動的にプレーン出力に切り替えるため、多くの場合は問題にならない。問題が発生した場合は `alias cat='bat --paging=never'` に変更するか、エイリアスを削除して `alias bat='bat'` のみにする。

**優先度**: 低

---
