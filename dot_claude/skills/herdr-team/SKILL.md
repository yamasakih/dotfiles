---
name: herdr-team
description: herdr で複数の Claude Code パネルをチームとして運用するときの手順・ルール集。オーケストレーター役（alice）が他のパネル（bob 等）にタスクを委譲し、完了を検知してユーザーに報告するまでの一連の運用パターンをまとめる。トリガー: "herdr で panel", "bob に指示", "alice", "herdr-team", "パネルを分けて作業", "他のパネルに任せて"
---

# herdr-team — herdr パネルを使ったマルチエージェント運用

複数の Claude Code パネル（herdr session 内）を役割分担させて運用するときのルール。
このスキルは実行のたびに気づいたルールを追記していく前提（都度アップデート）。

## 役割の考え方

- **alice**（オーケストレーター）: ユーザーとの連絡係。自分では具体的な作業をせず、他パネルに指示を出し、結果をまとめてユーザーに報告する。
- **bob / carol / dave**（ワーカー）: 実際の作業（別リポジトリでの調査・実装など）を行う。
- **eve**（レビュアー、固定role）: 一般ワーカーではなく、Bob/Carol/Dave が完了報告する**前に必ず通す品質ゲート**。詳細は下記「レビュー体制（Eveによるレビュー）」を参照。
- パネル名は `herdr pane rename <pane_id> <label>` で付ける。名前を付けると `herdr pane list` の `label` で判別できるようになる。

## default パネル配置

「default のパネル配置でスタートして」と言われたら、2タブ構成で起動する。

**Tab 1（Alice タブ）**: ユーザーの作業場 + Alice（オーケストレーター）のみ。Alice は単独パネル。

**Tab 2（Workers タブ）**: ワーカー 3 名 + レビュアー 1 名を 2x2 グリッドで配置。

```
Bob (Sonnet)  | Carol (Sonnet)
--------------+---------------
Dave (Haiku)  | Eve (Opus, レビュアー)
```

| パネル | 役割 | モデル | 起動時の claude 引数 |
|---|---|---|---|
| Alice | オーケストレーター | Opus 4.6（※現状の指定。将来 downgrade 予定なので都度ユーザーに確認） | `claude --model claude-opus-4-6` |
| Bob | ワーカー（高難度） | Sonnet 5 | `claude --model sonnet` |
| Carol | ワーカー（高難度） | Sonnet 5 | `claude --model sonnet` |
| Dave | ワーカー（軽量） | Haiku 4.5 | `claude --model haiku` |
| Eve | **レビュアー（固定role）** | **Opus**（レビューは全体の整合性判断が必要なため高性能モデルを割り当てる） | `claude --model opus` |

### タスク割り振りの方針

Alice はタスクの難易度に応じてワーカー（Bob / Carol / Dave）を選ぶ。Eve はワーカーではなくレビュアー固定なので、実装・調査タスクの割り振り先には含めない:

- **Sonnet（Bob / Carol）**: 設計判断が必要な実装、複雑なリファクタリング、コードレビュー、調査・分析など思考力が求められるタスク
- **Haiku（Dave）**: 単純な検索・grep、定型的なファイル編集、フォーマット修正、情報の転記・整形など機械的なタスク

迷ったら Sonnet に振る。Haiku で失敗して Sonnet でやり直すほうがコストが高い。

### 前提: クリーンな状態から開始する

既に複数パネル/タブがある場合は、先に不要なものを閉じる:

```bash
# パネルで Claude が起動中なら先に終了
herdr pane send-text <pane_id> "/exit"
herdr pane send-keys <pane_id> Enter
herdr wait agent-status <pane_id> --status unknown --timeout 10000
# パネルを閉じる
herdr pane close <pane_id>
```

Alice のパネルだけになったことを `herdr pane list` で確認してから次に進む。

### スプリット手順（順序厳守）

分割の順序と方向がレイアウトを決める。

**Tab 2（Workers タブ）の作成:**

1. `herdr tab create` で新しいタブを作成 → 最初のパネルを Bob とする、`pane rename`
2. Bob を `--direction right` で分割 → Carol を作成、`pane rename`
   → この時点で `[Bob | Carol]` の横並び
3. Bob を `--direction down` で分割 → Dave を作成、`pane rename`
   → この時点で `[Bob / Dave | Carol]`
4. Carol を `--direction down` で分割 → Eve を作成、`pane rename`
   → これで 2x2 グリッド完成
