# フレームワーク選定とアーキテクチャ（SwiftUI / UIKit）

> 出典: Apple Human Interface Guidelines / Apple Developer Documentation（最終確認 2026-07-13）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。日本語版がある場合は公式の言語切替または本文の日本語 URL を使い、英語版との差分がある場合は最新側を確認する。

> 鮮度補正: 本文のOS導入版、Xcode要件、API名、推奨deployment targetは2026-07-13時点のスナップショットであり、恒久的な採用条件ではない。実装時は対象XcodeのSDKと各Apple Developer DocumentationのAvailabilityを確認し、確認日・対象OS・代替経路を記録すること。

---

## SwiftUI vs UIKit の選定基準（Framework Selection）

### 概要

SwiftUI は宣言型 UI フレームワークで、iOS 13.0+ / iPadOS 13.0+ を含む全 Apple プラットフォームに対応する。UIKit は iOS 2.0 以来のイベント駆動型（命令型）GUI フレームワークで、iOS / iPadOS / tvOS / Mac Catalyst を対象とする。両者は排他ではなく、1 アプリ内で混在できる（相互運用の節を参照）。

### 🔴 必須（遵守事項）

| 判断軸 | 遵守事項 |
|--------|---------|
| 新規アプリ | 明確な阻害要因（下記）がない限り **SwiftUI を第一選択**とすること。Apple 公式も新規プロジェクトでは SwiftUI の優先検討を推奨している |
| 既存 UIKit アプリ | 全面書き換えを強行しないこと。`UIHostingController` を使い**画面単位で段階的に SwiftUI を導入**する |
| OS 要件 | SwiftUI の基本機能は iOS 13+ だが、実用上の主要 API に強い OS 依存がある（`NavigationStack`=iOS 16+、`@Observable`=iOS 17+、`Layout` プロトコル=iOS 16+ 等）。**採用 API と最低デプロイメントターゲットを必ず突き合わせる**こと |
| メインスレッド制約 | UIKit のクラス（特に `UIResponder` 派生と UI 操作に関わる全クラス）は**メインスレッド／メインディスパッチキューでのみ使用**すること。バックグラウンドスレッドからの UI 操作は禁止 |
| 混在方針 | SwiftUI / UIKit を混在させる場合、**どちらがナビゲーションとライフサイクルのオーナーか**をプロジェクト方針として先に決めること（画面ごとに揺れると遷移・状態管理が破綻する） |

### 選定マトリクス

| 条件 | 推奨 |
|------|------|
| 新規アプリ・iOS 16+ をターゲットにできる | SwiftUI（`NavigationStack` 前提で設計可能） |
| 新規アプリ・iOS 17+ をターゲットにできる | SwiftUI + `@Observable`（状態管理が最も簡潔） |
| 既存 UIKit 資産が大きい | UIKit 基盤を維持し、新規画面のみ SwiftUI（`UIHostingController` 経由） |
| 高度なテキスト編集（TextKit）、複雑なコレクションレイアウト、細粒度のスクロール制御 | UIKit（該当画面のみ）。SwiftUI からは Representable でラップ |
| カメラ・PencilKit・地図など UIKit/UIView ベース SDK の統合 | SwiftUI 基盤 + `UIViewRepresentable` / `UIViewControllerRepresentable` |
| iPad のマルチウィンドウ・ポインタ・Apple Pencil 対応が主要件 | どちらでも可。UIKit は Pointer Interactions / Pencil Interactions を直接提供 |
| watchOS / visionOS など複数プラットフォーム展開 | SwiftUI（コード共有率が最大化する） |

### よくある違反・注意点

- ❌ 「SwiftUI は新しいから」という理由だけで、iOS 14/15 サポートが必要なのに `NavigationStack` や `@Observable` 前提の設計を始める（ビルドは通っても `#available` 分岐だらけになる）。
- ❌ UIKit アプリの 1 画面を SwiftUI 化する際、ナビゲーション（push/pop）まで SwiftUI 側で二重管理する。既存の `UINavigationController` を正とし、SwiftUI 側からはクロージャで遷移要求を返すこと。
- ❌ tvOS/macOS 専用のコンポーネント（`Table` の macOS 専用挙動等）を iOS 向けリファレンスとして流用する。本スキルの対象は iOS/iPadOS のみ。

公式: https://developer.apple.com/documentation/swiftui / https://developer.apple.com/documentation/uikit

---

