# TypeScript固有エラーパターン

> PT-CH07-ERROR-HANDLING.md（エラー処理戦略の比較）との重複を除いた、TypeScript特有のエラー分類・非同期エラー・デバッグ活用パターン

---

## 1. TypeScript固有エラー型分類

TSの型システムにより、エラーは発生タイミングで明確に4分類できる。

| エラー種別 | 発生タイミング | 検出方法 | TypeScript固有? |
|-----------|--------------|---------|----------------|
| **Syntax Error** | コンパイル前 | エディタ赤線・`tsc` エラー | 一般的（全言語共通） |
| **Type Error** | コンパイル時 | TSC静的解析 | ✅ TS固有 |
| **Runtime Error** | 実行時 | コンソールエラー | 一般的（JS共通） |
| **Logical Error** | 実行時（サイレント） | テスト・デバッグ | 一般的（全言語共通） |

### Type Error の主要パターン

```typescript
// 1. 型の非互換
let num: number = 42;
num = "Hello"; // Error: Type 'string' is not assignable to type 'number'

// 2. 存在しないメソッドの呼び出し
let user: string = "John";
user.push("Doe"); // Error: Property 'push' does not exist on type 'string'

// 3. null/undefined アクセス（strict mode必須）
function fetchUser(): User | null { /* ... */ }
const user = fetchUser();
console.log(user.firstName); // Error: Object is possibly 'null'

// 修正: null チェック or optional chaining
if (user) { console.log(user.firstName); }
console.log(user?.firstName);
```

### Runtime Error の根本原因

TypeScriptは静的解析で多くを防ぐが、以下は防げない：
- `any` や型アサーション（`as`）でのバイパス
- 外部APIレスポンスの実際の型不一致
- サードパーティライブラリの予期しない戻り値

```typescript
function greet(user: User) {
  console.log(user.name.toUpperCase());
}
greet(undefined as any); // コンパイルは通るが実行時クラッシュ
```

**対策**: 境界値（外部入力・API）は必ず実行時バリデーションを追加。

---

## 2. catch ブロックの unknown 型

TypeScript の catch ブロックは `error: unknown` となる。これは TS 固有の重要な設計。

```typescript
// ❌ 危険: error.message に直接アクセス
try {
  // ...
} catch (error) {
  console.error(error.message); // error は unknown
}

// ✅ 安全: instanceof で型を絞り込む
try {
  // ...
} catch (error: unknown) {
  if (error instanceof Error) {
    console.error("Error:", error.message);
  } else {
    console.error("Unknown error:", error);
  }
}
```

**理由**: JS では何でもスローできる（文字列・数値・オブジェクト）。サードパーティライブラリは `Error` 以外をスローする場合がある。

---

## 3. 非同期エラーハンドリングパターン

### Promise チェーン

```typescript
function fetchData(url: string): Promise<void> {
  return fetch(url)
    .then(response => {
      if (!response.ok) {
        throw new Error("Network response was not ok");
      }
      return response.json();
    })
    .then(data => {
      console.log("Data:", data);
    })
    .catch(error => {
      console.error("Error:", error.message);
    })
    .finally(() => {
      // 成否に関わらず実行（リソース解放等）
      console.log("Fetch completed.");
    });
}
```

### async/await + try-catch（推奨）

```typescript
async function fetchData(url: string): Promise<void> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error("Network response was not ok");
    }
    const data = await response.json();
    console.log("Data:", data);
  } catch (error: unknown) {
    if (error instanceof Error) {
      console.error("Error:", error.message);
    }
  } finally {
    console.log("Fetch completed.");
  }
}
```

### Promise vs async/await の選択基準

| 観点 | Promise チェーン | async/await |
|-----|----------------|-------------|
| 可読性 | 複数操作の連鎖に向く | 同期コードに近く直感的 |
| エラー処理 | `.catch()` でチェーン末尾に集約 | `try-catch` で馴染み深い |
| デバッグ | スタックトレースが追いにくい | ソースマップ連携でしやすい |
| 推奨場面 | 既存Promiseベースのコード | 新規コード・複雑なフロー |

### 非同期エラーハンドリングのベストプラクティス

- **必ずエラーハンドリングを付ける**: `.catch()` または `try-catch` を省略しない
- **finally でクリーンアップ**: DB接続・ファイルハンドル等の解放
- **タイムアウトとリトライ**: ネットワーク障害に備える
- **中央集権的なエラーログ**: Sentry/Datadog 等のモニタリングサービスと連携

---

## 4. デバッグツール活用

### Source Maps 設定

TypeScriptはJSにコンパイルされるが、source mapsで元のTSコードをデバッグできる。

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES6",
    "module": "commonjs",
    "outDir": "./dist",
    "sourceMap": true   // ← これで .js.map が生成される
  }
}
```

コンパイル後、`dist/` に `.js` と `.js.map` が生成される。ブレークポイントはTS元ファイルで設定できる。

### VS Code デバッガー設定

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Launch Program",
      "skipFiles": ["<node_internals>/**"],
      "program": "${workspaceFolder}/dist/index.js",
      "outFiles": ["${workspaceFolder}/**/*.js"]
    }
  ]
}
```

| ショートカット | 動作 |
|-------------|------|
| F5 | デバッグ開始 / 次のブレークポイントまで継続 |
| F10 | Step Over（次の行へ） |
| F11 | Step Into（関数内へ） |
| Shift+F11 | Step Out（関数から抜ける） |

### ブレークポイントの種類

| 種別 | 用途 | 設定方法 |
|-----|------|---------|
| **Line Breakpoint** | 指定行で一時停止 | 行番号左をクリック |
| **Conditional Breakpoint** | 条件が真の時のみ停止（例: `count > 10`） | 右クリック → Add Conditional |
| **Logpoint** | 停止せずにログ出力（例: `Value: {message}`） | 右クリック → Add Logpoint |

### Console メソッド使い分け

```typescript
console.log("通常のデバッグ出力");
console.error("エラー情報（赤表示）");
console.warn("警告（黄色表示）");
console.table([{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }]); // テーブル形式
```

**本番環境での注意**: `console.log` はデプロイ前に削除またはログレベルで制御する。機密情報が漏洩するリスクがある。
