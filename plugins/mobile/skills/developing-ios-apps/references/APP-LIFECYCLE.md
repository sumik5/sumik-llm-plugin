# アプリライフサイクルとバックグラウンド実行

> 出典: Apple Human Interface Guidelines / Apple Developer Documentation（最終確認 2026-07-13）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。日本語版がある場合は公式の言語切替または本文の日本語 URL を使い、英語版との差分がある場合は最新側を確認する。

> 鮮度補正: 本文のOS導入版、利用可能なtask種別、実行時間の目安、delegate/APIの契約は2026-07-13時点のスナップショットである。実装時は対象symbolのAvailabilityとBackgroundTasks、UserNotificationsの現行Apple公式資料を確認し、固定時間を実行保証として扱わないこと。

iOS/iPadOS アプリはユーザー操作・システム都合により頻繁に状態遷移する。**「いつでも中断・終了されうる」前提で、遷移フックごとに保存・解放・復元を実装すること**が全項目に共通する原則である。

---

## SwiftUI のライフサイクル（App / Scene / scenePhase）

### 概要

SwiftUI アプリは `@main` を付けた `App` 準拠型がエントリポイントとなり、`body` に `Scene`（`WindowGroup` 等）を宣言する。ライフサイクル状態は環境値 `\.scenePhase`（`ScenePhase` 列挙型）として公開され、delegate メソッドの代わりに `onChange(of:)` で遷移を監視する。

### ScenePhase の 3 状態

| ケース | 意味 | すべきこと |
|--------|------|-----------|
| `.active` | フォアグラウンドでインタラクティブ | タイマー・アニメーション・センサー・リアルタイム更新の再開 |
| `.inactive` | フォアグラウンドだが操作を受けない（App Switcher 表示中・Split View 遷移中・着信等） | 進行中の作業を一時停止。編集データの保存開始 |
| `.background` | UI が非表示。この後 Suspended → 終了されうる | データ永続化・リソース解放・クリーンアップの最後の機会 |

### 🔴 必須（遵守事項）

- 読み取り位置で意味が変わることを理解して実装すること:
  - **View で読む** → その View を含む個別シーンの状態。
  - **App で読む** → 全シーンの**集約値**（いずれかが active なら `.active`、全シーンが background になって初めて `.background`）。
- アプリ全体のクリーンアップ（キャッシュ破棄・接続クローズ・永続化）は **App 層の `.background` 検知**で行うこと。個別 View の `.background` はそのシーンのみの状態であり、アプリ終了間際の合図ではない。
- `.background` 到達後に長時間処理を開始してはならない（Suspended 移行までの猶予は短い。長い処理は後述の `beginBackgroundTask` / BGTaskScheduler を使う）。
- 最終確認時点では `ScenePhase` のAvailabilityはiOS 14.0+と表示されていた。実装時は対象SDKの公式Availabilityを再確認し、deployment targetが満たさない場合だけUIKitライフサイクル等の代替経路を設計すること。

```swift
@main
struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup { RootView() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:     resumeWork()
                case .inactive:   pauseWork()          // 保存はここから始める
                case .background: persistAndRelease()  // 終了前の最後の機会
                @unknown default: break
                }
            }
    }
}
```

### 推奨

- View 単位の UI 制御（タイマー停止・アニメーション停止）は View 側の `@Environment(\.scenePhase)` + `onChange` で行い、責務を分離する。
- UIKit の delegate 通知が必要なライブラリ連携には `@UIApplicationDelegateAdaptor` で AppDelegate を併設できる（SwiftUI ライフサイクルと共存可能）。
- 軽量な UI 状態の自動保存には `@SceneStorage`、アプリ全体設定には `@AppStorage` を使う（後述「状態保存と復元」参照）。

### よくある違反・注意点

- ❌ View の `scenePhase == .background` を「アプリがバックグラウンドに入った」と解釈する（マルチシーン iPad では他シーンがまだ active でありうる）。
- ❌ `.inactive` を無視して `.background` だけで保存する — 電話着信や App Switcher 一瞥では `.inactive` 止まりのことがあり、その間に強制終了されると保存漏れになる。保存は `.inactive` 時点から着手する。
- ❌ 全遷移ケースに同一処理を割り当てる（状態ごとの意味を無視した実装はリソース浪費・保存漏れの温床）。