## 相互運用（Interoperability: UIHostingController / UIViewRepresentable / UIViewControllerRepresentable）

### 概要

方向は 2 つ。「UIKit の中に SwiftUI」は `UIHostingController`（および セル用の `UIHostingConfiguration`）、「SwiftUI の中に UIKit」は `UIViewRepresentable`（UIView 用）と `UIViewControllerRepresentable`（UIViewController 用）を使う。

### 🔴 必須（遵守事項）

**UIHostingController（UIKit → SwiftUI を埋め込む）**

- 子 ViewController として埋め込む場合は、UIKit の containment 手順を**完全に**実行すること: `addChild(_:)` → `view.addSubview(_:)`（＋制約設定）→ `didMove(toParent:)`。省略するとライフサイクルイベントが欠落する。
- サイズ追従が必要な場合は `sizingOptions` を明示設定すること（例: `.preferredContentSize`）。未設定だとコンテンツサイズの変化が親に伝わらない。
- `rootView` はいつでも差し替え可能で UI は自動更新される。SwiftUI 側へ渡すデータは `rootView` 再代入か、`@Observable` モデルの共有で行うこと。
- セーフエリアの扱いをカスタムする場合のみ `safeAreaRegions` を変更する。既定挙動で足りるなら触らない。

**UIViewRepresentable / UIViewControllerRepresentable（SwiftUI → UIKit を埋め込む）**

- 必須実装は `makeUIView(context:)` / `updateUIView(_:context:)`（ViewController 版は `makeUIViewController` / `updateUIViewController`）。生成は make に、SwiftUI の状態反映は update に**役割を分離**すること。
- `updateUIView` / `updateUIViewController` は**何度でも呼ばれる**。冪等（副作用なし・同じ入力なら同じ結果）に実装すること。ここでオブジェクト生成・通知登録などをしてはならない。
- UIKit 側のイベント（delegate / target-action）を SwiftUI へ戻すときは **Coordinator** を実装し、`makeCoordinator()` で生成、`context.coordinator` を delegate に設定すること。
- ラップした `UIView` / `UIViewController` の `frame` / `bounds` / `center` / `transform` を**直接設定してはならない**。レイアウトは SwiftUI 側（`.frame()` / `.position()` 等）が所有する。
- delegate 解除・オブザーバ登録解除などのクリーンアップは `static func dismantleUIView(_:coordinator:)`（/ `dismantleUIViewController`）で行うこと。

### 推奨

- Coordinator には `parent`（Representable 本体）への参照を持たせ、UIKit イベントを `@Binding` / `@Observable` モデル経由で SwiftUI 状態に反映する。
- `context.environment` から SwiftUI の環境値（レイアウト方向・カラースキーム等）を読み、UIKit 側の見た目を同期させる。
- `rootView` の差し替えにアニメーションを付ける場合は `UIView.transition(with:duration:options:)` を使う。
- リスト内セルに SwiftUI を使う場合は、セルごとに `UIHostingController` を生成せず `UIHostingConfiguration` を使う。

### よくある違反・注意点

- ❌ `updateUIView` 内で毎回 delegate 再設定や `addTarget` を行い、イベントが多重発火する。
- ❌ Coordinator を使わず、Representable 構造体自体を delegate にしようとする（構造体は再生成されるため機能しない。Coordinator は参照型で生存期間が View と同期される）。
- ❌ `dismantleUIView` を実装せず、KVO / NotificationCenter の購読が残ってクラッシュ・リークする。
- ❌ 埋め込んだ `UIHostingController` の `view` に直接 `frame` を毎フレーム設定し、Auto Layout 制約と競合する。制約ベースで固定すること。
- ⚠️ モーダルで出した `UIHostingController` の dismiss 検知は自動では SwiftUI 側に伝わらない。必要なら明示的にコールバックを実装する。

公式: https://developer.apple.com/documentation/swiftui/uihostingcontroller / https://developer.apple.com/documentation/swiftui/uiviewrepresentable / https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable

---

## 最低デプロイメントターゲットの決め方（Minimum Deployment Target)

### 概要

最低デプロイメントターゲット（`IPHONEOS_DEPLOYMENT_TARGET`）は「どの iOS バージョンのユーザーまでサポートするか」と「どの API を条件分岐なしで使えるか」のトレードオフを決める、プロジェクト初期の最重要判断のひとつ。

### 🔴 必須（遵守事項）

