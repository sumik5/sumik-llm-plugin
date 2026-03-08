# React × Clean Architecture

## 概要

Clean Architecture をフロントエンド（SPA/React）に適用するための実践ガイド。Clean Architectureの核心原則（依存性ルール・同心円モデル）を維持しながら、React・Redux・TypeScript の文化に合わせて適用する方法を解説する。

**基本的なCAの概念（同心円モデル・依存性ルール・コンポーネント原則）は `applying-clean-architecture` を参照すること。**

---

## DI（Dependency Injection）

### なぜDIが必要か

Clean Architecture の依存性ルール（「外から内にしか依存してはいけない」）を守るためには、処理の流れと依存関係の方向を逆転させる必要がある。

**典型的な問題パターン:**

```typescript
// ❌ 安定コードが不安定コードに依存（DIP違反）
import Database from './database';

class User {
  constructor(private database: Database) {}
  save() {
    this.database.save(this);
  }
}
```

この実装では `User`（安定・内側）が `Database`（不安定・外側）に依存してしまい、依存性ルールに違反する。

### DI の基本パターン（ライブラリ不使用）

依存関係を逆転させる手順:

1. 内側（安定コード）にインターフェースを定義する
2. 外側（不安定コード）がそのインターフェースを実装する
3. 利用側コードがインターフェースを実装したインスタンスを注入する

```typescript
// ✅ user.ts（内側）にインターフェースを定義
export interface DatabaseInterface {
  save: (user: User) => void;
}

export class User {
  constructor(private database: DatabaseInterface) {}
  save() {
    this.database.save(this);
  }
}

// database.ts（外側）がインターフェースを実装
import User, { DatabaseInterface } from './user';

export class Database implements DatabaseInterface {
  save(user: User) {
    console.log(`${user.name} を保存しました`);
  }
}

// main.ts（最外側）でインスタンスを注入
const user = new User(new Database());
```

**問題点**: 複数箇所で `User` を利用する場合、それぞれの場所で `Database` の具象コードへの依存が分散してしまう。解決策は **DI コンテナ**（依存対象の対応表を保持するオブジェクト）の導入。

### TSyringe（DI ライブラリ）

Microsoft 主導で開発された TypeScript 向け DI ライブラリ。Decorators + Reflect metadata を活用して、依存関係の解決を自動化する。

#### セットアップ

```bash
npm install tsyringe reflect-metadata
```

```json
// tsconfig.json
{
  "compilerOptions": {
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  }
}
```

```typescript
// main.ts（エントリーポイントの先頭で1回だけimport）
import 'reflect-metadata';
```

#### 基本的な使い方

```typescript
// インターフェース定義
export interface UserApiInterface {
  fetchUser: (args: { id: number }) => User;
}

// 実装クラス
import { injectable } from 'tsyringe';
@injectable()
export class UserApiImpl implements UserApiInterface {
  fetchUser({ id }: { id: number }): User {
    return { id, name: `User ${id}` };
  }
}

// 注入対象クラス
import { injectable, inject } from 'tsyringe';
@injectable()
export class UserApi {
  constructor(
    @inject('UserApiInterface') private api: UserApiInterface
  ) {}
  fetchUser(args: { id: number }) {
    return this.api.fetchUser(args);
  }
}

// main.ts: DI コンテナで対応関係を登録
import { container } from 'tsyringe';
container.register('UserApiInterface', { useClass: UserApiImpl });
const userApi = container.resolve(UserApi);
```

`container.register()` で登録した依存関係を `container.resolve()` 解決時に自動注入する。具象コードへの依存を **メインコンポーネント（最外側）** に集約できる。

---

## SPA × 同心円図

### SPAにおけるCAレイヤーのマッピング

Clean Architecture における UI（View）は同心円の最外側に位置する。SPA においてもこの原則が適用できるが、プロダクト全体の同心円図と SPA 内部の同心円図を分けて考える必要がある。

| ケース | 説明 |
|-------|------|
| **SPA + マネージドサービス** | SPA が直接 Firebase 等と通信する場合、ビジネスロジックはすべて SPA 側に実装される。プロダクト全体とSPA内部の同心円図は一致する |
| **SPA + API サーバー** | API サーバーがビジネスロジックを保有し、SPA はデータ表示に特化する。プロダクト全体ではSPAは外側だが、**SPA内部に再帰的に同心円構造を適用できる** |

