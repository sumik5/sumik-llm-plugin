# Codex Agent オーケストレーション

**Codex本体はオーケストレーターに徹し、tachikoma-product-manager agent に計画策定を委譲する。計画承認後、ドメイン別専門agentを自然言語で起動し、`config.toml` の `max_threads` による並列制御に委ねる。**

---

## 概要

### Codex方式
```
Codex本体 → tachikoma-product-manager agent（要件分析・計画策定・Wave分割）
         → ユーザー確認（テキストベース）
         → Wave 1: 独立agentを自然言語で同時起動（max_threadsが並列制御を担う）→ 全完了待ち
         → Wave 2: Wave 1に依存するagentを同時起動 → 全完了待ち
         → ...（Wave N まで繰り返し）
```

**Wave は「依存関係グラフに基づくグループ化」の計画パターン。実際の並列実行はCodexのネイティブ `max_threads` に委ねる。手動でスレッドを制御しない。**

### Wave並列実行の原則

**🔴 依存関係がないタスク群は必ず同一Waveにまとめて起動する。逐次実行はアンチパターン。**

```
❌ Bad: DB設計 → API実装 → 型定義 → UI実装 → テスト（全直列）
✅ Good:
  Wave 1: DB設計 + 共通型定義（独立タスク）
  Wave 2: API実装 ∥ UIスケルトン実装（Wave 1に依存、相互に独立）
  Wave 3: E2Eテスト ∥ 統合テスト（Wave 2に依存、相互に独立）
```

---

## 前提条件

- Codex CLI がインストール済み
- `~/.codex/agents/`（個人）または `.codex/agents/`（プロジェクト）にagent定義ファイルが存在
- Git が使用可能

---

## Codex設定（config.toml）

`config.toml` の `[agents]` セクションで並列動作を宣言的に制御する:

```toml
[agents]
max_threads = 6              # 同時オープンスレッド上限（デフォルト: 6）
max_depth = 1                # サブエージェントのネスト深さ（root=0、デフォルト: 1）
job_max_runtime_seconds = 1800  # CSVジョブのワーカータイムアウト（デフォルト: 1800秒）
```

**`max_threads` は Wave内agent数の上限として機能する。大規模な並列タスク（Wave内5agent以上）では `max_threads` を適切に増加させること。超過分はキューイングされ、並列効果が失われる。**

---

## ビルトインAgent（3体）

Codexには以下のビルトインagentが存在する:

| Agent名 | 特性 | 用途 |
|---------|------|------|
| `default` | 汎用フォールバック | カスタムagentでカバーされないタスク |
| `worker` | 実装・修正に特化 | コードの書き込み・変更タスク |
| `explorer` | 読み取り重視 | コードベース探索・分析タスク |

**カスタムagentが同名（`default`, `worker`, `explorer`）の場合、ビルトインをオーバーライドする。** tachikoma agentはカスタム定義のため共存する。

---

## Agent定義（TOML形式）

カスタムagentは `~/.codex/agents/<name>.toml`（個人）または `.codex/agents/<name>.toml`（プロジェクト）に配置:

```toml
# 必須フィールド
name = "tachikoma-nextjs"
description = "Next.js/React専門agent。App Router・Server Components・Turbopack対応。"
developer_instructions = """
あなたはNext.js/React専門のtachikoma agentです。
担当ファイル所有権の範囲内のみ実装してください。
git書込操作（commit/push）は行わないこと。
"""

# オプション
nickname_candidates = ["Atlas", "Delta", "Echo"]
model = "gpt-5.4"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"  # "read-only" or "workspace-write"

# MCPサーバー（任意）
[mcp_servers.serverName]
url = "https://example.com/mcp"
```

**`sandbox_mode`:** `"read-only"` は読み取り専用（tachikoma-architectureに推奨）、`"workspace-write"` は書き込み可（実装agentに使用）。

---

## スレッド管理

`/agent` コマンドでアクティブスレッドを管理する:

```
/agent list          # アクティブスレッド一覧
/agent switch <id>   # スレッド切替
/agent inspect <id>  # 指定スレッドの状態確認
```

