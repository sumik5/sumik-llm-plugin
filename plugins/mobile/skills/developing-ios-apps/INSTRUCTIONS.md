# iOS・iPadOSアプリ開発ガイド

## 目的

このスキルは、iPhone・iPad向けアプリの技術設計、実装、検証、プライバシー対応、署名、ベータ配布、App Store提出を一貫して進めるための判断基準を提供する。対象はiOS・iPadOSの新規アプリ、既存アプリの機能追加、SwiftUI/UIKit移行、品質改善、TestFlight配布、App Storeリリース準備である。
## 責務境界

このスキルが担当するもの:

- Xcodeプロジェクト、ターゲット、ビルド設定、依存関係
- SwiftUIとUIKitの選定、相互運用、移行方針
- architecture、state ownership、data flow、依存注入
- App・Sceneライフサイクル、状態保存、復元
- 永続化、ネットワーク、バックグラウンド実行、通知
- テスト、性能、実機品質、診断
- Privacy Manifest、Required Reason API、App Privacy、権限
- コード署名、TestFlight、App Store審査、配布

applying-apple-higが担当するもの:

- Apple HIGに基づく画面構成、ナビゲーション、レイアウト
- コンポーネント、入力、ジェスチャ、カラー、素材、モーション
- UI文言、プラットフォームらしさ、アクセシビリティ体験

UIを作成、変更、レビューするタスクでは、developing-ios-appsとapplying-apple-higを必ず併用する。技術的に動くことだけでUI判断を完了しない。反対に、HIGの推奨だけで署名、API契約、プライバシー、配布要件を判定しない。
## Source of truthと鮮度

Apple公式のオンライン資料を最終的なsource of truthとする。
### 鮮度ルール

次の事項は変動しやすいため、記憶や本スキル内の固定値だけで決定してはならない。

- Xcode、SDK、Swift、提出に必要なビルド環境
- OS/APIのAvailabilityと最低デプロイメントターゲット
- App Review Guidelinesの条項番号と文言
- Privacy ManifestとRequired Reason APIの対象、理由コード、提出条件
- App Privacyのデータ分類と申告画面
- 証明書の種類、有効期間、作成権限、枚数上限
- TestFlightの人数、端末数、ビルド数、有効期間、Beta App Review条件
- App Store Connectのメタデータ、画像、年齢制限、提出条件
- 代替配布の対象地域、資格、契約、手数料
- 性能ツールの名称、メトリクス、報告閾値

上記を含む作業では、実行時に該当するApple公式ページを開き、対象プラットフォーム、対象OS、対象Xcode、確認日を記録する。reference内の数値、OS導入版、条項番号、理由コード、期限は、最終確認日付きの作業用スナップショットである。Apple公式と不一致ならApple公式を採用し、差異を報告する。日本語公式ページに必要な情報がない、更新が遅い、または英語版と差がある場合は英語公式ページを確認する。Apple以外の二次資料を規範根拠にしない。
### 鮮度記録

変動項目を判断したときは、作業メモまたは完了報告に次を残す。

- 確認日
- Apple公式URL
- 確認した対象OS、SDK、Xcode、配布経路
- 採用した要件
- referenceとの差異
- 未確認または条件付きの事項
## 要求強度

すべての記述を同じ強さで扱わない。根拠と影響から次の3段階に分類する。
### 必須

次に該当し、違反するとビルド失敗、実行時障害、提出不能、安全性・法令・契約上の問題につながる要件。

- 公開API、Availability、entitlement、署名の契約
- App Review、App Store Connect、プライバシー申告
- ユーザーの安全、同意、データ保護
- 権限purpose string、Required Reason APIの適正理由
- 完了コールバック、期限処理、データ整合性

必須と記すときは、該当するApple公式根拠を確認する。本スキルの文言だけを根拠に必須へ格上げしない。
### 原則採用

Appleが標準として提供する構造、プラットフォーム慣行、保守性と品質の高い既定値。

- 新規UIでSwiftUIを第一候補にする
- システムコンポーネントと標準ライフサイクルを使う
- 単一の状態所有者と一方向のデータフローを保つ
- 自動署名とSwift Package Managerを先に検討する
- 実機計測と多層テストを行う

採用しない場合は、製品要件、既存資産、API不足、運用制約と代替策を説明できるようにする。
### 条件付き

