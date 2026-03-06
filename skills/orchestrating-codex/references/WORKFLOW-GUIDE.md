# Codex Agent ワークフローガイド

Codex本体がAgentをWave単位で最大並列起動する2フェーズ方式のワークフロー。**Phase 1（計画策定・Wave分割）はtachikoma-architecture agentに委譲し、Phase 2（実装）でWave内のagentを全て同時並列起動**する。

---

## Phase 1: 計画策定

### Step 1: tachikoma-architecture agent 起動（即座に実行）

**🔴 Codex本体はファイルを読まない・コードベースを分析しない。**

ユーザー要求を受け取ったら、即座に tachikoma-architecture agent を起動する:

```
Agent起動: tachikoma-architecture

プロンプト:
## タスク: 実装計画の策定（Wave並列分割必須）

**ユーザー要求:** {ユーザーの要求をそのまま記載}

以下を実行してください:
1. コードベースを分析し、変更対象ファイル・影響範囲を特定
2. タスク分解（1 agentあたり3-5タスク目標）
3. 各タスクに最適な専門agentを選定（Agent マッピング表参照）
4. ファイル所有権パターンを定義（同一Wave内で排他的であること）
5. 依存関係グラフを作成し、独立タスクを同一Waveにまとめる（🔴 Wave数の最小化＝並列度の最大化が最優先）
6. docs/plan-{feature-name}.md を PLAN-TEMPLATE.md の形式で作成

Wave分割の原則:
- 依存関係がないタスク群は必ず同一Waveに配置して並列起動する
- Wave内の各agentのファイル所有権は排他的（重複禁止）
- 共通型定義・インターフェースはWave 1に分離し、後続Waveが参照可能にする
- テストagentは実装agentと異なるファイルを所有するため、同一Wave配置を積極的に検討する

禁止事項:
- 実装コードの変更（計画策定のみ）
- jj書込操作
- 依存関係がないタスクを別Waveに分離すること（逐次実行はアンチパターン）
```

**tachikoma-architecture agent の責務（全委譲）:**
1. **現状把握**: コードベースの読み込み・プロジェクト構造の理解・既存実装の分析
2. **要件分析**: ユーザー要求の詳細化・変更対象ファイル・影響範囲の特定
3. **タスク分解**: agentごとの担当タスク・依存関係の整理
4. **Agent選定**: Agent マッピング表から最適な専門agentを推薦
5. **ファイル所有権パターン定義**: 各agentの担当ファイル範囲を明確化（同一Wave内は排他）
6. **Wave分割**: 依存関係グラフに基づきWave数を最小化した並列実行計画を策定
7. **計画書作成**: `docs/plan-{feature-name}.md` を作成（Execution Wavesセクション必須）

**tachikoma-architecture agent は実装コードを変更しない（読み取り専用 + docs/ への計画書作成のみ）。**

---

### Step 2: 計画レビュー・承認

tachikoma-architecture agent が `docs/plan-{feature-name}.md` を作成しユーザーに提示する。

**ユーザーへの提示方法（テキストベース）:**

```
以下の実装計画を作成しました。内容を確認してください。

📄 docs/plan-{feature-name}.md

【計画概要】
- Agent構成: {agent一覧}
- タスク数: {合計タスク数}
- 実行順序: {agent実行順}

この計画で進めてよろしいですか？
修正が必要な場合は、修正内容をお知らせください。
```

**ユーザーの応答に基づく対応:**
- **承認** → Phase 2 へ進む
- **修正要求** → tachikoma-architecture agent を再起動し、ユーザーのフィードバックを渡して計画を修正

---

## Phase 2: 実装（Wave並列起動）

### Step 3: Wave内agentを全て同時並列起動

**🔴 最重要ルール: 同一Wave内のagentは1つずつではなく、全て同時に起動する。**

Codex本体は以下のループを実行する:
```
for each wave in plan.execution_waves:
    # Wave内の全agentを同時に起動（1つずつ起動してはならない）
    全agentを並列起動（agent_1, agent_2, ..., agent_N）
    全agentの完了を待機
    → 次のWaveへ
```

