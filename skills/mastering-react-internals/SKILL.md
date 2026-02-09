---
name: mastering-react-internals
description: Deep React internals covering rendering mechanisms, advanced patterns, and performance optimization. MUST load when working in React projects detected by package.json. Complements react-best-practices (Vercel rules) with deeper mechanism-level understanding for architecture design.
---

# mastering-react-internals

## 概要

このスキルは、Reactの内部メカニズムを深く理解し、実践的なアーキテクチャ設計力を養うための包括的な知識を提供します。表面的なAPIの使い方だけでなく、**なぜそのように動作するのか**を理解することで、パフォーマンス問題の診断、適切なパターンの選択、保守性の高いコード設計が可能になります。

### このスキルが提供する知識

- **Reactレンダリングメカニズムの深い理解**: 仮想DOM、リコンシリエーション、レンダリングトリガー
- **高度なコンポーネント設計パターン**: Provider、Composite、Summaryパターンの実践
- **パフォーマンス最適化の体系的手法**: メモ化戦略、プロファイリング、ボトルネック解消
- **状態管理アーキテクチャ**: useState/Context、useReducer、Redux Toolkit、zustand、XStateの選定基準
- **TypeScript×React実践**: 型安全なコンポーネント設計、ジェネリクス、型推論の活用
- **テスト戦略**: React Testing Library、Vitest、E2Eテストのベストプラクティス

---

## 使用タイミング

以下の場面でこのスキルを参照してください：

### 設計・アーキテクチャ決定時
- **コンポーネント設計パターンの選択**: 複合UI、状態共有、ロジック抽出のアプローチを決定
- **状態管理ライブラリの選定**: プロジェクト規模、チーム経験、要件に基づく最適選択
- **アプリケーション構成**: ディレクトリ構造、モジュール分割、依存関係の設計

### パフォーマンス問題の診断・解決時
- **不要な再レンダーの特定**: React DevTools Profilerによる分析
- **メモ化戦略の適用**: useMemo、useCallback、React.memoの使い分け
- **大量データの効率的描画**: 仮想化、遅延ロード、最適化手法

### TypeScript統合時
- **型安全なコンポーネント設計**: Props型定義、ジェネリクス、型推論
- **高度な型パターン**: Discriminated Unions、Conditional Types、Template Literal Types
- **any禁止環境での実践**: unknown + 型ガード、適切なUtility Types

### テスト戦略の策定時
- **テスト範囲の決定**: ユニット/統合/E2Eのバランス
- **Reactコンポーネントテストのベストプラクティス**: Testing Libraryの原則
- **モックとスタブの使い分け**: MSW、vitest.mock、テストダブル戦略

---

## 既存スキルとの関係

| スキル | 関係 | 使い分け |
|--------|------|---------|
| **react-best-practices** | 補完関係 | Vercelルール集（実践的ガイドライン）vs 内部メカニズム理解（理論的基盤）。両方併用で最大効果 |
| **developing-nextjs** | 特化 vs 汎用 | Next.js特化（RSC、App Router）vs React全般の深い理解。Next.js開発時は両方参照 |
| **enforcing-type-safety** | ルール vs 実践 | any禁止の絶対ルール vs React×TypeScript実践パターン。型安全性の具体的適用例 |
| **testing** | 汎用 vs 特化 | TDD全般（AAAパターン、カバレッジ）vs Reactテスト特化手法（Testing Library、フック） |
| **applying-solid-principles** | 原則 vs 実装 | SOLID原則（抽象的原則）vs Reactコンポーネントでの具体的実装例 |

---

## コンポーネント設計パターン早見表

詳細は [PATTERNS.md](./PATTERNS.md) を参照。

| パターン | 用途 | 複雑度 | 主な利点 | 主な欠点 |
|---------|------|--------|---------|---------|
| **Provider** | コンポーネントツリー全体への状態配布 | 中 | グローバル状態管理が容易 | 過度な使用でパフォーマンス低下 |
| **Composite** | 複合UIコンポーネントの構築 | 高 | 柔軟性と再利用性の両立 | 初期設計コスト高 |
| **Summary** | カスタムフックによるロジック集約 | 低-中 | テストが容易、ロジック再利用 | フックのルールに従う必要 |