5. Bob/Carol は `claude --model sonnet`、Dave は `claude --model haiku`、**Eve は `claude --model opus`**（レビュアー固定role）を `send-text` + `send-keys Enter` で起動
6. Alice 自身は既に起動済みのセッションなのでモデル切り替えは `/model` コマンドで行う（Opus 4.6 が選択肢にない場合はユーザーに確認）

**重要**: 既存の複数パネルを「流用」してリネームするだけでは空間配置が保証されない。必ず上記の順序でスプリットすること。

### worktree 利用時の git push 設定

ワーカーが worktree で作業する場合、`origin/main` を起点にブランチを作成すると追跡先が `origin/main` に自動設定され、`git push` が main に向かってしまう問題がある。起動時の初期メッセージで以下を伝えるか、worktree 作成後に確認させる:

```bash
# push.default が current になっているか確認（なっていなければ設定）
git config --global push.default current

# worktree でブランチ作成後、追跡先が main になっていないか確認
git branch -vv

# もし [origin/main] になっていたら解除
git branch --unset-upstream

# push 時は明示的に指定すると安全
git push -u origin <branch>:<branch>
```

### 起動後の初期メッセージ

Claude を起動したら、最初に自己紹介メッセージを送って役割・完了報告ルールを認識させる。**Bob/Carol/Dave（ワーカー）と Eve（レビュアー）でメッセージが異なる**点に注意。

**ワーカー（Bob/Carol/Dave）向け:**

```bash
herdr pane send-text <pane_id> "あなたは herdr team の一員で、名前は <name> です。オーケストレーションの Alice が私です。指示は Alice から送ります。

タスクが完了しても、まだ Alice には報告しないでください。必ず先に Eve（レビュアー）へレビューを依頼してください:
1. herdr pane send-text <eveのpane_id> '<name>です。<タスク概要> が完了しました。レビューをお願いします。<成果物のパス/PR番号/diffの要点など>'
2. herdr pane send-keys <eveのpane_id> Enter

Eve から指摘があれば対応し、再度レビューを依頼してください（往復は複数回になることがあります）。Eve が OK を出したら、そこで初めて以下を実行して Alice に完了を通知してください:
1. herdr pane report-agent <自分のpane_id> --source claude --agent <name> --state idle --message '完了: <タスクの要約>（Eveレビュー済み）'
2. echo \"done\" > /tmp/herdr-team/<name>-done.txt

作業中に判断に迷うことがあれば、まず Eve に相談してください（Alice にではなく）。Eve が判断できない場合のみ、Eve から Alice にエスカレーションされます。"
herdr pane send-keys <pane_id> Enter
```

**Eve（レビュアー）向け:**

```bash
herdr pane send-text <eve_pane_id> "あなたは herdr team のレビュアー、Eve です。オーケストレーションの Alice が私です。

役割:
- Bob/Carol/Dave が作業完了時にあなたへレビューを依頼してきます。plan への準拠だけでなく、局所的ではなく全体を通して『期待通りのタスク完了』と言える状態になっているかを確認してください。
- 指摘があれば担当ワーカーに差し戻し、対応後に再度レビューしてください（この往復は複数回になって構いません）。
- OK を出したら、そのワーカー自身が Alice に完了報告する流れです。加えてあなたからも herdr pane report-agent <自分のpane_id> --source claude --agent eve --state idle --message 'レビュー完了: <name>の<タスク概要>を承認' で Alice に一言通知してください。
- ワーカーから作業中に相談が来ることがあります。まずあなたの判断で回答してください。以下のいずれかに該当する場合のみ、Alice にエスカレーションしてください:
  - セキュリティリスクが高い判断（認証情報の扱い、外部送信、破壊的操作の実行可否など）
  - やり直しが効かない（不可逆な）操作の可否判断
  それ以外（あとから修正・再実行が可能な範囲）は、あなたの判断で進めさせて構いません。"
herdr pane send-keys <eve_pane_id> Enter
```

各パネルが idle に戻ったことを確認してからタスクの指示に移る。

### ワーカーへのタスク指示時の完了通知テンプレート

タスク指示の末尾に以下を必ず含める（起動時の初期メッセージで伝えていても毎回リマインドする）。
**「共有ディレクトリ（orbit-outpost-apps 本体等）で直接作業せず、専用の worktree を作成してから作業すること」も同様に毎回リマインドする**
（このリマインドを忘れると「複数ワーカーが同じ共有チェックアウトで作業してしまう」節の事故が高確率で再発する。実際、一度指摘して直った後のタスクでも、指示に worktree 作成を明記し忘れた回で再発した）。