#### Agent起動プロンプトテンプレート

```
Agent起動: {agent名}

プロンプト:
## タスク: {task_title}

**担当タスク:** {task_ids}
**ファイル所有権:** {file_ownership_pattern}（🔴 この範囲外のファイルは絶対に編集しない）
**実行計画:** docs/plan-{feature-name}.md を参照

具体的な実装指示:
- [計画書から抽出した詳細指示1]
- [計画書から抽出した詳細指示2]
- [計画書から抽出した詳細指示3]

前のWaveの成果物:
- [前のWaveのagentが作成したファイル一覧（依存関係がある場合）]

禁止事項:
- 所有権範囲外のファイルを編集しない（並列agentとの競合防止）
- jj書込操作（jj new, jj commit, jj describe, jj push）を実行しない

完了時:
- 担当タスクのチェックリストを docs/plan-*.md で `- [x]` に更新
- 作成・変更したファイル一覧を報告
```

#### 起動例（3 Wave並列実行）

**Wave 1: 独立タスク（2 agent同時起動）**

以下の2つのagentを**同時に**起動する:

```
Agent起動: tachikoma-database

プロンプト:
## タスク: DBスキーマ設計

担当タスク: #1
ファイル所有権: migrations/**, src/models/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- PostgreSQLテーブル定義・マイグレーション作成
- Userモデル定義
```

```
Agent起動: tachikoma-typescript

プロンプト:
## タスク: 共通型定義

担当タスク: #2
ファイル所有権: src/types/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- APIリクエスト/レスポンス型定義
- 共通ユーティリティ型
```

→ **Wave 1の全agent完了を待機**

**Wave 2: API + UI（2 agent同時起動、Wave 1完了後）**

以下の2つのagentを**同時に**起動する:

```
Agent起動: tachikoma-fullstack-js

プロンプト:
## タスク: REST API CRUD実装

担当タスク: #3, #4
ファイル所有権: src/api/**, src/services/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- GET/POST/PUT/DELETE エンドポイント実装
- バリデーション、エラーハンドリング

前のWaveの成果物:
- src/models/user.ts, src/types/user.ts
```

```
Agent起動: tachikoma-nextjs

プロンプト:
## タスク: Reactコンポーネント実装

担当タスク: #5, #6
ファイル所有権: src/components/**, src/pages/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- ユーザー一覧コンポーネント（データテーブル、ページネーション）
- ユーザー編集フォーム（バリデーション、API連携）

前のWaveの成果物:
- src/types/user.ts（型定義を参照）
```

→ **Wave 2の全agent完了を待機**

**Wave 3: テスト（2 agent同時起動、Wave 2完了後）**

以下の2つのagentを**同時に**起動する:

```
Agent起動: tachikoma-test

プロンプト:
## タスク: 統合テスト作成

担当タスク: #7
ファイル所有権: tests/integration/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- APIエンドポイントの統合テスト
```

```
Agent起動: tachikoma-e2e-test

プロンプト:
## タスク: E2Eテストシナリオ作成

担当タスク: #8
ファイル所有権: tests/e2e/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- Playwrightによるユーザー登録・編集・削除フロー検証
```

---

### Step 4: 進捗管理

#### Wave単位の完了待機

**🔴 Codex本体はWave内の全agentが完了するまで待機し、次のWaveに進む。**

```
Wave N 並列起動 → 全agent完了待ち → Wave N+1 並列起動
```

各agent完了後にタスクリストが `- [x]` に更新されていることを確認する。

#### 実行ログセクションに記録

各Wave開始/完了時にCodex本体が実行ログに追記:

```markdown
## 実行ログ

- [2026-02-18 10:00] tachikoma-architecture agent 起動（計画策定）
- [2026-02-18 10:30] 計画書作成完了、ユーザー承認取得
- [2026-02-18 10:35] Wave 1 並列起動: tachikoma-database(#1) ∥ tachikoma-typescript(#2)
- [2026-02-18 11:10] Wave 1 全完了
- [2026-02-18 11:15] Wave 2 並列起動: tachikoma-fullstack-js(#3-4) ∥ tachikoma-nextjs(#5-6)
- [2026-02-18 12:00] Wave 2 全完了
- [2026-02-18 12:05] Wave 3 並列起動: tachikoma-test(#7) ∥ tachikoma-e2e-test(#8)
- [2026-02-18 12:30] Wave 3 全完了 → 全タスク完了
```

