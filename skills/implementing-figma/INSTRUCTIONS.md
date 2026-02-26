# Figma MCP 包括的ワークフロー

## 1. Overview

基本的なFigma→コード変換から、Figma Make統合・Code Connect・Design System Rules・デザイントークン同期まで、Figma MCPのすべてのワークフローをカバーする包括的スキル。

> **非FigmaのデザインガイドラインとUI実装原則については `implementing-design` スキルを参照**

| ワークフロー | ユースケース |
|------------|------------|
| 基本変換（§2） | FigmaのURLからコンポーネント/ページを実装 |
| Figma Make統合（§4） | デザインプロトタイプ→本番アプリへの拡張 |
| Code Connect（§5） | Figmaコンポーネント↔コードコンポーネントのマッピング |
| Design System Rules（§6） | コード生成一貫性ルールの自動生成 |
| デザイントークン同期（§7） | Figma Variables→CSS変数/Tailwindの自動同期 |

---

## 2. 基本ワークフロー（Step 1-7）

**すべてのFigma→コード変換の基本フロー。順番を守って実行すること。**

### Step 1: Node ID の取得

**Option A: FigmaURLから解析**
```
URL: https://figma.com/design/:fileKey/:fileName?node-id=1-2
→ fileKey: `/design/` 以降のセグメント
→ nodeId: `node-id` クエリパラメータの値（例: `42-15`）
```

**Option B: Figma Desktop App（figma-desktop MCPのみ）**
URLなしで使用可能。デスクトップで選択中のノードを自動使用。`fileKey` は不要。

### Step 2: デザインコンテキスト取得

```
get_design_context(fileKey=":fileKey", nodeId="1-2")
```
取得内容: レイアウト・タイポグラフィ・カラー・コンポーネント構造・スペーシング

**レスポンスが切り捨てられた場合:**
1. `get_metadata(fileKey, nodeId)` でノードマップ取得
2. 子ノードIDを特定
3. `get_design_context` を子ノードごとに個別実行

### Step 3: ビジュアル参照取得

```
get_screenshot(fileKey=":fileKey", nodeId="1-2")
```
スクリーンショットが視覚的検証の唯一の正解。実装中は常に参照すること。

### Step 4: アセットDL

- Figma MCPサーバーが返す `localhost` ソースのアセットはそのまま使用
- 新たなアイコンパッケージを追加しない
- `localhost` ソースが提供された場合はプレースホルダーを使用しない

### Step 5: プロジェクト規約への変換

- Figma MCPの出力（React + Tailwind）はデザイン意図の表現。最終コードとしてそのまま使用しない
- 既存コンポーネント（ボタン・入力・タイポグラフィ）を再利用
- プロジェクトのカラーシステム・タイポグラフィスケール・スペーシングトークンを使用

### Step 6: 1:1 ビジュアルパリティ

- Figmaの忠実な再現を最優先
- ハードコード値を避けてデザイントークンを使用
- プロジェクトトークンとFigmaの値が異なる場合は、プロジェクトトークン優先・スペーシングは視覚的整合性を確保
- WCAGアクセシビリティ要件を満たす

### Step 7: 実装後バリデーション

- [ ] レイアウト一致（スペーシング・配置・サイズ）
- [ ] タイポグラフィ一致（フォント・サイズ・ウェイト・行高）
- [ ] カラー完全一致
- [ ] インタラクティブ状態動作（ホバー・アクティブ・無効）
- [ ] レスポンシブ動作がFigma制約に従っている
- [ ] アセットの正常描画
- [ ] アクセシビリティ基準充足

---

## 3. Figma MCP 全13ツール一覧