### パターン選定の基本フロー

```
状態を複数コンポーネントで共有したい
  └─ YES → Providerパターン
      └─ パフォーマンス問題あり？
          └─ YES → use-context-selectorで最適化

複雑なUI部品を作りたい（タブ、アコーディオン等）
  └─ YES → Compositeパターン
      └─ サブコンポーネント間で状態共有が必要
          └─ YES → Composite + Provider（内部Context）

コンポーネントのロジックが肥大化している
  └─ YES → Summaryパターン
      └─ カスタムフックに抽出
          └─ 単一フック vs 複数フック？
              └─ 関心事が単一 → 単一フック
              └─ 複数の独立した関心事 → 複数フック
```

---

## パフォーマンス最適化概要

詳細は [PERFORMANCE.md](./PERFORMANCE.md) を参照。

### Reactレンダリングの3つのトリガー

1. **マウント（初回レンダー）**: コンポーネントがDOMに追加される
2. **親の再レンダー**: 親コンポーネントが再レンダーされると、デフォルトで子も再レンダー
3. **フックによるフラグ**: useState、useReducer、useContextによる状態変更

**重要な誤解の訂正**:
- ❌ **プロパティ変更がレンダリングを引き起こす**
- ✅ **親の再レンダーが子のレンダリングを引き起こす**（プロパティが変更されていなくても）

### メモ化判断フロー

```
パフォーマンス問題がある？
  └─ NO → 最適化不要（早すぎる最適化は悪）
  └─ YES → React DevTools Profilerで測定
      └─ 不要な再レンダーが原因？
          ├─ YES → React.memoを検討
          │   └─ Propsに関数/オブジェクトがある？
          │       └─ YES → useCallback/useMemoで安定化
          └─ 重い計算が原因？
              └─ YES → useMemoで結果をキャッシュ
```

### メモ化のベストプラクティス

| 手法 | 用途 | 注意点 |
|------|------|--------|
| `React.memo` | コンポーネント全体のメモ化 | 浅い比較（Propsの参照が変わると再レンダー） |
| `useMemo` | 重い計算結果のキャッシュ | 依存配列の正確な指定が必須 |
| `useCallback` | 関数の参照を安定化 | 子コンポーネントがReact.memoで包まれている場合に有効 |

**原則**: 測定なき最適化は行わない。React DevTools Profilerで実測してから判断。

---

## 状態管理選定ガイド

詳細は [DATA-MANAGEMENT.md](./DATA-MANAGEMENT.md) を参照。

### 状態管理ライブラリ比較

| ライブラリ | ボイラープレート | 学習コスト | デバッグ | 推奨用途 | 回避すべきケース |
|-----------|----------------|-----------|---------|---------|-----------------|
| **useState + Context** | 少 | 低 | 容易 | 小規模アプリ、シンプルな状態共有 | 大量の状態、頻繁な更新 |
| **useReducer + Immer** | 少 | 中 | 中 | 中規模、複雑なstate遷移 | 非常に大規模なアプリ |
| **Redux Toolkit** | 中 | 高 | 優秀（DevTools） | 大規模、チーム標準、時間旅行デバッグ | 小規模プロジェクト |
| **zustand** | 最小 | 低 | 容易 | 柔軟性重視、簡潔なコード | 厳密な型制約が必要 |
| **XState** | 多 | 高 | 優秀（視覚化） | 複雑なワークフロー、有限状態機械 | シンプルな状態管理 |

### 選定フロー

```
プロジェクト規模は？
  ├─ 小規模（~10コンポーネント）
  │   └─ useState + Context（またはzustand）
  ├─ 中規模（~50コンポーネント）
  │   └─ useReducer + Immer または zustand
  └─ 大規模（50+コンポーネント）
      └─ チームにRedux経験者がいる？
          ├─ YES → Redux Toolkit
          └─ NO → zustand（学習コスト低）

複雑なワークフロー（承認フロー、マルチステップフォーム等）がある？
  └─ YES → XState（状態機械で明確にモデル化）
```