CAの構造を再帰的に適用することで、**SPA同心円図（SPA中心の独立した同心円図）** を定義できる。

### エンティティ ↔ ビューモデルの分離

- **エンティティ（プロダクトレベル）**: 企業・プロダクトのビジネスルールを表現。API サーバー側で管理する
- **ビューモデル（SPA同心円図の中心）**: エンティティを表示用に変換したデータ構造。SPAの中心に配置し、変更から守る

SPA同心円図では、ビューモデルがエンティティに相当する役割を担う。エンティティをそのまま View に渡さず、表示専用のビューモデルに変換することで、API レスポンスの変更から View を守る。

### ユースケースのSPA実装

ユースケースはビューモデルをコントロールしながら表示に必要な処理を行う層。Redux・Flux などの状態管理フレームワークと守備範囲が重複するため、両者の関係を整理して適用する必要がある。

---

## Redux × Clean Architecture

### Redux 同心楕円図

Redux の構成要素を依存関係で整理すると、以下の関係が導かれる:

| 要素 | 依存先 | 位置 |
|------|-------|------|
| View | ActionCreator, State | 最外側（変更が多い） |
| ActionCreator | Action | 外側 |
| Reducer | Action, State | 中間 |
| **Action** | 無依存 | **中心（安定）** |
| **State** | 無依存 | **中心（安定）** |

Action と State がともに無依存なため、同心円の「中心が2点」になる（楕円に近い構造）。Redux は **State と Action を中心とした構造** として捉え直せる。

### Redux と SOLID

**OCP（開放閉鎖）の観点:**
- State は他要素に依存しないため、新機能追加時に他要素に影響を与えない → 拡張に開いている
- ただし State が他要素から依存されるため、修正時の影響範囲に注意が必要

**View の保護:**
- View はどの要素からも依存されないため、変更が他レイヤーに波及しない
- View同士は `import` 依存以外に、State を介した **暗黙的な依存関係** が存在する → TypeScriptの型チェックで防御

### hooks API による State 接続の改善

Redux に hooks API（v7.1.0+）が導入されたことで、各コンポーネントが State と直接接続できるようになった。

**以前のパターン（hooks 以前）:**

```
上位コンポーネント（State接続）
 ↓ Props経由でバケツリレー
下位コンポーネント（State非接続）
```

バケツリレーによりコンポーネント間の依存が強くなっていた。

**hooks API 導入後:**

```typescript
// 各コンポーネントが直接 State に接続可能
const MyComponent: React.FC = () => {
  const value = useSelector((state: RootState) => state.something);
  const dispatch = useDispatch();
  // ...
};
```

コンポーネント間の依存関係が弱まり、Clean Architecture の観点からクリーンな構成が実現しやすくなった。

---

## CSS依存関係の逆転

### コンポーネント同心円図

React コンポーネントの構成要素を依存関係で整理した「コンポーネント同心円図」:

```
外側（不安定）
   CSS
    ↓ 依存
  Renderer（ReactElement）
    ↓ 依存
 View Logic（State/Propsから表示データ生成）
    ↓ 依存
State / Props（独立・無依存）
内側（安定）
```

一般的な実装では Renderer が CSS に依存するが、Clean Architecture の観点では **CSS を Renderer に依存させる**（方向を逆転する）ことが望ましい。

### CSS依存逆転の3段階設計

#### 段階1: スタイルを同じファイルに記述（最もシンプル）

コンポーネントとスタイルを同一ファイルに記述。アプリケーション固有の小規模コンポーネントに適している。

```typescript
import styled from 'styled-components';

const Text = styled.div`text-decoration: underline;`;

const SampleComponent: React.FC = () => (
  <Text>This is sample text</Text>
);
```

#### 段階2: スタイルを別ファイルに分離

スタイルファイルを分離し、複数のスタイルを切り替えやすくする。ただし、コンポーネントファイルがスタイルファイルに依存する状態は維持される。

```
src/components/SampleCss/
├── index.tsx      ← スタイルをimport・適用
├── styles1.ts     ← スタイル定義1
└── styles2.ts     ← スタイル定義2
```