対象OS、デバイス、ウインドウ、入力方式、採用フレームワーク、アプリ目的、配布経路で変わる事項。

- UIKitの採用やSwiftUIとの混在
- iPadマルチウインドウ、外部ディスプレイ、Apple Pencil
- バックグラウンドモード、通知、位置情報
- CloudKit、SwiftData、Core Data、ファイル保存
- ATT、HealthKit、Sign in with Apple、App Groups
- Mac Catalyst、Designed for iPad on Mac、代替配布

条件付き項目は、該当条件を先に示してから実装する。
## タスク開始時の前提確認

まず、既存ファイルと依頼内容から次を確定する。発見できる情報をユーザーへ聞き直さない。

| 項目 | 確認内容 |
|---|---|
| 目的 | 新規作成、機能追加、改修、移行、品質改善、リリースのどれか |
| 対象 | iPhone、iPad、両方、Mac上のiPadアプリ、Catalyst |
| OS | 現在のdeployment target、引き上げ可否、採用APIのAvailability |
| Xcode | プロジェクトが使用するXcodeとSDK、CIとの差 |
| UI | SwiftUI、UIKit、混在、既存ナビゲーションの所有者 |
| 画面 | 向き、可変ウインドウ、複数Scene、外部ディスプレイ |
| 入力 | タッチ、キーボード、ポインタ、Apple Pencil、音声 |
| データ | 保存対象、機密性、同期、オフライン、競合解決 |
| 通信 | API契約、認証、再試行、キャッシュ、バックグラウンド転送 |
| 権限 | カメラ、写真、位置、通知、マイク、Bluetooth等 |
| SDK | Apple SDKとサードパーティSDK、Privacy Manifest、署名 |
| 配布 | 開発、Ad Hoc、TestFlight、App Store、その他の経路 |
| アカウント | 作成、ログイン、削除、サブスクリプション |
| 品質 | テスト対象、性能予算、対応端末、アクセシビリティ |

不足情報がアーキテクチャ、データ保護、配布可否を変える場合だけ確認する。安全な既定値で進められる場合は、仮定を明記して実装を進める。
## 実行ワークフロー

### 1. 現状を把握する

- project/workspace、target、scheme、Package.swiftを確認する
- deployment target、Swift language mode、build configurationを確認する
- Info.plist、entitlements、PrivacyInfo.xcprivacyを確認する
- App、Scene、root navigation、依存注入の入口を特定する
- テストtarget、CI、archive設定、署名方式を確認する
- サードパーティSDKとデータ送信先を棚卸しする
### 2. 変動要件を再確認する

- 採用APIのApple Developer DocumentationでAvailabilityを確認する
- App Store提出なら最新の提出要件とApp Review Guidelinesを確認する
- プライバシー対象ならRequired Reason APIとSDK要件を確認する
- TestFlight・署名ならApp Store Connect HelpとAccount Helpを確認する
- 固定値をコードや文書へ写す必要がある場合は確認日を残す
### 3. 技術方針を決める

- SwiftUI/UIKitと相互運用境界を決める
- 状態の所有者、イベント、非同期処理、データ層を決める
- Sceneごとの状態とアプリ共有状態を分離する
- 保存、通信、バックグラウンド、通知の失敗時動作を決める
- 必須、原則採用、条件付きに判断を分類する
### 4. 小さい垂直スライスで実装する

- UI、状態、データ、副作用、エラー表示を一つの経路で通す
- Previewまたはfixtureで主要状態を再現する
- 単体テストを追加し、必要な統合・UIテストへ広げる
- UIを含む場合はapplying-apple-higの完了条件も同時に満たす
### 5. 端末品質を検証する

- Simulatorで機能とレイアウトの幅を確認する
- 実機で性能、メモリ、サーマル、カメラ、通知等を確認する
- iPadの可変ウインドウ、回転、複数Scene、状態復元を確認する
- VoiceOver、Dynamic Type、キーボード、ポインタ等を確認する
### 6. プライバシーと配布を閉じる

- データフローと権限を実装に照合する
- manifest、App Privacy、purpose string、SDK申告を揃える
- archive、署名、TestFlight、審査メタデータを確認する
- 実装完了ゲートとリリース完了ゲートを別々に通す
## SwiftUIとUIKitの選定

### SwiftUIを原則採用する条件

