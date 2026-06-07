# 非同期プログラミングと並列処理

> TypeScriptにおける非同期処理の型安全な実装パターン

## 目次

1. [イベントループの基礎](#1-イベントループの基礎)
2. [コールバックの型付け](#2-コールバックの型付け)
3. [Promiseの型付け](#3-promiseの型付け)
4. [async/await](#4-asyncawait)
5. [非同期ストリーム](#5-非同期ストリーム)
6. [型安全なマルチスレッディング](#6-型安全なマルチスレッディング)

---

## 1. イベントループの基礎

### JavaScriptの並行モデル

JavaScriptエンジン（V8、SpiderMonkey）は**イベントループ**を使用して、1つのスレッド上でタスクを多重化する。

### 実行順序の例

```typescript
setTimeout(() => console.info('A'), 1)
setTimeout(() => console.info('B'), 2)
console.info('C')

// 出力: C, A, B
```

### イベントループの動作

1. **非同期API呼び出し**: `setTimeout`、`readFile`などがネイティブAPIを呼び出す
2. **即座の制御返却**: 呼び出し後すぐにメインスレッドに制御が戻る
3. **タスクキューイング**: 非同期操作完了時にイベントキューにタスクを追加
4. **タスク実行**: コールスタックが空になるとキューからタスクを実行
5. **ループ**: コールスタックとキューが空になるまで繰り返し

---

## 2. コールバックの型付け

### 基本的なコールバック型

```typescript
// Node.jsスタイルのコールバック
function readFile(
  path: string,
  options: {encoding: string, flag?: string},
  callback: (err: Error | null, data: string | null) => void
): void

// 使用例
readFile('/path/to/file', {encoding: 'utf8'}, (error, data) => {
  if (error) {
    console.error('error reading!', error)
    return
  }
  console.info('success reading!', data)
})
```

### コールバックの限界

**1. 非同期性が型に現れない**

型シグネチャから非同期かどうか判断できない。

**2. コールバックピラミッド**

```typescript
async1((err1, res1) => {
  if (res1) {
    async2(res1, (err2, res2) => {
      if (res2) {
        async3(res2, (err3, res3) => {
          // さらにネスト...
        })
      }
    })
  }
})
```

**3. エラー処理が煩雑**

各コールバックで手動エラーチェックが必要。

---

## 3. Promiseの型付け

### Promise型の設計

```typescript
type Executor<T> = (
  resolve: (result: T) => void,
  reject: (error: unknown) => void
) => void

class Promise<T> {
  constructor(f: Executor<T>) {}

  then<U>(g: (result: T) => Promise<U> | U): Promise<U> {
    // ...
  }

  catch<U>(g: (error: unknown) => Promise<U> | U): Promise<U> {
    // ...
  }
}
```

### Promiseのラッピング

```typescript
// コールバックベースのAPIをPromiseでラップ
import {readFile} from 'fs'

function readFilePromise(path: string): Promise<string> {
  return new Promise((resolve, reject) => {
    readFile(path, (error, result) => {
      if (error) {
        reject(error)
      } else {
        resolve(result)
      }
    })
  })
}
```

### Promiseの連鎖

```typescript
function appendAndReadPromise(path: string, data: string): Promise<string> {
  return appendPromise(path, data)
    .then(() => readPromise(path))
    .catch(error => console.error(error))
}

// コールバック版（比較）
function appendAndRead(
  path: string,
  data: string,
  cb: (error: Error | null, result: string | null) => void
) {
  appendFile(path, data, error => {
    if (error) {
      return cb(error, null)
    }
    readFile(path, (error, result) => {
      if (error) {
        return cb(error, null)
      }
      cb(null, result)
    })
  })
}
```

### Promise.all と Promise.race の型付け

```typescript
// Promise.all: すべてのPromiseの完了を待つ
const results: [User, Location, Settings] = await Promise.all([
  getUser(id),      // Promise<User>
  getLocation(id),  // Promise<Location>
  getSettings(id)   // Promise<Settings>
])

// Promise.race: 最初に完了したPromiseを取得
const fastest: User | Location = await Promise.race([
  getUser(id),
  getLocation(id)
])
```

---

## 4. async/await

### 基本構文

```typescript
// Promise連鎖
function getUser() {
  return getUserID(18)
    .then(user => getLocation(user))
    .then(location => console.info('got location', location))
    .catch(error => console.error(error))
    .finally(() => console.info('done'))
}

// async/await版
async function getUser() {
  try {
    const user = await getUserID(18)
    const location = await getLocation(user)
    console.info('got location', location)
  } catch(error) {
    console.error(error)
  } finally {
    console.info('done')
  }
}
```

### 型推論

```typescript
async function fetchData(): Promise<Data> {
  const response = await fetch('/api/data')  // Promise<Response>
  const json = await response.json()         // Promise<any>
  return json as Data                        // Data
}

// awaitなしで型を明示
function fetchData(): Promise<Data> {
  return fetch('/api/data')
    .then(response => response.json())
    .then(json => json as Data)
}
```

### 並列実行

```typescript
// 逐次実行（遅い）
const user = await getUser(id)
const posts = await getPosts(id)
const comments = await getComments(id)

// 並列実行（速い）
const [user, posts, comments] = await Promise.all([
  getUser(id),
  getPosts(id),
  getComments(id)
])
```

---

## 5. 非同期ストリーム

### EventEmitterの型安全化

```typescript
// イベント定義
type Events = {
  ready: void
  error: Error
  reconnecting: {attempt: number, delay: number}
}

// 型安全なEmitter
type SafeEmitter<E extends Record<string, unknown>> = {
  on<K extends keyof E>(
    event: K,
    f: (arg: E[K]) => void
  ): void

  emit<K extends keyof E>(
    event: K,
    arg: E[K]
  ): void
}

// 使用例
type RedisClient = SafeEmitter<Events>

const client: RedisClient = createClient()
client.on('ready', () => console.log('ready'))  // void
client.on('error', e => console.error(e))       // Error
client.on('reconnecting', params => {           // {attempt, delay}
  console.log(`Attempt ${params.attempt}`)
})
```

### WindowイベントのEmitter型付け

TypeScriptの標準ライブラリはこのパターンを使用：

```typescript
interface WindowEventMap {
  click: MouseEvent
  keydown: KeyboardEvent
  load: Event
}

interface Window {
  addEventListener<K extends keyof WindowEventMap>(
    type: K,
    listener: (event: WindowEventMap[K]) => any
  ): void
}
```

### RxJSとリアクティブプログラミング

```typescript
import {Observable, fromEvent} from 'rxjs'
import {map, filter, debounceTime} from 'rxjs/operators'

// イベントストリームの型安全な操作
const clicks$: Observable<MouseEvent> = fromEvent(button, 'click')

clicks$
  .pipe(
    debounceTime(300),
    map(e => ({x: e.clientX, y: e.clientY})),
    filter(pos => pos.x > 100)
  )
  .subscribe(pos => console.log(pos))
```

---

## 6. 型安全なマルチスレッディング

### Web Worker（ブラウザ）

**メッセージパッシングの型安全化**

```typescript
// コマンド・イベント定義
type Commands = {
  sendMessage: [threadID: number, message: string]
  createThread: [participants: number[]]
}

type Events = {
  receivedMessage: [threadID: number, userID: number, message: string]
  createdThread: [threadID: number, participants: number[]]
}

// 型安全なEmitterラッパー
interface SafeEmitter<Events extends Record<PropertyKey, unknown[]>> {
  emit<K extends keyof Events>(
    channel: K,
    ...data: Events[K]
  ): boolean

  on<K extends keyof Events>(
    channel: K,
    listener: (...data: Events[K]) => void
  ): this
}
```

**WorkerScript側**

```typescript
import {EventEmitter} from 'events'

const commandEmitter: SafeEmitter<Commands> = new EventEmitter()
const eventEmitter: SafeEmitter<Events> = new EventEmitter()

// メインスレッドからのコマンドをリッスン
onmessage = command =>
  commandEmitter.emit(command.data.type, ...command.data.data)

// イベントをメインスレッドに送信
eventEmitter.on('createdThread', data =>
  postMessage({type: 'createdThread', data})
)

// コマンド処理
commandEmitter.on('sendMessage', (threadID, message) => {
  console.log(`Sending message to thread ${threadID}`)
  eventEmitter.emit('receivedMessage', threadID, userId, message)
})
```

**MainThread側**

```typescript
const worker = new Worker('WorkerScript.js')
const commandEmitter: SafeEmitter<Commands> = new EventEmitter()
const eventEmitter: SafeEmitter<Events> = new EventEmitter()

// Workerからのイベントをリッスン
worker.onmessage = event =>
  eventEmitter.emit(event.data.type, ...event.data.data)

// コマンドをWorkerに送信
commandEmitter.on('sendMessage', data =>
  worker.postMessage({type: 'sendMessage', data})
)

// イベント処理
eventEmitter.on('createdThread', (threadID, participants) => {
  console.log('Created thread!', threadID, participants)
})

// コマンド実行
commandEmitter.emit('createThread', [123, 456])
```

### 型安全なプロトコル

**プロトコル定義**

```typescript
type Protocol = {
  [command: string]: {
    in: unknown[]
    out: unknown
  }
}

type MatrixProtocol = {
  determinant: {
    in: [Matrix]
    out: number
  }
  'dot-product': {
    in: [Matrix, Matrix]
    out: Matrix
  }
  invert: {
    in: [Matrix]
    out: Matrix
  }
}
```

**プロトコル実装**

```typescript
function createProtocol<P extends Protocol>(script: string) {
  return <K extends keyof P>(command: K) =>
    (...args: P[K]['in']) =>
      new Promise<P[K]['out']>((resolve, reject) => {
        const worker = new Worker(script)
        worker.onerror = reject
        worker.onmessage = event => resolve(event.data)
        worker.postMessage({command, args})
      })
}

// 使用例
const runWithMatrixProtocol = createProtocol<MatrixProtocol>(
  'MatrixWorkerScript.js'
)

const parallelDeterminant = runWithMatrixProtocol('determinant')

parallelDeterminant([[1, 2], [3, 4]])  // Promise<number>
  .then(det => console.log(det))       // -2
```

### Node.js子プロセス

```typescript
import {fork} from 'child_process'

// 親プロセス
const child = fork('./ChildProcess.js')

child.on('message', data => {
  console.log('Child sent:', data)
})

child.send({type: 'command', data: [123]})

// 子プロセス
process.on('message', data => {
  console.log('Parent sent:', data)
})

process.send({type: 'response', data: [456]})
```

---

## まとめ

TypeScriptの非同期プログラミングの選択肢：

| 用途 | 推奨手法 |
|------|---------|
| **シンプルな非同期タスク** | コールバック |
| **複数タスクの連鎖・並列化** | Promise、async/await |
| **イベントの繰り返し発火** | EventEmitter、RxJS |
| **マルチスレッド通信** | 型安全なプロトコル |

**重要原則:**
- async/awaitを優先（可読性・保守性）
- Promiseチェーンよりasync/awaitが明確
- イベントストリームは型安全なEmitterでラップ
- スレッド間通信は型安全なプロトコルで抽象化
