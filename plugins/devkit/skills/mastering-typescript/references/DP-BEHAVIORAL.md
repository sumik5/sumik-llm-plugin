# 振る舞いパターン（Behavioral Patterns）

TypeScriptにおける振る舞いパターン（Behavioral Design Patterns）は、オブジェクト間のコミュニケーションと責任の割り当てを最適化し、疎結合で拡張可能なシステムを構築するための設計パターン群。本ドキュメントでは、オブジェクト間コミュニケーションに関する5つのパターンと、状態・振る舞い管理に関する5つのパターンを解説する。

---

## パターン選択ガイド（Object Communication）

| パターン | 使用場面 | 主な目的 |
|---------|---------|---------|
| **Strategy** | アルゴリズムの動的切り替え | アルゴリズムファミリーをカプセル化し、実行時に交換可能にする |
| **Chain of Responsibility** | 順次処理とリクエスト伝播 | リクエストを処理できるまでハンドラーチェーンを通過させる |
| **Command** | リクエストのオブジェクト化 | アクションを独立したオブジェクトとしてカプセル化 |
| **Mediator** | オブジェクト間の複雑な通信 | 中央集権的なメディエーターを通じて通信を一元化 |
| **Observer** | 一対多の状態通知 | 発行者が複数の購読者に状態変更を通知 |

---

## パターン選択ガイド（State & Behavior Management）

| パターン | 使用場面 | 主な目的 |
|---------|---------|---------|
| **Iterator** | コレクションの順次アクセス | 内部構造を隠蔽してコレクション要素を巡回 |
| **Memento** | 状態の保存と復元 | オブジェクトの以前の状態を保存しundo機能を実現 |
| **State** | 状態依存の振る舞い | オブジェクトの状態に応じて振る舞いを変更 |
| **Template Method** | アルゴリズムの骨組み定義 | 親クラスでアルゴリズムの構造を定義し、一部を子クラスで実装 |
| **Visitor** | 操作の追加と分離 | データ構造と操作を分離し、新しい操作を追加しやすくする |

---

## 1. Strategy パターン（戦略）

### 目的
アルゴリズムのファミリーを定義し、それぞれをカプセル化して実行時に交換可能にする。アルゴリズムをクライアントから独立させ、動的に変更できるようにする。

### 使用場面
- **アルゴリズムの動的切り替え**: 税計算、ソートアルゴリズム、認証方式など、実行時に処理方法を変更したい場合
- **条件分岐の削減**: 多数のif/switch文をポリモーフィズムで置き換える
- **疎結合化**: アルゴリズムの実装詳細をクライアントから隠蔽
- **設定可能性**: ユーザーや管理者がソースコード変更なしに振る舞いを変更

### TypeScript実装

**Classic実装**:
```typescript
interface SortStrategy {
  sort(data: number[]): number[];
}

class BubbleSort implements SortStrategy {
  sort(data: number[]): number[] {
    // Bubble sort実装
    const arr = [...data];
    for (let i = 0; i < arr.length; i++) {
      for (let j = 0; j < arr.length - i - 1; j++) {
        if (arr[j] > arr[j + 1]) {
          [arr[j], arr[j + 1]] = [arr[j + 1], arr[j]];
        }
      }
    }
    return arr;
  }
}

class QuickSort implements SortStrategy {
  sort(data: number[]): number[] {
    if (data.length <= 1) return data;
    const pivot = data[0];
    const left = data.slice(1).filter(x => x <= pivot);
    const right = data.slice(1).filter(x => x > pivot);
    return [...this.sort(left), pivot, ...this.sort(right)];
  }
}

class Sorter {
  constructor(private strategy: SortStrategy) {
    if (!strategy || typeof strategy.sort !== 'function') {
      throw new Error('Invalid strategy provided');
    }
  }

  setStrategy(strategy: SortStrategy): void {
    this.strategy = strategy;
  }

  performSort(data: number[]): number[] {
    return this.strategy.sort(data);
  }
}

// 使用例
const data = [64, 34, 25, 12, 22, 11, 90];
const sorter = new Sorter(new BubbleSort());
console.log(sorter.performSort(data));

sorter.setStrategy(new QuickSort());
console.log(sorter.performSort(data));
```

