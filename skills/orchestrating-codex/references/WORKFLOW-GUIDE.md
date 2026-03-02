# Codex Agent ワークフローガイド

Codex本体がAgentを逐次起動する2フェーズ方式のワークフロー。**Phase 1（計画策定）はtachikoma-architecture agentに委譲し、Phase 2（実装）でドメイン別agentを逐次起動**する。

---

## Phase 1: 計画策定

### Step 1: tachikoma-architecture agent 起動（即座に実行）

**🔴 Codex本体はファイルを読まない・コードベースを分析しない。**

ユーザー要求を受け取ったら、即座に tachikoma-architecture agent を起動する:

```
Agent起動: tachikoma-architecture

プロンプト:
## タスク: 実装計画の策定

**ユーザー要求:** {ユーザーの要求をそのまま記載}

以下を実行してください:
1. コードベースを分析し、変更対象ファイル・影響範囲を特定
2. タスク分解（1 agentあたり5-6タスク目標）
3. 各タスクに最適な専門agentを選定（Agent マッピング表参照）
4. ファイル所有権パターンを定義（各agentの所有範囲を明確に）
5. 依存関係に基づく実行順序を決定
6. docs/plan-{feature-name}.md を PLAN-TEMPLATE.md の形式で作成

禁止事項:
- 実装コードの変更（計画策定のみ）
- jj書込操作
```

**tachikoma-architecture agent の責務（全委譲）:**
1. **現状把握**: コードベースの読み込み・プロジェクト構造の理解・既存実装の分析
2. **要件分析**: ユーザー要求の詳細化・変更対象ファイル・影響範囲の特定
3. **タスク分解**: agentごとの担当タスク・依存関係の整理
4. **Agent選定**: Agent マッピング表から最適な専門agentを推薦
5. **ファイル所有権パターン定義**: 各agentの担当ファイル範囲を明確化
6. **実行順序決定**: 依存関係に基づく逐次実行の順番を指定
7. **計画書作成**: `docs/plan-{feature-name}.md` を作成

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

## Phase 2: 実装

### Step 3: ドメイン別agent 逐次起動

**plannerが作成した `docs/plan-*.md` の実行順序に従い、agentを1つずつ起動する。**

#### Agent起動プロンプトテンプレート

```
Agent起動: {agent名}

プロンプト:
## タスク: {task_title}

**担当タスク:** {task_ids}
**ファイル所有権:** {file_ownership_pattern}
**実行計画:** docs/plan-{feature-name}.md を参照

具体的な実装指示:
- [計画書から抽出した詳細指示1]
- [計画書から抽出した詳細指示2]
- [計画書から抽出した詳細指示3]

前のagentの成果物:
- [前のagentが作成したファイル一覧（依存関係がある場合）]

禁止事項:
- 所有権範囲外のファイルを編集しない
- jj書込操作（jj new, jj commit, jj describe, jj push）を実行しない

完了時:
- 担当タスクのチェックリストを docs/plan-*.md で `- [x]` に更新
- 作成・変更したファイル一覧を報告
```

#### 起動例（3 agent逐次実行）

**Agent 1: backend（最初に実行）**
```
Agent起動: tachikoma-fullstack-js

プロンプト:
## タスク: REST API CRUD実装

担当タスク: #1, #2, #3
ファイル所有権: src/api/**, src/services/**, src/models/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- PostgreSQLスキーマ設計・マイグレーション
- GET/POST/PUT/DELETE エンドポイント実装
- バリデーション、エラーハンドリング

禁止事項:
- 所有権範囲外のファイルを編集しない
- jj書込操作を実行しない
```

**Agent 2: frontend（backend完了後に実行）**
```
Agent起動: tachikoma-nextjs

プロンプト:
## タスク: Reactコンポーネント実装

担当タスク: #4, #5, #6
ファイル所有権: src/components/**, src/pages/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- ユーザー一覧コンポーネント（データテーブル、ページネーション）
- ユーザー編集フォーム（バリデーション、API連携）
- エラー表示・ローディング状態

前のagentの成果物:
- src/api/users.ts (APIエンドポイント)
- src/models/user.ts (型定義)

禁止事項:
- 所有権範囲外のファイルを編集しない
- jj書込操作を実行しない
```