- プロジェクト作成時に**採用予定の主要 API の必要 OS バージョンを一覧化**し、その最大値以上をターゲットにするか、`if #available` 分岐のコストを明示的に受け入れるかを決定すること。
- 使用する API がターゲットより新しい場合は、`@available` 属性／`if #available` で必ずガードすること（ガードなしはコンパイルエラーまたは実行時クラッシュ）。
- サードパーティ SDK・SPM パッケージの最低ターゲットも確認すること（依存の方が高い場合、自プロジェクトも引き上げが必要）。

### 主要 API と必要 OS バージョン（iOS・確認時点のスナップショット）

次表はAPI選定時に確認すべき論点を残すための索引であり、表の数値だけでdeployment targetを決めてはならない。Appleが提供するback deployment、SDK同梱状況、個別APIのAvailabilityは変わり得るため、採用する各symbolの現行公式ページで再確認する。

| API / 機能 | 必要バージョン | 影響 |
|-----------|--------------|------|
| SwiftUI 基本（`View`, `@State`, `@Binding`, `ObservableObject`） | iOS 13.0+ | SwiftUI 採用の絶対下限 |
| `UIViewRepresentable` / `UIViewControllerRepresentable` / `UIHostingController` | iOS 13.0+ | 相互運用は初期から利用可 |
| async/await（Swift Concurrency） | iOS 13.0+（Xcode 13.2 以降のバックデプロイ） | 実質的にほぼ制約なし |
| `NavigationStack` / `NavigationSplitView` | iOS 16.0+ | 旧 `NavigationView` は非推奨方向 |
| カスタム `Layout` プロトコル | iOS 16.0+ | 独自レイアウトの可否 |
| `@Observable`（Observation フレームワーク） | iOS 17.0+ | 状態管理設計を左右する分水嶺 |
| SwiftData | iOS 17.0+ | 永続化層の選定に影響 |

### 推奨

- 最低ターゲットは、App Store Connectで確認できる実ユーザー分布、製品要件、Appleが現行Xcodeでサポートする範囲、採用API、テスト可能な端末から決める。「最新から何世代前」という固定ルールにしない。
- iOS 17+でObservationとSwiftDataを活用できるという記述は確認時点の設計例であり、新規アプリの固定既定値ではない。対象OSで利用するsymbolのAvailabilityを確認し、旧OS対応が必要なら互換層とテストコストを明示する。
- ターゲットを下げる判断は「そのバージョン帯の実ユーザー数（既存アプリなら App Store Connect の計測値）」を根拠にすること。感覚で決めない。
- Deployment Target は App 本体・App Extension・Widget・各パッケージで整合させる（Extension だけ古い/新しい構成は事故のもと）。

### よくある違反・注意点

- ❌ `#available` 分岐の中と外で UI 構造が大きく異なる二重実装を放置する（テスト対象が倍になる）。分岐が 3 箇所を超えたらターゲット引き上げを検討する。
- ❌ 「とりあえず最も古い iOS をサポート」して、`NavigationView` の deprecated 警告と `@Observable` 不使用の複雑な状態管理を全部背負う。
- ❌ Xcode / SDK 更新時にデプロイメントターゲットが意図せず書き換わったことに気づかない。ビルド設定の差分を PR でレビューすること。

公式: https://developer.apple.com/documentation/swiftui （各 API ページの Availability 欄で必ず確認）

---

## Swift Concurrency（async/await・MainActor）採用時の注意

### 概要

Swift Concurrency は async/await・`Task`・actor・`Sendable` からなる構造化並行性の仕組み。iOS アプリでは「UI 更新はメインスレッド必須」という UIKit/SwiftUI の制約と直結するため、`@MainActor` の設計が中心課題になる。

### 🔴 必須（遵守事項）

- **UI 更新は必ず `@MainActor` 上で行うこと。** `Task.detached` やバックグラウンドコンテキストから UIKit ビュー・SwiftUI 状態を直接触ってはならない（データ競合・クラッシュの原因）。
  ```swift
  // ❌ 禁止
  Task.detached { self.label.text = "update" }
  // ✅ 正解
  Task { @MainActor in self.label.text = "update" }
  ```