**非アクティブスレッドからの承認リクエスト:** ソーススレッドラベル付きで表示される。`o` キーで対象スレッドを開いて承認/拒否する。

---

## サンドボックス継承

サブエージェントは親セッションのサンドボックスポリシーを継承する:
- `/approvals` の設定変更も引き継がれる
- `--yolo` フラグも引き継がれる
- **agent個別の `sandbox_mode` で上書き可能**（TOML定義参照）

---

## ⚠️ トークン消費

サブエージェントは独自のモデル・ツール処理を行うため、**単一agentより大幅にトークンを消費する**。Wave内のagent数（並列数）が増えるほど消費量は増大する。大規模並列タスクでは事前にコスト見積もりを行うこと。

---

## 使用タイミング

**🔴 ファイルを読んで判断しない。ユーザーの要求文から以下に該当しそうなら即座にtachikoma-product-manager agentを起動:**

1. **複数の機能・コンポーネント** に言及している（例: 「UIとAPIを作って」）
2. **異なる関心事** が含まれる（例: 「フロントエンドとバックエンドを変更」）
3. **複数のサブタスク** が明示的または暗示的に含まれる
4. **「〜を追加して」＋「テストも書いて」** のような複合要求

**以下の場合のみ単体agent起動:**
- 明らかに1ファイルのみの変更（「このファイルのバグを直して」）
- 単一の小さなタスク（「typoを修正して」）

---

## クイックスタート（2フェーズ方式）

### Phase 1: 計画策定（tachikoma-product-manager agent に全委譲）
1. **tachikoma-product-manager agent 起動** - ユーザー要求をそのまま渡す。現状把握・コードベース分析・要件整理・**Wave分割**・`docs/plan-{feature}.md` 作成を全てplannerが実行
2. **計画レビュー・承認** - Codex本体がdocs/planの内容をユーザーに提示し、承認を求める

### Phase 2: 実装（Wave単位で最大並列起動）
3. **Wave N のagentを自然言語で全て同時起動** - `max_threads` が並列制御を担う
4. **Wave N の全agent完了を待機** → **Wave N+1 のagentを全て同時起動**
5. **全Wave完了後** - 品質チェック・統合確認

**🔴 Codex本体はファイルを読まない・分析しない。** ユーザー要求を受け取ったら即座にtachikoma-product-manager agentを起動。現状把握からWave分割・計画策定まで全てplannerの責務。

---

## 🔴 並列起動の実装方法（最重要）

**Wave内の複数agentは、自然言語で同時指示することで並列起動する。逐次指示してはならない。**

### 正しいパターン（自然言語で並列起動）

```
# Wave 2の2つのagentを同時に起動する場合:
# → 1つの指示でagentを同時起動するよう記述する

"Spawn tachikoma-fullstack-js for API implementation and tachikoma-nextjs for UI implementation at the same time."

# 両方のagentが完了するまで待機
# → 両方完了したらWave 3へ進む
```

### 間違ったパターン（逐次起動 = アンチパターン）

```
❌ "Start tachikoma-fullstack-js." → 完了待ち → "Now start tachikoma-nextjs."
   これは逐次実行であり、Wave並列の意味がない
```

### 実装の鍵

1. **同一Wave内の全agentを1つの自然言語指示で同時起動する**
2. **各agentへの指示にファイル所有権を明記する**（並列実行で競合しないため）
3. **全agentの完了を待ってから次のWaveの全agentを同時起動する**
4. **Wave内のagent数は `max_threads` を超えないよう設計する**（超過分はキューイングされる）
5. **大規模並列が必要な場合は `config.toml` の `max_threads` を増加させる**

---

## 🔴 ファイル所有権パターン（必須ルール）

**Wave内の並列agentが同一ファイルに書き込むと競合する。plannerが排他的所有権を厳密に定義すること。**

plannerが事前にパスベースの所有権を定義（Wave内で重複禁止）:
```
frontend agent: src/components/**, src/pages/**
backend agent: src/api/**, src/services/**, src/models/**
test agent: tests/e2e/**, tests/integration/**
architect agent: docs/design/**
```

