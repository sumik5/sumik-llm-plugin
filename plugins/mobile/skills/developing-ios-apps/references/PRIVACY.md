# プライバシー要件（必須コンプライアンス）

> 出典: Apple Human Interface Guidelines / Apple Developer Documentation（最終確認 2026-07-13）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。日本語版がある場合は公式の言語切替または本文の日本語 URL を使い、英語版との差分がある場合は最新側を確認する。

> 鮮度補正: Privacy Manifestの適用範囲、Required Reason APIカテゴリ・理由コード・開始日、manifest/署名が必要なSDK一覧、App Privacy分類、ATT/API導入版、purpose string key、アカウント削除条件は2026-07-13時点のスナップショットである。提出時はApple公式の現行一覧とApp Store Connectの申告画面で再確認し、本ファイルのコード・日付・分類だけで判定しないこと。

iOS/iPadOS アプリのプライバシー要件は「守らなければ App Store リジェクト・実行時クラッシュ・機能不全」に直結する必須コンプライアンスである。実装前にこのファイル全体を確認し、該当する項目をすべて満たすこと。

---

## App Privacy Details（プライバシーラベル / App Privacy Details）

### 概要

App Store に提出するすべてのアプリ（新規・アップデート）は、App Store Connect で「プライバシーラベル（栄養表示ラベル）」の申告が必須。申告内容は (1) 収集するデータの種類、(2) データがユーザー/デバイスに紐付くか（Linked to You）、(3) トラッキングに使われるか（Used to Track You）の 3 軸で構成される。

### 🔴 必須（遵守事項）

- 提出前に App Store Connect でデータ収集の申告を完了すること（未申告では提出不可）。
- **サードパーティ SDK が収集するデータも自社収集と同様に申告すること**（デベロッパはアプリ内の全コードに責任を負う。SDK 提供元にデータ収集内容・トラッキング目的の有無を確認し記録を残す）。
- WebView 経由で収集するデータも申告対象に含めること（汎用 Web ブラウジング用途の WebView のみ除外）。
- 子ども向け/無料/有料などユーザー区分で収集ポリシーが異なる場合は、**すべての区分の収集を合算して**申告すること。
- プライバシーポリシーの URL を必ず登録すること（プライバシー選択 URL は任意だが推奨）。
- 収集ポリシーを変更したら、アプリのアップデート提出を待たずに App Store Connect 上で申告を即時更新すること（正確性の維持はデベロッパの責任）。
- 過小申告をしないこと（発覚時は審査却下・アプリ削除の対象）。

### データカテゴリ（申告時の分類基準）

| カテゴリ | 代表例・判断基準 |
|---|---|
| 連絡先情報 | 氏名・メール・電話番号・住所。**ハッシュ化済みでも対象** |
| 健康とフィットネス | HealthKit・Clinical Health Records・Motion/Fitness API のデータ |
| 財務情報 | 支払い情報・与信・収入。外部決済サービスが処理しデベロッパが受領しない分は対象外 |
| 位置情報 | **緯度経度が小数点以下 3 桁以上 = 「正確な位置情報」**、それ未満 = 「おおよその位置情報」 |
| 機密情報 | 人種・性的指向・妊娠・障がい・宗教・政治的意見・生体情報等 |
| 連絡先（アドレス帳） | 電話帳・ソーシャルグラフ |
| ユーザーコンテンツ | 写真/動画・音声録音・アプリ内メッセージ・ゲームのセーブデータ・サポート問い合わせ内容 |
| 閲覧履歴 / 検索履歴 | アプリ外 Web 閲覧 / アプリ内検索クエリ |
| ID | ユーザー ID・デバイス ID（IDFA 等） |
| 購入 / 使用状況データ / 診断 | 購入履歴 / タップ・スクロール等の操作ログ・広告インプレッション / クラッシュログ・起動時間等 |
| 周囲環境・身体 | 環境スキャン（メッシュ・画像検出）・手/頭部の動き |

### 「収集」に該当しない（申告不要となる）条件

| 状況 | 条件 |
|---|---|
| 一時利用のみ | リクエスト処理後すぐ破棄される認証トークン・IP アドレス等（サーバに保持しない） |
| オンデバイス処理のみ | サーバへ送信せずデバイス上でのみ処理 |
| 即時粗粒度化 | 正確な位置情報を取得直後に粗粒度化して保存 → 「おおよその位置情報」として申告 |
| Apple フレームワーク側の収集 | MapKit・CloudKit・App Analytics 等、Apple が収集する分の申告責任はデベロッパにない |
| 任意開示の例外 | トラッキング/広告/マーケティングに不使用・主要機能外・低頻度・UI 上で明示的にユーザーが入力（例: 任意のフィードバックフォームの氏名/メール）— **全条件を満たす場合のみ** |

