# VITEST-CLI — CLI・フィルタ・タグ・デバッグ

Vitest v4.x (v4.1.7)。Node.js >= 20 / Vite >= 6 が必須。

---

## 実行モード

| コマンド | 動作 | 用途 |
|---------|------|------|
| `vitest` | TTY 検出時は watch、非 TTY 時は run を自動選択 | 開発中・標準 |
| `vitest watch` / `vitest dev` | 強制 watch | ファイル変更の即時フィードバック |
| `vitest run` | 強制ワンショット実行（プロセス終了） | CI・スクリプト |
| `vitest run --no-watch` | 明示的にプロセス終了を保証 | **AI エージェントでは必須** |

> **AI エージェント規約**: `vitest run` または `--no-watch` を使用し、プロセスが終了することを必ず保証する。
> watch モードのままではプロセスが返らず次ステップへ進めない。

---

## 主要フラグ一覧

| フラグ | 説明 |
|-------|------|
| `-t` / `--testNamePattern <regex>` | テスト名を正規表現でフィルタ |
| `--shard=X/Y` | 分散 CI 用シャード（1-indexed） |
| `--maxWorkers <n>` | ワーカー数上限（v4 で `maxThreads`/`maxForks` を統合） |
| `--pool <type>` | ワーカープール: `forks`（デフォルト）/ `threads` / `vmForks` / `vmThreads` |
| `--isolate` / `--no-isolate` | モジュールアイソレーション制御（`false` で高速化） |
| `--reporter <name>` | レポーター指定（複数可） |
| `--coverage.*` | カバレッジオプション（例: `--coverage.provider=v8`） |
| `-u` / `--update` | スナップショット更新 |
| `--retry <n>` | テスト失敗時の再試行回数 |
| `--bail <n>` | n 件失敗でスイート全体を中断 |
| `--sequence.shuffle` | テスト実行順をランダム化 |
| `--sequence.seed <n>` | ランダム化のシード値 |
| `--typecheck` | TypeScript 型チェックを有効化 |
| `--slowTestThreshold <ms>` | この時間を超えたテストを遅いと表示（デフォルト 300ms） |
| `--ui` / `--open` | @vitest/ui ブラウザ UI を起動 |
| `--tags-filter <expr>` | タグのブール式でフィルタ（v4 新機能） |
| `--list-tags[=json]` | 定義済みタグ一覧を出力（v4 新機能） |
| `--static-parse` | 実行せず静的解析でテスト一覧を表示（`vitest list` と組み合わせ） |
| `--inspect-brk` | Node.js インスペクタを有効化（ブレークポイント待機） |
| `--no-file-parallelism` | ファイルを直列処理（デバッグ用） |
| `--test-timeout=0` | タイムアウト無効化（デバッグ用） |

---

## フィルタ

### ファイルパターン

テストファイルをパスで絞り込む。部分一致のグロブ文字列を渡す。

```bash
# 特定ディレクトリ以下のみ実行
vitest run src/utils

# 複数パターン
vitest run src/auth src/payment
```

### テスト名正規表現（-t）

```bash
# "login" を含むテスト名のみ実行
vitest run -t login

# 正規表現が使える（引用符で保護する）
vitest run -t '^should (create|update) user$'
```

### 行番号指定（v4 新機能）

ファイル名 + `:行番号` で特定のテストだけ実行できる。**フルファイル名と拡張子が必要**。単一行のみ指定可能。

```bash
vitest src/foo.test.ts:10
```

### vitest list --static-parse（v4 新機能）

テストを**実行せずに**静的解析でテスト一覧を取得する。

```bash
# テスト名・ファイル・行番号を JSON で出力
vitest list --static-parse
```

---

## タグ（Test Tags）— v4 新機能

### タグ定義（設定ファイル）

タグには `name`・`timeout`・`retry`・`priority` を定義できる。`priority` は数値が**小さいほど高優先**（低い値が高いプライオリティのタグ設定を上書きする）。

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    tags: [
      { name: 'slow',     timeout: 60000, retry: 3, priority: 1 },
      { name: 'frontend', priority: 2 },
      { name: 'backend',  priority: 2 },
    ],
  },
})
```

### タグの付与

`test()`・`describe()` の**第2引数**に `{ tags: [...] }` で付与する（v4 で第2引数に移動）。

```typescript
test('renders button', { tags: ['frontend'] }, () => {
  // ...
})

