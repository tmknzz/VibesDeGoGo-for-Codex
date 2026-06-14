# VibesDeGoGo! for Codex

**Codexの推進力はそのまま。台無しは置いていく。**

Codexは速い。そして完走したがる。そこが危うい ── 確かめない思い込み、飛ばした検証、いつの間にか逸脱したスコープ。そのまま「完了」の緑チェックだけ立って、下は散らかっている。

VibesDeGoGo! for Codex は、その推進力を残したままレールを敷きます。**Codexの推進力を残したまま、速い完走を「高くつく完走」に変える3つ ── 思い込み・検証漏れ・スコープ逸脱 ── を止めるための state-and-hook workflow** です。

すべてを貫くのは1つの非対称：

- **進捗確認では止まらない** ──「続けていいですか？」を言わず、走り続ける。
- **制約違反の手前では止まる** ── 依存の追加、auth / 永続化 / 課金 / セキュリティに触る、破壊的操作、合意スコープからの逸脱 ── これらの直前で止まって尋ねる。

ルールはプロンプト内のお願いではありません。hook（`PreToolUse` / `PostToolUse` / `Stop`）＋ state file で強制し、タスクゲートが実際のファイル変更を宣言済み許可リストと突き合わせます。（初日から残す正直な但し書き：Codex はフックを「完全な強制境界ではなくガードレール」と位置づけています。だからこれは「強固なレール＋監査記録」であって、正しさの証明ではありません。）

bash と jq だけ。SaaSなし・アカウントなし・APIキーなし・テレメトリなし。MIT、無料。

> これの出どころ：私はコードを書きません ── 一文字も書いたことがないし、一行も読みません。それでもこのリポジトリのツールは本物で、テスト付きで、オープンソースです。読めない分をレールが肩代わりするから ── 各ステップは検証され、テストは通らねばならず、レビュー無しでは何も出荷されません。それが核心：VibesDeGoGo! は、コードを書けない人間が、速いエージェントを誠実に走らせるための仕組みです。

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

## オプション：MAGI 連携

**MAGI**（小さなオープンソースの3人格合議スキル）も入れていれば、VibesDeGoGo! は2箇所でそれを使います ── 無ければ黙ってスキップ：**Step 0** で本当に割れた高リスクの判断を合議し（材料を返すだけ／決めるのはあなた）、**Step 7** で主観的成果物（ドキュメント・コピー・デザイン）のレビューゲートにします。MAGIが見るのは「望ましさ」で、コードの正しさではありません。→ https://github.com/tmknzz/MAGI

## ステータス

このリポジトリは Codex 向けエディションです。Claude Code 向けエディションは [VibesDeGoGo-for-Claude-Code](https://github.com/tmknzz/VibesDeGoGo-for-Claude-Code) として別リポジトリにあります。

## 支援（Support）

無料、ずっと無料。もし週末を1回救えたなら、コーヒー1杯は歓迎 ── 強制はしません。