| ツール | 対応環境 | 機能・用途 |
|--------|---------|-----------|
| `get_design_context` | リモート/デスクトップ | React+TailwindでFigmaフレームのコード生成。Design/Make対応 |
| `get_variable_defs` | **デスクトップのみ** | 色・スペーシング・タイポグラフィの変数・スタイル抽出 |
| `get_code_connect_map` | **デスクトップのみ** | FigmaノードID↔コードコンポーネントのマッピング取得 |
| `add_code_connect_map` | **デスクトップのみ** | 新しいFigmaノード↔コードコンポーネントのマッピング追加 |
| `get_code_connect_suggestions` | **デスクトップのみ** | 未マッピングFigmaコンポーネントへのコードマッピング提案 |
| `send_code_connect_mappings` | **デスクトップのみ** | Code Connectマッピングの確認・送信 |
| `get_screenshot` | リモート/デスクトップ | 選択範囲のスクリーンショット取得。Design/FigJam対応 |
| `get_metadata` | リモート/デスクトップ | レイヤーID・名前・種類・位置・サイズのXML表現 |
| `create_design_system_rules` | リモート/デスクトップ | コード生成一貫性のためのデザインシステムルールファイル生成 |
| `get_figjam` | リモート/デスクトップ | FigJamダイアグラムのXML変換 |
| `generate_diagram` | リモート/デスクトップ | Mermaid→FigJamダイアグラム生成 |
| `generate_figma_design` | **リモートのみ** | UIをFigmaに送信（新規/既存/クリップボード） |
| `whoami` | **リモートのみ** | 認証済みユーザー情報・権限確認 |

> デスクトップ専用ツールはFigma Desktop Appが起動中で対象ファイルを開いている必要がある。

---

## 4. Figma Make 統合ワークフロー

**Figma Make:** デザインプロトタイプを本番アプリへ拡張するツール。

```
1. MakeリンクをエージェントにShare
   → "このMakeプロジェクトを実装して: https://www.figma.com/make/..."

2. get_design_context でMakeファイルのコンテキスト取得
   → fileKey と nodeId を URL から抽出

3. Makeプロジェクトのファイルリスト確認（MCPリソース機能）
   → 対応クライアントのみ。未対応の場合は get_metadata で代替

4. 既存コンポーネント再利用の指示
   → "既存の /components/ui/ を優先的に使用すること"

5. 実装・Step 7バリデーション
```

---

## 5. Code Connect 統合

**Code Connect:** FigmaコンポーネントIDとコードコンポーネントのマッピングシステム。重複実装を防ぐ。

### マッピング構造

```json
{ "node-id": { "codeConnectSrc": "components/ui/Button.tsx", "codeConnectName": "Button" } }
```

### ワークフロー

```
1. get_code_connect_map でマッピング取得
2. マッピング済み → 既存コンポーネントを import して再利用（新規作成禁止）
3. 未マッピング → get_code_connect_suggestions で提案取得
4. 実装後に add_code_connect_map でマッピング追加
5. send_code_connect_mappings で確認送信
```

---

## 6. Design System Rules 生成

```
1. create_design_system_rules を実行
   → fileKey + nodeId（デザインシステムページ）を指定

2. 生成されるルール内容:
   Tech Stack / Component Structure / Styling System /
   Layout Patterns / Naming Conventions

3. プロジェクトルートに保存: .mcp/design-system-rules.txt

4. get_design_context 呼び出し時にルールをプロンプトに含める
   → "以下のデザインシステムルールに従って実装してください: [rules]"

5. デザインシステム変更時・フレームワーク移行後に更新
```

---

## 7. デザイントークン同期ワークフロー

`get_variable_defs` を使ったFigma Variables→コード変数の同期（デスクトップ環境必須）。

### Phase 1: 準備（AskUserQuestionで確認）
- 同期対象: JSON変数のみ / Typographyのみ / 両方
- 更新ファイル: globals.css / tailwind.config.ts / 両方

### Phase 2: データ解析
- `get_variable_defs` で全Figma変数取得
- Primitive / Semantic / Number / Font Family に分類
- 既存設定ファイルとの差分確認

### Phase 3: データ変換

| 変換内容 | Figma形式 | コード形式 |
|---------|----------|-----------|
| 変数名 | `Semantic/TextAndIcon/Heading` | `--semantic-text-icon-heading` |
| 色 | `rgb(255, 255, 255)` | `hsl(0 0% 100%)` （shadcn/ui互換） |
| エイリアス | `{Primitive/Blue/500}` | `var(--primitive-blue-500)` |
| Typography | Figmaフォント定義 | Tailwind `fontSize` 形式 |