```
作業は必ず専用の worktree を作成してから行ってください（orbit-outpost-apps 本体などの共有ディレクトリで直接 checkout/編集しないこと）。

完了したら、Alice にではなくまず Eve にレビューを依頼してください:
herdr pane send-text <eveのpane_id> "<name>です。<タスク概要> のレビューをお願いします。"
herdr pane send-keys <eveのpane_id> Enter

Eve の OK が出てから、以下を実行して Alice に完了を通知してください:
1. herdr pane report-agent <pane_id> --source claude --agent <name> --state idle --message '完了: <タスクの1行要約>（Eveレビュー済み）'
2. echo "done" > /tmp/herdr-team/<name>-done.txt

判断に迷うことがあれば Alice ではなくまず Eve に相談してください。
```

`report-agent` により Alice 側で `herdr pane list` するだけで各パネルの最新状態とメッセージが確認でき、`pane read` する前に完了/ブロック状態を把握できる。

## パネル作成の基本コマンド

```bash
# セッション内のパネル一覧（pane_id・cwd・agent_status を確認）
herdr --session <session_name> pane list

# 現在のパネルを水平（上下）分割。水平＝上下に区切る方向なので --direction down
herdr --session <session_name> pane split <pane_id> --direction down [--cwd PATH]
# 垂直（左右）分割にしたい場合は --direction right

# パネルに名前を付ける
herdr --session <session_name> pane rename <pane_id> <label>
```

## ワーカーへの指示の送り方

`send-text` はテキストを入力欄に入れるだけで実行されない。必ず `send-keys Enter` で確定する。

```bash
herdr --session <session_name> pane send-text <pane_id> "<指示文>"
herdr --session <session_name> pane send-keys <pane_id> Enter
```

## 完了検知（ワーカーから Alice への通知）

### 基本方針: ファイルベースのシグナル

ワーカーへの指示文に「完了したらシグナルファイルを書け」と含める。
Alice は Bash の `inotifywait`（または軽い ls ポーリング）で検知し、完了したワーカーから順に結果を読む。

**Eve レビュー体制導入後の注意**: ワーカーは Eve のレビューを通してから done ファイルを書く運用になったため、Alice 側の待ち時間は「作業時間 + Eve とのレビュー往復時間」を含む。単純作業でも複数回のレビュー往復が挟まる場合があるため、タイムアウトは余裕を持って設定する。

**ワーカーへの指示テンプレート（末尾に必ず付ける）:**

```
作業が完了したら、結果サマリーを以下のファイルに書いてください:
echo "done" > /tmp/herdr-team/<name>-done.txt
```

**Alice 側の検知（複数ワーカー並列待ち）:**

```bash
# /tmp/herdr-team/ を作成（初回のみ）
mkdir -p /tmp/herdr-team

# 複数ワーカーを同時に待つ: いずれかのシグナルファイルが現れたら検知
inotifywait -m -e create /tmp/herdr-team/ --format '%f' --timeout 300
# → "bob-done.txt" 等が出力される

# または簡易ポーリング（inotifywait が使えない場合）
while [ ! -f /tmp/herdr-team/bob-done.txt ]; do sleep 5; done
```

シグナルファイルを検知したら `herdr pane read <pane_id> --lines 80` で結果を読む。
次のタスクサイクル開始前に `rm /tmp/herdr-team/*-done.txt` でクリーンアップする。

### フォールバック: herdr wait（ワーカーがシグナルを書き忘れた場合）

ワーカーがシグナルファイルを書かずに終了した場合のフォールバックとして `herdr wait` も併用できる。
ただし逐次実行ではなくバックグラウンド並列で走らせること:

```bash
herdr wait agent-status <pane_id_bob> --status idle --timeout 300000 &
herdr wait agent-status <pane_id_carol> --status idle --timeout 300000 &
wait -n  # どれか1つが終わったら即座に返る
```

### herdr wait のサブコマンド（リファレンス）

- `herdr wait output <pane_id> --match <text> [--regex] [--timeout MS]` — 特定の文字列が出力されるまで待つ
- `herdr wait agent-status <pane_id> --status <idle|working|blocked|done|unknown> [--timeout MS]` — エージェントの状態変化を待つ

### 注意: send-keys 直後の wait は即座に返ることがある（レース）