---

### Step 5: 統合・完了

#### 全タスク完了の確認

`docs/plan-*.md` のタスクリストが全て `- [x]` になったことを確認。

#### 品質チェック

**CodeGuardセキュリティチェック実行（推奨）:**

```bash
/codeguard-security:software-security
```

#### docs/plan-*.md を全完了に更新

```markdown
- [x] タスク1-8: 全完了

## 実行ログ

- [2026-02-18 13:05] 全タスク完了
- [2026-02-18 13:10] 品質チェック完了
```

---

### Step 6: ユーザーへの完了報告

全Wave完了後、Codex本体がユーザーに報告:

```
全タスクが完了しました。

📄 実装計画: docs/plan-{feature-name}.md

【実行結果（Wave並列実行）】
Wave 1: tachikoma-database(#1) ∥ tachikoma-typescript(#2) → 完了
Wave 2: tachikoma-fullstack-js(#3-4) ∥ tachikoma-nextjs(#5-6) → 完了
Wave 3: tachikoma-test(#7) ∥ tachikoma-e2e-test(#8) → 完了

【作成・変更ファイル】
- migrations/001_create_users.sql
- src/models/user.ts, src/types/user.ts
- src/api/users.ts, src/services/user.service.ts
- src/components/UserList.tsx, src/components/UserForm.tsx
- tests/integration/users.test.ts, tests/e2e/users.spec.ts

変更内容をコミットしますか？
```

---

## パターン別ワークフロー

### パターン1: feature-dev（機能開発）

```
tachikoma-architecture（計画策定・Wave分割）
  → ユーザー確認
  → Wave 1: tachikoma-database ∥ tachikoma-typescript（スキーマ＋型定義を並列）
  → Wave 2: tachikoma-fullstack-js ∥ tachikoma-nextjs（API＋UIを並列）
  → Wave 3: tachikoma-test ∥ tachikoma-e2e-test（テストを並列）
```

### パターン2: investigation（調査・デバッグ）

```
tachikoma-architecture（調査計画策定）
  → ユーザー確認
  → Wave 1: tachikoma-{frontend} ∥ tachikoma-{backend}（多視点調査を並列）
  → Codex本体が調査結果を統合してユーザーに報告
```

### パターン3: refactoring（リファクタリング）

```
tachikoma-architecture（分析・移行計画策定・Wave分割）
  → ユーザー確認
  → Wave 1: tachikoma-{domain-A} ∥ tachikoma-{domain-B}（独立モジュールの変更を並列）
  → Wave 2: tachikoma-test ∥ tachikoma-e2e-test（回帰テストを並列）
```

### パターン4: scale-out（同一agent複数並列起動）

**同一agentを異なるスコープで同一Wave内に同時起動:**

```
tachikoma-architecture（計画策定・Wave分割）
  → ユーザー確認
  → Wave 1: tachikoma-nextjs(dashboard) ∥ tachikoma-nextjs(settings) ∥ tachikoma-nextjs(profile)
    所有権: src/app/dashboard/** ∥ src/app/settings/** ∥ src/app/profile/**
  → Wave 2: tachikoma-e2e-test（全ページの統合E2Eテスト）
```

### パターン5: maximum-parallelism（並列度最大化）

**テストagentを実装agentと同一Waveに配置（ファイル所有権が排他的なため可能）:**

```
tachikoma-architecture（計画策定）
  → ユーザー確認
  → Wave 1: tachikoma-typescript（共通型定義）
  → Wave 2: tachikoma-fullstack-js(API) ∥ tachikoma-nextjs(UI) ∥ tachikoma-test(unitテスト)
    ※ テストagentはtests/**のみ所有、実装agentとファイル競合なし
```