### よくある違反・注意点

- 分析 SDK・広告 SDK・クラッシュレポート SDK の収集分の申告漏れ（最頻出の重大違反）。
- 自由記述テキストは「その他のユーザーコンテンツ」、音声録音は「オーディオデータ」など、実態に合うカテゴリへ正確に分類していない。
- 「Linked to You」の判定漏れ: アカウント ID やデバイス ID と結合可能な形で保存していれば「紐付けあり」。

公式: https://developer.apple.com/jp/app-store/app-privacy-details/

---

## Privacy Manifest（PrivacyInfo.xcprivacy）

### 概要

Privacy Manifest は、アプリおよびサードパーティ SDK が「収集するデータ」「Required Reason API の使用理由」「トラッキング有無・トラッキングドメイン」を機械可読形式で申告するプロパティリスト。対象platform、bundle、提出物に対する現行の必須条件はApple公式で確認する。Xcode はアプリと依存 SDK の manifest を集約してPrivacy Reportを生成し、App Store Connectが提出時に検証する。

### 🔴 必須（該当する場合の遵守事項）

- まず、実際に使うRequired Reason API、収集データ、tracking、組み込むSDK、各bundleについて、manifestが必要となる現行条件をApple公式で判定する。空のmanifestを全アプリへ一律必須とみなさない。
- manifestを用意する場合、ファイル名は **`PrivacyInfo.xcprivacy` 固定**とする（Xcode: File > New File > Resource > App Privacy File で作成し、該当ターゲットの Bundle Resources に追加する）。
- 以下 4 つのトップレベルキーを実態に合わせて記述すること。

| キー | 型 | 内容 |
|---|---|---|
| `NSPrivacyTracking` | Boolean | ATT の定義するトラッキングを行うか |
| `NSPrivacyTrackingDomains` | Array\<String\> | トラッキングに使うドメイン一覧。**`NSPrivacyTracking = true` なら必須**。ユーザーが ATT で拒否した場合、これらのドメインへの通信は OS によって失敗させられる |
| `NSPrivacyCollectedDataTypes` | Array\<Dictionary\> | 収集データの種類・目的・紐付け有無・トラッキング有無（プライバシーラベルと整合させる） |
| `NSPrivacyAccessedAPITypes` | Array\<Dictionary\> | Required Reason API のカテゴリと使用理由コード |

必要と判定したmanifestは対象bundleごとに独立して同梱し、アプリ本体のファイルで別bundleやSDKの申告責任を代替しない。

- 2024年5月1日は確認時点のApple資料に記載された施行上の節目である。現在の提出可否は、使用API、bundle、SDKを現行のRequired Reason API資料とApp Store Connect要件に照合して判定する。
- 申告した理由**以外の目的**で当該 API や派生データを使用しないこと（トラッキング目的での使用は理由コードに関わらず禁止）。

### Required Reason API（NSPrivacyAccessedAPITypes）

フィンガープリンティングに悪用され得るAPI群は、現行ルールで該当する場合に許可された理由コードの申告が必要になる。次表は確認時点の検索索引であり、コードをコピーして提出してはならない。最新のカテゴリ、対象API、理由コード、許容用途を公式ドキュメントで確認すること。

| カテゴリ（`NSPrivacyAccessedAPIType`） | 対象 API 例 | 代表的な理由コード |
|---|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `creationDate`・`modificationDate`・`fileModificationDate` | `C617.1`（アプリコンテナ内のファイル日時をユーザー表示）・`DDA9.1`・`3B52.1` |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `systemUptime`・`mach_absolute_time()` | `35F9.1`（アプリ内イベントの経過時間計測）・`8FFB.1` |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `volumeAvailableCapacityKey`・`systemFreeSize` | `E174.1`（容量不足時のユーザー通知）・`85F4.1` |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | `activeInputModes` | `3EC4.1`（カスタムキーボードアプリ）・`54BD.1` |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `UserDefaults` | `CA92.1`（自アプリからのみアクセス）・`1C8F.1`（同一 App Group 内） |

- `UserDefaults` のような日常的APIも現行リストの対象になり得る。ほぼすべてのアプリで特定コードが必要と固定せず、実際に呼ぶAPI、アクセス範囲、許容理由を現行公式一覧に照合する。

### サードパーティ SDK 要件

