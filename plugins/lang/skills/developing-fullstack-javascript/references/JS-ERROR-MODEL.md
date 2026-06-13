# JS-ERROR-MODEL — JavaScript エラーモデル

JavaScript のエラーシステムは仕様・エンジン・ランタイムの三層で構成され、思いのほか複雑。
本 reference は JS/Node.js ランタイム視点のエラー機構に特化する（TypeScript 型設計は別 reference 担当）。

---

## 目次

1. [エラーの二面性](#1-エラーの二面性)
2. [エラーオブジェクトの構造](#2-エラーオブジェクトの構造)
3. [Node.js エラー体系](#3-nodejs-エラー体系)
4. [error stack の構造とコスト](#4-error-stack-の構造とコスト)
5. [カスタムエラーの作り方](#5-カスタムエラーの作り方)
6. [エラー伝播と制御フロー設計](#6-エラー伝播と制御フロー設計)

---

## 1. エラーの二面性

エラーには根本的に対立する2つの目的がある。

| 用途 | 必要な情報 | 情報のコスト |
|------|-----------|------------|
| **リカバリー** | 失敗カテゴリ・再試行可否・フォールバック有無 | 低い（少量で十分） |
| **デバッグ** | スタックトレース・行番号・詳細コンテキスト | 高い（CPU/メモリを消費） |

```js
// リカバリー側が必要な情報（最小限）
const forRecovery = { type: 'NETWORK_ERROR', retryable: true, fallbackAvailable: true };

// デバッグ側が必要な情報（詳細）
const forDebug = {
  message: 'Connection to database timed out after 5000ms',
  stack: 'at connectDB (db.js:42:15)\n  at initialize (app.js:12:8)',
  timestamp: new Date().toISOString(),
  context: { userId: 1234, operation: 'user_fetch' }
};
```

**重要な認識**: 言語仕様が定義するのは `message` と `name` の2プロパティのみ。スタックトレース・エラーコードはエンジンとランタイムの独自実装であり、仕様外の動作。

---

## 2. エラーオブジェクトの構造

### 2.1 何でも throw できる

JavaScript では任意の値を throw できるが、エコシステムは `Error` オブジェクトに統一された。

```js
throw new Error("Error object");   // ✅ 推奨: スタックトレース付き
throw "just a string";             // ❌ 非推奨: .message/.stack がない
throw 42;                          // ❌ 非推奨
throw { custom: "object" };        // ❌ 非推奨
```

catch 側では常に `instanceof Error` を確認すること。

```js
try {
  someFunction();
} catch (e) {
  if (!(e instanceof Error)) {
    // 文字列・数値など非 Error 値が throw された場合
    throw new Error(String(e));
  }
  console.log(e.message);  // 安全
  console.log(e.stack);    // 安全（V8/Node.js では存在する）
}
```

### 2.2 ネイティブエラー型

仕様が定義する9種のエラーコンストラクタ。最初の7つは構造が同一で `name` プロパティだけが異なる。

| 型 | 用途 | リカバリー用途 |
|----|------|--------------|
| `Error` | 基底クラス | — |
| `TypeError` | 型の不一致 | なし（コードのバグ） |
| `ReferenceError` | 未定義変数アクセス | なし（コードのバグ） |
| `SyntaxError` | 構文違反 | なし（コードのバグ） |
| `RangeError` | 数値範囲外 | なし（コードのバグ） |
| `URIError` | URI エンコードエラー | なし |
| `EvalError` | 非推奨・現代では throw されない | — |
| `AggregateError` | 複数エラーのコンテナ | 各エラーを個別確認可 |
| `SuppressedError` | クリーンアップ失敗の保存 | 両エラーを個別確認可 |

**設計上の欠陥**: `TypeError` と `ReferenceError` はどちらも「コードが壊れている」ことしか伝えない。再試行すべきか・フォールバックすべきかの判断には使えない。

### 2.3 モダンエラー型

#### AggregateError（ES2021）

`Promise.any()` が全 Promise を reject した際、すべての失敗を1つにまとめる。

```js
try {
  const result = await Promise.any([
    fetch('/api/primary'),
    fetch('/api/backup1'),
    fetch('/api/backup2')
  ]);
} catch (e) {
  // e は AggregateError
  e.errors.forEach((err, i) => console.log(`Attempt ${i}: ${err.message}`));
}
```

#### SuppressedError（ES2024）

`using` キーワードのリソース管理中、クリーンアップが別エラーを throw した場合に両エラーを保存する。

```js
class DatabaseConnection {
  [Symbol.dispose]() {
    throw new Error('Failed to close connection');
  }
}

try {
  using connection = new DatabaseConnection();
  throw new Error('Things went badly');
} catch (err) {
  // err は SuppressedError
  console.log(err.error);      // 元のエラー: 'Things went badly'
  console.log(err.suppressed); // クリーンアップエラー: 'Failed to close connection'
}
```

#### DOMException（Web 標準）

JavaScript 仕様外。W3C が DOM 仕様で定義したセマンティックエラー体系で、**リカバリーに実用的な型名**を持つ。

| 型名 | 意味 | リカバリー指針 |
|------|------|--------------|
| `NetworkError` | ネットワーク失敗 | 再試行 |
| `AbortError` | 操作がキャンセルされた | 再開 |
| `TimeoutError` | 制限時間超過 | 待機後再試行 |
| `QuotaExceededError` | ストレージ上限 | データ削除後再試行 |
| `SecurityError` | セキュリティポリシー違反 | フォールバック |
| `NotAllowedError` | ユーザーが権限を拒否 | UI で案内 |
| `InvalidStateError` | オブジェクトの状態が不正 | 状態リセット後再試行 |
| `DataCloneError` | 値をクローンできない | データ変換後再試行 |

### 2.4 cause チェーン（ES2022）

境界をまたぐ際に元エラーを保存しながら公開用エラーを生成する標準的なパターン。

```js
function processPayment(args) {
  try {
    return thirdParty.authorize(args);
  } catch (paymentError) {
    // 内部詳細（APIキー等）を外部に露出させず、デバッグ情報は保存
    throw new Error('Payment authorization failed', {
      cause: {
        name: paymentError.name,
        message: paymentError.message
      }
    });
  }
}

try {
  processPayment(args);
} catch (err) {
  console.log(err.cause);  // 元エラーの情報にアクセス可能
}
```

---

## 3. Node.js エラー体系

Node.js はエラーコードで**機械が読む情報**と**人間が読む情報**を分離した。

```js
try {
  await someFileOperation();
} catch (e) {
  switch (e.code) {
    case 'ENOENT':
      // ファイル未発見 → 作成する
      break;
    case 'EACCES':
      // 権限エラー → 致命的、再 throw
      throw e;
    case 'EMFILE':
      // オープンファイル上限 → 待機後リトライ
      await delay(100);
      return retry();
  }
}
```

### エラーコードの分類

| プレフィックス | 種類 | 例 |
|--------------|------|-----|
| `ENOENT`, `EACCES`, `EMFILE` | システムエラー（OS 層） | ファイル・ネットワーク操作 |
| `ERR_ASSERTION` | アサーションエラー | `assert` モジュール |
| `ERR_INVALID_ARG_TYPE` | 引数型エラー | API 引数の型不一致 |
| `ERR_OUT_OF_RANGE` | 範囲外エラー | 数値・インデックスの境界違反 |

**設計原則**: `e.code` は機械用（リカバリー判断）、`e.message` は人間用（デバッグ）。`e.message` に依存した条件分岐はメッセージ変更で壊れるアンチパターン。

---

## 4. error stack の構造とコスト

### 4.1 スタックトレースの仕組み

スタックトレースはエンジンが独自に実装したデバッグ用機能（仕様外）。`Error` 生成時にコールスタックのフレーム情報を収集し、`stack` プロパティへの初回アクセス時に文字列へシリアライズする（遅延評価）。

```js
function inner() { throw new Error("Problem here"); }
function middle() { return inner(); }
function outer() { return middle(); }

try {
  outer();
} catch (e) {
  console.log(e.stack);
  // Error: Problem here
  //     at inner (file.js:1:22)
  //     at middle (file.js:2:22)
  //     at outer (file.js:3:22)
}
```

**コストの2段階**:
1. **キャプチャ**（`new Error()` 時）: エンジンがフレーム情報を収集。`stack` を読まなくても発生する
2. **シリアライズ**（`e.stack` 初回アクセス時）: フレーム情報を文字列に変換。一度変換すると内部構造を解放

### 4.2 コスト管理

1つの `Error` オブジェクトは数KB のメモリを消費する。高スループット環境（秒間数千エラー）では無視できないオーバーヘッドになる。

```js
// V8 非標準 API: キャプチャフレーム数の制限
Error.stackTraceLimit = 10;  // デフォルトは 10（V8）
Error.stackTraceLimit = 5;   // 本番環境ではさらに絞る
Error.stackTraceLimit = 0;   // スタックトレースを一切不要な場合（最大節約）
```

### 4.3 Error.captureStackTrace（V8 固有 API）

カスタムエラークラスのスタックトレースから、ラッパー関数フレームを除外するための V8 固有 API。

```js
class AppError extends Error {
  constructor(message, options) {
    super(message, options);
    this.name = this.constructor.name;

    // スタックトレースの先頭から AppError コンストラクタ自体を除外
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

// 第2引数に指定した関数より上のフレームを除去できる
// → スタックが AppError 呼び出し元から始まり、内部実装が隠れる
```

**使用条件**:
- V8（Node.js / Chrome）専用。他エンジンでは `if (Error.captureStackTrace)` でガード必須
- カスタムエラー基底クラスでの使用が主ユースケース

---

## 5. カスタムエラーの作り方

### 基本パターン

```js
class DatabaseError extends Error {
  constructor(message, { code, table, cause } = {}) {
    super(message, { cause });       // cause チェーンを継承
    this.name = 'DatabaseError';     // name を明示設定（必須）
    this.code = code;                // リカバリー用コード
    this.table = table;              // デバッグ用コンテキスト

    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

// 使用例
try {
  await db.query(sql);
} catch (e) {
  throw new DatabaseError('Query execution failed', {
    code: 'QUERY_TIMEOUT',
    table: 'users',
    cause: e
  });
}

// catch 側
try {
  await updateUserProfile(userId, changes);
} catch (e) {
  if (e instanceof DatabaseError) {
    if (e.code === 'QUERY_TIMEOUT') {
      return retry();
    }
  }
  throw e;  // 想定外エラーは再 throw
}
```

### 判断基準: 組み込み型 vs カスタムクラス

| 状況 | 選択 |
|------|------|
| コードのバグ（引数型違反など） | 組み込み `TypeError` / `RangeError` |
| ドメイン固有の失敗（DB・外部API・認証） | カスタム `Error` サブクラス |
| 複数の並列処理が全失敗 | `AggregateError` |
| リソースクリーンアップが失敗 | `SuppressedError` または `cause` |
| 境界をまたぐラップ | `cause` プロパティで元エラーを保存 |

---

## 6. エラー伝播と制御フロー設計

### 6.1 セマンティック境界でキャッチする

キャッチ位置の選択がリカバリーとデバッグ品質を左右する。

```
個別クエリ（too early）  → リカバリー判断に情報不足
↓
トランザクション境界（✅ best）→ コミット/ロールバック判断ができる
↓
アプリケーション層（too late）→ どの操作が失敗したか不明
```

```js
function updateUserProfile(userId, changes) {
  const tx = db.beginTransaction();
  try {
    tx.query('SELECT * FROM users WHERE id = ?', userId);
    tx.query('UPDATE users SET ... WHERE id = ?', userId, changes);
    tx.query('INSERT INTO audit_log ...', userId, changes);
    tx.commit();
  } catch (e) {
    tx.rollback();                                          // リカバリー決定
    throw new Error('Profile update failed', { cause: e }); // 上位へ伝播
  }
}
```

**セマンティック境界の種類**:
- トランザクション境界（コミット/ロールバック単位）
- API 境界（外部サービス呼び出し）
- ユーザー操作境界（単一ユーザーアクション）
- リソース境界（取得/解放ペア）

### 6.2 finally の罠

`finally` 内の `return` や `throw` は伝播中のエラーを**無言で消す**。

```js
function suppressed() {
  try {
    throw new Error("This disappears");
  } finally {
    return "Success!";          // エラーが消える！
  }
}

function replaced() {
  try {
    throw new Error("This disappears");
  } finally {
    throw new Error("This replaces it");  // 元エラーが上書きされる
  }
}
```

**対策**: `finally` 内は純粋なクリーンアップのみ行い、`return`・`throw` を使わない。クリーンアップが失敗しうる場合は `SuppressedError` またはログのみで対応。

### 6.3 非同期境界問題

`setTimeout` / `process.nextTick` / イベントリスナー内のエラーは `try-catch` では捕捉できない。

```js
function processData(data) {
  setTimeout(() => {
    throw new Error("Processing failed");  // try-catch を抜け出す
  }, 100);
}

try {
  processData(data);
} catch (e) {
  console.log("Never catches it");  // 到達しない
}
```

**理由**: `setTimeout` コールバックが実行される時点で、元の `try-catch` を含むコールスタックはすでに消滅している。エラーは全く別のスタックから throw される。

非同期エラーのデバッグには V8 の async stack traces が部分的に助けになるが、`setTimeout` のような Web API の呼び出しはエンジンが把握できないため、トレースは不完全なまま。

### 6.4 グローバルハンドラー（最終防衛線）

通常のエラー処理を抜け出したエラーをログ・監視するための最終防衛線。主目的は**ロギングと監視**であり、リカバリーロジックを置く場所ではない。

```js
// ブラウザ
window.addEventListener('error', (event) => {
  errorMonitoring.report(event.error);  // 監視サービスに送信
  event.preventDefault();               // デフォルトのコンソール出力を抑制
});

// Node.js
process.on('uncaughtException', (err, origin) => {
  logger.fatal({ err, origin }, 'Uncaught exception');
  // ⚠️ 処理後は process.exit() が推奨（状態が不定のため）
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error({ reason }, 'Unhandled promise rejection');
});
```

**グローバルハンドラーへの到達は設計上の欠陥を示す**。到達が頻発する場合、適切なセマンティック境界でのキャッチが欠けているサイン。

### 6.5 throw を制御フローに使わない

`throw` は例外的状況のみ。`forEach` から早期脱出するために `throw` を使うパターンはアンチパターン。

```js
// ❌ アンチパターン: throw を goto 代わりに使用
function findItem(array, test) {
  try {
    array.forEach((item) => { if (test(item)) throw item; });
  } catch (result) { return result; }
}

// ✅ 正しい実装
function findItem(array, test) {
  for (const item of array) {
    if (test(item)) return item;
  }
  return undefined;
}
```

制御フローには `return` / `break` / `continue` を使う。`throw` / `try` / `catch` はエラー専用。