### テスト考慮事項
- 各Strategyオブジェクトが期待通り動作することを検証
- Contextクラスがストラテジーを正しく使用するかをモックでテスト
- `setStrategy`メソッドで正しいストラテジーが適用されるかを確認

### 注意点
- **複雑さとメリットのバランス**: 2-3個の単純な分岐なら、if文やラムダ関数の方が適切
- **クラス数の増加**: 各ストラテジーが独立クラスになるため、ナビゲートが困難になる可能性
- **状態共有**: ストラテジー間で状態を共有する場合、Contextとの結合度が高まる恐れ
- **パフォーマンス**: 頻繁なストラテジー切り替えは副作用を伴う場合、オーバーヘッドになる

### 実世界の適用例
- **認証ストラテジー**: nuxt-auth、Passport.jsなどのOAuth認証フレームワーク（GitHub、Google、Facebook等の認証プロバイダーを動的に切り替え）

---

## 2. Chain of Responsibility パターン（責任の連鎖）

### 目的
リクエストを処理できるハンドラーのチェーンを構築し、各ハンドラーが処理するか次に渡すかを決定する。送信者と受信者を疎結合にする。

### 使用場面
- **複数のハンドラー候補**: どのハンドラーが処理するか事前に分からない場合
- **階層的な処理**: カスタマーサポート（フロントデスク→スーパーバイザー→マネージャー→CEO）のようなエスカレーションフロー
- **動的なチェーン構成**: 実行時にハンドラーを追加・削除・並び替え
- **疎結合なリクエスト処理**: 送信者が受信者の詳細を知らなくてよい

### TypeScript実装

**Classic実装**:
```typescript
interface SupportTicket {
  getId(): number;
  getCustomer(): string;
  getIssue(): string;
  getPriority(): number;
  setResolution(resolution: string): void;
  getResolution(): string | null;
}

class CustomerSupportTicket implements SupportTicket {
  private resolution: string | null = null;

  constructor(
    private id: number,
    private customer: string,
    private issue: string,
    private priority: number
  ) {}

  getId(): number { return this.id; }
  getCustomer(): string { return this.customer; }
  getIssue(): string { return this.issue; }
  getPriority(): number { return this.priority; }
  setResolution(resolution: string): void { this.resolution = resolution; }
  getResolution(): string | null { return this.resolution; }
}

abstract class SupportHandler {
  protected nextHandler: SupportHandler | null = null;

  setNext(handler: SupportHandler): SupportHandler {
    this.nextHandler = handler;
    return handler;
  }

  abstract handle(ticket: SupportTicket): void;
}

class FrontDeskHandler extends SupportHandler {
  handle(ticket: SupportTicket): void {
    if (ticket.getPriority() <= 1) {
      ticket.setResolution("Resolved by Front Desk: General inquiry handled");
      console.log(`Ticket ${ticket.getId()} handled by Front Desk`);
    } else if (this.nextHandler) {
      this.nextHandler.handle(ticket);
    }
  }
}

class TechnicalSupportHandler extends SupportHandler {
  handle(ticket: SupportTicket): void {
    if (ticket.getPriority() <= 3) {
      ticket.setResolution("Resolved by Technical Support: Technical issue addressed");
      console.log(`Ticket ${ticket.getId()} handled by Technical Support`);
    } else if (this.nextHandler) {
      this.nextHandler.handle(ticket);
    }
  }
}

// 使用例
const frontDesk = new FrontDeskHandler();
const techSupport = new TechnicalSupportHandler();
frontDesk.setNext(techSupport);

const tickets: SupportTicket[] = [
  new CustomerSupportTicket(1, "John Doe", "General inquiry", 1),
  new CustomerSupportTicket(2, "Jane Smith", "Software bug", 2),
];

tickets.forEach(ticket => {
  console.log(`Processing ticket ${ticket.getId()} for ${ticket.getCustomer()}`);
  frontDesk.handle(ticket);
  console.log(`Resolution: ${ticket.getResolution()}\n`);
});
```

