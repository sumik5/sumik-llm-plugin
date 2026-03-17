# スケーラブルTypeScriptプロジェクト設計

TypeScriptプロジェクトが成長するにつれ、フォルダ構成・リポジトリ戦略・自動品質管理の意思決定がコードベースの持続可能性を左右する。本リファレンスは「どう構成するか」の判断基準を整理する。

---

## 1. プロジェクト構成パターン

### 標準ディレクトリ構成

| ディレクトリ/ファイル | 役割 | 備考 |
|---------------------|------|------|
| `src/` | TypeScriptソースコード一式 | ロールと機能でサブディレクトリ分割 |
| `dist/` | コンパイル済みJS出力 | デプロイ対象。gitignore推奨 |
| `config/` | ツール設定ファイル群 | webpack, Babel, 環境変数など |
| `test/` または colocated | テストコード | コンポーネント隣接配置がモダンなアプローチ |
| `index.ts` | モジュールエクスポートの単一エントリー | barrel fileパターン |

### Feature-based vs Function-based vs Hybrid

| 観点 | Feature-based | Function-based | Hybrid（推奨） |
|------|--------------|---------------|----------------|
| **構造原則** | 機能（ビジネスドメイン）単位 | 役割（components/services/utils）単位 | トップレベルはFeature、内部はFunction |
| **凝集性** | ◎ 関連コードが同じ場所に集約 | △ 機能跨ぎで分散しがち | ◎ 両方の利点 |
| **再利用性** | △ 共通処理が重複しやすい | ◎ 共通処理が一元化 | ○ shared/以下に共通処理 |
| **スケーラビリティ** | ◎ 新機能追加が他に影響しない | △ 同一レイヤーが肥大化 | ◎ 段階的に成長可能 |
| **開発体験** | ◎ ビジネスドメインで検索可能 | △ 複数ディレクトリを横断 | ◎ 直感的なナビゲーション |
| **テスト配置** | ◎ 機能コードと同居できる | △ テストの場所が不明確になりやすい | ◎ feature内にcolocate |
| **適したチーム規模** | 中〜大規模 | 小規模 | 全規模 |

#### Hybrid構造の例

```
src/
  products/           ← Feature
    components/       ← Function（内部）
      ProductList.ts
    services/
      ProductService.ts
  cart/               ← Feature
    components/
      Cart.ts
    services/
      CartService.ts
  shared/             ← 横断的共通処理
    utils/
    types/
```

### 構成パターン選択フロー

```
チーム3人以下 AND 機能数が少ない
  → Function-based でシンプルに開始

チームが成長 OR 機能境界が明確になった
  → Hybrid へ移行（ビジネスドメインでルーティング）

Monorepo / 複数アプリ
  → Module-based（Nx/Turborepo管理下のapps/ + libs/）
```

---

## 2. モジュールシステム選択

> 基礎的なESM/CJS仕様は `PT-CH09-10-MODULES.md` を参照。ここでは**プロジェクト設計時の選択判断**に絞る。

| 判断軸 | ESM（ES6 Modules） | CommonJS |
|--------|-------------------|----------|
| **ランタイム** | ブラウザ + Node.js 12+ | Node.js（デフォルト） |
| **静的解析** | ◎ 静的インポート → tree shakingが効く | △ 動的 `require` → 解析困難 |
| **bundle最適化** | ◎ 未使用コードの自動除去が可能 | △ バンドルサイズが大きくなりやすい |
| **`tsconfig` 設定** | `"module": "ESNext"` or `"ES2022"` | `"module": "CommonJS"` |
| **採用シーン** | フロントエンド全般、モダンNode.jsライブラリ | 旧来Node.jsサーバー、CLIツール |

**推奨**: 新規プロジェクトはESMを基本とし、Node.jsレガシー互換が必要な場合のみCJS or dual-format。

---

## 3. 依存管理

### 依存タイプ分類