公式: https://developer.apple.com/documentation/swiftui/scenephase

---

## UIKit のライフサイクル（UIApplicationDelegate / UISceneDelegate）

### 概要

iOS 13 以降はシーンベースライフサイクルが標準。1 アプリが複数シーン（UI インスタンス）を持ち、各シーンが独立に状態遷移する。`Info.plist` に `UIApplicationSceneManifest` を追加し `UISceneDelegate` を実装して採用する。iOS 12 以前互換が必要な場合のみ `UIApplicationDelegate` のライフサイクルメソッドを併用する。

シーン状態遷移: `Unattached → Foreground-Inactive ⇄ Foreground-Active → Background → Suspended →（切断）Unattached`

### 役割分担

| Delegate | 担当 |
|----------|------|
| `UIApplicationDelegate` | プロセスレベルのイベント: 起動（`didFinishLaunchingWithOptions`）、シーンセッションの生成/破棄、リモート通知登録コールバック、BGTask ハンドラ登録 |
| `UISceneDelegate` | シーン（UI）レベルのイベント: 接続/切断、active/inactive、foreground/background 遷移、URL/UserActivity の受け取り |

### 🔴 必須（遵守事項）

| フック | 必ず行うこと |
|--------|-------------|
| `scene(_:willConnectTo:options:)` | 初期 UI 構築・データロード・`connectionOptions` の userActivity/URL/通知起因の起動処理・状態復元 |
| `sceneDidBecomeActive(_:)` | 一時停止した処理（タイマー・アニメーション・音声・センサー・ネットワーク）の再開 |
| `sceneWillResignActive(_:)` | 編集中データの保存・タイマー/アニメーション停止・進行中リクエストの保留 |
| `sceneDidEnterBackground(_:)` | 残る重要データの保存・メモリ解放（キャッシュ破棄・大容量オブジェクト解放）・**スナップショット用に UI から機密情報を隠す**・必要なら残処理のバックグラウンド実行時間を要求 |
| `sceneDidDisconnect(_:)` | シーン固有リソース（接続・セッション）の破棄と状態の永続化。切断は再接続されうるため、破壊的なデータ削除はしない |

- シーンベース採用時、フォアグラウンド/バックグラウンド遷移イベントは **SceneDelegate に届き、AppDelegate の対応メソッドは呼ばれない**。両方に同じ処理を書いて二重実行を期待/危惧する実装をしないこと。
- バックグラウンド遷移後に完了させたい短い処理は `UIApplication.beginBackgroundTask(expirationHandler:)` で実行時間を明示的に要求し、**完了時に必ず `endBackgroundTask(_:)` を呼ぶ**こと（対で呼ばないとシステムに強制終了される）。

```swift
func sceneDidEnterBackground(_ scene: UIScene) {
    var bgTask: UIBackgroundTaskIdentifier = .invalid
    bgTask = UIApplication.shared.beginBackgroundTask {
        UIApplication.shared.endBackgroundTask(bgTask)  // 期限切れ時も必ず終了
        bgTask = .invalid
    }
    saveCriticalData {
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }
}
```

### 推奨

- メモリ警告（`didReceiveMemoryWarning` / `UIApplication.didReceiveMemoryWarningNotification`）で `URLCache` や画像キャッシュを破棄する経路を用意する。
- デバイスロックで保護データが利用不可になるアプリは `applicationProtectedDataWillBecomeUnavailable(_:)` / `DidBecomeAvailable` に対応する（バックグラウンド処理中にファイルが読めなくなる事故を防ぐ）。
- 大幅な時刻変更（日付跨ぎ・タイムゾーン変更）に依存する UI は `applicationSignificantTimeChange(_:)` で更新する。
- URL スキーム/Universal Links は起動時（`connectionOptions.urlContexts`）と実行中（`scene(_:openURLContexts:)`）の**両経路**を実装する。

