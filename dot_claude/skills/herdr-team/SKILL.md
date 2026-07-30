---
name: herdr-team
description: herdr のパネル + agmsg（エージェント間メッセージング）を組み合わせた3人体制（Alice=リーダー/Claude Code、Bob=コーダー/Codex、Carol=レビュアー/Claude Code）のマルチエージェント運用ルール集。パネルは Alice と同じタブ内に配置する。トリガー: "herdr で panel", "bob に指示", "alice", "herdr-team", "パネルを分けて作業", "他のパネルに任せて", "agmsg"
---

# herdr-team — herdr + agmsg によるマルチエージェント運用

herdr のパネル管理と agmsg のエージェント間メッセージングを組み合わせて、3人体制（Alice/Bob/Carol）で作業を進めるときのルール。
参考: https://zenn.dev/horatjp/articles/multi-agent-dev-agmsg-herdr

このスキルは実行のたびに気づいたルールを追記していく前提（都度アップデート）。

## 役割の考え方

- **Alice**（リーダー / Claude Code）: ユーザーとの連絡係。現在のセッション自身。要件をタスクに分解し、Bob に実装を依頼し、Carol のレビューを経た完了報告を受けてユーザーに報告する。
- **Bob**（コーダー / Codex）: 実装専任。**唯一の編集者**。レビューは自分ではせず、完了したら必ず Carol にレビューを依頼する。
- **Carol**（レビュアー / Claude Code）: Bob の実装をレビューする品質ゲート。「実装した本人がレビューもする」問題を避けるための別の目。OK が出たら Bob 自身が Alice に完了報告する。

エージェント間のやり取り（タスク依頼・レビュー依頼・完了報告）は **agmsg** で行う。herdr はパネル（ターミナル）の起動・分割・状態監視・yes/no プロンプトの検知に使う。両者は役割が違うので混同しない。

## パネル配置（Alice と同じタブ）

タブは分けず、Alice のタブ内にそのまま分割する。

```
Alice | Bob
      |------
      | Carol
```

- 左（縦フル）: Alice（既存セッション、分割不要）
- 右上: Bob（Codex）
- 右下: Carol（Claude Code）

### スプリット手順

1. Alice のパネルを `--direction right` で分割 → Bob のパネル作成、`pane rename` で `bob`
   → `[Alice | Bob]`
2. Bob のパネルを `--direction down` で分割 → Carol のパネル作成、`pane rename` で `carol`
   → `[Alice | Bob]` / `[      | Carol]`

```bash
herdr pane split <alice_pane_id> --direction right   # → bob_pane_id
herdr pane rename <bob_pane_id> bob

herdr pane split <bob_pane_id> --direction down       # → carol_pane_id
herdr pane rename <carol_pane_id> carol
```

既に他のパネル/タブがある場合は、先に `herdr pane send-text <id> "/exit"` → `send-keys Enter` → `herdr pane close <id>` で片付けてから始める（`herdr pane list` で Alice だけの状態を確認）。

## agmsg セットアップ

`agmsg install` 済みが前提（`npx agmsg install` で `~/.agents/skills/agmsg/` に導入し、Claude Code には `/agmsg`、Codex には `$agmsg` コマンドが登録される。導入直後は各エージェントの再起動が必要）。

### チーム名

複数プロジェクトを並行運用する場合にメッセージが混線しないよう、チーム名はプロジェクト単位で決める（例: リポジトリ名や `orbit-outpost-apps` のような短い識別子）。迷ったらユーザーに確認する。

### 各エージェントの参加とモード

| エージェント | コマンド | 参加時のコマンド | 推奨モード | 理由 |
|---|---|---|---|---|
| Alice | Claude Code（既存セッション） | `/agmsg` → team/agent 名入力 → mode 選択 | **monitor** | 常時監視、~5秒でリアルタイム受信。ユーザー対応中も取りこぼさない |
| Bob | `codex` | `$agmsg` → team/agent 名入力 → mode 選択 | **turn**（既定運用） | Codex の monitor は `codex` の起動方法自体を変える必要があり、herdr からの通常起動を維持したいので turn を使う。turn は「自分の応答の最後」にしか受信をチェックしないため、Alice からのメッセージ送信後は herdr で一言ナッジが必要（後述） |
| Carol | `claude --model opus`（レビューは全体整合性判断が必要なため高性能モデルを割り当てる） | `/agmsg` → team/agent 名入力 → mode 選択 | **monitor** | Bob からのレビュー依頼を待つだけなので、通常起動のまま常時監視でよい |

