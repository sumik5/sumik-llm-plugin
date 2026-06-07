# 計画ドキュメントテンプレート

Agent逐次実行前に必ず `docs/plan-{feature-name}.md` を作成する。このファイルがAgent実行の設計図・進捗管理・回復の起点となる。

---

## テンプレート全文

```markdown
# {feature-name} 実装計画

## 概要

**目的:**
（なぜこの変更が必要か？）

**背景:**
（現状の問題点・ユーザーからの要求）

**スコープ:**
（今回の変更に含まれるもの・含まれないもの）

---

## Agent構成

| Agent名 | 専門領域 | 担当 | ファイル所有権 |
|---------|---------|------|-------------|
| tachikoma-nextjs | Next.js/React | Reactコンポーネント実装 | src/components/**, src/pages/** |
| tachikoma-fullstack-js | NestJS/Express | REST API実装 | src/api/**, src/services/**, src/models/** |
| tachikoma-test | テスト | E2Eテスト作成 | tests/e2e/** |

---

## Execution Waves（並列実行グループ）

**🔴 Wave内のagentは自然言語で一括指示し、全て同時並列起動する。Waveの数を最小化（=並列度を最大化）すること。実際の並列制御はCodexのネイティブ `max_threads`（config.toml）が担う。**

### Wave 1（独立タスク・同時起動）
| Agent | 担当タスク | ファイル所有権 |
|-------|----------|--------------|
| tachikoma-database | #1: スキーマ設計・マイグレーション | `migrations/**`, `src/models/**` |
| tachikoma-typescript | #2: 共通型定義・APIインターフェース | `src/types/**` |

### Wave 2（Wave 1完了後・同時起動）
| Agent | 担当タスク | ファイル所有権 |
|-------|----------|--------------|
| tachikoma-fullstack-js | #3-4: REST API CRUD・バリデーション | `src/api/**`, `src/services/**` |
| tachikoma-nextjs | #5-6: ユーザー一覧・編集フォーム | `src/components/**`, `src/pages/**` |

### Wave 3（Wave 2完了後・同時起動）
| Agent | 担当タスク | ファイル所有権 |
|-------|----------|--------------|
| tachikoma-test | #7: 統合テスト | `tests/integration/**` |
| tachikoma-e2e-test | #8: E2Eテストシナリオ | `tests/e2e/**` |

---

## タスクリスト

### Wave 1（並列起動）
- [ ] タスク1: ユーザーモデルのスキーマ設計（PostgreSQLテーブル定義・マイグレーション）[tachikoma-database]
- [ ] タスク2: 共通型定義・APIインターフェース定義 [tachikoma-typescript]

### Wave 2（Wave 1完了後・並列起動）
- [ ] タスク3: REST API CRUDエンドポイント実装 [tachikoma-fullstack-js]
- [ ] タスク4: バリデーション・エラーハンドリング [tachikoma-fullstack-js]
- [ ] タスク5: ユーザー一覧コンポーネント実装（データテーブル、ページネーション）[tachikoma-nextjs]
- [ ] タスク6: ユーザー編集フォーム実装（バリデーション、API連携）[tachikoma-nextjs]

### Wave 3（Wave 2完了後・並列起動）
- [ ] タスク7: 統合テスト作成 [tachikoma-test]
- [ ] タスク8: E2Eテストシナリオ作成（Playwright、登録・編集・削除フロー）[tachikoma-e2e-test]

---

## ファイル所有権パターン

**🔴 重要: 同一Wave内のagentは所有権が排他的であること（重複禁止）**

| Agent | 所有権パターン | Wave | 説明 |
|-------|--------------|------|------|
| tachikoma-database | `migrations/**`, `src/models/**` | 1 | DBスキーマ・マイグレーション |
| tachikoma-typescript | `src/types/**` | 1 | 共通型定義 |
| tachikoma-fullstack-js | `src/api/**`, `src/services/**` | 2 | API・ビジネスロジック |
| tachikoma-nextjs | `src/components/**`, `src/pages/**` | 2 | Reactコンポーネント・ページ |
| tachikoma-test | `tests/integration/**` | 3 | 統合テスト |
| tachikoma-e2e-test | `tests/e2e/**` | 3 | E2Eテスト |

**競合リスク対策:**
- `src/types/**`（型定義）→ Wave 1で専用agentが先行作成。Wave 2以降は参照のみ
- 設定ファイル（`tsconfig.json`, `package.json`）→ 必要な場合はCodex本体がWave 1前に事前作成

---

## 依存関係と実行順序

```
Wave 1: tachikoma-database ∥ tachikoma-typescript  ← 同時並列起動
         ↓ 全完了待ち
Wave 2: tachikoma-fullstack-js ∥ tachikoma-nextjs   ← 同時並列起動
         ↓ 全完了待ち
Wave 3: tachikoma-test ∥ tachikoma-e2e-test          ← 同時並列起動
```

**Wave内のagentは必ず同時起動。Wave間でのみ順序制約を設ける。**

---

## 実行ログ

（Agent逐次実行中の進捗・完了状況をここに記録）

### 形式
```
- [YYYY-MM-DD HH:MM] イベント内容
```

### 例
```markdown
- [2026-02-18 10:00] tachikoma-architecture agent 起動（計画策定）
- [2026-02-18 10:30] 計画書作成完了、ユーザー承認取得
- [2026-02-18 10:35] Wave 1 並列起動: tachikoma-database(#1) ∥ tachikoma-typescript(#2)
- [2026-02-18 11:00] tachikoma-typescript #2完了（型定義）
- [2026-02-18 11:10] tachikoma-database #1完了（スキーマ設計）
- [2026-02-18 11:10] Wave 1 全完了
- [2026-02-18 11:15] Wave 2 並列起動: tachikoma-fullstack-js(#3-4) ∥ tachikoma-nextjs(#5-6)
- [2026-02-18 11:45] tachikoma-nextjs #5-6完了（UIコンポーネント）
- [2026-02-18 12:00] tachikoma-fullstack-js #3-4完了（API実装）
- [2026-02-18 12:00] Wave 2 全完了
- [2026-02-18 12:05] Wave 3 並列起動: tachikoma-test(#7) ∥ tachikoma-e2e-test(#8)
- [2026-02-18 12:25] tachikoma-test #7完了（統合テスト）
- [2026-02-18 12:30] tachikoma-e2e-test #8完了（E2Eテスト）
- [2026-02-18 12:30] Wave 3 全完了 → 全タスク完了
- [2026-02-18 12:35] 品質チェック完了
```

---

## 回復手順

**失敗時はこのファイルのタスクリストを確認し、未完了タスク（`- [ ]`）から再開。**

### 手順

1. **未完了タスクの特定**
   - タスクリストで `- [ ]`（未完了）のタスクを特定
   - 実行ログで最後に完了したタスクを確認

2. **中断したagentの再起動**
   - 未完了タスクを担当するagentを特定
   - 同じagentを再起動し、未完了タスクのみを指示
   - 完了済みタスクは再実行しない

3. **タスクリスト更新**
   - 完了したら `- [x]` に変更
   - 実行ログに再開時刻・完了時刻を記録

### 例（タスク5-8が未完了の場合）

```markdown
## 実行ログ

- [2026-02-18 10:35] tachikoma-fullstack-js agent 起動
- [2026-02-18 11:30] タスク1-3完了
- [2026-02-18 11:35] tachikoma-nextjs agent 起動
- [2026-02-18 12:00] タスク4完了
- [2026-02-18 12:10] ⚠️ エラー発生（タスク5実行中にAPI仕様の誤解）
- [2026-02-18 12:15] 中断
- [2026-02-18 14:00] tachikoma-nextjs agent 再起動（タスク5-6のみ指示）
- [2026-02-18 14:20] タスク5完了（API仕様修正後）
- [2026-02-18 14:30] タスク6完了
- [2026-02-18 14:35] tachikoma-test agent 起動（タスク7-8）
- [2026-02-18 14:55] タスク7-8完了
- [2026-02-18 15:00] 全タスク完了
```

---

## 注意事項・リスク

（プロジェクト固有の注意点を記載）

### 技術的リスク
- 例: `src/types/user.ts` の型定義が競合する可能性 → backend agentが先に作成、frontend agentは参照のみ

### 依存関係リスク
- 例: backend agentのタスク2が失敗すると、以降のfrontend/test agentがブロックされる → 早期のAPI実装完了を優先
```

---

## 実行ログの記録方法

### タイムスタンプ形式
```
[YYYY-MM-DD HH:MM] イベント内容
```

### 記録すべき内容

| カテゴリ | 記録内容 |
|---------|---------|
| **Agent起動** | Agent名・担当タスク・起動時刻 |
| **タスク完了** | タスク番号・担当Agent・完了時刻 |
| **エラー** | エラー内容・発生時刻・影響範囲 |
| **再起動** | 再開時刻・再開理由・未完了タスク |
| **統合** | 品質チェック・完了時刻 |

---

## テンプレート使用のベストプラクティス

1. **計画は詳細に**: タスク数・所有権パターン・実行順序を明確に記述
2. **実行ログは即座に記録**: agent完了報告を受けたらすぐに実行ログに追記
3. **競合リスクを事前に特定**: 共有ファイル・設定ファイルの扱いを明示
4. **回復手順を事前に想定**: 失敗時の再開方法を計画段階で検討
5. **ドキュメントは削除しない**: 作業完了後も将来の参照用として保持
6. **max_threadsを確認**: Wave内agent数が `config.toml` の `max_threads`（デフォルト6）を超えないよう設計する