### よくある違反・注意点

- ❌ `sceneDidEnterBackground` で重い処理を同期実行する — 猶予（おおむね数秒）を超えるとウォッチドッグに殺される。
- ❌ バックグラウンドスナップショットにパスワード・残高等の機密 UI を残す（App Switcher に露出する。遷移時にブラー/カバー View を被せる）。
- ❌ `sceneDidDisconnect` を「アプリ終了」と同一視して破壊的クリーンアップを行う（シーンは後で再接続されうる）。
- ❌ フォアグラウンド復帰処理を `willEnterForeground` と `didBecomeActive` の両方に重複実装して二重再開する。

公式: https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle

---

## 状態保存と復元（State Preservation and Restoration）

### 概要

システムはメモリ回収のためバックグラウンドのアプリを黙って終了する。ユーザーには「アプリに戻ったら続きから」に見えるよう、UI 状態を保存・復元する。iOS 13+ のシーンベースでは **`NSUserActivity` ベースの復元が推奨**。SwiftUI では `@SceneStorage` が同等の役割を担う。

### 🔴 必須（遵守事項）

- シーンベース復元では `UISceneDelegate` の **`stateRestorationActivity(for:)` を実装**し、現在の UI 状態を表す `NSUserActivity` を返すこと（これが復元サポートの宣言になる）。
- シーンが inactive/background になるタイミングで `scene.userActivity`（の `userInfo`）を最新化しておくこと。
- 復元は `scene(_:willConnectTo:options:)` で `session.stateRestorationActivity` / `connectionOptions.userActivities` を読み、UI を再構築すること。
- 復元データには**識別子（ID）等の軽量な値のみ**を入れ、モデルデータ本体は入れないこと（モデルはアプリのデータ層から ID で引き直す）。復元値が欠落・不整合でもクラッシュさせず、デフォルト画面へフォールバックすること。
- ViewController ベース復元（レガシー・iOS 12 以前互換）を使う場合:
  - AppDelegate で `shouldSaveSecureApplicationState` / `shouldRestoreSecureApplicationState` に `true` を返す。
  - 復元対象の各 ViewController に **Restoration ID** を設定する（Storyboard の Identity Inspector。未設定の VC は復元対象外）。
  - `encodeRestorableState(with:)` / `decodeRestorableState(with:)` で `super` を必ず呼ぶ。

### 推奨

- SwiftUI では画面ローカルの軽量状態（選択タブ・スクロール対象 ID・入力途中テキスト等）を `@SceneStorage` に載せ、シーンごとに自動保存・復元させる。機密情報は入れない（保護されない平文保存）。
- iPad マルチウィンドウでは**シーンごとに**独立した復元状態を持たせる（全シーン共通のシングルトン状態に集約しない）。
- 復元テストは「Home でサスペンド → Xcode から停止 → 再起動」で行う。**Force Quit（App Switcher 上スワイプ）やクラッシュ後はシステムが保存状態を破棄する**ため、復元されないのは仕様であり不具合ではない。

### よくある違反・注意点

- ❌ 復元データにモデルオブジェクト全体をシリアライズして肥大化させる。
- ❌ 復元失敗時に `fatalError` する（古いバージョンで保存されたデータや削除済みレコードの ID が来ることを想定する）。
- ❌ Force Quit 後に復元されないことをバグとして「対策」し、独自の常時復元を実装する — ユーザーの明示的終了は「まっさらに戻したい」意思表示であり尊重する。
- ❌ `@SceneStorage` にトークンや個人情報を保存する。

公式: https://developer.apple.com/documentation/uikit/restoring-your-app-s-state

---

## 複数Sceneとウインドウルーティング（該当時）