### テスト考慮事項
- チェーン全体の動作を検証（リクエストが正しく処理されるか、チェーンが正しく巡回されるか）
- 各ハンドラーが処理できないリクエストを次に渡すことをモックで確認
- チェーンの末尾でリクエストが未処理のままになるケースをテスト

### 注意点
- **チェーン切断**: ハンドラーが次に渡すのを忘れたり、例外をスローすると連鎖が途切れる
- **パフォーマンスオーバーヘッド**: 長いチェーンはレイテンシーを増加させ、複数オブジェクトを経由するコストが蓄積
- **デバッグの複雑性**: チェーンが長いと制御フローの追跡が困難。デバッグ用ハンドラーの挿入が有効
- **処理保証の欠如**: チェーンの末尾まで到達しても処理されない場合がある。デフォルトハンドラーが必要
- **コード重複**: Decorator パターンと同様、次のハンドラーに渡すロジックが重複する可能性
- **循環参照**: チェーンを慎重に管理しないと無限ループが発生

### 実世界の適用例
- **Express.jsミドルウェア**: HTTPリクエストを複数のミドルウェアハンドラーが順次処理

---

## 3. Command パターン（コマンド）

### 目的
リクエストをオブジェクトとしてカプセル化し、送信者と受信者を分離する。リクエストのキューイング、ログ記録、undo/redo機能を実現。

### 使用場面
- **送信者と受信者の疎結合**: 操作を開始するオブジェクトと実行するオブジェクトを分離
- **リクエストのパラメータ化**: 実行時に異なるリクエストでオブジェクトを設定
- **undo/redo機能**: テキストエディタ、グラフィックツールでコマンドの取り消しと再実行
- **操作のキューイング**: マルチスレッド環境やトランザクションシステムで特定順序で実行
- **複合コマンド**: 複数の単純なコマンドを組み合わせてマクロを作成
- **トランザクション動作**: すべての操作が完了するか、まったく実行されないことを保証

### TypeScript実装

**Classic実装**:
```typescript
interface Command {
  execute(): void;
}

class Light {
  turnOn(): void {
    console.log("Light is turned on");
  }

  turnOff(): void {
    console.log("Light is turned off");
  }
}

class TurnOnLightCommand implements Command {
  constructor(private light: Light) {}

  execute(): void {
    this.light.turnOn();
  }
}

class TurnOffLightCommand implements Command {
  constructor(private light: Light) {}

  execute(): void {
    this.light.turnOff();
  }
}

class SmartHomeController {
  private commands: Command[] = [];

  addCommand(command: Command): void {
    this.commands.push(command);
  }

  executeCommands(): void {
    this.commands.forEach(command => command.execute());
    this.commands = [];
  }
}

// 使用例
const light = new Light();
const controller = new SmartHomeController();

controller.addCommand(new TurnOnLightCommand(light));
controller.addCommand(new TurnOffLightCommand(light));
controller.executeCommands();
```

### テスト考慮事項
- 各Commandが`execute()`メソッドで期待される動作を実行するかを検証
- Receiverのモックを使用してCommandが正しく呼び出されることを確認
- SmartHomeControllerがコマンドリストを正しく管理し、実行するかをテスト

### 注意点
- **抽象化レイヤーの増加**: 単純なアプリケーションでは過剰な複雑さを導入する可能性
- **パフォーマンスオーバーヘッド**: `execute()`メソッド呼び出しが極端にパフォーマンス重視のアプリケーションでは影響を与える
- **過剰設計のリスク**: 限られた操作セットでは不要な構造を押し付ける
- **誤用の可能性**: 多数の小さな特定コマンドクラスが乱立し、クラス数が膨れ上がる。コマンドがReceiverと密結合になるリスク

### 実世界の適用例
- **Redux（React状態管理）**: ActionをCommandとして扱い、Reducerがそれを処理

---

## 4. Mediator パターン（仲介者）

### 目的
複数のオブジェクト間の通信を中央のメディエーターオブジェクトで調整し、直接通信を避ける。依存関係を削減し、システムの複雑性を管理。

