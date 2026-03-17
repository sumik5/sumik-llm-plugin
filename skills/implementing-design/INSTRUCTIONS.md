# Implement Design

## Overview

This skill provides general principles for translating any visual design into production-ready code with pixel-perfect accuracy. It covers design system integration, visual parity validation, responsive implementation, accessibility, and component organization. These principles apply regardless of the design source (screenshots, mockups, Zeplin specs, Figma exports, or written specifications).

> **Figma Workflows**: Figma MCP統合、Code Connect、Design System Rules、デザイントークン同期などのFigma固有のワークフローについては `implementing-figma` スキルを参照してください。

## Design System Integration

### Always Prefer Existing Components

- Search the project's component library before creating anything new
- Extend existing components with new variants rather than duplicating functionality
- When a matching component exists, use it even if minor style adjustments are needed
- Document any new components added to the design system

### Map Design Tokens

- Translate design specification values to the project's token system (CSS variables, Tailwind theme, design tokens file)
- Colors → project color tokens (e.g., `--color-primary-500`, `theme.colors.primary[500]`)
- Typography → typographic scale tokens (font family, size, weight, line height)
- Spacing → spacing scale tokens (padding, margin, gap)
- Shadows, borders, radii → effect tokens

### Avoid Hardcoded Values

- Never hardcode color hex values, pixel sizes, or font stacks inline
- Extract to named constants or design tokens
- When the project's token value differs slightly from the spec, prefer the token for consistency

### Naming Consistency

- Mirror the design's component and layer names in code (camelCase or PascalCase as appropriate)
- Use semantic names that describe purpose, not appearance (e.g., `ButtonPrimary` not `BlueButton`)

## 1:1 Visual Parity Principles

Strive for pixel-perfect visual parity with the design specification.

**Key priorities:**

1. **Layout** — spacing, alignment, sizing, grid structure
2. **Typography** — font family, size, weight, line height, letter spacing
3. **Color** — exact token or hex match, including opacity
4. **Interactive states** — hover, active, focus, disabled, loading, error
5. **Responsive behavior** — breakpoints, fluid sizing, content reflow

When a conflict arises between design spec values and the project's design system tokens, prefer the design system tokens but adjust spacing or sizing minimally to maintain visual fidelity. Document the deviation in a code comment.

## Component Design

### Structure

- Place UI components in the project's designated design system directory
- Follow the project's existing file and directory naming conventions
- Keep components composable: accept children and slots where the design calls for flexible content

### TypeScript Props Interface

```typescript
// Always define a typed props interface
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
}
```

### Code Quality

- Avoid inline styles except for truly dynamic values (e.g., computed widths from JS)
- Keep component files focused: one primary component per file
- Add JSDoc comments for exported components describing props and usage
- No `any` types — use proper TypeScript interfaces

## Accessibility

Every component must meet WCAG 2.1 AA standards:

| Requirement | Implementation |
|------------|---------------|
| Semantic HTML | Use `<button>`, `<nav>`, `<main>`, `<section>` etc. over generic `<div>` |
| ARIA attributes | `aria-label`, `aria-describedby`, `role` where semantic HTML is insufficient |
| Keyboard navigation | All interactive elements reachable and operable via keyboard |
| Focus management | Visible focus ring, correct tab order, focus trapping in modals |
| Contrast ratio | Minimum 4.5:1 for body text, 3:1 for large text and UI components |
| Color independence | Never convey information by color alone — use icons, text, or patterns too |

## Validation Checklist

Before marking implementation complete, validate against the design specification:

- [ ] Layout matches (spacing, alignment, sizing)
- [ ] Typography matches (font, size, weight, line height)
- [ ] Colors match exactly (token or hex)
- [ ] Interactive states work as designed (hover, active, focus, disabled)
- [ ] Responsive behavior follows design constraints
- [ ] Assets render correctly (images, icons, SVGs)
- [ ] Accessibility standards met (WCAG 2.1 AA)
- [ ] No hardcoded values — all values use design tokens

## Best Practices

### Context First

Never implement based on assumptions. Before writing any code, confirm:
- Target framework and component library
- Responsive strategy (fixed vs. fluid vs. breakpoints)
- Interaction behavior for states not explicitly shown in the design

### Incremental Validation

Validate frequently during implementation, not only at the end. Catching discrepancies early costs far less than fixing them after the full component is built.

### Document Deviations

If you must deviate from the design spec (for accessibility, technical constraints, or design system alignment), document why in a code comment:

```tsx
// Deviation: using `--color-primary-600` instead of spec's `#2563EB`
// for WCAG 4.5:1 contrast on white background.
```

### Reuse Over Recreation

Consistency across the codebase is more valuable than exact design replication. A slightly adapted existing component is almost always better than a new one-off component.

### Design System First

When in doubt, defer to the project's established design system patterns. The design specification describes the intent; the design system defines the implementation contract.

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| ターゲットフレームワーク | React, Next.js, Vue, HTML |
| コンポーネント粒度 | 1コンポーネント, ページ全体, デザインシステム |
| レスポンシブ対応 | 仕様通り固定, ブレークポイント追加 |
| 画像アセット | SVGインライン, 画像ファイル, CSS背景 |
| インタラクション | 仕様に記載なしのホバー/アニメーション追加可否 |

### 確認不要な場面

- デザイン仕様のカラー・フォント・スペーシングの忠実な再現（常に1:1）
- セマンティックHTMLの使用（常に必須）
- TypeScript使用（プロジェクトがTS環境の場合）

## Related Skills

- [`applying-design-guidelines`](../applying-design-guidelines/) — UI/UXデザイン理論と原則
- [`designing-frontend`](../designing-frontend/) — フロントエンドUIコード生成（shadcn/ui・Storybook）
- [`building-design-systems`](../building-design-systems/) — デザインシステム設計・ガバナンス・Figma変数/トークン実装

---

## Figma UIデザインワークフロー

Figmaを使ったUIデザイン制作ワークフロー（ワイヤーフレーム→プロトタイプ→詳細デザイン→ハンドオフ）。デザイン側の視点からFigmaを操作する際に参照する。

> 注: Figma MCP統合（デザイン→コード自動変換）は上記「Figma MCP統合」セクション参照。このセクションはFigma上でのUIデザイン作業自体を対象とする。

### 4フェーズ制作フロー

```
Phase 1: ワイヤーフレーム → 8ptグリッド設定、Safe Area確保、UI Kit活用
Phase 2: プロトタイプ   → Flow管理、インタラクション設定、Smart Animate
Phase 3: 詳細デザイン   → コンポーネント化、バリアント設計、UIスタック（5状態）
Phase 4: ハンドオフ    → スタイル命名整備、Inspect/Designタブ確認環境の整備
```

### コアプリンシプル

- **8ptグリッドシステム**: 全レイアウト値を8の倍数で統一（@0.75x〜@4xで整数ピクセル保証）
- **コンポーネント駆動設計**: 同じUIを2箇所以上で使う場合はコンポーネント化
- **UIスタック（5状態）**: Blank/Loading/Partial/Error/Ideal の全状態を必ず設計
- **スタイル命名規則**: `[Mode]/[Element]/[Type]` 形式（例: `Light/Label/1`, `Dark/Background/1`）

### 詳細ガイド

| ファイル | 内容 |
|---------|------|
| [`references/FIGMA-UI-DESIGN-GUIDE.md`](references/FIGMA-UI-DESIGN-GUIDE.md) | 制作ワークフロー全体・単位リファレンス・コアプリンシプル詳細 |
| [`references/FIGMA-PRODUCTION-WORKFLOW.md`](references/FIGMA-PRODUCTION-WORKFLOW.md) | Auto Layout・コンポーネント/バリアント設計・ワイヤーフレーム・プロトタイプ |
| [`references/FIGMA-HANDOFF-DESIGN.md`](references/FIGMA-HANDOFF-DESIGN.md) | カラースタイル設計・ダークモード対応・テキストスタイル・インタラクティブコンポーネント |
| [`references/FIGMA-ENGINEER-COLLABORATION.md`](references/FIGMA-ENGINEER-COLLABORATION.md) | Inspect/Design/Prototypeタブ活用・画像書き出し設定 |
| [`references/FIGMA-PLUGIN-WORKFLOW.md`](references/FIGMA-PLUGIN-WORKFLOW.md) | プラグイン活用（Unsplash・Content Reel）・推奨プラグイン |

---

## Figma MCP統合

Figma MCPを使ったデザイン→コード変換の包括的ワークフロー。基本変換からFigma Make統合・Code Connect・Design System Rules・デザイントークン同期まで対応。

### 基本ワークフロー（Step 1-7）

**すべてのFigma→コード変換の基本フロー。順番を守って実行すること。**

#### Step 1: Node ID の取得

```
URL: https://figma.com/design/:fileKey/:fileName?node-id=1-2
→ fileKey: `/design/` 以降のセグメント
→ nodeId: `node-id` クエリパラメータの値（例: `42-15`）
```

#### Step 2: デザインコンテキスト取得

```
get_design_context(fileKey=":fileKey", nodeId="1-2")
```

レスポンスが切り捨てられた場合: `get_metadata` でノードマップ取得 → 子ノードIDを特定 → `get_design_context` を子ノードごとに個別実行

#### Step 3: ビジュアル参照取得

```
get_screenshot(fileKey=":fileKey", nodeId="1-2")
```

スクリーンショットが視覚的検証の唯一の正解。実装中は常に参照すること。

#### Step 4-6: アセット・変換・パリティ

- Figma MCPが返す `localhost` ソースのアセットはそのまま使用
- Figma MCPの出力（React + Tailwind）はデザイン意図の表現。最終コードとしてそのまま使わずプロジェクト規約へ変換
- ハードコード値を避けてデザイントークンを使用

#### Step 7: バリデーション

- [ ] レイアウト・タイポグラフィ・カラー一致
- [ ] インタラクティブ状態（ホバー・アクティブ・無効）
- [ ] レスポンシブ動作・アセット描画・アクセシビリティ

### Figma MCP 全13ツール一覧

| ツール | 対応環境 | 機能・用途 |
|--------|---------|-----------|
| `get_design_context` | リモート/デスクトップ | React+TailwindでFigmaフレームのコード生成 |
| `get_variable_defs` | **デスクトップのみ** | 色・スペーシング・タイポグラフィの変数・スタイル抽出 |
| `get_code_connect_map` | **デスクトップのみ** | FigmaノードID↔コードコンポーネントのマッピング取得 |
| `add_code_connect_map` | **デスクトップのみ** | 新しいFigmaノード↔コードコンポーネントのマッピング追加 |
| `get_code_connect_suggestions` | **デスクトップのみ** | 未マッピングFigmaコンポーネントへのコードマッピング提案 |
| `send_code_connect_mappings` | **デスクトップのみ** | Code Connectマッピングの確認・送信 |
| `get_screenshot` | リモート/デスクトップ | 選択範囲のスクリーンショット取得 |
| `get_metadata` | リモート/デスクトップ | レイヤーID・名前・種類・位置・サイズのXML表現 |
| `create_design_system_rules` | リモート/デスクトップ | コード生成一貫性のためのデザインシステムルールファイル生成 |
| `get_figjam` | リモート/デスクトップ | FigJamダイアグラムのXML変換 |
| `generate_diagram` | リモート/デスクトップ | Mermaid→FigJamダイアグラム生成 |
| `generate_figma_design` | **リモートのみ** | UIをFigmaに送信（新規/既存/クリップボード） |
| `whoami` | **リモートのみ** | 認証済みユーザー情報・権限確認 |

### Code Connect 統合

```
1. get_code_connect_map でマッピング取得
2. マッピング済み → 既存コンポーネントを import して再利用（新規作成禁止）
3. 未マッピング → get_code_connect_suggestions で提案取得
4. 実装後に add_code_connect_map でマッピング追加
```

### Design System Rules 生成

```
1. create_design_system_rules を実行（fileKey + デザインシステムページの nodeId を指定）
2. プロジェクトルートに保存: .mcp/design-system-rules.txt
3. get_design_context 呼び出し時にルールをプロンプトに含める
```

### デザイントークン同期ワークフロー

`get_variable_defs` を使ったFigma Variables→コード変数の同期（デスクトップ環境必須）。

| フェーズ | 内容 |
|---------|------|
| Phase 1: 準備 | 同期対象（JSONのみ/Typographyのみ/両方）・更新ファイル（globals.css/tailwind.config.ts）を確認 |
| Phase 2: データ解析 | `get_variable_defs` で全Figma変数取得 → Primitive/Semantic/Font Familyに分類 |
| Phase 3: データ変換 | 変数名: `Semantic/TextAndIcon/Heading` → `--semantic-text-icon-heading`。色: RGB→HSL |
| Phase 4: 更新提案 | サンプル定義をユーザーに提示 → **ユーザー承認後**に本番適用 |
| Phase 5: ファイル更新 | globals.css・tailwind.config.ts の更新 → prettier/biome フォーマット |

### 接続設定

| 環境 | エンドポイント |
|------|--------------|
| リモート（Claude Code） | `https://mcp.figma.com/mcp` |
| デスクトップ | `http://127.0.0.1:3845/mcp` |

接続確認: `whoami()` で認証済みユーザー情報を取得して確認する。

### Figmaユーザー確認の原則

確認すべき場面: ターゲットフレームワーク・コンポーネント粒度・デザイントークン同期対象・Code Connect候補複数の場合

確認不要な場面: Figmaのカラー/フォント/スペーシングの忠実な再現・セマンティックHTMLの使用・CSS変数名変換規則（`/` → `-`）