```typescript
// index.tsx
export interface Styles {
  Text: StyledComponent<'div', any>;
}

// styles1.ts が Styles インターフェースを実装
import * as S from './styles1';
const { Text }: Styles = S;
```

#### 段階3: スタイルを注入する層を分離（完全分離）

依存関係を完全に逆転させる設計。`injectStyle` 関数でスタイルを DI する。

```
src/components/SampleCss/
├── index.ts          ← スタイルとコンポーネントを結合（メインコンポーネント相当）
├── component.tsx     ← Stylesインターフェースのみに依存
├── styles1.ts
└── styles2.ts
```

```typescript
// component.tsx: スタイル詳細を知らない
export interface Styles {
  Text: StyledComponent<'div', any>;
}
export const injectStyle = (styles: Styles) => {
  const { Text } = styles;
  const Component: React.FC = () => (
    <Text>This is a sample text</Text>
  );
  return Component;
};

// index.ts: スタイルを注入する層（最外側）
import * as S from './styles1';
import { injectStyle } from './component';
const SampleCss = injectStyle(S);
export default SampleCss;
```

**設計の選択基準:**

| 設計 | 適するケース |
|------|------------|
| 段階1（同一ファイル） | アプリ固有コンポーネント、小規模 |
| 段階2（ファイル分離） | スタイルを切り替えたい、中規模 |
| 段階3（層分離） | 再利用性を最大化したい、デザインシステム構築 |

---

## Reactコンポーネント設計

### Hooks API と CA 原則の統合

Hooks API の最大の価値は **ロジックをコンポーネントから分離できる** 点にある。

**ロジック分離による利点（CA観点）:**
- Hook 関数はコンポーネントに依存しないため、再利用可能
- 共通ロジックを持つ親コンポーネントが不要になり、コンポーネント間の依存関係が弱まる
- High Order Component（HOC）より柔軟にロジックを抽出・再利用できる

**Hook 関数設計時の注意点:**

```typescript
// ❌ 特定コンポーネントAの型に依存するHook → 再利用不可
function useFeature(props: ComponentAProps) { ... }

// ✅ 汎用型・独立した型に依存するHook → 再利用可能
function useFeature(id: string, options: FeatureOptions) { ... }
```

Hook 関数が特定のコンポーネントに依存すると、他のコンポーネントから利用する際に不要な依存関係が生まれてしまう。

### コンポーネント連携の原則

React のコンポーネント構成（親から子への依存）は Clean Architecture の依存性ルールには厳密には違反するが、以下の理由から実用的な設計として成立する:

- 各コンポーネントは関数として独立しており、内部状態を持たないよう設計できる
- Props による型定義で入出力が明確にコントロールされる
- コンポーネントの独立性を高めることで、上流→下流への依存を弱くできる

**コンポーネント間の依存を弱くする実践:**

| 問題 | 解決策 |
|------|-------|
| Props のバケツリレー | Redux/Zustand + hooks API で各コンポーネントが State に直接接続 |
| 共通ロジックの重複 | カスタム Hook に抽出して各コンポーネントで再利用 |
| CSS の密結合 | `injectStyle` パターンで依存を逆転 |
| ViewModel の欠如 | API レスポンスをそのまま使わず、表示用 ViewModel に変換する |

### Reactとクリーンアーキテクチャのバランス

React 開発の文化・慣習に沿った設計をすることが重要。Clean Architecture を忠実に守りすぎると:
- React のバージョンアップの影響を受けやすくなる
- 他の開発者がキャッチアップしにくくなる
- 小規模コンポーネントで冗長な設計になる

**現実的なアプローチ**: React の慣習を踏まえながら、Clean Architecture の原則を **選択的に** 取り入れる。

---

## 相互参照

| スキル | 関係 |
|--------|------|
| **`applying-clean-architecture`** | CA一般原則（依存性ルール・同心円モデル・コンポーネント原則・Humble Objects等）。本ドキュメントはReact固有の適用に特化 |
| **`writing-clean-code`** | コードレベルのSOLID原則・クリーンコード。本ドキュメントはアーキテクチャレベルのCA適用に特化 |
| **`applying-domain-driven-design`** | DDD戦術パターン（Entity・Repository等）。CAのエンティティ層設計で活用 |