**起動〜参加の実行例（Bob）:**

```bash
herdr pane send-text <bob_pane_id> "codex"
herdr pane send-keys <bob_pane_id> Enter
# codex の起動を待ってから
herdr pane send-text <bob_pane_id> "\$agmsg"
herdr pane send-keys <bob_pane_id> Enter
# → team名/agent名(bob)/モード(turn)を対話で入力させる。入力が必要な箇所は pane read で確認しつつ send-text + send-keys Enter で答える
```

**起動〜参加の実行例（Carol）:**

```bash
herdr pane send-text <carol_pane_id> "claude --model opus"
herdr pane send-keys <carol_pane_id> Enter
herdr pane send-text <carol_pane_id> "/agmsg"
herdr pane send-keys <carol_pane_id> Enter
# → team名/agent名(carol)/モード(monitor)を対話で入力させる
```

Alice（自分自身）も同じチームに `/agmsg` で参加し、モードは monitor を選ぶ。

### CLAUDE.md / AGENTS.md（Codex は AGENTS.md を読む）

Bob（Codex）はプロジェクト規約を `AGENTS.md` から読む。このリポジトリの規約は `CLAUDE.md` にあるため、Bob の worktree 作成後に一度だけ確認する:

```bash
# worktree 内に AGENTS.md が無ければ、CLAUDE.md へのシンボリックリンクを作る（worktree ローカルのみ、コミットしない）
[ -e AGENTS.md ] || ln -s CLAUDE.md AGENTS.md
```

## タスク委譲の流れ（agmsg 主体）

1. Alice が Bob にタスク内容を **agmsg で送信**する（herdr の pane send-text ではなく agmsg 経由。長文の指示もここに書く）:
   ```bash
   ~/.agents/skills/agmsg/scripts/send.sh <team> alice bob "<タスク本文>"
   ```
   （もしくは Alice のセッション内で `/agmsg send bob "<タスク本文>"`）
2. Bob は turn モードなので、新しいメッセージが来ただけでは自発的に気づかない。Alice は herdr 経由で **短いナッジ**を送って Bob に新しいターンを起こさせる:
   ```bash
   herdr pane send-text <bob_pane_id> "agmsgの受信箱を確認して"
   herdr pane send-keys <bob_pane_id> Enter
   ```
3. Bob は実装が完了したら、**Alice にではなく先に Carol へ agmsg でレビュー依頼**する:
   ```
   $agmsg send carol "<タスク概要> が完了しました。レビューをお願いします。<成果物のパス/PR番号/diffの要点など>"
   ```
   Carol は monitor モードなので herdr 側のナッジは不要（~5秒で自動的に気づく）。
4. Carol はレビューし、指摘があれば `$agmsg`（Claude Code なので `/agmsg send bob ...`）で Bob に差し戻す。**この往復は複数回になってよい**。
5. Carol が OK を出したら:
   - Carol → Bob へ承認を agmsg で送る
   - Bob → Alice へ完了報告を agmsg で送る（Alice は monitor なので自動で気づく）
   - Carol からも Alice へ一言（レビュー承認の旨）を agmsg で送っておくと Alice 側の状況把握がしやすい

### 作業中の相談・エスカレーション

Bob が作業中に判断に迷った場合は、まず Carol に agmsg で相談する（Alice にではない）。Carol が自分で判断できない場合、以下のいずれかに該当するときのみ Alice にエスカレーションする:

- セキュリティリスクが高い判断（認証情報の扱い、外部送信の可否、破壊的操作の実行可否など）
- やり直しが効かない（不可逆な）操作の可否判断

それ以外（あとから修正・再実行が可能な範囲）は Carol の判断で Bob に進めさせてよい。

## Codex（Bob）の承認モード