- 新規画面または新規アプリである
- 必要APIが対象OSで利用できる
- 宣言的状態管理とPreviewの利点を得られる
- 既存UIKitナビゲーションとの境界を明確にできる
### UIKitを選ぶ条件

- 既存UIKit資産を維持する方が安全である
- 必要な制御やApple APIがUIKitにしかない
- TextKit、複雑なcollection、細粒度scroll等の要件がある
- 段階的移行でUIKitをnavigation/lifecycle ownerに保つ
### 混在時の規則

- navigationとlifecycleの所有者を一方に決める
- UIKitからSwiftUIはUIHostingController等の公式相互運用を使う
- SwiftUIからUIKitはRepresentableとCoordinatorを使う
- update処理を冪等にし、登録と解除の対を保つ
- 状態を両フレームワークへ二重保持しない
- 相互運用APIのAvailabilityを実行時に公式で確認する

API導入版の一覧を恒久ルールとしてコピーしない。対象プロジェクトのdeployment targetとApple公式Availabilityを突き合わせる。
## Architecture、state、data flow

### 基本原則

- 状態には一つの所有者を置く
- Viewは状態を描画し、ユーザーイベントを上位へ渡す
- 副作用をnetwork、persistence、notification等の境界へ分離する
- 依存をprotocolまたは明示的なinitializerで注入する
- グローバルsingletonへ画面状態を集約しない
- loading、empty、content、error、offlineを明示的に表現する
### SwiftUI状態

- Viewローカル状態はStateで所有する
- 親所有の編集値はBindingで渡す
- 共有モデルは対象OSで利用可能なObservation方式を選ぶ
- ObservationとObservableObjectの選定はdeployment targetに合わせる
- Environmentは広域依存に限定し、暗黙依存を増やしすぎない
- navigation pathとdeep link状態は復元可能な上位状態として扱う
### 並行処理

- UI状態の更新をMainActorへ隔離する
- 共有可変状態はactor等で保護する
- 境界を越える値のSendable適合を確認する
- Viewの寿命に紐づく処理は自動キャンセル可能な構造にする
- await後は前提が変わり得るため、不変条件を再確認する
- cancellation、timeout、重複実行を正常系として設計する

特定のarchitecture名を目的化しない。最も単純な構造から始め、状態直積、テスト困難、副作用混在が生じた時点で状態機械やViewModel等を導入する。
## App・Sceneライフサイクル

- SwiftUI AppとScene、UIKit AppDelegateとSceneDelegateの責務を分ける
- Sceneのactive、inactive、backgroundを画面単位で扱う
- アプリ共有処理とScene固有処理を混ぜない
- inactiveから保存を始め、backgroundで短時間に完了できるようにする
- Scene切断をアプリ終了とみなして破壊的処理をしない
- Sceneごとにnavigation、選択、編集中データ、復元情報を保持する
- モデル本体ではなく軽量な識別子を復元情報へ保存する
- 復元失敗時は安全な初期画面へフォールバックする
- App Switcherのsnapshotへ機密画面を露出しない
- ライフサイクルAPIの導入版と現行動作はApple公式で確認する

詳細は [references/APP-LIFECYCLE.md](references/APP-LIFECYCLE.md) を参照する。
## 永続化

| 種類 | 適する用途 | 注意点 |
|---|---|---|
| UserDefaults系 | 小さな設定、feature preference | tokenや個人情報を保存しない |
| Keychain | credential、token、秘密情報 | access groupと保護クラスを確認する |
| SwiftData/Core Data | 構造化モデル、検索、関係 | OS要件、migration、競合を設計する |
| FileManager | 文書、画像、export | Documents、Application Support、Cachesを使い分ける |
| CloudKit | Apple ecosystem同期 | account、offline、conflict、quotaを扱う |
### 永続化ゲート

- データの所有者とsource of truthが明確
- schema migrationと旧データ読込をテスト済み
- 書込失敗、容量不足、保護データ利用不可を処理
- cacheは削除されても再生成可能
- backup対象と除外対象を意図的に分ける
- Scene状態と永続モデルを混同しない
- 機密データの保存先と保持期間がプライバシー申告と一致
## ネットワーク