### Phase 4: 更新提案
- サンプル定義（5〜10変数）をユーザーに提示
- 差分サマリー（追加/更新/削除件数）を報告
- **ユーザー承認後**に本番適用

### Phase 5: ファイル更新
- `globals.css`: カテゴリ内は数字順ソート、カテゴリ区切りにコメント
- `tailwind.config.ts`: 数字キー昇順ソート、既存カスタム設定を保持

### Phase 6: フォーマット実行（prettier/biome）

---

## 8. 高度なFigma→コード変換（5フェーズ）

### Phase 1: 情報収集
- Figma URL + 参考APIインターフェース取得

### Phase 2: 既存コンポーネント確認
- `/components/ui/` を確認
- Figma情報コメントで重複判定:
  ```
  // @figma-node: 42-15
  // @figma-component: Button/Primary
  ```

### Phase 3: Figmaデザイン情報取得（並列）
```typescript
const [screenshot, metadata] = await Promise.all([
  get_screenshot({ fileKey, nodeId }),
  get_metadata({ fileKey, nodeId }),
]);
// Token Limit対応: 大規模デザインは子ノード分割して get_design_context を個別実行
```

### Phase 4: 実装方針提案（ユーザー承認後Phase 5へ）
```
AppCard
├── AppCardHeader (既存: components/ui/CardHeader)
├── AppCardBody   (新規作成)
└── AppCardFooter (既存: components/ui/CardFooter)
```

### Phase 5: 実装
- コンポーネント実装（Figma情報コメント付き）
- TypeScript型定義・Storybookストーリー
- get_screenshot との視覚比較バリデーション

---

## 9. Figmaファイル準備のベストプラクティス

| 項目 | 推奨 | 理由 |
|------|------|------|
| Auto Layout | 全フレームに適用 | レスポンシブ意図が正確に伝わる |
| 命名 | セマンティック（`CardContainer`） | `Frame 123` より変換精度向上 |
| スペーシング | 4px基準グリッド統一 | Tailwindデフォルトスケールと親和性が高い |
| カラー | Figma Variables 階層化 | `get_variable_defs` で正確に取得可能 |
| コンポーネント | バリアント定義（Size/State） | get_design_context でバリアント情報取得可 |

---

## 10. 効果的なプロンプト作成

**Before（精度が低い）:** `このFigmaを実装して: https://figma.com/design/xxx?node-id=1-2`

**After（精度が高い）:**
```
以下のFigmaカードコンポーネントをNext.js + Tailwind CSSで実装してください:
https://figma.com/design/xxx?node-id=1-2

- 出力先: components/features/ProductCard/
- 既存コンポーネント: /components/ui/ を優先的に再利用
- デザインシステムルール: .mcp/design-system-rules.txt を参照
- Code Connect: get_code_connect_map で既存マッピングを先に確認
```

**ツール明示的指定が有効な場面:**
- デザイントークン同期: `get_variable_defs を使用して globals.css を更新してください`
- Code Connect初期設定: `get_code_connect_suggestions でマッピング提案を取得してから実装してください`

---

## 11. 接続設定リファレンス

| 環境 | エンドポイント |
|------|--------------|
| リモート（Claude Code） | `https://mcp.figma.com/mcp` |
| デスクトップ | `http://127.0.0.1:3845/mcp` |

接続確認: `whoami()` で認証済みユーザー情報を取得して確認する。

---

## 12. ユーザー確認の原則（AskUserQuestion）

### 確認すべき場面

| 場面 | 確認項目 |
|------|---------|
| 基本変換 | ターゲットフレームワーク・コンポーネント粒度・レスポンシブ対応 |
| デザイントークン同期 | 同期対象カテゴリ・更新ファイル範囲 |
| Code Connect | 複数候補がある場合のコンポーネント選択 |
| Figma Make | 既存コンポーネント再利用 vs 新規作成 |

### 確認不要な場面

- Figmaのカラー・フォント・スペーシングの忠実な再現（常に1:1）
- セマンティックHTMLの使用（常に必須）
- Code Connectマッピング済みコンポーネントの再利用（必ず再利用）
- CSS変数名変換規則（`/` → `-` への変換は常に適用）