**Agent 3: tester（frontend完了後に実行）**
```
Agent起動: tachikoma-test

プロンプト:
## タスク: E2Eテストシナリオ作成

担当タスク: #7, #8
ファイル所有権: tests/e2e/**
実行計画: docs/plan-user-management.md を参照

具体的な実装指示:
- Playwrightによるユーザー登録・編集・削除フロー検証
- 各種エラーケースのテスト

前のagentの成果物:
- src/api/users.ts, src/components/UserList.tsx 等

禁止事項:
- 所有権範囲外のファイルを編集しない
- jj書込操作を実行しない
```

---

### Step 4: 進捗管理

#### docs/plan-*.md のタスクリスト更新

**🔴 各agentは自身のタスク完了時に `docs/plan-*.md` のチェックリストを `- [x]` に更新する。**

Codex本体は各agent完了後にリストが更新されていることを確認する。

```markdown
- [x] タスク1: ユーザーモデルのスキーマ設計（担当: tachikoma-fullstack-js）
- [x] タスク2: REST API CRUD エンドポイント実装（担当: tachikoma-fullstack-js）
- [x] タスク3: バリデーション・エラーハンドリング（担当: tachikoma-fullstack-js）
- [ ] タスク4: ユーザー一覧コンポーネント実装（担当: tachikoma-nextjs）← 次に実行
```

#### 実行ログセクションに記録

各agent完了後、Codex本体が実行ログに追記:

```markdown
## 実行ログ

- [2026-02-18 10:00] tachikoma-architecture agent 起動（計画策定）
- [2026-02-18 10:30] 計画書作成完了、Codexレビューループ完了
- [2026-02-18 10:35] ユーザー承認取得
- [2026-02-18 10:40] tachikoma-fullstack-js agent 起動（タスク1-3）
- [2026-02-18 11:30] タスク1-3完了（backend: API実装）
- [2026-02-18 11:35] tachikoma-nextjs agent 起動（タスク4-6）
- [2026-02-18 12:25] タスク4-6完了（frontend: コンポーネント実装）
- [2026-02-18 12:30] tachikoma-test agent 起動（タスク7-8）
- [2026-02-18 13:00] タスク7-8完了（tester: E2Eテスト）
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

全タスク完了後、Codex本体がユーザーに報告:

```
全タスクが完了しました。

📄 実装計画: docs/plan-{feature-name}.md

【実行結果】
- tachikoma-fullstack-js: タスク1-3完了（API実装）
- tachikoma-nextjs: タスク4-6完了（フロントエンド実装）
- tachikoma-test: タスク7-8完了（E2Eテスト）

【作成・変更ファイル】
- src/api/users.ts
- src/models/user.ts
- src/components/UserList.tsx
- src/components/UserForm.tsx
- tests/e2e/users.spec.ts

変更内容をコミットしますか？
```

---

## パターン別ワークフロー

### パターン1: feature-dev（機能開発）

```
tachikoma-architecture（計画策定）
  → ユーザー確認
  → tachikoma-database / tachikoma-fullstack-js（API実装）
  → tachikoma-nextjs / tachikoma-frontend（UI実装）
  → tachikoma-test / tachikoma-e2e-test（テスト作成）
```

### パターン2: investigation（調査・デバッグ）

```
tachikoma-architecture（調査計画策定）
  → ユーザー確認
  → tachikoma-{domain}（フロントエンド視点の調査）
  → tachikoma-{domain}（バックエンド視点の調査）
  → Codex本体が調査結果を統合してユーザーに報告
```

### パターン3: refactoring（リファクタリング）

```
tachikoma-architecture（分析・移行計画策定）
  → ユーザー確認
  → tachikoma-{domain}（段階的コード変更）
  → tachikoma-test（回帰テスト）
```

### パターン4: scale-out（同一agent複数回起動）

**逐次実行のため真の並列化はできないが、同一agentを異なるスコープで複数回起動可能:**

```
tachikoma-architecture（計画策定）
  → ユーザー確認
  → tachikoma-nextjs（ダッシュボードページ実装、所有: src/app/dashboard/**）
  → tachikoma-nextjs（設定ページ実装、所有: src/app/settings/**）
  → tachikoma-nextjs（プロフィールページ実装、所有: src/app/profile/**）
```