- UI に紐づく ViewModel／状態モデルはクラス全体を `@MainActor` で分離すること（メソッド単位のばら撒きより一貫する）。
- 並行コンテキスト間で受け渡す型は `Sendable` に準拠させること。クラスを `Sendable` にする場合は完全な内部同期（lock 等）が必須。actor / `@MainActor` 分離型は自動的に `Sendable`。
- 共有ミュータブル状態は **actor でカプセル化**すること。actor のプロパティ・メソッドへの外部アクセスは `await` が必須になる（これが仕様であり、回避してはならない）。
- コールバック API を async 化する場合は `withCheckedContinuation` / `withCheckedThrowingContinuation` を使い、**resume をちょうど 1 回**呼ぶこと（0 回=永久停止、2 回=未定義動作）。`UnsafeContinuation` は計測で必要と判明した場合のみ。
- 複数の独立した非同期処理は `withTaskGroup` / `withThrowingTaskGroup` で構造化すること。親タスクのキャンセルは子へ自動伝播する — 長時間処理では `Task.checkCancellation()` / `Task.isCancelled` を確認する。

### 推奨

- Swift 6 言語モード（または `-strict-concurrency=complete`）でビルドし、データ競合をコンパイル時に検出する。新規プロジェクトでは最初から strict モードで開始する方が、後からの移行より遥かに安い。
- SwiftUI では、View の生存期間に紐づく非同期処理は `Task { }` の手動管理ではなく `.task { }` modifier を使う（View 消滅時に自動キャンセルされる）。
- `DispatchQueue.main.async` と `@MainActor` を同一コードベースで混在させない。新規コードは Swift Concurrency に統一する。
- タスク優先度（`Task(priority:)`）は UI 応答に関わるものだけ `.userInitiated` 以上にし、既定は指定なし（親から継承）とする。
- 非同期のイベント列は `AsyncSequence` / `AsyncStream` で表現し、`for await` で消費する。

### よくある違反・注意点

- ❌ `await` 呼び出しの前後で self の状態が変わらない前提を置く（suspension point を跨ぐと他の処理が割り込み得る。actor でも re-entrancy がある）。await 後は必要な不変条件を再検証すること。
- ❌ `ObservableObject` の `@Published` プロパティをバックグラウンドから更新する（実行時警告 "Publishing changes from background threads is not allowed"）。ViewModel を `@MainActor` にして根本解決する。
- ❌ 同期メソッド内から結果が必要なのに `Task { }` を発行して「戻り値がない」と混乱する。呼び出し側を async 化するか、設計を見直す。
- ❌ delegate ベースの UIKit API（位置情報・カメラ等）を Continuation でラップする際、delegate が複数回呼ばれるケースで resume を多重呼び出しする。ガード用フラグまたは `AsyncStream` を使う。
- ⚠️ async/await 自体は iOS 13 までバックデプロイされるが、各フレームワークが提供する async API（例: 一部の新 API）はそれぞれの Availability に従う。

公式: https://developer.apple.com/documentation/swift/concurrency

---

## 状態管理とアーキテクチャパターン概観（State Management & Architecture）

### 概要

SwiftUI の状態管理プリミティブは「状態の所有者は誰か」「どの範囲で共有するか」で選ぶ。iOS 17+ では Observation フレームワークの `@Observable` マクロが中核で、旧来の `ObservableObject`+`@Published` を置き換える。

### 🔴 必須（遵守事項）

**プリミティブの使い分け**

| ラッパー / 型 | 用途 | 遵守事項 |
|--------------|------|---------|
| `@State` | View ローカルの値・`@Observable` モデルの所有 | 必ず `private` にすること。View の外から注入しない |
| `@Binding` | 親が所有する状態への双方向参照 | 所有権を持たないことを理解して使う。値のコピーを別途保持しない |
| `@Observable`（iOS 17+） | 複数 View で共有するモデル | クラスに付与。読まれたプロパティのみ変更追跡されるため、`@Published` 相当の指定は不要 |
| `@Environment` | View 階層を貫通する値・モデルの注入 | `@Observable` モデルは `.environment(model)` で注入し `@Environment(Model.self)` で受ける |
| `@StateObject` / `@ObservedObject` | `ObservableObject` 用（iOS 16 以前サポート時） | 所有するなら `@StateObject`、注入されるだけなら `@ObservedObject`。逆にすると再生成バグになる |
| `@AppStorage` | UserDefaults 連動の軽量設定値 | 機密情報を入れない（Keychain を使う） |