### 使用場面
- **結合度の削減と通信の一元化**: オブジェクト間の直接通信を避け、メディエーターを単一の通信ポイントとする
- **複雑な相互作用の簡略化**: 多数のオブジェクトが協調する場合に構造化されたアプローチを提供
- **変更の影響範囲を限定**: あるオブジェクトの変更が他に影響しないようにする

### TypeScript実装

**Classic実装**:
```typescript
interface WorkerMediator {
  triggerEvent(sender: object, message: string): void;
}

class WorkerCenter implements WorkerMediator {
  constructor(
    private workerA: BatchWorker,
    private workerB: SingleTaskWorker
  ) {
    workerA.setMediator(this);
    workerB.setMediator(this);
  }

  triggerEvent(sender: object, message: string): void {
    if (message.startsWith("single_job_completed")) {
      this.workerA.finalize();
    }
    if (message.startsWith("batch_job_completed")) {
      this.workerB.performWork();
    }
  }
}

abstract class Workhorse {
  protected mediator: WorkerMediator | null = null;

  setMediator(mediator: WorkerMediator): void {
    this.mediator = mediator;
  }

  abstract performWork(): void;
}

class BatchWorker extends Workhorse {
  performWork(): void {
    console.log("Performing batch work in BatchWorker");
    this.mediator?.triggerEvent(this, "batch_job_completed");
  }

  finalize(): void {
    console.log("Performing final work in BatchWorker");
    this.mediator?.triggerEvent(this, "final_job_completed");
  }
}

class SingleTaskWorker extends Workhorse {
  performWork(): void {
    console.log("Performing work in SingleTaskWorker");
    this.mediator?.triggerEvent(this, "single_job_completed");
  }
}

// 使用例
const workerA = new BatchWorker();
const workerB = new SingleTaskWorker();
const mediator = new WorkerCenter(workerA, workerB);
workerA.performWork();
```

### テスト考慮事項
- メディエーターが各オブジェクトからのイベントを正しく処理し、適切な順序で他のオブジェクトに委譲するかをテスト
- 具体的なコンポーネントがメディエーターにメッセージを送信することをモックで確認
- メディエーターがイベントを受信することを検証

### 注意点
- **スタックオーバーフロー**: あるサービスがメディエーターを通じて別のサービスを呼び出し、同じ関数を意図せず再度トリガーすると無限ループが発生
- **複雑な相互作用**: メディエーターが唯一の相互作用ポイントになるとボトルネックやバグの原因になる
- **モノリシック化**: 適切に管理されないとメディエーターが多数の責任を持ち、単一責任原則に違反
- **テストとデバッグの困難**: メディエーターの状態と振る舞いを含めたテストが複雑化

### 実世界の適用例
- **チャットルームアプリケーション**: ユーザー間の通信をチャットルーム（メディエーター）が管理
- **UI要素の相互作用**: ボタンクリックが複数のUI要素を更新する場合、メディエーターが通知を管理

---

## 5. Observer パターン（観察者）

### 目的
発行者（Subject）と購読者（Observer）の一対多の関係を確立し、発行者の状態変更時に購読者全員に自動通知する。publish-subscribeパターンとも呼ばれる。

### 使用場面
- **一対多のオブジェクト通信**: 1つの発行者オブジェクトが複数の購読者に疎結合な方法でイベントを配信
- **異なるシステム部分へのイベント伝播**: 依存関係を結合せずに異なる部分を更新

### TypeScript実装

**Classic実装**:
```typescript
interface Subscriber {
  notify(message: any): void;
}

abstract class Subject {
  private subscribers: Subscriber[] = [];

  addSubscriber(subscriber: Subscriber): void {
    this.subscribers.push(subscriber);
  }

  removeSubscriber(subscriber: Subscriber): void {
    const index = this.subscribers.indexOf(subscriber);
    if (index !== -1) {
      this.subscribers.splice(index, 1);
    }
  }

  public notify(message?: any): void {
    console.log("Notifying all subscribers");
    this.subscribers.forEach((s) => s.notify(message));
  }
}

class ConcreteSubject extends Subject {
  private state: any;

  getState(): any {
    return this.state;
  }

  setState(state: any): void {
    this.state = state;
    this.notify(state);
  }
}

class ConcreteSubscriber implements Subscriber {
  private state: any;

  constructor(private subject: ConcreteSubject) {}

  public notify(message: any): void {
    this.state = message;
    console.log(`ConcreteSubscriber: Received update with state: ${this.state}`);
  }
}

// 使用例
const subject = new ConcreteSubject();
const subscriberA = new ConcreteSubscriber(subject);
subject.addSubscriber(subscriberA);

const subscriberB = new ConcreteSubscriber(subject);
subject.addSubscriber(subscriberB);

subject.setState(19);
subject.removeSubscriber(subscriberB);
subject.setState(21);
```