- Appleが公開する「privacy manifestと署名が必要なSDK」の現行リスト、およびRequired Reason API・データ収集・tracking domainに関する現行条件を確認する。該当するSDKは、Appleが現在要求する単位と形式でmanifestを同梱しなければならない。
- 該当 SDK を導入する側は、manifest と署名（signature）付きのバージョンを使用すること。manifest 非同梱の古い SDK バージョンは提出却下の原因になる。
- 自作SDKを配布する場合は、XCFramework / Swift Package / Xcode project / 静的ライブラリごとの現行同梱手順をApple公式で確認する。Xcode 15以降という記述は確認時点の導入情報であり、現在の最低条件として固定しない。

### よくある違反・注意点

- SDK が内部で `UserDefaults` 等を使っているのに自アプリの manifest にしか記載がない（バンドル単位申告の理解漏れ）。SDK 側 manifest の有無を必ず確認する。
- `NSPrivacyTracking = true` なのに `NSPrivacyTrackingDomains` が空。
- manifest の申告とプライバシーラベルの申告が矛盾している（審査で照合される前提で整合させる）。

公式: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
公式: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

---

## App Tracking Transparency（ATT・IDFA）

### 概要

「トラッキング」= アプリで収集したユーザー/デバイスデータを、ターゲット広告・広告効果測定のために他社のアプリ/Web サイト由来のデータと紐付けること、またはデータブローカーへ共有すること。最終確認時点ではiOS/iPadOS 14.5以降でAppTrackingTransparency frameworkによる許可が必要と案内されていた。実装時は対象OSのAvailabilityとAppleの現行定義を再確認する。

### 🔴 必須（遵守事項）

- トラッキングする場合は `ATTrackingManager.requestTrackingAuthorization` を呼び、`.authorized` の場合のみトラッキング・IDFA 利用を行うこと。
- Info.plist に **`NSUserTrackingUsageDescription`**（Purpose String）を設定すること。未設定ではシステムの許可アラートが表示されない。
- 許可が得られない限り IDFA は取得不可（全ゼロの値が返る）。`ASIdentifierManager.shared().advertisingIdentifier` は `.authorized` 時のみ有効。
- **フィンガープリンティングは ATT の許可有無に関わらず全面禁止**（デバイス/OS 設定・ネットワーク情報などのシグナルからデバイスを一意識別する行為。違反は却下対象）。
- ユーザーが ATT を拒否した場合、その選択を常に尊重すること。GDPR/ePrivacy 対応で独自の同意 UI（CMP）を併用する場合でも、**ATT の回答を他の同意で上書きしてはならない**。
- トラッキングへの同意を機能提供の条件にしないこと。5.1.2系という番号は確認時点の索引であり、同意とインセンティブに関する現行条項を提出時に確認する。
- アプリ機能の一部として表示する WebView 内のトラッキングにも ATT が必要（汎用 Web ブラウジング用途は除外）。
- SSO やログイン SDK が他社アプリの広告最適化にデータを使う場合もトラッキングに該当し得る。SDK の挙動を確認すること。

### 認可ステータスの取り扱い

| `ATTrackingManager.AuthorizationStatus` | 意味 | 実装上の対応 |
|---|---|---|
| `.notDetermined` | 未回答（初期状態） | プロンプト表示可能。この状態でトラッキングしてはならない |
| `.authorized` | 許可 | IDFA・トラッキング可 |
| `.denied` | 拒否 | トラッキング禁止。SKAdNetwork 等プライバシー保護型の計測へフォールバック |
| `.restricted` | ペアレンタルコントロール等で制限 | プロンプト自体が表示されない。拒否と同様に扱う |

### 推奨

- プロンプト表示前に、トラッキングの価値をアプリ独自の画面（pre-prompt）で説明してよい。ただしシステムプロンプトの文言・選択肢を模倣/誘導する UI は不可。
- 広告アトリビューションはトラッキング許可に依存しない **SKAdNetwork**（アプリ広告）/ **Private Click Measurement**（Web 広告）を第一選択にする。
- 拒否ユーザーにはコンテキスト広告（アプリ内の文脈ベース）で運用を継続する設計にする。

### よくある違反・注意点

- ATT プロンプトを出さずに IDFA 取得コードを残置（値が取れないだけでなく審査で検出される）。
- 起動直後・文脈なしでの即時プロンプト表示（拒否率が最大化する。タイミングは自由だが、価値説明後が有効）。
- `.notDetermined` のまま広告 SDK を初期化し、SDK が先にトラッキングを開始してしまう（SDK 初期化を許可フロー後に遅延させる）。

公式: https://developer.apple.com/documentation/apptrackingtransparency
公式: https://developer.apple.com/jp/app-store/user-privacy-and-data-use/

---

## Info.plist の Purpose String（利用目的の説明文字列）

### 概要