- SwiftUIでは`WindowGroup`を基本にし、値付きWindowGroup、`openWindow`、`dismissWindow`等は対象OSのAvailabilityを公式で確認する。
- 永続モデル、同期サービス、認証はアプリ共通にし、navigation path、選択、編集中ドラフト、表示フィルタはSceneごとに分離する。
- `@SceneStorage`やstate restorationには軽量なIDを保存し、モデル本体、credential、個人情報を入れない。
- 同一レコードを複数Sceneで編集できる場合、保存時の競合規則と他Sceneへの更新通知をデータ層で定義する。
- deep link、Universal Link、通知タップが既存Sceneを選ぶのか、新規Sceneを生成するのかを製品仕様として決める。
- Sceneの接続・切断をアカウント開始・終了と同一視せず、共有データを破壊しない。
- iPadの狭い・中間・広いウインドウで、Scene生成、復元、同時編集、ルーティングを実機検証する。

公式: https://developer.apple.com/documentation/swiftui/bringing-multiple-windows-to-your-swiftui-app

---

## バックグラウンド実行（BGTaskScheduler / Background Modes）

### 概要

BackgroundTasks フレームワーク（iOS 13+）は、アプリがバックグラウンドにある間の遅延実行可能な処理をシステム裁量でスケジュールする。実行タイミングは**システムが電力・利用パターンから決定し、アプリは制御できない**。

| タスク種別 | 用途 | 実行時間の目安 |
|-----------|------|---------------|
| `BGAppRefreshTask` | コンテンツの軽量な定期更新（次回起動時に新鮮な状態にする） | 数秒〜短時間（おおむね 30 秒以内に収める） |
| `BGProcessingTask` | 時間のかかるメンテナンス・同期・ML 学習等 | 数分単位。`requiresNetworkConnectivity` / `requiresExternalPower` を指定可能 |
| `BGContinuedProcessingTask` | フォアグラウンドで開始した処理をバックグラウンドで継続（GPU 利用は entitlement `com.apple.developer.background-tasks.continued-processing.gpu` が必要） | ユーザー開始の長時間処理 |

表のtask種別、entitlement、時間表現は確認時点の索引であり、利用可能性や実行時間を保証しない。対象OS・SDKのApple公式資料で再確認し、常にexpirationと未実行を正常系として扱う。

### 🔴 必須（遵守事項）