- URLSession等のApple公式APIを基本にする
- request、response、domain modelを分離する
- cancellationとtimeoutを伝播する
- retryは冪等性、回数、backoff、network状態を考慮する
- HTTP statusとtransport errorとdecode errorを分ける
- offline、stale cache、再接続時同期を設計する
- credentialをログへ出さない
- App Transport Securityを回避する例外を安易に追加しない
- 大容量転送や中断継続はbackground URLSessionを検討する
- UI更新だけをMainActorへ戻し、decodeやI/OをUIから分離する
## バックグラウンド実行

- 実行時刻や頻度をユーザーへ保証しない
- 短い猶予処理とBackgroundTasksを使い分ける
- task identifier、capability、Info.plistの宣言を一致させる
- launch handlerをAppleの要求する時点までに登録する
- expiration handlerで処理を止め、完了を必ず報告する
- 定期処理は次回requestの再登録を設計する
- background modeは実際の用途に必要なものだけ有効にする
- foreground復帰時の更新経路を必ず用意する
- 時間上限や利用可能task種別は実行時にApple公式で確認する
## 通知

- 通知の価値が理解できる文脈で権限を求める
- authorization statusを確認し、拒否時の代替を用意する
- APNs tokenを固定値または永続的識別子として扱わない
- notification categoryとactionを登録する
- foreground表示、tap、cold launchの経路を検証する
- completion handlerを必ず完了させる
- 通知を唯一の同期手段にしない
- 通知本文へ機密情報を載せない
- marketing通知は現行ガイドラインの同意条件を確認する
## テスト、性能、端末品質

### テスト層

- domainとstate transitionの単体テスト
- persistence、network、migrationの統合テスト
- 主要ユーザーフローのXCUITest
- launch、memory、clock等の性能テスト
- archive相当構成のsmoke test
- TestFlightによる実利用条件の確認

Swift TestingとXCTestの採用可否、混在条件、利用可能APIは対象XcodeのApple公式資料で確認する。UIテストと性能テストのフレームワークを推測で置き換えない。
### 性能

- 起動経路で同期networkと重い同期I/Oを行わない
- main threadの長時間占有をInstrumentsで特定する
- 画像を表示サイズへdownsampleする
- cacheに上限と解放経路を設ける
- frame rateを固定値と仮定しない
- energy、disk write、memory、hangを実機で測る
- dSYMとarchiveを保持し、crashをsymbolicate可能にする
- OrganizerとMetricKitの現行メトリクスを確認する

固定の起動時間、hang、frame予算を合否基準として写さない。Apple公式の現行ツール、対象端末でbaselineを作り、変更前後を同条件で比較する。
### 検証マトリクス

| 軸 | 最低限の確認 |
|---|---|
| iPhone | サポート範囲の小さい画面と大きい画面 |
| iPad | 狭いウインドウから広いウインドウ、複数Scene |
| 向き | 製品が対応するportraitとlandscape |
| 入力 | touch、hardware keyboard、pointer、必要ならApple Pencil |
| 文字 | 既定Dynamic Typeと最大級accessibility size |
| 外観 | light、dark、increased contrast、色以外の識別 |
| 動作 | Reduce Motion、Reduce Transparency |
| 支援 | VoiceOver、Voice Control、Switch Controlの該当経路 |
| 言語 | 長い翻訳、改行、RTL、locale依存の日時と数値 |
| 状態 | offline、低速通信、permission拒否、low storage |
| lifecycle | inactive、background、復帰、終了、状態復元 |
| 性能 | 低速な実機、最新実機、thermalとlow power |

UI項目の具体的な判定はapplying-apple-higを必ず併用する。

詳細は [references/DEVICE-QUALITY.md](references/DEVICE-QUALITY.md) を参照する。
## アクセシビリティとHIG

アクセシビリティはリリース後の追加作業ではない。UIの設計と実装に含める。

- semanticな標準controlを優先する
- label、value、hint、traitを必要な要素へ付ける
- Dynamic Typeで切れ、重なり、操作不能がない
- 色だけで状態やエラーを区別しない
- motionと点滅を減らす設定を尊重する
- keyboard focusとpointer操作を確認する
- custom gestureに代替操作を用意する
- 自動検査だけでなく支援機能を使って手動確認する

画面、navigation、layout、component、input、visual design、UI writingの判断は applying-apple-hig を併用し、そのreferenceへ委ねる。
## プライバシーと権限

### データインベントリ

SDKを含め、次をデータ種別ごとに記録する。