保護されたリソース（カメラ・位置情報・マイク等）へアクセスする際、システムはユーザーに許可アラートを表示する。アラートに載せる説明文（Purpose String）は Info.plist のキーとして**事前定義が必須**であり、**キーが無い状態で該当 API にアクセスするとアプリは即クラッシュする**（審査以前に実行時に落ちる）。

### 🔴 必須（遵守事項）

- 使用する保護リソースごとに、対応するUsage Description keyをInfo.plistに定義する。次表は確認時点の主要key索引であり、対象OS・APIの現行ドキュメントでkey名と必要条件を再確認する。

| キー | 対象リソース |
|---|---|
| `NSCameraUsageDescription` | カメラ |
| `NSMicrophoneUsageDescription` | マイク |
| `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription` | 写真ライブラリ（読取 / 追加のみ） |
| `NSLocationWhenInUseUsageDescription` | 位置情報（使用中のみ） |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | 位置情報（常時 + 使用中） |
| `NSContactsUsageDescription` | 連絡先 |
| `NSCalendarsFullAccessUsageDescription` / `NSRemindersFullAccessUsageDescription` | カレンダー / リマインダー |
| `NSFaceIDUsageDescription` | Face ID |
| `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` | HealthKit 読取 / 書込 |
| `NSMotionUsageDescription` | モーション・フィットネス |
| `NSBluetoothAlwaysUsageDescription` | Bluetooth |
| `NSLocalNetworkUsageDescription` | ローカルネットワーク |
| `NSSpeechRecognitionUsageDescription` | 音声認識 |
| `NSUserTrackingUsageDescription` | トラッキング（ATT） |

- Purpose String には「**何のデータを・何のために使うか**」を具体的に書くこと。空文字・「アプリがカメラを使用します」のような同語反復・プレースホルダ文言を避け、提出時は現行のAPI契約とApp Review Guidelinesを再確認する。
  - 良い例: 「商品のレビュー写真を撮影するためにカメラを使用します」
  - 悪い例: 「カメラを使用します」「For camera access」
- ローカライズ対象言語すべてで `InfoPlist.strings` により Purpose String を翻訳すること。

### よくある違反・注意点

- 依存 SDK が内部で保護 API に触れており、自分のコードでは使っていないのにクラッシュ/リジェクトされる（例: 広告 SDK が位置情報 API を参照）。使用キーは依存関係込みで洗い出す。
- デバッグ用に追加した権限キーを本番でも残置し、「使っていない権限の申告」で審査質問を受ける。使わない権限のキーは削除する。
- 位置情報で「常時」を最初から要求する（後述のタイミング原則に反する。まず When In Use を取得し、必要になった時点で Always に昇格させる）。

公式: https://developer.apple.com/jp/app-store/user-privacy-and-data-use/

---

## データ最小化と権限要求のタイミング

### 概要

Apple のプライバシー原則の中核は「データ最小化（必要最小限のデータのみ・必要最小限の権限で）」と「文脈のある権限要求（ユーザーが理由を理解できるタイミングで求める）」。設計段階でデータフローを図示し、各データについて収集の必要性を検証してから実装すること。

### 🔴 必須（遵守事項）

- 機能の実現に**不要なデータを収集しない**こと。収集する場合も精度・範囲を最小化する（例: 天気表示なら正確な位置ではなくおおよその位置で足りる）。
- 権限の付与を機能全体の利用条件にしないこと（権限拒否時も、当該機能以外は使える設計にする）。
- 権限拒否時にアプリをブロック・繰り返し要求で追い込む UI を実装しないこと。
- オンデバイス処理で足りる処理をサーバへ送らないこと（送らなければプライバシーラベルの「収集」にも該当しない）。

### 推奨（権限要求タイミングの設計原則）

| 原則 | 内容 |
|---|---|
| Just-in-time | 起動直後に一括要求せず、**その権限が必要になる操作の直前**に要求する（例: 写真添付ボタンを押した時に写真ライブラリ許可を要求） |
| 文脈の事前説明 | システムプロンプトの前に、なぜ必要かをアプリ UI で 1 画面説明してよい（Purpose String と矛盾しないこと） |
| 段階的要求 | 位置情報は When In Use → 必要時に Always へ昇格。写真は Limited アクセス（選択した写真のみ）を前提に設計する |
| 拒否時のリカバリ | `.denied` 検出時は設定アプリへの導線（`UIApplication.openSettingsURLString`）と代替手段を提示する |
| API の選択 | 権限プロンプト自体が不要な API を優先する（例: 写真の取得は `PHPicker`、位置の単発取得は `CLLocationButton` / 一時許可）— プロンプトを減らすこと自体が最善のタイミング設計 |