### テスト考慮事項
- Subjectクラスがリソースをクリーンアップし、メモリリークを起こさないことを検証
- `unsubscribe`メソッドが一貫して購読者をリストから削除することを確認
- 各ObserverがSubjectからのメッセージ受信時に正しいビジネスロジックを実行するかをテスト
- モックを使用してObserverが実装の詳細に依存せずに更新を受け取ることを検証

### 注意点
- **メモリリーク**: Subjectが強参照でObserverを保持し、適切に削除されないとObserverがメモリに残る
- **パフォーマンスの懸念**: 多数のObserverに通知すると線形時間（O(n)）がかかり、遅延が発生。シングルスレッド環境では長時間実行Observerの更新がアプリケーション全体をブロック
- **予期しない更新**: Observerが予期しないタイミングで更新を受け取り、複雑で困難なバグが発生。カスケード更新（ある更新が別の更新を引き起こす）が微妙なバグを招く
- **単純なシナリオでのオーバーヘッド**: 単純な一対一の関係ではSubjectとObserverのインフラ設定が過剰

### 実世界の適用例
- **RxJS Observables**: リアクティブプログラミングライブラリでObservableを大規模に作成・操作・結合

---

## 6. Iterator パターン（反復子）

### 目的
コレクションの内部構造を隠蔽しながら、要素を順次アクセスする統一的な方法を提供する。

### 使用場面
- **コレクションの巡回**: 配列、リスト、ツリー、グラフなどの内部構造を知らずに要素にアクセス
- **統一されたインターフェース**: 異なるコレクション型に対して共通のアクセス方法を提供
- **カプセル化**: コレクションの内部表現を隠蔽

### TypeScript実装

**Modern実装（ES6 Iteratorプロトコル）**:
```typescript
class Range {
  constructor(
    private start: number,
    private end: number,
    private step: number = 1
  ) {}

  *[Symbol.iterator]() {
    for (let i = this.start; i <= this.end; i += this.step) {
      yield i;
    }
  }
}

// 使用例
const range = new Range(1, 10, 2);
for (const num of range) {
  console.log(num); // 1, 3, 5, 7, 9
}
```

### テスト考慮事項
- Iteratorが正しい順序で要素を返すかを検証
- コレクションの境界（空、1要素、多数要素）をテスト
- 複数のIteratorが独立して動作することを確認

### 注意点
- **遅延評価の誤解**: Iteratorが遅延評価を意味するわけではない
- **状態管理**: Iterator自体が状態を持つため、複数のIteratorを同時使用する場合は注意
- **変更中の反復**: コレクションを反復中に変更すると予期しない動作が発生

### 実世界の適用例
- JavaScriptの`for...of`ループ、配列のメソッド（`map`, `filter`, `reduce`）

---

## 7. Memento パターン（記念品）

### 目的
オブジェクトの以前の状態を保存し、後で復元できるようにする。カプセル化を破らずにundo機能を実現。

### 使用場面
- **undo/redo機能**: テキストエディタ、グラフィックツール、ゲームのセーブポイント
- **スナップショット**: データベーストランザクションのロールバック
- **履歴管理**: 変更履歴を保持して以前の状態に戻す

### TypeScript実装