`send-keys Enter` 直後に `wait agent-status --status idle` を呼ぶと、エージェントがまだ処理を開始する前の
古い `idle` イベントを拾って即座に返ってしまうことがある（実際にはまだ "Processing…" 中）。
一度で判定せず、`pane read` で実際に応答が出揃っているか確認する。心配な場合は:

```bash
herdr wait agent-status <pane_id> --status working --timeout 15000  # 処理開始を確認
herdr wait agent-status <pane_id> --status idle --timeout 60000      # 完了を待つ
```

最終的には `pane read` の内容で完了を確認するのが確実。

### 承認待ち（yes/no プロンプト）の検出と判断基準

ワーカー（Bob/Carol/Dave）や Eve は、Bash コマンド実行やファイル編集の際に yes/no の承認プロンプトで止まることがある（例: `Do you want to proceed?` `Do you want to make this edit?`）。herdr のパネルは自動で先に進まないため、Alice が気づかない限りそのパネルは無期限に停止し続ける。

- Alice は各パネルを `pane read` するたびに、末尾が `❯ 1. Yes` のような選択式プロンプトで止まっていないか**毎回チェックする**。ワーカー側から「承認待ちです」と申告があるとは限らない（申告なくパネルが固まっていることも多い）。
- 判断に迷わない軽微な承認（ファイル作成・読み取り、ローカルの確認コマンド、既に合意済みの作業範囲内の操作等）は、その場で `pane send-keys <pane_id> Enter`（または該当の選択肢に `Down`+`Enter`）で承認してよい。
- **承認すべきか迷う場合**（不可逆な操作、外部リポジトリへの実インフラ変更、認証情報・権限が絡むもの、影響範囲が不明瞭なもの等）は、自動承認せずに必ずユーザーに確認する。「レビュー体制」節のエスカレーション基準（セキュリティリスク・不可逆操作）と同じ基準で判断してよい。

#### 落とし穴: `pane read` に承認ダイアログが表示されないことがある（"dialog waiting"）

パネルが `idle` のまま長時間同じ内容（例: 同じ `sleep N; <コマンド>` 行が "Waiting…" のまま）を表示し続け、`pane list` のステータス行に **`dialog waiting`** という文字列が出ている場合、実際には yes/no の承認ダイアログが表示されているのに `pane read` の出力には反映されないことがある（tmux 的なペインの描画とスクロールバッファの取得タイミングのズレが原因と推測される）。

- 単なる長時間実行中のコマンド（ネットワーク呼び出しのハング等）と区別がつきにくいが、`dialog waiting` の文字列が出ていたら承認ダイアログが隠れている可能性を疑う。
- 対処: 該当パネルに `herdr pane send-keys <pane_id> C-c` を送ると、隠れていたダイアログが `pane read` に表示されるようになることがある（Enter や Down では効かない場合、これを試す）。ダイアログが見えたら内容を確認し、通常の承認フローに従う。
- 注意: `C-c` は稀に実行中の別コマンドを中断してしまう可能性があるため、まず `pane read` を数回試して本当に進捗が無いことを確認してから使う。

### 既知の落とし穴: 実インフラ変更PRのマージをワーカーに条件付き委任してしまう

Alice がワーカーに「CIを再実行して、問題なければマージしてよい」のような**条件付きの事前承認**を出すと、ワーカーは自分の判断でPRをマージし、Terraform apply 等で実クラウドリソースが作成・変更されてしまう。これは Alice 自身がユーザーの確認を経ずにマージという不可逆操作を許可してしまっていることになり、パネルの yes/no プロンプト承認とは別の問題として区別すること。

- CI が green であることと、実インフラ変更（マージ・apply）を実行してよいかは**別の判断軸**。前者はワーカーが自律的に確認してよいが、後者は必ずユーザーに確認する。
- ワーカーへの指示では「CIの状態を確認して報告して」までに留め、「問題なければマージしてよい」のような事前承認は含めない。マージの実行可否は都度 Alice がユーザーに確認してから改めてワーカーに指示する。

## 既知の落とし穴: 複数ワーカーが同じ共有チェックアウトで作業してしまう

ワーカーは基本的にリポジトリ本体（例: `orbit-outpost-apps` 直下、Alice や他ワーカーも共有する単一のチェックアウト）ではなく、**専用の worktree** を作って作業する運用だが、指示にworktree作成を明記し忘れる／ワーカーが手順を省略すると、共有チェックアウトのまま別ブランチを checkout して直接編集してしまうことがある。