1. **Info.plist 宣言**: 使用する全タスク識別子を `BGTaskSchedulerPermittedIdentifiers` に列挙する。加えて Xcode の Signing & Capabilities で Background Modes（Background fetch / Background processing）を有効化する。未宣言の識別子は submit 時にエラーになる。
2. **起動時のハンドラ登録**: `BGTaskScheduler.shared.register(forTaskWithIdentifier:using:launchHandler:)` を**アプリ起動完了前（`didFinishLaunchingWithOptions` 内等）に必ず実行**する。登録前にタスクが起動されると失敗する。
3. **submit でスケジュール**: `BGAppRefreshTaskRequest` / `BGProcessingTaskRequest` を作り `earliestBeginDate` 等を設定して `submit(_:)`。同一識別子の再 submit は既存リクエストを置換する。
4. **`setTaskCompleted(success:)` を必ず呼ぶ**: 呼ばないとシステム評価が下がり、以後の実行機会が減る／ブロックされる。
5. **`expirationHandler` を必ず実装**: 期限到来時に進行中の処理を即キャンセルし、`setTaskCompleted(success: false)` を呼ぶ。実装しないまま時間超過するとプロセスが強制終了される。
6. **継続実行のための再スケジュール**: 定期実行したい場合、ハンドラ冒頭で次回分を submit する（1 回の submit は 1 回分の実行機会でしかない）。

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.app.refresh", using: nil) { task in
    scheduleAppRefresh()                       // 次回分を先に予約
    let op = RefreshOperation()
    task.expirationHandler = { op.cancel() }   // 期限切れで即中断
    op.completionBlock = { task.setTaskCompleted(success: !op.isCancelled) }
    OperationQueue().addOperation(op)
}
```

### 推奨

- 実行頻度・タイミングをユーザーに約束する UI を作らない（「毎朝 6 時に更新」は BGTaskScheduler では保証できない。確実な時刻起動が必要ならサーバー起点のリモート通知やユーザー操作起点に設計を変える）。
- ネットワーク必須の処理は `requiresNetworkConnectivity = true`、電力を食う処理は `requiresExternalPower = true` を設定してシステムに正直に申告する（適切な申告は実行機会の質を上げる）。
- 用途特化の background modes（`audio`・`location`・`voip`・`bluetooth-central` 等）は該当機能を実際に提供する場合のみ有効化する。用途外の常駐目的での宣言は App Review でリジェクトされる。
- デバッグは Xcode（スキームの Background Fetch シミュレート、または LLDB からの `_simulateLaunchForTaskWithIdentifier` 系デバッグ関数）で発火させて検証する。実機で自然発火を待つテストは再現性がない。

### よくある違反・注意点

- ❌ `BGAppRefreshTask` で大容量ダウンロードや重い処理を行う（時間切れで success を返せず、実行機会が先細りする）。大物は `BGProcessingTask` か `URLSession` の background configuration に逃がす。
- ❌ ハンドラ登録を非同期初期化の後回しにして、システム起動時に「未登録」でクラッシュ/失敗する。
- ❌ Low Power Mode・アプリのバックグラウンド更新設定 OFF・利用頻度の低さで実行されないことを考慮せず、バックグラウンド実行を唯一のデータ更新経路にする（フォアグラウンド復帰時の更新経路を必ず併設する）。
- ❌ 大きなファイル転送を BGTask 内の通常 URLSession で行う — background `URLSessionConfiguration` を使えばプロセス外でシステムが転送を継続してくれる。

公式: https://developer.apple.com/documentation/backgroundtasks

---

## 通知（UserNotifications / APNs / 通知権限）

### 概要

UserNotifications フレームワーク（iOS 10+）は、ローカル通知とリモート通知（APNs 経由）を `UNUserNotificationCenter` で統一的に扱う。アラート・サウンド・バッジ・カスタムアクション・添付メディアをサポートする。

| 項目 | ローカル通知 | リモート通知（APNs） |
|------|-------------|---------------------|
| 生成元 | アプリ内（トリガー: 時間間隔 / カレンダー / 位置） | 自社サーバー → APNs → デバイス |
| 必要な構成 | 権限のみ | 権限 + `aps-environment` entitlement + APNs 認証キー（p8）+ デバイストークン管理 |
| 即時性 | トリガー条件依存 | 高（ただし配信保証なし） |

### 🔴 必須（遵守事項）

- **権限リクエスト**: 通知表示前に `requestAuthorization(options:)`（`.alert` `.sound` `.badge` 等）で許可を得ること。拒否されても機能が破綻しない設計（graceful degradation）にすること。
- **権限状態の確認**: 表示可否は `getNotificationSettings` で毎回確認する。`authorizationStatus` は `.authorized` / `.denied` / `.notDetermined` / `.provisional` / `.ephemeral` の 5 値があり、`.denied` 時に再リクエストしてもダイアログは出ない（設定アプリへの誘導のみ可能）。
- **リモート通知の登録手順**: ①`UNUserNotificationCenter.current().delegate` を**起動完了前**（`didFinishLaunchingWithOptions` 内）に設定 → ②権限取得後にメインスレッドで `registerForRemoteNotifications()` → ③`application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` で得たトークンを自社サーバーへ送る。
- **デバイストークンをキャッシュ・固定値扱いしないこと**: トークンは変わりうる。起動のたびに登録し、コールバックで受け取った最新値をサーバーへ同期する。
- **entitlement**: リモート通知は `aps-environment`（development / production）の Push Notifications capability が必須。
- **フォアグラウンド受信**: アプリ前面時は既定で通知が表示されない。表示したい場合は `userNotificationCenter(_:willPresent:withCompletionHandler:)` で `[.banner, .sound, .badge]` 等を返す。
- **タップ処理**: `userNotificationCenter(_:didReceive:withCompletionHandler:)` で `actionIdentifier` と `userInfo` を処理し、**必ず completionHandler を呼ぶ**。通知起因のコールドローンチ（起動オプション経由）も同 delegate に届くよう、delegate 設定を起動直後に済ませておく。

### 推奨

- **カスタムアクション**: `UNNotificationCategory` + `UNNotificationAction` / `UNTextInputNotificationAction` を `setNotificationCategories` で登録し、通知の `categoryIdentifier` で紐付ける。アプリを開かず完結する操作を提供できる。
- **provisional 権限**: `.provisional` を指定すると許可ダイアログなしで「静かに配信」（通知センターのみ・音なし）から始められる。価値を体験させてから正式許可を求める段階的アプローチに有効。
- **権限リクエストのタイミング**: 起動直後の無説明ダイアログは拒否率が高い。通知の価値が伝わる文脈（機能を有効化した直後等）で、事前説明 UI（プレパーミッション）を挟んでから出す。
- **Notification Service Extension**: `UNNotificationServiceExtension` で受信ペイロードの復号・画像添付・本文加工を配信前に行える（`mutable-content: 1` が必要）。
- **配信保証はない**: APNs もローカル通知も配信を保証しない。通知を唯一のデータ同期手段にせず、起動時のフェッチと組み合わせる。バッジやリストの整合はサーバー/アプリ側の状態を正とする。
- テストには Apple の Push Notification Console（開発用トークンへのテスト送信）を利用する。

### APNs provider／サーバー側

- APNs認証キー（`.p8`）と秘密鍵をサーバーのsecret管理へ置き、アプリバンドル、ログ、リポジトリへ含めない。
- development／production endpoint、topic、entitlement、アプリの配布環境を一致させる。
- デバイストークンをユーザーの永続IDとみなさず、端末・アプリ・環境との対応を更新できるようにする。
- APNs応答を分類し、無効・期限切れtokenは応答に従って削除する。恒久的な4xxを無制限再試行しない。
- 429や一時的な5xxは現行Provider APIの指示に従いbackoffとjitterで再試行し、論理イベントの重複送信を抑える。
- payloadへcredentialや機密本文を入れず、認証後に取得できる最小の識別子だけを送る。
- collapse ID、expiration、priority、通知種別は用途ごとに決め、現行Provider APIの上限と意味を確認する。
- APNs応答、失敗率、無効token削除、通知起点のアプリ内処理を監視する。

公式: https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server
公式: https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns

### よくある違反・注意点

- ❌ 起動即・文脈なしで権限ダイアログを出す（一度 `.denied` になると回復はユーザー任せ）。
- ❌ `willPresent` を実装せず「フォアグラウンドで通知が出ない」をバグ扱いする（仕様である）。
- ❌ サイレント通知（`content-available: 1`）を確実な定期実行手段として設計する — 配信・起動はシステム裁量であり、頻度も抑制される。
- ❌ マーケティング通知を乱発してユーザーに通知 OFF される（通知はユーザーが価値を感じる情報に限定し、頻度・時間帯を制御する。アプリ内に通知種別ごとのオプトイン/アウト設定を持たせる）。
- ❌ development / production の APNs 環境を取り違え、トークン不一致（BadDeviceToken）で配信失敗する。

公式: https://developer.apple.com/documentation/usernotifications

---

## クイックリファレンス: 遷移イベント対応表

| タイミング | SwiftUI | UIKit（シーンベース） | 必須処理 |
|-----------|---------|----------------------|---------|
| 起動・シーン接続 | `App.init` / View 初期化 | `scene(_:willConnectTo:options:)` | UI 構築・状態復元・起動オプション処理 |
| アクティブ化 | `scenePhase == .active` | `sceneDidBecomeActive` | 一時停止処理の再開 |
| 非アクティブ化 | `scenePhase == .inactive` | `sceneWillResignActive` | 保存開始・タイマー/アニメーション停止 |
| バックグラウンド | `scenePhase == .background`（App 層で集約） | `sceneDidEnterBackground` | 永続化完了・メモリ解放・機密 UI 隠蔽・BGTask スケジュール |
| フォアグラウンド復帰 | `.background → .inactive → .active` | `sceneWillEnterForeground` → `sceneDidBecomeActive` | データ再フェッチ・UI 更新 |
| シーン切断 | —（システム管理） | `sceneDidDisconnect` | シーン固有リソース破棄（非破壊的に） |