- 取得元
- 利用目的
- device外へ送るか
- user/deviceへ紐付くか
- trackingに使うか
- 保存先と保持期間
- 共有先
- 削除方法
### Privacy Manifest

- app、extension、SDK等の対象bundleを棚卸しする
- PrivacyInfo.xcprivacyのtarget membershipを確認する
- collected data、tracking、tracking domainを実態に合わせる
- Required Reason APIのカテゴリと理由を依存コード込みで確認する
- 理由コードはApple公式の現行一覧から選ぶ
- 理由コードの許容目的を拡大解釈しない
- Xcodeのprivacy reportで依存manifestとの集約結果を確認する
- manifestや署名が必要なSDKの現行リストを確認する

開始日、対象SDK、理由コード、Required Reason APIカテゴリをこの文書の固定値で判定しない。
### App Privacy

- App Store Connectの申告を実装と一致させる
- first-party、third-party SDK、WebViewを含める
- linked、tracking、purposeの現行定義を公式で確認する
- privacy policy、manifest、App Privacyの三者を一致させる
- データフロー変更時に申告更新の要否を確認する
### 権限

- 保護resourceごとのpurpose stringを具体的に書く
- 対応言語でローカライズする
- just-in-timeで要求する
- 拒否、limited、restrictedの状態を扱う
- picker等、広い権限を不要にするAPIを優先する
- ATTが必要なtrackingは許可前に開始しない
- fingerprintingを行わない
- アカウント作成がある場合は現行の削除要件を確認する

詳細は [references/PRIVACY.md](references/PRIVACY.md) を参照する。
## 署名、TestFlight、App Store

### コード署名

- Bundle ID、Team、capability、entitlementを一致させる
- 自動署名を先に検討し、手動署名には運用理由を残す
- appとextensionの署名方式を揃える
- CIのkey、certificate、profileを安全に扱う
- archiveとexportの配布経路を一致させる
- certificateの有効期間、枚数上限、作成可能roleを公式で確認する
- 既存certificateを失効させる前にチームとCIへの影響を確認する
### TestFlight

- 内部テストで起動、migration、課金、通知、主要フローを確認する
- 外部テスト前にBeta App Review条件を確認する
- tester、device、build、期限の上限を公式で確認する
- review information、連絡先、demo accountを用意する
- crash、feedback、performanceを確認して提出buildを決める
- TestFlightを恒久配布として扱わない
### App Store審査

- 提出時点のApp Review Guidelines全文を確認する
- 条項番号はreferenceの番号を転記せず、現行ページで再検索する
- metadataを実際の機能と一致させる
- loginが必要なら有効なdemo accountと手順を提供する
- 特殊hardware、地域、設定が必要なら審査メモで説明する
- privacy、IAP、account deletion、UGC等の該当条件を確認する
- reviewerとの応答期限や処理時間を固定値で約束しない
- reject時は現行の条項と指摘事実を分けて対応する

詳細は次を参照する。

- [references/DISTRIBUTION.md](references/DISTRIBUTION.md)
- [references/APP-STORE-REVIEW.md](references/APP-STORE-REVIEW.md)
## Referenceルーティング

| タスク | 読むreference |
|---|---|
| SwiftUI/UIKit選定、相互運用、状態、並行処理、オフライン同期、Xcode構成 | [FRAMEWORKS-ARCHITECTURE.md](references/FRAMEWORKS-ARCHITECTURE.md) |
| App/Scene、状態復元、BackgroundTasks、通知 | [APP-LIFECYCLE.md](references/APP-LIFECYCLE.md) |
| iPhone/iPad、可変ウインドウ、性能、テスト、診断 | [DEVICE-QUALITY.md](references/DEVICE-QUALITY.md) |
| Privacy Manifest、Required Reason API、ATT、権限、削除 | [PRIVACY.md](references/PRIVACY.md) |
| 署名、App Store Connect、TestFlight、version、release | [DISTRIBUTION.md](references/DISTRIBUTION.md) |
| App Review Guidelines、IAP、metadata、reject対応 | [APP-STORE-REVIEW.md](references/APP-STORE-REVIEW.md) |

referenceはすべてINSTRUCTIONS.mdから1階層で到達する。referenceから別referenceをたどる前提にしない。
## Apple公式の入口