この場合、後から別のワーカーが同じ共有ディレクトリで作業を始めると、前のワーカーのブランチがチェックアウトされたままの状態を引き継いでしまい、意図せず他人のブランチに追記・コミットしてしまうリスクがある（`git branch --show-current` が想定と違うブランチを指している、`pane` のステータス行に見覚えのない `🔀 <branch>`/`PR #NN` が出ている等で気づける）。

- ワーカーへのタスク指示には毎回「作業は worktree を作成して行う」ことを明記する（このファイルの「起動後の初期メッセージ」テンプレートにも含まれているが、都度のタスク指示でもリマインドするとより安全）。
- Alice は `pane read` の際、ステータス行の `cwd`/`branch`/`PR #` 表示が他ワーカーのものと重複していないか確認する。重複を見つけたら即座に作業を止めさせ、共有チェックアウトを安全なブランチ（`main` 等）に戻させた上で、そのワーカー専用の worktree を新規作成させてから作業を再開させる。
- 幸い、先行ワーカーが既に push・PR作成済みであれば実害は小さい（作業はリモートに残っているため）。ただし push 前の未コミット変更がある状態で共有チェックアウトを奪うと変更が失われる/混ざるリスクがあるため、疑わしい場合は必ず `git status` で未コミット変更の有無を確認してから対処する。

## レビュー体制（Eve によるレビュー）

Bob/Carol/Dave は、タスク完了時に **Alice にではなく先に Eve にレビューを依頼する**。この体制の目的は、Alice（オーケストレーター）に生の成果物チェックの負荷を集中させず、レビュー専任の Eve が品質ゲートとして機能することにある。

### レビューの流れ

1. ワーカー（Bob/Carol/Dave）はタスクが完了したと思ったら、Eve に `pane send-text` でレビューを依頼する（Alice への報告はまだしない）
2. Eve は以下の観点でチェックする:
   - **plan への準拠**: そのタスクが元々の plan / 指示内容を満たしているか
   - **局所的でなく全体を通した完了と言えるか**: 該当箇所だけでなく、関連する既存機能・テスト・他タスクとの整合性まで見て、"期待通りに完了した" と言える状態になっているかを判断する（部分的にしか対応していない、副作用で他が壊れている、等を見逃さない）
3. 指摘があればワーカーに差し戻す。ワーカーは対応後、再度 Eve にレビューを依頼する。**この往復は複数回になってよい**（1回で通す必要はない）。
4. Eve が OK を出したら、その時点でワーカー自身が Alice に完了報告する（`report-agent` + done ファイル）。Eve からも Alice へ一言（レビュー承認の旨）通知する。
5. Alice はレビュー済みの完了報告として受け取り、追加のレビューをゼロからやり直す必要はない（ただしユーザーへの報告前に軽く目を通すのは妨げない）。

### 作業中の相談・エスカレーションの判断基準

ワーカーが作業中に判断に迷った場合は、まず Eve に相談する（Alice にではない）。

- Eve が自分で判断できる場合はその場で回答し、ワーカーはそのまま作業を続行する。
- Eve が判断できない場合、**以下のいずれかに該当するときのみ** Alice にエスカレーションする:
  - セキュリティリスクが高い判断（認証情報の扱い、外部送信の可否、破壊的操作の実行可否など）
  - やり直しが効かない（不可逆な）操作の可否判断
- 上記に該当しない、つまり **セキュリティリスクが低く、あとから修正・やり直しが効く範囲の判断**は、Eve が自分の判断でワーカーに進めさせてよい（Alice へのエスカレーション不要）。

### ワーカーが詰まった場合の自律判断

ワーカーが「認証エラーで読めない」「ツールが見つからない」等で止まった場合は、まず Eve に相談する。Eve が上記基準に沿って自分で解決策を出すか、必要な場合のみ Alice にエスカレーションする。（Eve 不在時や暫定運用時は、この判断を Alice が肩代わりしてよい）

- **Google Doc / Google 系サービスへのアクセス**: `gws` コマンドを使うよう指示する
- **ツールやスキルの使い方がわからない**: 使い方を調べて具体的なコマンドを教える
- **権限エラー**: 回避策を試させる。どうしても解決できない場合のみ Alice にエスカレーション

## 報告のフォーマット

- ワーカーからの生ログをそのまま貼らず、要点を表や箇条書きに要約してユーザーに伝える。
- ワーカー側からユーザーへの確認事項（例: 不要ファイルの削除可否）が出てきた場合は、要約の最後に明示的に転記してユーザーの判断を仰ぐ。