デフォルト（`--ask-for-approval` 未指定、承認あり）で起動する。ファイル編集・Bash 実行のたびに承認プロンプトが出るので、Alice は下記「承認待ちの検出」に従って都度確認する。**自動承認（`--ask-for-approval never`）は使わない**（このリポジトリはインフラ変更のマージ等を都度確認する方針のため）。

```bash
codex --sandbox workspace-write
```

## worktree 利用時の git push 設定

Bob が worktree で作業する場合、`origin/main` を起点にブランチを作成すると追跡先が `origin/main` に自動設定され、`git push` が main に向かってしまう問題がある。worktree 作成後に確認させる:

```bash
git config --global push.default current
git branch -vv                      # 追跡先が [origin/main] になっていないか確認
git branch --unset-upstream         # なっていたら解除
git push -u origin <branch>:<branch>  # push 時は明示的に指定すると安全
```

## パネル作成の基本コマンド

```bash
# セッション内のパネル一覧（pane_id・cwd・agent_status を確認）
herdr --session <session_name> pane list

# 現在のパネルを分割
herdr --session <session_name> pane split <pane_id> --direction down   # 上下
herdr --session <session_name> pane split <pane_id> --direction right  # 左右

# パネルに名前を付ける
herdr --session <session_name> pane rename <pane_id> <label>
```

## herdr でのテキスト送信

`send-text` はテキストを入力欄に入れるだけで実行されない。必ず `send-keys Enter` で確定する。

```bash
herdr --session <session_name> pane send-text <pane_id> "<テキスト>"
herdr --session <session_name> pane send-keys <pane_id> Enter
```

### 既知の落とし穴: send-text の直後に send-keys Enter を忘れる

`herdr pane send-text` だけ実行して `send-keys Enter` を呼び忘れると、メッセージは入力欄に入ったまま未送信になる。送った側は「送信した」つもりで先に進むが、相手は何も受け取れず反応がない。
Alice 側の検知方法: 相手パネルが `idle` のまま応答が進まない、`pane read` した際に入力ボックス（`❯ <text>` の行）にメッセージらしき文字列が表示されたまま応答が始まっていない場合はこれを疑う。対処は該当パネルに直接 `herdr pane send-keys <pane_id> Enter` を送って詰まりを解消する。

agmsg 経由のメッセージ自体はこの問題の影響を受けない（スクリプト実行なので送信漏れは起きにくい）。この落とし穴が起きるのは主に herdr 経由のナッジ・起動コマンド・承認プロンプトへの返答である点に注意。

## 承認待ち（yes/no プロンプト）の検出と判断基準

Bob（Codex）や Carol（Claude Code）は、Bash コマンド実行やファイル編集の際に承認プロンプトで止まることがある（Codex は例: `Allow command?` 形式、Claude Code は例: `Do you want to proceed?` `❯ 1. Yes` 形式）。herdr のパネルは自動で先に進まないため、Alice が気づかない限りそのパネルは無期限に停止し続ける。

- Alice は各パネルを `pane read` するたびに、選択式プロンプトで止まっていないか**毎回チェックする**。相手から「承認待ちです」と申告があるとは限らない。
- 判断に迷わない軽微な承認（ファイル作成・読み取り、ローカルの確認コマンド、既に合意済みの作業範囲内の操作等）は、その場で `pane send-keys <pane_id> Enter`（または該当の選択肢に矢印+Enter）で承認してよい。
- **承認すべきか迷う場合**（不可逆な操作、外部リポジトリへの実インフラ変更、認証情報・権限が絡むもの、影響範囲が不明瞭なもの等）は、自動承認せずに必ずユーザーに確認する。

### 落とし穴: `pane read` に承認ダイアログが表示されないことがある（"dialog waiting"）

パネルが `idle` のまま長時間同じ内容を表示し続け、`pane list` のステータス行に `dialog waiting` という文字列が出ている場合、実際には承認ダイアログが表示されているのに `pane read` の出力には反映されないことがある。

- 対処: 該当パネルに `herdr pane send-keys <pane_id> C-c` を送ると、隠れていたダイアログが `pane read` に表示されるようになることがある。
- 注意: `C-c` は稀に実行中の別コマンドを中断してしまう可能性があるため、まず `pane read` を数回試して本当に進捗が無いことを確認してから使う。