**各agentは自身の所有範囲外のファイルを編集しない。** 共有ファイル（型定義・設定ファイル等）はWave分割で先行Waveに配置するか、1つのagentに所有権を集約する。

---

## Agent マッピング表

Claude Code の subagent_type と Codex agent名の対応表（参照用）:

| Claude Code subagent_type | Codex agent名 | 用途 |
|--------------------------|--------------|------|
| `sumik:タチコマ（プロダクトマネジメント）` | `tachikoma-product-manager` | 要件分析・計画策定（読取専用） |
| `sumik:タチコマ（Next.js）` | `tachikoma-nextjs` | Next.js/React開発 |
| `sumik:タチコマ（フロントエンド）` | `tachikoma-frontend` | UI/UX・shadcn |
| `sumik:タチコマ（フルスタックJS）` | `tachikoma-fullstack-js` | NestJS/Express |
| `sumik:タチコマ（TypeScript）` | `tachikoma-typescript` | TypeScript型設計 |
| `sumik:タチコマ（Python）` | `tachikoma-python` | Python・ADK |
| `sumik:タチコマ（Go）` | `tachikoma-go` | Go開発 |
| `sumik:タチコマ（Bash）` | `tachikoma-bash` | シェルスクリプト |
| `sumik:タチコマ（インフラ）` | `tachikoma-infra` | Docker/CI-CD |
| `sumik:タチコマ（Terraform）` | `tachikoma-terraform` | Terraform IaC |
| `sumik:タチコマ（AWS）` | `tachikoma-aws` | AWS全般 |
| `sumik:タチコマ（Google Cloud）` | `tachikoma-google-cloud` | GCP全般 |
| `sumik:タチコマ（セキュリティ）` | `tachikoma-security` | セキュリティ監査（読取専用） |
| `sumik:タチコマ（データベース）` | `tachikoma-database` | DB設計・SQL |
| `sumik:タチコマ（AI/ML）` | `tachikoma-ai-ml` | AI/RAG/MCP |
| `sumik:タチコマ（テスト）` | `tachikoma-test` | ユニット/統合テスト |
| `sumik:タチコマ（E2Eテスト）` | `tachikoma-e2e-test` | Playwright E2E |
| `sumik:タチコマ（オブザーバビリティ）` | `tachikoma-observability` | 監視・OTel |
| `sumik:タチコマ（ドキュメント）` | `tachikoma-document` | 技術文書 |
| `sumik:タチコマ（デザイン）` | `tachikoma-design` | Figma→コード |
| `sumik:タチコマ（研修・プレゼン）` | `tachikoma-training-presenter` | 研修・プレゼン |
| `sumik:タチコマ` | `tachikoma` | 汎用フォールバック |
| `sumik:serena-expert` | `serena-expert` | トークン効率化開発 |

### Agent選択の判断基準

- プロジェクトの技術スタック（package.json, go.mod等）から判定
- 複数候補がある場合はより専門的な方を優先
- 汎用 `tachikoma` は専門agentでカバーされない場合のフォールバック
- ビルトインの `worker`（実装特化）・`explorer`（読み取り重視）はカスタムagentが定義されていない環境で有効

---

## タスク分解ルール

### 最適なタスク粒度
- **1 agentあたり3-5タスクを目標**（並列度を上げるため、agentあたりのスコープを絞る）
- タスクが多すぎる（6+）→ agentのコンテキスト過負荷、完了まで他Waveをブロック
- タスクが少なすぎる（1）→ agent起動のオーバーヘッドが相対的に大きい

### Wave分割の原則（🔴 並列度最大化）

**plannerは依存関係グラフを作成し、独立タスクを同一Waveにまとめる。Waveの数を最小化（=並列度を最大化）することが最優先。**

```
Wave 1: スキーマ設計 (tachikoma-database) ∥ 共通型定義 (tachikoma-typescript)
  ↓ 全完了待ち
Wave 2: API実装 (tachikoma-fullstack-js) ∥ UIスケルトン (tachikoma-nextjs)
  ↓ 全完了待ち
Wave 3: E2Eテスト (tachikoma-e2e-test) ∥ 統合テスト (tachikoma-test)
```

