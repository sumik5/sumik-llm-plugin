# フレームワーク統合とモジュールシステム

> TypeScriptのフレームワーク統合、モジュール管理、宣言マージの実践パターン

## 目次

1. [フロントエンドフレームワークの型安全性](#1-フロントエンドフレームワークの型安全性)
2. [型安全なAPI設計](#2-型安全なapi設計)
3. [モジュールシステムの変遷](#3-モジュールシステムの変遷)
4. [インポート・エクスポート](#4-インポートエクスポート)
5. [名前空間](#5-名前空間)
6. [宣言のマージ](#6-宣言のマージ)

---

## 1. フロントエンドフレームワークの型安全性

### React/TSXの型安全性

**関数コンポーネント**

```typescript
import React from 'react'

type Props = {
  isDisabled?: boolean
  size: 'Big' | 'Small'
  text: string
  onClick(event: React.MouseEvent<HTMLButtonElement>): void
}

export function FancyButton(props: Props) {
  const [toggled, setToggled] = React.useState(false)

  return <button
    className={'Size-' + props.size}
    disabled={props.isDisabled || false}
    onClick={event => {
      setToggled(!toggled)
      props.onClick(event)
    }}
  >{props.text}</button>
}

// 使用例 - TypeScriptが型チェック
<FancyButton
  size='Big'
  text='Sign Up Now'
  onClick={() => console.log('Clicked!')}
/>
```

**クラスコンポーネント**

```typescript
type Props = {
  firstName: string
  userId: string
}

type State = {
  isLoading: boolean
}

class SignupForm extends React.Component<Props, State> {
  state = {
    isLoading: false
  }

  render() {
    return <>
      <h2>Sign up, {this.props.firstName}</h2>
      <FancyButton
        isDisabled={this.state.isLoading}
        size='Big'
        text='Sign Up Now'
        onClick={this.signUp}
      />
    </>
  }

  private signUp = async () => {
    this.setState({isLoading: true})
    try {
      await fetch('/api/signup?userId=' + this.props.userId)
    } finally {
      this.setState({isLoading: false})
    }
  }
}
```

### Angularの依存性注入

```typescript
import {Component, OnInit} from '@angular/core'
import {MessageService} from '../services/message.service'

@Component({
  selector: 'simple-message',
  templateUrl: './simple-message.component.html',
  styleUrls: ['./simple-message.component.css']
})
export class SimpleMessageComponent implements OnInit {
  message?: string

  constructor(
    private messageService: MessageService
  ) {}

  ngOnInit() {
    this.messageService.getMessage().subscribe(response =>
      this.message = response.message
    )
  }
}

// サービス定義
@Injectable({
  providedIn: 'root'
})
export class MessageService {
  constructor(private http: HttpClient) {}

  getMessage() {
    return this.http.get('/api/message')
  }
}
```

---

## 2. 型安全なAPI設計

### REST APIの型安全化（Swagger/OpenAPI）

```typescript
// 共通スキーマから生成されたクライアント
type Request =
  | {entity: 'user', data: User}
  | {entity: 'location', data: Location}

async function get<R extends Request>(
  entity: R['entity']
): Promise<R['data']> {
  const res = await fetch(`/api/${entity}`)
  const json = await res.json()
  if (!json) {
    throw ReferenceError('Empty response')
  }
  return json
}

// 使用例
async function startApp() {
  const user = await get('user')  // User型に推論される
}
```

### TypeORMによるバックエンド型安全性

```typescript
// 生SQL（型安全でない）
const client = new Client()
const res = await client.query(
  'SELECT name FROM users where id = $1',
  [739311]
) // any

// TypeORM（型安全）
const user = await UserRepository
  .findOne({id: 739311})  // User | undefined
```

---

## 3. モジュールシステムの変遷

### 歴史的経緯

**1. グローバル名前空間（1995-2004）**

```javascript
window.emailListModule = {
  renderList() {}
}

window.appModule = {
  renderApp() {
    window.emailListModule.renderList()
  }
}
```

**2. CommonJS（2009-）**

```javascript
// emailBaseModule.js
const emailList = require('emailListModule')

module.exports.renderBase = function() {
  // ...
}
```

**3. AMD（2008-）**

```javascript
define('emailBaseModule',
  ['require', 'exports', 'emailListModule'],
  function(require, exports, emailListModule) {
    exports.renderBase = function() {
      // ...
    }
  }
)
```

**4. ES2015モジュール（現在）**

```typescript
// emailBaseModule.js
import emailList from 'emailListModule'

export function renderBase() {
  // ...
}
```

---

## 4. インポート・エクスポート

### 基本的なインポート・エクスポート

```typescript
// a.ts
export function foo() {}
export function bar() {}

// b.ts
import {foo, bar} from './a'
foo()
export const result = bar()
```

### デフォルトエクスポート

```typescript
// c.ts
export default function meow(loudness: number) {}

// d.ts
import meow from './c'  // 波括弧なし
meow(11)
```

### ワイルドカードインポート

```typescript
// e.ts
import * as a from './a'
a.foo()
a.bar()
```

### 再エクスポート

```typescript
// f.ts
export * from './a'
export {result} from './b'
export meow from './c'
```

### 型と値の同時エクスポート

```typescript
// g.ts
export let X = 3
export type X = {y: string}

// h.ts
import {X} from './g'

const a = X + 1         // Xは値（3）
const b: X = {y: 'z'}   // Xは型
```

### 動的インポート

```typescript
// 型安全な動的インポート
import {locale} from './locales/locale-us'

async function main() {
  const userLocale = await getUserLocale()
  const path = `./locales/locale-${userLocale}`
  const localeUS: typeof locale = await import(path)
}

// コード分割
const Component = React.lazy(() => import('./HeavyComponent'))
```

### CommonJS/AMDとの相互運用

```typescript
// デフォルト設定
import * as fs from 'fs'
fs.readFile('file.txt')

// esModuleInterop: true
import fs from 'fs'
fs.readFile('file.txt')
```

### モジュールモード vs スクリプトモード

**モジュールモード**: `import`/`export`を含むファイル

- 明示的な依存関係
- ファイル間の分離
- 推奨される標準的な方法

**スクリプトモード**: `import`/`export`なし

- グローバルスコープ
- UMDモジュールの直接利用
- プロトタイピング・型宣言のみ

---

## 5. 名前空間

### 基本構文

```typescript
// Get.ts
namespace Network {
  export function get<T>(url: string): Promise<T> {
    // ...
  }
}

// App.ts
namespace App {
  Network.get<GitRepo>('https://api.github.com/repos/Microsoft/typescript')
}
```

### ネストされた名前空間

```typescript
namespace Network {
  export namespace HTTP {
    export function get<T>(url: string): Promise<T> {
      // ...
    }
  }

  export namespace TCP {
    export function listenOn(port: number): Connection {
      // ...
    }
  }

  export namespace UDP {
    // ...
  }
}

// 使用例
Network.HTTP.get('http://url.com')
Network.TCP.listenOn(8080)
```

### 名前空間のマージ

```typescript
// HTTP.ts
namespace Network {
  export namespace HTTP {
    export function get<T>(url: string): Promise<T> {
      // ...
    }
  }
}

// UDP.ts
namespace Network {
  export namespace UDP {
    export function send(url: string, packets: Buffer): Promise<void> {
      // ...
    }
  }
}

// MyApp.ts - 自動的にマージされる
Network.HTTP.get<Dog[]>('http://url.com/dogs')
Network.UDP.send('http://url.com/cats', new Buffer(123))
```

### 名前空間エイリアス

```typescript
namespace A {
  export namespace B {
    export namespace C {
      export let d = 3
    }
  }
}

// エイリアス
import d = A.B.C.d
const e = d * 3
```

### 名前空間 vs モジュール

**名前空間を使うべき場合:**
- ブラウザのグローバルスクリプト
- レガシーコードとの互換性

**モジュールを使うべき場合（推奨）:**
- 明示的な依存関係
- コード分割・デッドコード除去
- Node.js/モダンブラウザ環境
- 中〜大規模プロジェクト

---

## 6. 宣言のマージ

### マージ可能な組み合わせ

| マージ元 ↓ / マージ先 → | 値 | クラス | 列挙型 | 関数 | 型エイリアス | インターフェース | 名前空間 |
|---|---|---|---|---|---|---|---|
| **値** | × | × | × | × | ○ | ○ | × |
| **クラス** | - | × | × | × | × | ○ | ○ |
| **列挙型** | - | - | ○ | × | × | × | ○ |
| **関数** | - | - | - | × | ○ | ○ | ○ |
| **型エイリアス** | - | - | - | - | × | × | ○ |
| **インターフェース** | - | - | - | - | - | ○ | ○ |
| **名前空間** | - | - | - | - | - | - | ○ |

### コンパニオンオブジェクトパターン

```typescript
// 値と型の同時宣言
type Currency = {
  unit: 'EUR' | 'GBP' | 'JPY' | 'USD'
  value: number
}

const Currency = {
  from(value: number, unit: Currency['unit']): Currency {
    return {unit, value}
  }
}

// 使用例
const amount: Currency = Currency.from(100, 'USD')
```

### インターフェースと名前空間のマージ

```typescript
interface User {
  name: string
}

namespace User {
  export function create(name: string): User {
    return {name}
  }
}

// 使用例
const user: User = User.create('Alice')
```

### 列挙型への静的メソッド追加

```typescript
enum Color {
  Red,
  Green,
  Blue
}

namespace Color {
  export function toHex(color: Color): string {
    switch (color) {
      case Color.Red: return '#FF0000'
      case Color.Green: return '#00FF00'
      case Color.Blue: return '#0000FF'
    }
  }
}

// 使用例
Color.toHex(Color.Red)  // '#FF0000'
```

### モジュール拡張

```typescript
// サードパーティモジュールの拡張
declare module 'some-library' {
  export interface Config {
    customOption?: boolean
  }
}

// 使用可能に
import {Config} from 'some-library'
const config: Config = {
  customOption: true
}
```

---

## まとめ

**フレームワーク統合:**
- React/Angular: コンポーネントPropsと依存性注入の型安全性
- TypeORM: データベースアクセスの型安全化
- Swagger/gRPC: API層の型安全性

**モジュールシステム:**
- ES2015モジュールを優先使用
- 動的インポートでコード分割
- CommonJS/AMDとの相互運用性

**名前空間:**
- ファイルシステムからの抽象化
- レガシーコード互換性
- モジュールが利用可能なら避ける

**宣言のマージ:**
- コンパニオンオブジェクト（値+型）
- 列挙型への静的メソッド
- サードパーティモジュール拡張