- Apple Developer Documentation: https://developer.apple.com/documentation/
- SwiftUI: https://developer.apple.com/documentation/swiftui/
- UIKit: https://developer.apple.com/documentation/uikit/
- Swift Concurrency: https://developer.apple.com/documentation/swift/concurrency
- BackgroundTasks: https://developer.apple.com/documentation/backgroundtasks
- UserNotifications: https://developer.apple.com/documentation/usernotifications
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Accessibility: https://developer.apple.com/accessibility/
- Testing with Xcode: https://developer.apple.com/documentation/xctest
- Performance: https://developer.apple.com/documentation/xcode/improving-your-app-s-performance
- Privacy manifests: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Required Reason API: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- App Privacy Details: https://developer.apple.com/jp/app-store/app-privacy-details/
- User privacy and data use: https://developer.apple.com/jp/app-store/user-privacy-and-data-use/
- Code signing: https://developer.apple.com/jp/support/code-signing/
- Certificates Help: https://developer.apple.com/help/account/certificates/certificates-overview/
- TestFlight: https://developer.apple.com/jp/testflight/
- App Review Guidelines: https://developer.apple.com/jp/app-store/review/guidelines/
- App Store Connect Help: https://developer.apple.com/jp/help/app-store-connect/
- Distribution: https://developer.apple.com/jp/distribute/
## 実装完了ゲート

- [ ] 要件、対象OS、iPhone/iPad、入力方式を確認した
- [ ] 採用APIのAvailabilityをApple公式で確認した
- [ ] SwiftUI/UIKitとnavigation/lifecycle ownerを決めた
- [ ] state ownershipとdata flowが一方向である
- [ ] loading、empty、error、offline、cancellationを扱った
- [ ] App/Scene遷移と状態復元を確認した
- [ ] persistence migrationとnetwork failureをテストした
- [ ] background taskとnotificationの期限・completionを処理した
- [ ] 単体、統合、UI、性能の必要なテストを通した
- [ ] Simulatorと該当実機で検証した
- [ ] iPad可変ウインドウと複数Sceneを該当範囲で確認した
- [ ] applying-apple-higを併用してUIとアクセシビリティを確認した
- [ ] data inventory、権限、Privacy Manifestを実装に照合した
- [ ] 固定数値や時限条件をApple公式で再確認した
- [ ] 既存機能と既存データを破壊していない
## リリース完了ゲート

- [ ] Release構成でarchiveできる
- [ ] Bundle ID、version、build、signing、entitlementが整合する
- [ ] dSYMとarchiveを保管できる
- [ ] サードパーティSDKのmanifestと署名要件を確認した
- [ ] App Privacy、privacy policy、manifest、実装が一致する
- [ ] purpose stringと権限拒否時の動作を確認した
- [ ] account deletion、IAP、UGC等の該当要件を確認した
- [ ] TestFlightでmigrationと主要フローを実機確認した
- [ ] crash、hang、performance、feedbackを確認した
- [ ] App Review情報、demo account、審査メモを用意した
- [ ] metadata、screenshot、年齢制限、輸出申告を確認した
- [ ] 最新のSDK提出条件、審査条項、上限値を公式で再確認した
- [ ] リリース後の監視、停止、前方修正手順を決めた
## レビュー報告形式

完了報告には次を含める。

1. 対象OS、デバイス、Xcode、SwiftUI/UIKit方針
2. 必須、原則採用、条件付きの判断
3. 実装したstate、data flow、lifecycle、data境界
4. テスト、実機、性能、アクセシビリティの結果
5. privacy、署名、TestFlight、App Reviewの確認結果
6. 参照したApple公式URLと確認日
7. 仮定、未確認事項、残るリスク

## 禁止事項

- Apple以外の二次資料を規範根拠にする
- 古いSDK提出条件、条項番号、理由コード、証明書上限を固定知識で断定する
- iPhoneの固定画面幅、portrait、touchだけを前提にする
- iPadを常にfull screenまたはregular widthと仮定する
- UI実装でapplying-apple-higを省略する
- SwiftUI/UIKitの状態とnavigationを二重管理する
- background実行や通知配信の時刻を保証する
- 権限、tracking、SDKデータ収集を実装後まで放置する
- Simulatorだけで性能とリリース品質を判定する
- 審査提出前にdemo account、backend、metadataの動作確認を省略する