| タイプ | `package.json` フィールド | 例 | 本番ビルドに含まれるか |
|--------|--------------------------|----|-----------------------|
| 本番依存 | `dependencies` | React, Axios | ◎ 含まれる |
| 開発依存 | `devDependencies` | Jest, ESLint, TypeScript | × 含まれない |
| ピア依存 | `peerDependencies` | ライブラリがhost側のReactを使う場合 | 呼び出し元が管理 |

### パッケージマネージャー比較

| 観点 | npm | Yarn | pnpm |
|------|-----|------|------|
| **インストール** | Node.jsに同梱 | `npm i -g yarn` | `npm i -g pnpm` |
| **ストレージ** | `node_modules/`（フラット） | `node_modules/`（フラット） | コンテンツアドレス型ストア + symlink |
| **ディスク効率** | 普通 | 普通 | ◎ プロジェクト間で共有 |
| **インストール速度** | 普通 | 速い | ◎ 最速 |
| **Monorepoサポート** | 基本的 | 良好 | ◎ 優秀（workspaces） |
| **lockファイル** | `package-lock.json` | `yarn.lock` | `pnpm-lock.yaml` |
| **依存の重複排除** | 部分的 | npmより良い | ◎ 厳密かつ効率的 |
| **学習コスト** | 低 | 低 | 中 |
| **最適ケース** | 入門・シンプルなプロジェクト | 安定性重視のチーム | Monorepo、パフォーマンス重視 |

**Monorepoを使うならpnpmを推奨**（ディスク効率とworkspace管理が優秀）。

### 依存更新の安全戦略

```
1. 更新前に git commit でスナップショット
2. 1パッケージずつ更新（依存解決の失敗を分離）
3. CHANGELOG/リリースノートでbreaking changesを確認
4. Major update → テスト全実行 → 段階的に本番適用
```

---

## 4. リポジトリ戦略

### Monorepo vs Polyrepo 比較

| 観点 | Monorepo | Polyrepo |
|------|---------|----------|
| **ツール統一** | ◎ スクリプト・設定を1箇所で管理 | △ リポジトリごとに重複 |
| **アトミック変更** | ◎ 複数プロジェクトを1コミットで変更可 | △ クロスリポジトリ変更が困難 |
| **型/ライブラリ共有** | ◎ パッケージ公開不要で直接参照 | △ 共有ライブラリをnpmパッケージ化が必要 |
| **独立デプロイ** | △ 設定が必要（affectedコマンドで対応） | ◎ 各サービスが独自スケジュールで可能 |
| **チーム自律性** | △ 全員が同じリポジトリに変更を加える | ◎ チームが独立して所有 |
| **技術多様性** | △ 共通のツールチェーンに縛られやすい | ◎ スタック・言語を自由に選択 |
| **CI複雑度** | 要affected-based CI（Nx等で解決） | シンプル（小規模時） |

### Monorepo/Polyrepo 選択判断フロー

```
コード共有 (型/ユーティリティ) が多い
  → Monorepo

チームが独立して異なる技術スタックを使う
  → Polyrepo

一部は共有・一部は独立
  → Hybrid（共有ライブラリはMonorepo、独立サービスは別repo）
```

### Monorepoツール比較

| ツール | 特徴 | TypeScript対応 | コードgenerator | affectedビルド |
|--------|------|---------------|----------------|---------------|
| **Nx** | エンタープライズ向け高機能 | ◎ ファーストクラス | ◎ あり | ◎ あり |
| **Turborepo** | Vercel製・高速・シンプル | ○ | △ なし | ◎ あり |
| **Lerna** | パッケージ公開特化 | △ | × | △ 限定的 |
| **Rush** | 超大規模向け（MS製） | ○ | △ | ◎ あり |
| **Yarn Workspaces** | 依存管理のみ | ○ | × | × |

#### Nx の主な強み

- **Project Graph**: アプリ・ライブラリ間の依存関係を可視化
- **Affected Commands**: 変更のあったプロジェクトのみビルド/テスト → CI高速化
- **Generators**: `nx g @nx/next:app apps/my-app` でアプリ雛形を自動生成
- **Plugins**: React / Next.js / NestJS / Express など主要フレームワークに対応

#### Nx Workspace 標準構成