## 既知の落とし穴: `sleep N; pane read <1パネル>` で他パネルを見落とす

進捗確認のたびに `sleep 45; herdr pane read <pane_id> --lines 30` のように**特定の1パネルだけを
長時間ブロッキングで待って読む**のは避ける。理由:

- herdr のパネルは Alice に自動で push 通知しない。Alice が明示的に見に行かない限り、
  他パネル（例: Bob を待っている間の Dave/Carol）の完了・エスカレーション・詰まりに一切気づけない。
- ユーザーからの新規メッセージは `sleep` 中でもシステム側が次のツール結果と一緒に届けてくれるため
  取りこぼさないが、**ワーカー側の状態変化は同様の仕組みがなく、完全に見落とす**。
- 長い `sleep` は単に時間を消費するだけで、その間に他の作業（他パネルの確認、ユーザーへの中間報告）ができない。

代わりに:

1. まず `herdr pane list` で**全パネルの `agent_status` を一度に確認**し、`idle`/`unknown`/`blocked`
   になっているものだけ `pane read` する（`working` のものは無駄に読みに行かない）。
2. 複数パネルの完了を待ちたいときは、1パネルに対する長時間 `sleep` ではなく、
   「フォールバック: herdr wait」節にある `herdr wait agent-status <id> --status idle --timeout N &`
   を対象パネル分だけバックグラウンド起動して `wait -n` で待つか、
   `inotifywait` で `/tmp/herdr-team/` の done ファイル生成を待つ（「完了検知」節参照）方式を使う。
3. どうしても一度だけ様子見したい場合も、`sleep` は数秒程度の短い間隔に留め、
   毎回 `pane list` で全パネルの状態を見てから、動きがあったパネルだけ `pane read` する。

## 既知の落とし穴: send-text の直後に send-keys Enter を忘れる（Bob/Dave → Eve 等の連絡全般）

ワーカー（Bob/Carol/Dave）や Eve が、他パネルへの連絡で `herdr pane send-text` だけ実行して
`herdr pane send-keys <pane_id> Enter` を呼び忘れるケースが頻発する。この場合メッセージは
相手パネルの**入力欄に入ったまま未送信**になり、送った側は「送信した」つもりで先に進んでしまうが、
相手は何も受け取れず反応がない（相手パネルを読むと、入力ボックスにテキストが表示されたまま止まっている）。

これは Eve→ワーカーの経路だけでなく、ワーカー→Eve、ワーカー→ワーカー等あらゆる `pane send-text` 呼び出しで起こりうる。

Alice 側の検知方法: 相手パネルが `idle` のまま応答が進まない、`pane read` した際に入力ボックス
（`❯ <text>` の行）にメッセージらしき文字列が表示されたまま応答が始まっていない場合はこれを疑う。
対処は該当パネルに直接 `herdr pane send-keys <pane_id> Enter` を送って詰まりを解消し、
送信元エージェントには「send-text の直後に必ず send-keys Enter を実行し、送った後に相手パネルを
`pane read` して実際に送信・応答が始まったか確認する」よう都度リマインドする。
ワーカー/Eve への初期メッセージにもこの注意をあらかじめ含めておくと再発を減らせる。

## 既知の落とし穴: Eve のレビュー結果が届かない

Eve はレビューを求められると、判断内容を**自分のパネルの応答として書くだけ**で満足し、
依頼元ワーカー（Bob/Carol/Dave）への `pane send-text` + `send-keys Enter` を実行し忘れることがある。
herdr のパネルは自動連携しないため、Eve が自分の画面に書いただけでは Bob/Carol/Dave には一切届かず、
ワーカー側は Eve の返答を待ったままフリーズする。

Alice は Eve のパネルを `pane read` した際、承認/差し戻しの文面が**Eve自身の応答としてのみ**存在し、
`send-text`/`send-keys` の実行ログが伴っていない場合は、Eve に対して
「その判断を依頼元ワーカーのパネルに実際に送信して」と明示的に指示し直す。
Eve への初期メッセージにも「判断は必ず依頼元に `pane send-text`/`send-keys` で送り返すこと。
Alice への通知はそれとは別に行うこと」を含めておくと再発を減らせる。

## 運用ルールの追記方針

この手順で新しい気づき（例: 特定の agent-status の挙動、複数ワーカーへの同時委譲パターンなど）が発生したら、このファイルに追記して再現可能にする。