- 同じ状態を `@Observable` と `ObservableObject` の両方で所有・同期しない。deployment target、依存SDK、段階移行のため同一プロジェクトに両方式が存在する場合は、機能またはadapterの境界を明示し、単一のsource of truthを保つ。
- 追跡不要の内部キャッシュ等は `@ObservationIgnored` を付け、無駄な View 更新を防ぐこと。
- `List` / `ForEach` の要素は安定した一意 ID を持たせること（`Identifiable` 準拠、または `id:` 指定）。インデックスを ID にしない。

### アーキテクチャパターン概観

| パターン | 概要 | 向くケース |
|---------|------|-----------|
| 素の SwiftUI（View + `@Observable` モデル） | View にプレゼンテーションロジック、モデルにドメイン状態。Apple のサンプルが採る形 | 小〜中規模。まずこれから始めること |
| MV / MVVM | 画面ごとに ViewModel（`@MainActor` クラス）を置き、View を薄く保つ | テスト対象を View から分離したい中規模以上 |
| 状態機械 / 単方向データフロー（UDF） | 状態遷移を enum / reducer で明示し、イベント→状態→描画を一方向化 | 画面状態が複雑（ロード/エラー/空/成功の直積など） |
| UIKit 側: MVC + Coordinator | `UIViewController` はシーン単位、画面遷移は Coordinator オブジェクトへ分離 | 既存 UIKit 資産の整理・段階的 SwiftUI 移行の準備 |

### 推奨

- アーキテクチャは**最も単純なものから始めて必要時に強化**すること。新規に重量級のフレームワーク導入から始めない。
- ViewModel を置く場合は `@MainActor @Observable final class` を基本形とする（UI 安全性と変更追跡を両立）。
- 副作用（ネットワーク・永続化）はモデル層のプロトコル越しに注入し、Preview / テストではスタブに差し替えられるようにする。
- `#Preview` を全画面で維持し、状態バリエーション（ロード中・エラー・ダークモード）を Preview で確認できる粒度に View を分割する。
- 巨大な View 構造体は子 View に分割する。SwiftUI の差分更新は View 単位で働くため、分割はパフォーマンス改善にも直結する。

### よくある違反・注意点

- ❌ 関連する複数の値を個別の `@State` でばら撒く（`@State var name; @State var age; ...`）。1 つの `@Observable` モデルか構造体にまとめること。
- ❌ `@ObservedObject` で受けるべき注入モデルを `@StateObject` で宣言し、親の再描画でモデルが再生成されず古い状態が残る（またはその逆で毎回リセットされる）。
- ❌ `ObservableObject` で全プロパティに `@Published` を付け、無関係な変更で画面全体が再描画される。iOS 17+ なら `@Observable` へ移行する（公式移行ガイドあり: Migrating from the Observable Object protocol to the Observable macro）。
- ❌ ナビゲーション状態（path）を各 View がローカルに持ち、ディープリンクや状態復元が不可能になる。`NavigationStack(path:)` の path を上位の状態として一元管理する。

公式: https://developer.apple.com/documentation/observation / https://developer.apple.com/documentation/swiftui

---

## オフラインファースト同期（該当時）

サーバーまたはCloudKitと同期し、オフライン中も編集を許すアプリでは、ネットワーク応答をUIのsource of truthにしない。

### 設計原則

- UIはローカル永続ストアを読み、ユーザー操作を先にローカルへ確定する。
- ローカル変更と送信待ち操作（outbox）は、可能なら同一トランザクションで保存する。
- レコードに安定したID、サーバーrevisionまたは変更token、同期状態、必要なら削除tombstoneを持たせる。
- mutation IDやidempotency keyを使い、再試行で作成・課金・通知等が重複しないAPI契約にする。
- 差分cursorまたは変更tokenを永続化し、全件上書きではなく取得済み地点から同期する。
- 競合は最終更新優先へ暗黙に委ねず、フィールド単位マージ、サーバー優先、ユーザー選択等の製品ルールを定義する。
- 削除はサーバー確認前の即時物理削除を避け、別端末の古い更新で復活しないようにする。
- 認証失効、サインアウト、アカウント切替時のoutboxとローカルデータの扱いを定義する。
- foreground復帰とユーザー操作による同期経路を必ず残す。BackgroundTasksとサイレント通知は開始の契機であり、実行・配信保証ではない。
- CloudKit同期を採用する場合は、Appleの変更token、共有、競合、アカウント切替の契約を使い、独自outboxを無条件に重ねない。

### 検証