```
nx-workspace/
  apps/          ← アプリケーション（frontend, backend, e2e）
  libs/          ← 共有ライブラリ（ui-components, shared-types, utils）
  nx.json        ← Nx設定（workspace-wide）
  pnpm-workspace.yaml
  .lintstagedrc.json
```

---

## 5. ADR（Architecture Decision Records）

アーキテクチャ上の重要な決定を、コードベースと同じバージョン管理下に記録するドキュメント。

### ADRが必要な決定の例

- Monorepo vs Polyrepo の選択
- データベース技術の選択
- 認証・認可方式
- デプロイ戦略（Serverless vs コンテナ）
- フロントエンドフレームワーク選択

### ADR テンプレート

```markdown
# ADR {NNNN}: {決定タイトル}

## Context（背景）
なぜこの決定が必要になったか。
プロジェクトの制約・要件・チーム状況を記述。

## Decision（決定）
どのオプションを選んだか。

## Consequences（結果）
**Pros:**
- ...

**Cons:**
- ...

この前提が変わった場合の見直しトリガー:
- ...
```

### 運用ルール

| ルール | 詳細 |
|--------|------|
| 配置場所 | `/docs/adr/NNNN-{slug}.md` |
| 番号付け | 4桁の連番（0001〜） |
| 粒度 | 1 ADR = 1決定。長大な設計書にしない |
| 更新方針 | 過去ADRは変更しない。新しいADRで上書き決定を記録 |
| トリガー | 外部ライブラリの採用・アーキテクチャパターン変更・インフラ方式変更 |

---

## 6. コード品質自動化

### Git Hooks 戦略

| Hook | タイミング | 適切なチェック | 速度要件 |
|------|-----------|---------------|---------|
| `pre-commit` | コミット前 | lint, format, staged filesのみ | ◎ 数秒以内 |
| `pre-push` | push前 | full test suite, 統合チェック | △ 数十秒まで許容 |

**原則**: pre-commitは軽快に。重いチェックはpre-pushまたはCI。

### Husky + lint-staged 構成

```bash
# 1. インストール（workspace root）
pnpm add -D husky lint-staged -w

# 2. Husky 初期化
pnpm exec husky init

# 3. pre-commit hook 設定
echo "pnpm exec lint-staged" > .husky/pre-commit
chmod +x .husky/pre-commit
```

#### `.lintstagedrc.json`

```json
{
  "*.{js,ts,tsx}": ["eslint --fix", "prettier --write"],
  "*.json": "prettier --write",
  "*.md": "prettier --write"
}
```

### コミット時の実行フロー

```
git commit -m "feat: ..."
     ↓
Husky: pre-commit hook 起動
     ↓
lint-staged: staged ファイルのみに絞って実行
     ↓
ESLint --fix → 自動修正（修正不能なエラーがあればコミットブロック）
Prettier --write → 自動フォーマット
     ↓
✅ クリーンなコードのみがGit履歴に入る
```

### Git Hooks 拡張例

| チェック内容 | ツール | 推奨Hook |
|------------|--------|---------|
| コミットメッセージ規約 | `commitlint` | `commit-msg` |
| ブランチ名規約 | カスタムスクリプト | `pre-commit` |
| 型チェック（staged） | `tsc --noEmit` | `pre-push` |
| セキュリティスキャン | `npm audit` | `pre-push` |
| テスト実行 | Jest/Vitest | `pre-push` |

---

## 判断マトリクス: プロジェクト規模別推奨構成

| プロジェクト規模 | 構成パターン | パッケージマネージャー | リポジトリ戦略 | Monorepoツール |
|----------------|------------|----------------------|--------------|--------------|
| 個人・小規模（〜2人） | Function-based | npm / pnpm | Polyrepo or 単一repo | 不要 |
| チーム（3〜10人） | Hybrid | pnpm | Monorepo | Turborepo or Nx |
| 中〜大規模（10人〜） | Hybrid + Module-based | pnpm | Monorepo | Nx（推奨） |
| マルチチーム | Module-based | pnpm | Hybrid（shared=Mono, services=Poly） | Nx |
