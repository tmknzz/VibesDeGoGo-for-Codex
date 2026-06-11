# VibesDeGoGo! for Codex

VibesDeGoGo! for Codex は、Codex でのコーディングセッション向けの状態ファイル
＋フック駆動のワークフローです。要件定義・調査・計画・実装・検証・レビュー・
コミットを通してエージェントを走らせ続け、制約違反の手前でだけ止まります。

フックはガードレールであり、サンドボックスではありません。よくある脱線経路
（スコープ外の編集、検証・レビューの省略、黙った停止）を機械的にブロックし、
タスクゲートが実際のファイル変更を宣言済み許可リストと突き合わせます。Codex は
`PreToolUse` を「完全な強制境界ではなくガードレール」と位置づけているため、
これらは「安全柵＋監査記録」として捉えてください。正しさの証明ではありません。

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

## テスト

```bash
bash tests/run-all.sh
```

## ステータス

このリポジトリは Codex 向けエディションです。Claude Code 向けエディションは
`VibesDeGoGo-for-Claude-Code` として別リポジトリにあります。