describe('payment flow', { tags: ['backend', 'slow'] }, () => {
  test('charges card', () => { /* ... */ })
})
```

### 型補完（TypeScript）

```typescript
// vitest.d.ts または globals.d.ts
declare module 'vitest' {
  interface TestTags {
    tags: 'frontend' | 'backend' | 'slow' | 'unit'
  }
}
```

### タグ名の制約

以下は**タグ名に使用禁止**:
- 予約語（大小文字問わず）: `and`、`or`、`not`
- 特殊文字: `( ) & | ! * ` ` `（スペース）

### --tags-filter の構文

ブール式で複数タグを組み合わせる。優先順位は `NOT > AND > OR`。

| 演算子 | 例 | 意味 |
|-------|-----|------|
| 単純 | `--tags-filter='frontend'` | frontend タグのみ |
| AND | `--tags-filter='frontend and unit'` | 両方持つテスト |
| OR | `--tags-filter='unit or e2e'` | どちらか持つテスト |
| NOT | `--tags-filter='not slow'` | slow を持たないテスト |
| 複合 | `--tags-filter='(unit or e2e) and not slow'` | 括弧で優先度制御 |
| ワイルドカード | `--tags-filter='api/*'` | `api/` で始まるタグすべて |

```bash
# 実例
vitest --tags-filter='(unit || e2e) && !slow'
vitest --tags-filter='frontend and not slow'

# タグ一覧確認
vitest --list-tags
vitest --list-tags=json
```

---

## デバッグ

### VS Code での推奨デバッグ手順

**JS Debug Terminal を使う方法**（`launch.json` 設定不要）:

1. VS Code で「**JavaScript Debug Terminal**」を開く
2. 以下のコマンドを実行する

```bash
vitest --inspect-brk --no-file-parallelism --test-timeout=0
```

ブレークポイントは TypeScript ソースに直接設定できる。

### launch.json を使う方法

```json
{
  "type": "node",
  "request": "launch",
  "name": "Vitest Debug",
  "program": "${workspaceFolder}/node_modules/vitest/vitest.mjs",
  "args": ["run", "--no-file-parallelism"],
  "console": "integratedTerminal"
}
```

### デバッグ用フラグの組み合わせ

| フラグ | 理由 |
|-------|------|
| `--inspect-brk` | Node.js インスペクタ起動（デフォルトポート **9229**）、最初の行で停止 |
| `--no-file-parallelism` | ファイルを直列処理し、複数プロセスのデバッグ混在を防ぐ |
| `--test-timeout=0` | デバッグ中のステップ実行でタイムアウトを防ぐ |

```bash
# 基本のデバッグ起動
vitest --inspect-brk --no-file-parallelism --test-timeout=0

# watch モードでデバッグ（アイソレーション無効で高速化）
vitest --inspect-brk --no-file-parallelism --test-timeout=0 --isolate false
```

ブラウザモードのデバッグは `fileParallelism: false` を config で設定する。

---

## シャーディング（分散 CI）

複数の CI ジョブでテストを分割実行し、最後に `--merge-reports` で集約する。

```bash
# ジョブ 1/3
vitest run --shard=1/3 --reporter=blob --outputFile=.vitest-reports/blob-1.json

# ジョブ 2/3
vitest run --shard=2/3 --reporter=blob --outputFile=.vitest-reports/blob-2.json

# ジョブ 3/3
vitest run --shard=3/3 --reporter=blob --outputFile=.vitest-reports/blob-3.json

# 全ジョブ完了後に集約
vitest run --merge-reports
```

> `--merge-reports` は watch モードでは使用不可。

---

## AI エージェント向けチェックリスト

- [ ] `vitest run` または `--no-watch` でプロセスが終了することを保証している
- [ ] `vi.fn()` / `vi.mock()` を使用している（`jest.fn()` / `jest.mock()` ではない）
- [ ] `vitest run` の終了コードでテスト成否を判定している
- [ ] 必要に応じて `--reporter=minimal` または `--reporter=agent` でトークン消費を削減している

---

## 関連ファイル

- [./VITEST-CONFIG.md](./VITEST-CONFIG.md) — 設定ファイルの全体像・カバレッジ・environments
- [./VITEST-V4-MIGRATION.md](./VITEST-V4-MIGRATION.md) — v3 → v4 破壊的変更一覧（`maxWorkers` 統合・`test.projects` 等）
