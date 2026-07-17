# VibesDeGoGo! for Codex

Codex 向けの state ＋ hook ワークフロー。要件定義・調査・実装・検証・コミットを通してエージェントを走らせ続けつつ、確かめていない思い込み・検証の省略・スコープ逸脱の手前で止めます。

すべてを貫くのは1つの非対称：

- 進捗確認では止まらない ──「続けていいですか？」を言わず走り続ける。
- 制約違反の手前では止まる ── 依存の追加、auth / 永続化 / 課金 / セキュリティに触る、破壊的操作、合意スコープからの逸脱 ── これらの直前で止まって尋ねる。

ルールはプロンプト本文ではなく、hook（`PreToolUse` / `PostToolUse` / `Stop`）＋ state file で強制し、タスクゲートが実際のファイル変更を宣言済み許可リストと突き合わせます。hook はサンドボックスではなくガードレールです（Codex 自身が「完全な強制境界ではなくガードレール」と位置づけ）。「強固なレール＋監査記録」であって、正しさの証明ではありません。

bash と jq のみ。アカウント・鍵・テレメトリなし。MIT。

## 基本の流れ

1. ゴール / 制約 / 受け入れ基準に合意する。
2. `tasks/vdgg/{id}/requirements.md` を書く。
3. コードベースを調査して `investigation.md` を書く。
4. `todo.md` と `progress.md` を作る。
5. 区切りのよいタスクを1つずつ実装する。
6. 具体的なチェックで検証する。
7. 的を絞った簡素化／レビューのパスを通す。
8. 進捗を更新し、必要なら動作確認を依頼する。
9. コミットし、既定の `branch-pr` ワークフローでは PR を作って止まる。
   （PR＝プルリクエストは GitHub の「変更確認ページ」です。あなたが merge を
   承認するまで、本体のコードには何も反映されません。）

## StepごとのAI指定（Formation）

名前付きFormationで、各Stepの担当AIを自由に割り当てられます。設定はリポジトリではなく、信頼済みのユーザー設定 `~/.config/vdgg` に置きます。

```text
~/.config/vdgg/
  formations/local-balanced.conf
  executors/qwen.conf
  executors/gemma.conf
```

Formationは全Stepを明示します。省略による暗黙fallbackはありません。

```ini
STEP_0_AI=inline
STEP_1_AI=inline
STEP_2_AI=inline
STEP_3_AI=inline
STEP_4_AI=inline
STEP_5_AI=inline
STEP_6_AI=qwen
STEP_6R_AI=inline
STEP_7_AI=gemma
STEP_8_AI=inline
STEP_9_AI=inline
STEP_0_GRILL_AI=qwen
```

各executor設定には、引数なしで起動できる絶対パスのwrapperだけを書きます。shell文字列として評価しません。

```ini
# ~/.config/vdgg/executors/qwen.conf
COMMAND=/Users/you/.local/bin/vdgg-qwen
```

CodexへFormation名を指定すると、Step 1で次の形で固定されます。

```bash
vdgg_state_init --formation local-balanced
```

wrapperは`VDGG_EXECUTOR_FORMATION`、`VDGG_EXECUTOR_AI`、`VDGG_EXECUTOR_STEP`、`VDGG_EXECUTOR_INPUT`、`VDGG_EXECUTOR_OUTPUT`を受け取ります。外部AIが失敗した場合はstateを保持して停止し、`inline`へ黙って切り替えません。Formationを指定しなければ、従来のCodex実行と`.vdgg-target` executor設定がそのまま動きます。

## 構成

```text
.agents/skills/vibesdegogo/
  SKILL.md
  scripts/
    vdgg-state.sh
    vdgg-hook-pretool.sh
    vdgg-hook-posttool.sh
    vdgg-hook-stop.sh
    vdgg-hook-userprompt.sh
  references/
    codex-setup.md
.codex/hooks.json
tests/
```

## インストール

ローカルでの開発時は、Codex がこのリポジトリの `.agents/skills` からリポジトリ
スキルを読み込みます。

複数リポジトリで使う場合は、ユーザーレベルのスキルディレクトリにスキルを
インストールします:

```bash
mkdir -p "$HOME/.agents/skills"
cp -R .agents/skills/vibesdegogo "$HOME/.agents/skills/vibesdegogo"
```

その後、`~/.codex/hooks.json` または `~/.codex/config.toml` にグローバルフックを
登録してください。グローバルの `UserPromptSubmit` フックにより、任意の git
リポジトリでのコーディング作業で VDGG が既定になります。ツールフックは、その
リポジトリルートで VDGG の状態が初期化されたあとにワークフローを強制します。
次を参照してください:

```text
.agents/skills/vibesdegogo/references/codex-setup.md
```

プロジェクトローカルのフックは `.codex/hooks.json` に含まれています。Codex では
`/hooks` でそれらを確認し、信頼（trust）してください。

フックスクリプトは Codex のフックJSONを `jq` で解析するため、`jq` が必要です:

```bash
brew install jq               # macOS
sudo apt-get install jq       # Debian / Ubuntu / WSL
apk add jq                    # Alpine
sudo dnf install jq           # Fedora / RHEL
```

## アンインストール

すべての足跡の一覧です（あなた自身でも、Codex に頼む場合でもこのリストで完遂できます）:

- `~/.agents/skills/vibesdegogo/` を削除する。
- `~/.codex/hooks.json` から `vdgg-hook-*.sh` を参照するフック4件
  （`PreToolUse` / `PostToolUse` / `Stop` / `UserPromptSubmit`）を除去する。
- 各リポジトリ内のセッション生成物: `.codex/.vdgg-*` と `tasks/vdgg/` は削除して安全です。
  `.gitignore` に自動追記される `.codex/.vdgg-*` のブロックも不要なら消してかまいません。
- `.vdgg-target` は残してください — これはあなたの設定ファイルで、VDGG が入れたものではありません。

## テスト

```bash
bash tests/run-all.sh
```

## オプション：MAGI 連携

**MAGI**（小さなオープンソースの3人格合議スキル）も入れていれば、VibesDeGoGo! は2箇所でそれを使います ── 無ければ黙ってスキップ：**Step 0** で本当に割れた高リスクの判断を合議し（材料を返すだけ／決めるのはあなた）、**Step 7** で主観的成果物（ドキュメント・コピー・デザイン）のレビューゲートにします。MAGIが見るのは「望ましさ」で、コードの正しさではありません。→ https://github.com/tmknzz/MAGI

## ステータス

このリポジトリは Codex 向けエディションです。Claude Code 向けエディションは [VibesDeGoGo-for-Claude-Code](https://github.com/tmknzz/VibesDeGoGo-for-Claude-Code) として別リポジトリにあります。
