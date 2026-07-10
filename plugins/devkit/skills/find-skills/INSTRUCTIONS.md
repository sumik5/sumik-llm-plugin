# スキル発見・インストールガイド

オープンなエージェントスキルエコシステムからスキルを発見し、品質を検証してからユーザーに提示・インストールするための詳細手順。

## このスキルを使うタイミング

以下のようなときに使う:

- ユーザーが「X ってどうやるの？」と尋ね、X が既存スキルのありそうな一般的タスクであるとき
- 「X 用のスキルを探して」「X ができるスキルはある？」と言われたとき
- 「X はできる？」と専門的な能力について聞かれたとき
- エージェント能力の拡張に関心を示したとき
- ツール・テンプレート・ワークフローを検索したいとき
- 特定ドメイン（デザイン・テスト・デプロイ等）の支援がほしいと言及したとき

## Skills CLI とは

Skills CLI（`npx skills`）は、オープンなエージェントスキルエコシステムのパッケージマネージャー。スキルは専門知識・ワークフロー・ツールでエージェント能力を拡張するモジュール型パッケージ。

**主要コマンド:**

- `npx skills find [query]` - スキルを対話的またはキーワードで検索
- `npx skills add <package>` - GitHub 等のソースからスキルをインストール
- `npx skills check` - スキルの更新確認
- `npx skills update` - インストール済みスキルを一括更新

**スキル一覧の閲覧:** https://skills.sh/

## スキル発見の 6 ステップ

### Step 1: ニーズを理解する

ユーザーが何かの支援を求めたら、次を特定する:

1. ドメイン（例: React、テスト、デザイン、デプロイ）
2. 具体的タスク（例: テスト作成、アニメーション作成、PR レビュー）
3. スキルが存在していそうなほど一般的なタスクかどうか

### Step 2: まずリーダーボードを確認する

CLI 検索を実行する前に、[skills.sh のリーダーボード](https://skills.sh/) で該当ドメインの定番スキルが既にあるか確認する。リーダーボードは総インストール数でスキルをランク付けしており、最も人気があり実戦で鍛えられた選択肢が上位に出る。

例えば、Web 開発向けの上位スキルには次がある:

- `vercel-labs/agent-skills` — React、Next.js、Web デザイン（各 100K+ インストール）
- `anthropics/skills` — フロントエンドデザイン、ドキュメント処理（100K+ インストール）

### Step 3: スキルを検索する

リーダーボードでニーズをカバーできない場合、find コマンドを実行する:

```bash
npx skills find [query]
```

例:

- 「React アプリを速くするには？」→ `npx skills find react performance`
- 「PR レビューを手伝ってほしい」→ `npx skills find pr review`
- 「changelog を作りたい」→ `npx skills find changelog`

### Step 4: 推奨前に品質を検証する

**検索結果だけを根拠にスキルを推奨しない。** 必ず次を検証する:

1. **インストール数** — 1K+ インストールのスキルを優先する。100 未満は慎重に扱う。
2. **ソースの信頼性** — 公式ソース（`vercel-labs`、`anthropics`、`microsoft`）は無名の作者より信頼できる。
3. **GitHub stars** — ソースリポジトリを確認する。stars が 100 未満のリポジトリ由来のスキルは懐疑的に扱う。

### Step 5: ユーザーに選択肢を提示する

関連スキルが見つかったら、次を添えて提示する:

1. スキル名と機能の説明
2. インストール数とソース
3. ユーザーが実行できるインストールコマンド
4. skills.sh の詳細ページへのリンク

提示例:

```
役立ちそうなスキルが見つかりました。「react-best-practices」スキルは
Vercel Engineering 発の React / Next.js パフォーマンス最適化ガイドラインを
提供します（185K インストール）。

インストールするには:
npx skills add vercel-labs/agent-skills@react-best-practices

詳細: https://skills.sh/vercel-labs/agent-skills/react-best-practices
```

### Step 6: インストールを申し出る

ユーザーが進めたい場合、代わりにインストールを実行できる:

```bash
npx skills add <owner/repo@skill> -g -y
```

`-g` フラグはグローバル（ユーザーレベル）インストール、`-y` は確認プロンプトのスキップ。

## よくあるスキルカテゴリ

検索時は次の代表的カテゴリを考慮する:

| カテゴリ | クエリ例 |
|---------|---------|
| Web 開発 | react, nextjs, typescript, css, tailwind |
| テスト | testing, jest, playwright, e2e |
| DevOps | deploy, docker, kubernetes, ci-cd |
| ドキュメント | docs, readme, changelog, api-docs |
| コード品質 | review, lint, refactor, best-practices |
| デザイン | ui, ux, design-system, accessibility |
| 生産性 | workflow, automation, git |

## 効果的な検索の Tips

1. **具体的なキーワードを使う**: 単なる "testing" より "react testing" が良い
2. **別の語を試す**: "deploy" でヒットしなければ "deployment" や "ci-cd" を試す
3. **人気ソースを確認する**: 多くのスキルは `vercel-labs/agent-skills` や `ComposioHQ/awesome-claude-skills` 由来

## スキルが見つからない場合

関連スキルが存在しない場合:

1. 既存スキルが見つからなかったことを伝える
2. 汎用能力でタスクを直接支援すると申し出る
3. `npx skills init` で自作スキルを作れることを提案する

対応例:

```
「xyz」に関連するスキルを検索しましたが、該当するものは見つかりませんでした。
このタスクは直接お手伝いできます。このまま進めましょうか？

頻繁に行う作業であれば、自作スキルを作ることもできます:
npx skills init my-xyz-skill
```