## 既知の落とし穴: 実インフラ変更PRのマージをワーカーに条件付き委任してしまう

Alice が Bob に「CIを再実行して、問題なければマージしてよい」のような**条件付きの事前承認**を出すと、Bob は自分の判断でPRをマージし、Terraform apply 等で実クラウドリソースが作成・変更されてしまう。これは Alice 自身がユーザーの確認を経ずにマージという不可逆操作を許可してしまっていることになる。

- CI が green であることと、実インフラ変更（マージ・apply）を実行してよいかは**別の判断軸**。前者は Bob が自律的に確認してよいが、後者は必ずユーザーに確認する。
- Bob への指示では「CIの状態を確認して報告して」までに留め、「問題なければマージしてよい」のような事前承認は含めない。

## 既知の落とし穴: 共有チェックアウトで直接作業してしまう

Bob はリポジトリ本体（Alice や他パネルも共有する単一のチェックアウト）ではなく、**専用の worktree** を作って作業する。指示に worktree 作成を明記し忘れると、共有チェックアウトのまま別ブランチを checkout して直接編集してしまうことがある。

- Bob へのタスク依頼（agmsg 経由）には毎回「作業は worktree を作成して行う」ことを明記する。
- Alice は `pane read` の際、ステータス行の `cwd`/`branch`/`PR #` 表示が想定と違わないか確認する。

## sleep によるポーリングの落とし穴

進捗確認のたびに `sleep 45; herdr pane read <pane_id> --lines 30` のように**特定の1パネルだけを長時間ブロッキングで待って読む**のは避ける。herdr のパネルは Alice に自動で push 通知しない（agmsg のメッセージは monitor モードなら自動で気づくが、パネル自体の作業状況・承認待ちは別）。

代わりに:

1. まず `herdr pane list` で**全パネルの `agent_status` を一度に確認**し、`idle`/`unknown`/`blocked` になっているものだけ `pane read` する。
2. 複数パネルの完了を待ちたいときは、`herdr wait agent-status <id> --status idle --timeout N &` を対象パネル分だけバックグラウンド起動して `wait -n` で待つ。
3. どうしても様子見したい場合も `sleep` は数秒程度に留め、毎回 `pane list` で全パネルの状態を見る。

## herdr wait のサブコマンド（リファレンス）

- `herdr wait output <pane_id> --match <text> [--regex] [--timeout MS]` — 特定の文字列が出力されるまで待つ
- `herdr wait agent-status <pane_id> --status <idle|working|blocked|done|unknown> [--timeout MS]` — エージェントの状態変化を待つ

### 注意: send-keys 直後の wait は即座に返ることがある（レース）

`send-keys Enter` 直後に `wait agent-status --status idle` を呼ぶと、まだ処理を開始する前の古い `idle` イベントを拾って即座に返ってしまうことがある。心配な場合は:

```bash
herdr wait agent-status <pane_id> --status working --timeout 15000  # 処理開始を確認
herdr wait agent-status <pane_id> --status idle --timeout 60000      # 完了を待つ
```

最終的には `pane read` の内容で完了を確認するのが確実。

## 報告のフォーマット

- Bob/Carol からの生ログをそのまま貼らず、要点を表や箇条書きに要約してユーザーに伝える。
- ユーザーへの確認事項（例: 不要ファイルの削除可否）が出てきた場合は、要約の最後に明示的に転記してユーザーの判断を仰ぐ。

## 拡張（4人以上に増やす場合）

必要になれば Dave（追加ワーカー）等を同じパターンで増やせる。パネルは `[Alice | Bob]` / `[Dave | Carol]` のように2x2へ、agmsg のチームには `join.sh <team> dave codex "$(pwd)"` で追加する。レビューは Carol 固定のままでよい（複数ワーカーが1人のレビュアーに依頼する形）。

## 運用ルールの追記方針

この手順で新しい気づき（例: agmsg の delivery mode の挙動、Codex の承認プロンプトの具体的な文字列パターンなど）が発生したら、このファイルに追記して再現可能にする。
