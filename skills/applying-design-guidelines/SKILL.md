---
name: applying-design-guidelines
description: UI/UX design principles covering visual design and user experience fundamentals. Use when making design decisions or evaluating existing interfaces. Covers typography, color, motion, cognitive psychology, and interaction patterns. For frontend code generation, use designing-frontend instead.
license: Complete terms in LICENSE.txt
---

This skill provides comprehensive design guidance for creating exceptional frontend interfaces that are both visually distinctive and cognitively intuitive.

## When to Use

Apply these guidelines when:
- Building web components, pages, or applications
- Making UI/UX design decisions
- Designing interaction patterns and information architecture
- Evaluating existing interfaces for improvements
- Ensuring production-grade design quality

## Structure

This skill consists of two complementary perspectives:

### ui-design.md
Visual design principles focused on aesthetics and brand:
- Typography and color systems
- Motion and micro-interactions
- Spatial composition and layouts
- Anti-patterns to avoid (generic AI aesthetics)
- Creating memorable, distinctive interfaces

### ux-design.md
User experience principles based on cognitive psychology and HCI:
- Mental models and task flows
- Interaction patterns and usability
- Cognitive biases and perception
- Accessibility and inclusive design
- Making interfaces feel natural and effortless

**IMPORTANT**: Great design requires both perspectives. Visual beauty without usability is frustrating. Usability without aesthetics is forgettable. Use both documents together for complete design guidance.

## Design Philosophy

- **Intentionality over intensity**: Bold maximalism and refined minimalism both work - the key is executing with precision
- **Invisible interface**: The best UX feels like no UX at all - users accomplish goals without thinking about the tool
- **Context-specific creativity**: Avoid generic solutions - design for the specific problem, audience, and constraints
- **Cognitive respect**: Every element costs mental effort - be ruthless about reducing unnecessary complexity

Reference the specific documents (ui-design.md or ux-design.md) as needed for detailed guidance.

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| デザインシステムの有無 | 既存のデザインシステムに従うか、新規作成か |
| ブランドカラー | プロジェクト固有の配色指定 |
| アクセシビリティ基準 | WCAG 2.1 AA, AAA |
| モーション設定 | アニメーション有無、reduced motion対応 |
| タイポグラフィ | フォントファミリー、スケール |

### 確認不要な場面

- 認知心理学の原則適用（常に適用）
- コントラスト比の確保（常に必須）
- レスポンシブデザインの考慮（常に必須）
