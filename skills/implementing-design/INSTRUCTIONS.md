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

- [`implementing-figma`](../implementing-figma/) — Figma MCP統合ワークフロー（get_design_context・Code Connect・デザイントークン同期）
- [`applying-design-guidelines`](../applying-design-guidelines/) — UI/UXデザイン理論と原則
- [`designing-frontend`](../designing-frontend/) — フロントエンドUIコード生成（shadcn/ui・Storybook）