- offlineで作成・編集・削除し、強制終了と再起動を挟んでも保持される。
- 再接続、timeout、重複送信、401、競合、部分成功、低速通信で最終的に収束する。
- 2台以上と複数Sceneから同じデータを変更し、決定した競合規則どおりになる。
- schema migration中の未送信操作、削除済みデータ、古いcursor、アカウント切替をテストする。

公式: https://developer.apple.com/documentation/coredata/synchronizing-a-local-store-to-the-cloud
公式: https://developer.apple.com/documentation/coredata/mirroring-a-core-data-store-with-cloudkit
公式: https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices

---

## Xcode プロジェクト構成の基本（Project Structure）

### 概要

Xcode プロジェクトは Target（App 本体・Extension・テスト）、ビルド設定（Deployment Target・Signing 等）、依存（Swift Package Manager）で構成される。構成の乱れは後工程（CI・レビュー・マルチターゲット化）で高くつくため、初期に規約を固める。

### 🔴 必須（遵守事項）

- **依存管理は Swift Package Manager（SPM）を第一選択**とすること。新規プロジェクトで CocoaPods 等を導入する場合は明確な理由を残す。
- App 本体・Widget/Extension・テストの各 Target で Deployment Target と Swift 言語バージョンを整合させること。
- アプリのエントリポイントは SwiftUI アプリなら `@main` を付けた `App` プロトコル準拠型（`WindowGroup` でルート View を返す）、UIKit アプリなら `UIApplicationDelegate` + `UISceneDelegate` とすること。両方式を中途半端に混ぜない。
- 機密情報（API キー等）をソース・Info.plist に平文で置かないこと。ビルド設定 / 環境注入 / Keychain を使う。
- ユニットテスト Target（XCTest / Swift Testing）をプロジェクト作成時に含めること。後付けは実施率が下がる。

### 推奨

- **フォルダ構成は機能（Feature）単位**を基本とし、内部を `Views/` `Models/` `Services/` 程度に分ける。層だけの巨大フォルダ（全 View が 1 フォルダ）は避ける。
  ```
  MyApp/
  ├── App/                # @main, ルート構成, DI
  ├── Features/
  │   ├── Home/           # View + モデル + 画面固有ロジック
  │   └── Settings/
  ├── Core/               # 共有モデル・サービス（ネットワーク/永続化）
  ├── Resources/          # Assets.xcassets, Localizable strings
  └── Tests/
  ```
- 再利用層（デザインシステム・ネットワーククライアント等）が育ってきたら **ローカル Swift Package** に切り出す。モジュール境界が明示され、ビルド時間とテスト独立性が改善する。
- Asset Catalog（`Assets.xcassets`）で色・画像・アプリアイコンを一元管理し、ライト/ダーク両対応の色定義を Asset Catalog 側で行う。
- ビルド構成は Debug / Release を基本に、環境差（API 接続先等）は xcconfig ファイルで管理する。
- `.gitignore` に `xcuserdata/`・DerivedData を含め、`project.pbxproj` のコンフリクトを減らすためファイル追加は機能ブランチ単位でまとめる。
- SwiftLint / swift-format 等の整形・静的検査を CI に組み込み、レビューをスタイル議論から解放する。

### よくある違反・注意点

- ❌ ルート直下に全ソースをフラットに置き、100 ファイル超で探索不能になる。
- ❌ Info.plist に権限用途文字列（`NSCameraUsageDescription` 等）を書き忘れ、該当 API 使用時に即クラッシュする。権限を使う機能の実装時に必ずセットで追加すること。
- ❌ Extension Target に App 本体専用のソースを Target Membership で共有し、ビルドサイズ肥大や API 不整合（Extension で使用不可の API）を起こす。共有コードはローカルパッケージへ。
- ❌ Xcode の自動 Signing とマニュアル Signing を Target 間で混在させ、CI でだけ失敗する。
- ⚠️ SwiftUI プロジェクトでも AppDelegate 相当の処理（プッシュ通知登録等）が必要な場合は `@UIApplicationDelegateAdaptor` を使う。独自に UIKit エントリポイントへ作り替えない。

公式: https://developer.apple.com/documentation/swiftui / https://developer.apple.com/documentation/uikit

---

## 関連リファレンス

- 相互運用 API の詳細: https://developer.apple.com/documentation/swiftui/uihostingcontroller / https://developer.apple.com/documentation/swiftui/uiviewrepresentable / https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable
- 並行処理: https://developer.apple.com/documentation/swift/concurrency
- 状態観測: https://developer.apple.com/documentation/observation