### リモートデータ管理

| ライブラリ | 特徴 | 推奨ケース |
|-----------|------|-----------|
| **TanStack Query** | キャッシュ、再取得、楽観的更新 | REST API、自動キャッシュ |
| **SWR** | 軽量、Next.js統合 | Next.js、シンプルなデータフェッチ |
| **Apollo Client** | GraphQL特化、正規化キャッシュ | GraphQL API |

---

## TypeScript × React概要

詳細は [TYPESCRIPT-REACT.md](./TYPESCRIPT-REACT.md) を参照。

### 型安全なコンポーネント設計の原則

1. **Props型定義は必須**: interfaceまたはtype aliasで明示
2. **any禁止**: unknown + 型ガード、または適切なジェネリクス
3. **子要素の型付け**: `ReactNode`（推奨）、`ReactElement`、`JSX.Element`
4. **イベントハンドラ**: `React.MouseEvent<HTMLButtonElement>`等の具体的型

### 高度な型パターン

```typescript
// Discriminated Unions（判別可能なユニオン型）
type Status =
  | { type: 'idle' }
  | { type: 'loading' }
  | { type: 'success'; data: User }
  | { type: 'error'; error: Error };

// Conditional Types（条件付き型）
type IsArray<T> = T extends any[] ? true : false;

// Template Literal Types（テンプレートリテラル型）
type EventName = `on${Capitalize<string>}`;
```

### ジェネリクスの活用

```typescript
// 再利用可能なリストコンポーネント
interface ListProps<T> {
  items: T[];
  renderItem: (item: T) => ReactNode;
}

function List<T>({ items, renderItem }: ListProps<T>) {
  return <ul>{items.map((item, index) => <li key={index}>{renderItem(item)}</li>)}</ul>;
}

// 使用例
<List items={users} renderItem={(user) => <span>{user.name}</span>} />
```

---

## テスト・CSS・フレームワーク概要

詳細は [TESTING-AND-TOOLING.md](./TESTING-AND-TOOLING.md) を参照。

### React Testing Libraryの原則

1. **実装の詳細ではなく、ユーザーの振る舞いをテスト**
   - ❌ 内部stateの値を直接検証
   - ✅ レンダリング結果、ユーザーインタラクションの結果を検証

2. **AAAパターン（Arrange-Act-Assert）を厳守**
   ```typescript
   test('ボタンクリックでカウンタが増加する', () => {
     // Arrange: テスト対象をセットアップ
     const { getByRole } = render(<Counter />);
     const button = getByRole('button', { name: /increment/i });

     // Act: ユーザーアクションを実行
     fireEvent.click(button);

     // Assert: 期待される結果を検証
     expect(getByRole('heading')).toHaveTextContent('1');
   });
   ```

3. **クエリの優先順位**
   1. `getByRole` > `getByLabelText` > `getByPlaceholderText` > `getByText` > `getByTestId`
   2. アクセシビリティを考慮したセレクタを優先

### CSSアプローチの選定

| アプローチ | 学習コスト | パフォーマンス | TypeScript統合 | 推奨ケース |
|-----------|-----------|--------------|---------------|-----------|
| **CSS Modules** | 低 | 優秀 | なし | 従来型、スコープ分離重視 |
| **styled-components** | 中 | 中（ランタイム） | 優秀 | 動的スタイル、Theme |
| **Tailwind CSS** | 中 | 優秀 | プラグインで対応 | 高速開発、ユーティリティ重視 |
| **CSS-in-JS（Emotion）** | 中 | 中（ランタイム） | 優秀 | 動的スタイル、柔軟性 |

---

## ユーザー確認の原則（AskUserQuestion）

### 確認が必須な場面

以下のケースでは、ユーザーの要件・制約・好みに依存するため、**必ずAskUserQuestionツールで確認**してください：

#### 1. 状態管理ライブラリの選択
- プロジェクト規模が不明
- チームの技術スタックが不明
- 既存の状態管理方法がある場合