### よくある違反・注意点

- 初回起動時に位置情報・通知・カメラ・ATT を連続要求する「プロンプトの壁」（拒否率が跳ね上がり、一度拒否されるとシステムプロンプトは再表示できない）。
- 権限が拒否された状態を検出せず、機能が黙って動かない（ステータス確認 → 説明 → 設定導線のフローを必ず実装する）。
- 「あると便利」程度のデータをフォーム必須項目にする（データ最小化違反であり、機密カテゴリでは審査指摘対象）。

公式: https://developer.apple.com/jp/app-store/user-privacy-and-data-use/

---

## アカウント削除要件（Account Deletion）

### 概要

最終確認時点のApp Review Guidelinesでは、アカウント作成をサポートするアプリにアプリ内から削除を開始できる機能が求められていた。5.1.1(v)と2022年6月30日は確認時点の条項番号・施行履歴である。提出時に現行条項、対象アカウント、例外、削除方法を再確認する。

### 🔴 必須（遵守事項）

- 削除機能を**アプリ内**（アカウント設定内など発見しやすい場所）に配置すること。
- 削除は「アカウントの一時的な無効化・休眠化」では不十分で、**アカウントレコードと関連個人データ全体の削除**であること（ユーザー生成コンテンツ: 写真・投稿・レビュー等を含む）。法的保持義務があるデータのみ例外（その旨をユーザーに明示する）。
- 削除フローが Web で完結する場合は、アプリ内から**削除ページへの直接リンク**と明確な手順を提示すること（トップページへ飛ばすだけは不可）。
- **Sign in with Apple を提供している場合、アカウント削除時に Sign in with Apple REST API（`revoke_tokens` エンドポイント）でトークンを失効させること**。
- 自動更新サブスクリプションがある場合、削除だけでは課金が止まらないことをユーザーに伝え、キャンセル導線を提供すること（`showManageSubscriptions` の呼び出し、または `https://apps.apple.com/account/subscriptions` へのリンク）。
- 削除に時間がかかる場合（手動処理・段階的削除）は、所要時間の見込みを事前に通知し、完了時に確認を送ること。地域法の期限にも準拠する。
- GDPR/CCPA 対応として一部地域のみに削除機能を出すのは不十分。**全ユーザー**に提供すること（既存の GDPR/CCPA フローを全ユーザーへ拡大するのは可）。
- 現行ガイドラインが例外を認める高規制業界等を除き、削除の前提として電話・メールでの問い合わせを必須化しない。5.1.1(ix)という番号は確認時点の索引としてのみ扱う。

### 推奨

- 誤操作防止のため、削除前の再認証またはメール/SMS コードによる本人確認を挟む。
- 削除の影響（データ消失・サブスクリプションの扱い）を確認画面で警告する。
- 削除のスケジューリング（例: サブスクリプション期間満了後に削除実行）をオプションとして提供する。

### よくある違反・注意点

- 「退会申請フォームへ問い合わせてください」のみで審査リジェクト（アプリ内起点の完結した導線が必要）。
- 論理削除でデータを全て残したまま「削除しました」と表示する実装（削除の実体を伴わない）。
- Sign in with Apple のトークン失効漏れ（削除済みユーザーの Apple ID 連携が生き続ける）。

公式: https://developer.apple.com/support/offering-account-deletion-in-your-app/

---

## 実装前チェックリスト（統合）

| # | チェック項目 |
|---|---|
| 1 | 収集する全データを列挙し、各項目に「収集の必要性・保存先・紐付け・トラッキング有無」を定義したか |
| 2 | App Store Connect のプライバシーラベル申告が SDK 込みの実態と一致しているか |
| 3 | `PrivacyInfo.xcprivacy` を作成し、`NSPrivacyCollectedDataTypes` / `NSPrivacyAccessedAPITypes` を記述したか（`UserDefaults` 使用時の申告を含む） |
| 4 | 依存 SDK がすべて manifest（必要なら署名も）同梱バージョンか |
| 5 | トラッキング/IDFA 使用時: ATT プロンプト実装・`NSUserTrackingUsageDescription`・`NSPrivacyTracking`/`NSPrivacyTrackingDomains` が揃っているか |
| 6 | 使用する保護リソース全部の Purpose String が具体的な文言で Info.plist に定義され、全対応言語に翻訳されているか |
| 7 | 権限要求が Just-in-time で、拒否時のリカバリ導線（設定誘導・代替手段）があるか |
| 8 | アカウント作成があるなら、アプリ内アカウント削除（+ Sign in with Apple の `revoke_tokens`）を実装したか |