**Classic実装**:
```typescript
class Memento {
  constructor(private state: string) {}

  getState(): string {
    return this.state;
  }
}

class Originator {
  private state: string = "";

  setState(state: string): void {
    console.log(`Setting state to: ${state}`);
    this.state = state;
  }

  save(): Memento {
    console.log("Saving state to Memento");
    return new Memento(this.state);
  }

  restore(memento: Memento): void {
    this.state = memento.getState();
    console.log(`State restored to: ${this.state}`);
  }
}

class Caretaker {
  private mementos: Memento[] = [];

  addMemento(memento: Memento): void {
    this.mementos.push(memento);
  }

  getMemento(index: number): Memento {
    return this.mementos[index];
  }
}

// 使用例
const originator = new Originator();
const caretaker = new Caretaker();

originator.setState("State1");
caretaker.addMemento(originator.save());

originator.setState("State2");
caretaker.addMemento(originator.save());

originator.restore(caretaker.getMemento(0));
```

### テスト考慮事項
- Mementoが状態を正しく保存・復元するかを検証
- Caretakerが複数のMementoを正しく管理するかをテスト
- Originatorの内部状態がカプセル化されているかを確認

### 注意点
- **メモリ消費**: 大量の状態を保存するとメモリ使用量が増加
- **パフォーマンス**: 大きなオブジェクトの状態保存は遅い
- **不変性**: Mementoは不変であるべき

### 実世界の適用例
- テキストエディタのundo/redo、ゲームのセーブ機能

---

## 8. State パターン（状態）

### 目的
オブジェクトの内部状態に応じて振る舞いを変更する。状態遷移ロジックをカプセル化し、条件分岐を削減。

### 使用場面
- **状態依存の振る舞い**: メディアプレーヤー（再生中、一時停止中、停止中）、ネットワーク接続（接続中、切断中、再接続中）
- **状態遷移の管理**: ワークフロー、注文処理（新規→処理中→完了→配送）
- **条件分岐の削減**: 多数のif/switch文を状態オブジェクトで置き換え

### TypeScript実装

**Classic実装**:
```typescript
interface State {
  handle(context: Context): void;
}

class Context {
  private state: State;

  constructor(state: State) {
    this.transitionTo(state);
  }

  transitionTo(state: State): void {
    console.log(`Context: Transition to ${state.constructor.name}`);
    this.state = state;
  }

  request(): void {
    this.state.handle(this);
  }
}

class ConcreteStateA implements State {
  handle(context: Context): void {
    console.log("ConcreteStateA handles request");
    console.log("ConcreteStateA wants to change state");
    context.transitionTo(new ConcreteStateB());
  }
}

class ConcreteStateB implements State {
  handle(context: Context): void {
    console.log("ConcreteStateB handles request");
    console.log("ConcreteStateB wants to change state");
    context.transitionTo(new ConcreteStateA());
  }
}

// 使用例
const context = new Context(new ConcreteStateA());
context.request();
context.request();
```

### テスト考慮事項
- 各状態が正しい振る舞いを実行するかを検証
- 状態遷移が正しく行われるかをテスト
- 不正な状態遷移がエラーを引き起こすことを確認

### 注意点
- **状態クラスの増加**: 状態ごとにクラスが必要になる
- **状態遷移の複雑性**: 多数の状態と遷移がある場合、管理が困難
- **循環依存**: 状態間の遷移が複雑になると循環依存が発生する可能性

### 実世界の適用例
- ゲームのプレイヤー状態（ジャンプ中、走行中、待機中）、TCPコネクション状態

---

## 9. Template Method パターン（テンプレートメソッド）

### 目的
親クラスでアルゴリズムの骨組みを定義し、一部のステップを子クラスでオーバーライドする。アルゴリズムの構造を変更せずに特定ステップを再定義。

### 使用場面
- **アルゴリズムの共通構造**: データ処理パイプライン、テストフレームワークのsetUp/tearDown
- **フックメソッド**: 親クラスが特定タイミングで子クラスの処理を呼び出す
- **コード再利用**: 共通部分を親クラスに集約

### TypeScript実装