#### Wave分割の判断基準

| 条件 | Wave配置 |
|------|---------|
| 他タスクへの依存なし | Wave 1（最初に並列起動） |
| Wave N の成果物を読むだけ（書かない） | Wave N+1 で並列起動可能 |
| 他agentが作成したファイルを**編集**する必要がある | 別Waveに分離（先行Wave完了後に起動） |
| 同一ファイルに複数agentが書き込む | **同一Waveに入れてはならない** → 所有権を分離するか、1つのagentに統合 |

#### 並列度を上げるテクニック

1. **共通型定義・インターフェースを先行Wave（Wave 1）に分離** → API/UIが同時に着手可能
2. **テスト作成は実装と同一Waveに配置可能**（テストagentは実装agentと異なるファイルを所有）
3. **同一agentを複数起動してスコープ分割**（例: tachikoma-nextjs × 2 で異なるページ群を並列実装）
4. **ドキュメントagentは実装と並列起動可能**（docsファイルは実装agentの所有外）

---

## Git連携注意事項

### git操作の原則
- **Git を使用**
- **git読み取り操作は全agent許可**: `git status`, `git diff`, `git log`
- **git書込操作はCodex本体のみ**: `git commit`, `git push` → ユーザー確認必須

### 並列作業時の注意
- **全agentの変更は同一ブランチに統合される**（Wave内の並列agentも同様）
- ファイル所有権が分離されていれば並列書き込みでも競合しない
- 作業完了後、`git status` で全変更を確認してからコミット判断をユーザーに委ねる

---

## 🔴 絶対に避けるべきこと

- **Codex本体がファイルを読んで分析する**（plannerの責務）
- **同一Wave内で同一ファイルに複数agentが書き込む**（並列実行で競合する）
- **依存関係がないタスクを逐次実行する**（並列化できるのに直列にするのはアンチパターン）
- **`docs/plan-*.md` なしでagentを起動する**（回復不能になる）
- **汎用tachikoma agentを安易に使わない** → Agent マッピング表から適切な専門agentを選択
- **ユーザー確認なしに計画を実行する**（必ず計画を提示して承認を得る）
- **`max_threads` を大幅に超えるagent数を同一Waveに詰め込む**（キューイングで並列効果が失われる）

---

## Codex基本操作

スキル同梱のラッパースクリプトでコードレビュー・分析を実行する。

### コード相談

```bash
scripts/codex-consult.sh "<project_directory>" "<request>"
```

- `<project_directory>`: 対象プロジェクトのディレクトリ
- `<request>`: 依頼内容（末尾に「確認不要・具体的提案まで出力」指示を自動付与）

### プランレビュー

```bash
# 初回レビュー
SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/cert.pem}" codex exec -m "gpt-5.4" "このプランをレビューしてください。瑣末な点へのクソリプはしないでください。致命的な点のみを指摘してください: <plan_file_fullpath>"

# 再レビュー（直近セッション継続）
SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/cert.pem}" codex exec resume --last -m "gpt-5.4" "プランを更新したのでレビューを再度してください。瑣末なクソリプはせず、致命的な点だけ指摘してください: <plan_file_fullpath>"
```

codex未インストールの場合: `npm install -g @openai/codex` でインストールを案内して終了。

---

## サブファイルナビゲーション

| ファイル | 内容 |
|---------|------|
| `references/PLAN-TEMPLATE.md` | `docs/plan-{feature-name}.md` テンプレート・回復手順・実行ログ記録方法 |
| `references/WORKFLOW-GUIDE.md` | Phase 1-2 詳細ワークフロー（計画策定 → ユーザー確認 → Wave並列実装 → 統合 → 完了） |
| `scripts/codex-consult.sh` | コード相談ラッパースクリプト（モデル固定・プロンプト補正付き） |

---

## 関連スキル

- `converting-agents-to-codex` - Claude Code Agent → Codex Agent変換ガイド
- `implementing-as-tachikoma` - タチコマAgent運用ガイド
- `using-serena` - トークン効率化開発