**確認例**:
```typescript
AskUserQuestion({
  questions: [{
    question: "状態管理ライブラリの選択について確認させてください",
    header: "状態管理アプローチ",
    options: [
      {
        label: "useState + Context",
        description: "シンプル。小規模プロジェクト向け"
      },
      {
        label: "Redux Toolkit",
        description: "大規模、チーム標準。学習コストあり"
      },
      {
        label: "zustand",
        description: "最小のボイラープレート。柔軟性高"
      },
      {
        label: "既存の方法を教えてください",
        description: "プロジェクトで既に使用している方法"
      }
    ]
  }]
})
```

#### 2. CSSアプローチの選択
- プロジェクトのスタイル管理方法が不明
- パフォーマンス要件が不明

#### 3. テスト範囲・戦略の決定
- テストカバレッジ目標が不明
- E2Eテストの必要性が不明

#### 4. コンポーネントパターンの適用判断
- 複数のパターンが適用可能で、トレードオフがある場合
- 例: Composite vs Summary、単一フック vs 複数フック

### 確認不要な場面（明確なベストプラクティスがある）

以下のケースでは確認不要。業界標準・明確なルールに従って実装：

#### 1. メモ化のベストプラクティス
- React DevTools Profilerで測定してから適用
- React.memo + useCallback/useMemoの組み合わせ

#### 2. TypeScript型付けパターン
- `any`禁止（enforcing-type-safetyスキルの絶対ルール）
- Props型定義必須
- イベントハンドラの具体的型使用

#### 3. AAAテストパターンの採用
- Arrange-Act-Assertは業界標準
- Testing Libraryのクエリ優先順位

#### 4. SOLID原則の適用
- 単一責任原則、依存性逆転等は常に適用

---

## サブファイル一覧

| ファイル | 内容 | 参照タイミング |
|---------|------|---------------|
| [PATTERNS.md](./PATTERNS.md) | コンポーネント設計パターン（Provider, Composite, Summary） | パターン選択・実装時 |
| [PERFORMANCE.md](./PERFORMANCE.md) | レンダリング最適化、メモ化戦略、プロファイリング | パフォーマンス問題診断時 |
| [DATA-MANAGEMENT.md](./DATA-MANAGEMENT.md) | 状態管理、リモートデータ、ライブラリ選定 | アーキテクチャ設計時 |
| [TYPESCRIPT-REACT.md](./TYPESCRIPT-REACT.md) | TypeScript×React実践、ジェネリクス、高度な型 | 型設計時 |
| [TESTING-AND-TOOLING.md](./TESTING-AND-TOOLING.md) | テスト戦略、CSS、フレームワーク、ツール | テスト・スタイル実装時 |

---

## 参照の優先順位

1. **問題の性質を特定**
   - レンダリング遅い → PERFORMANCE.md
   - 状態管理で迷っている → DATA-MANAGEMENT.md
   - コンポーネント設計で迷っている → PATTERNS.md
   - TypeScript型エラー → TYPESCRIPT-REACT.md
   - テストの書き方 → TESTING-AND-TOOLING.md

2. **既存スキルとの連携**
   - `react-best-practices`: Vercelルール（実践的ガイドライン）
   - `enforcing-type-safety`: any禁止の絶対ルール
   - `testing`: TDD全般、AAAパターン

3. **AskUserQuestionの使用判断**
   - 上記「ユーザー確認の原則」セクションを参照
   - 明確なベストプラクティスがある場合は確認不要

---

## まとめ

このスキルは、**Reactの表面的なAPIだけでなく、内部メカニズムを理解することで、適切な設計判断・パフォーマンス最適化・保守性の高いコード実装**を可能にします。

- **設計段階**: PATTERNS.md、DATA-MANAGEMENT.mdで最適なアーキテクチャを選択
- **実装段階**: TYPESCRIPT-REACT.md、TESTING-AND-TOOLING.mdで型安全・テスト可能なコード作成
- **最適化段階**: PERFORMANCE.mdで測定ベースの改善

他のスキル（react-best-practices、developing-nextjs、enforcing-type-safety、testing）と組み合わせることで、エンタープライズグレードのReactアプリケーション開発が可能になります。