**Classic実装**:
```typescript
abstract class DataProcessor {
  // Template Method
  process(): void {
    this.readData();
    this.processData();
    this.saveData();
  }

  protected abstract readData(): void;
  protected abstract processData(): void;

  protected saveData(): void {
    console.log("Saving processed data (default implementation)");
  }
}

class CSVDataProcessor extends DataProcessor {
  protected readData(): void {
    console.log("Reading data from CSV file");
  }

  protected processData(): void {
    console.log("Processing CSV data");
  }
}

class JSONDataProcessor extends DataProcessor {
  protected readData(): void {
    console.log("Reading data from JSON file");
  }

  protected processData(): void {
    console.log("Processing JSON data");
  }

  protected saveData(): void {
    console.log("Saving JSON data in custom format");
  }
}

// 使用例
const csvProcessor = new CSVDataProcessor();
csvProcessor.process();

const jsonProcessor = new JSONDataProcessor();
jsonProcessor.process();
```

### テスト考慮事項
- Template Methodが正しい順序でステップを呼び出すかを検証
- 各子クラスが期待通りのステップをオーバーライドしているかをテスト
- デフォルト実装が正しく動作するかを確認

### 注意点
- **継承の制約**: 継承を使用するため、柔軟性が制限される
- **Liskov Substitution Principleの遵守**: 子クラスが親クラスの契約を守る必要がある
- **フックメソッドの過剰使用**: 多数のフックが複雑性を増す

### 実世界の適用例
- テストフレームワーク（Jest、Mocha）のライフサイクルメソッド、HTTPリクエストハンドリング

---

## 10. Visitor パターン（訪問者）

### 目的
データ構造と操作を分離し、データ構造を変更せずに新しい操作を追加する。Double Dispatchを利用。

### 使用場面
- **操作の追加**: データ構造は安定しているが、新しい操作を頻繁に追加する場合
- **異種コレクションの処理**: 異なる型の要素に対して統一的な操作を実行
- **コンパイラ・インタープリタ**: AST（抽象構文木）の走査と操作

### TypeScript実装

**Classic実装**:
```typescript
interface Visitor {
  visitConcreteElementA(element: ConcreteElementA): void;
  visitConcreteElementB(element: ConcreteElementB): void;
}

interface Element {
  accept(visitor: Visitor): void;
}

class ConcreteElementA implements Element {
  accept(visitor: Visitor): void {
    visitor.visitConcreteElementA(this);
  }

  operationA(): string {
    return "ConcreteElementA";
  }
}

class ConcreteElementB implements Element {
  accept(visitor: Visitor): void {
    visitor.visitConcreteElementB(this);
  }

  operationB(): string {
    return "ConcreteElementB";
  }
}

class ConcreteVisitor implements Visitor {
  visitConcreteElementA(element: ConcreteElementA): void {
    console.log(`Visiting ${element.operationA()}`);
  }

  visitConcreteElementB(element: ConcreteElementB): void {
    console.log(`Visiting ${element.operationB()}`);
  }
}

// 使用例
const elements: Element[] = [
  new ConcreteElementA(),
  new ConcreteElementB(),
];

const visitor = new ConcreteVisitor();
elements.forEach(element => element.accept(visitor));
```

### テスト考慮事項
- 各Visitorが各Element型を正しく訪問するかを検証
- 新しいVisitorを追加しても既存コードが影響を受けないことを確認
- Element構造が変更されない限り、Visitorが独立して動作することをテスト

### 注意点
- **Element追加の困難**: 新しいElement型を追加するとすべてのVisitorを更新する必要がある
- **カプセル化の破壊**: Visitorが内部状態にアクセスする必要がある場合、カプセル化が弱まる
- **複雑性**: Double Dispatchの概念が理解しにくい

### 実世界の適用例
- コンパイラのASTトラバーサル、レポート生成、ログ出力

---

## まとめ

振る舞いパターンは、オブジェクト間のコミュニケーションと責任の分散を最適化するための強力なツール。適切なパターンを選択することで、疎結合で保守性の高いシステムを構築できる。

**選択のポイント**:
- **アルゴリズム切り替え** → Strategy
- **順次処理とエスカレーション** → Chain of Responsibility
- **リクエストのカプセル化とundo** → Command
- **複雑な通信の一元化** → Mediator
- **状態変更の自動通知** → Observer
- **コレクション巡回** → Iterator
- **状態の保存と復元** → Memento
- **状態依存の振る舞い** → State
- **アルゴリズムの骨組み定義** → Template Method
- **操作の追加と分離** → Visitor
