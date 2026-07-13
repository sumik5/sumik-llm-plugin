# 配布・署名・TestFlight・リリース管理

> 出典: Apple Human Interface Guidelines / Apple Developer Documentation（最終確認 2026-07-13）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。日本語版がある場合は公式の言語切替または本文の日本語 URL を使い、英語版との差分がある場合は最新側を確認する。

> 鮮度補正: 証明書の種類・有効期間・作成role・枚数上限、登録端末上限、TestFlight上限と期限、段階的リリース割合、App Storeサイズ条件、代替配布地域は2026-07-13時点のスナップショットである。配布作業の開始時にApple Account Help、App Store Connect Help、TestFlight、Distributionの現行公式ページで再確認し、本ファイルの値を固定契約として使わないこと。

iOS/iPadOS アプリを App Store へ届けるまでの全工程（署名 → App Store Connect 登録 → TestFlight → 審査 → リリース）を、実装判断に直結する形でまとめる。

---

## コード署名とプロビジョニング（Code Signing & Provisioning）

### 概要

iOS 実機で動くバイナリはすべて署名が必須。署名は「証明書（誰が作ったか）」「App ID + Entitlements（何が許可されているか）」「Provisioning Profile（どのデバイス/配布経路で動かせるか）」の 3 要素で構成される。Xcode の自動署名（Automatically manage signing）がこれらを束ねて管理する。

### 主な証明書の種類

| 証明書 | 用途 | 備考 |
|--------|------|------|
| Apple Development | 開発中に実機実行・開発用 App Services 利用（iOS/macOS/tvOS/watchOS 共通） | 対応Xcodeと個人あたりの上限は現行Certificates Helpで確認する |
| Apple Distribution | App Store 提出・Ad Hoc テスト配布（プラットフォーム共通） | 対応Xcodeとチーム上限は現行Certificates Helpで確認する |
| iOS Development / iOS Distribution | 旧来のプラットフォーム別証明書（上記の前身） | 新規は Apple Development/Distribution を使う |
| Apple Push Services / APNs Auth Key | APNs との接続。Auth Key（.p8）はトークンベースの代替方式 | 自動失効、作成上限、role、revoke条件を現行公式で確認する。新規実装ではAuth Keyを第一候補にする |
| Pass Type ID / Apple Pay / Merchant Identity | Wallet パス署名・Apple Pay トランザクション復号など | 必要な機能を使う場合のみ |

### 🔴 必須（遵守事項）

- 証明書ごとの有効期間を現行Certificates Helpで確認し、CIと更新計画へ反映する。失効・更新が配布済みアプリと新規アップロードへ与える影響も証明書種別ごとに確認する。
- Distribution証明書を作成できるroleを現行Account Helpで確認し、CI構築に必要な最小権限で計画する。
- Distribution証明書のチーム上限を現行公式ページで確認する。上限値に関係なく、CIと開発者ローカルで無計画に作り直して既存を失効させてはならない（秘密鍵 .p12 を安全に共有するか、Xcode Cloud の cloud signing / App Store Connect API を使う）。
- App ID の **Capability（Push Notifications・App Groups・Sign in with Apple・HealthKit 等）は Developer アカウント側の App ID 設定と Xcode の Signing & Capabilities タブの両方で一致**していること。不一致は Provisioning Profile の再生成で解消する。
- Entitlements に宣言した権限は実際に使用する機能に限定すること。未使用の Capability の宣言は審査リジェクトの原因になる。
- App Store 配布用に署名したバイナリをローカルで直接起動してはならない（起動不能・検証エラーの原因。Apple も明示的に禁止している）。動作確認は Development 署名か TestFlight で行うこと。

### 推奨

- **自動署名（Automatically manage signing）を既定にする**こと。Xcode が証明書・App ID・Profile の作成/更新/デバイス登録を自動化する。手動署名は「CI で完全に再現可能な署名が必要」「Extension ごとに厳密な Profile 管理が必要」な場合に限定する。
- CI/CD では Xcode Cloud の cloud signing、または `xcodebuild -allowProvisioningUpdates` + App Store Connect API キー（JWT 認証）を使い、証明書ファイルの手作業配布を避ける。
- 署名トラブル時は「証明書の期限 → App ID の Capability 一致 → Profile の期限とデバイスリスト」の順に確認する。Provisioning Profile の技術詳細は TN3125 を参照。
- macOS 向けの `codesign --deep` に相当する「一括で深く署名する」発想は避け、ネストしたバンドル（Extension・Framework）は内側から順に署名する（Xcode に任せれば自動で正しく処理される）。

### よくある違反・注意点

- 「実機で急に起動しなくなった」場合はDevelopment Profileと証明書の期限を確認する。無料アカウント枠とProgramメンバーの有効期間は変わり得るため、7日・1年という確認時点の値を固定せず現行公式ページで確認する。
- チームメンバーが証明書を Revoke すると、同じ証明書に依存する他メンバーや CI のビルドが壊れる。Revoke は影響範囲を確認してから行う。
- Ad Hoc配布はデバイスUDIDの事前登録と現行上限の管理が必要で運用コストが高い。年間・デバイス種別ごとの上限はAccount Helpで再確認し、社外テスターへの配布はTestFlightを第一選択にする。

公式: https://developer.apple.com/jp/support/code-signing/
公式: https://developer.apple.com/help/account/certificates/certificates-overview/

---

## App Store Connect でのアプリ登録とメタデータ（App Store Connect）

### 概要

App Store Connect はアプリレコードの作成、メタデータ管理、ビルド管理、審査提出、売上・分析を一元管理するポータル。アプリの公開には Apple Developer Program メンバーシップと App Review ガイドラインへの準拠が前提となる。

### 🔴 必須（遵守事項）

| 項目 | 要件 |
|------|------|
| アプリレコード | Bundle ID・SKU・プライマリ言語を指定して新規作成。**Bundle ID は一度アプリを作成すると変更不可**のため命名（逆 DNS 形式）を最初に確定すること |
| アプリアイコン | 1024×1024 px のマーケティング用アイコンをアセットカタログに含める（アルファなし） |
| スクリーンショット | 対応デバイスサイズごとに必須。公式のスクリーンショット仕様（サイズ・フォーマット）に従うこと |
| 説明・キーワード | 説明文は最初の数行で価値が伝わるように書く。キーワードは検索性を考慮 |
| 年齢制限指定 | コンテンツ内容のアンケートに正確に回答して設定（虚偽はリジェクト/削除対象） |
| プライバシー | プライバシーポリシー URL と「アプリのプライバシー」（収集データの種類・用途・トラッキング有無）の申告が必須。**実装（SDK 含む）と申告を一致させること** |
| 輸出コンプライアンス | 暗号化利用の有無を申告。HTTPS 等の標準的な暗号のみなら `ITSAppUsesNonExemptEncryption = NO` を Info.plist に設定すると毎回の質問をスキップできる |
| 契約・税務 | 有料アプリ/アプリ内課金は Paid Applications 契約への署名・口座/税務情報の入力が完了していないと販売できない |

### ビルドのアップロード

- ビルドは **Xcode（Organizer → Distribute App）または Transporter** でアップロードする。自動化は App Store Connect API（JWT 認証）+ Transporter コマンドラインが推奨経路。
- アップロード後の処理（Processing）完了を待ってから TestFlight 配布・審査提出のビルド選択が可能になる。

### 推奨

- メタデータのローカライズは主要市場の言語分を用意する（日本市場向けなら日本語 + 英語が最低線）。
- App Analytics で売上・ユーザー行動を追跡し、スクリーンショットや説明文の改善に反映する。
- アプリ内購入・アセットパックはアプリ本体と同じ提出フローで審査に出せる。初回はアプリバージョンと同時提出すること。

### よくある違反・注意点

- 「アプリのプライバシー」申告漏れ（特にサードパーティ SDK が収集するデータ）はリジェクトの頻出原因。SDK のプライバシーマニフェスト（Privacy Manifest）を確認して申告に反映する。
- スクリーンショットに実機フレーム外の誇張表現やプラットフォーム外機能を載せるとメタデータリジェクトになる。
- デモアカウントが必要なアプリ（ログイン必須）は App Review 情報にテストアカウントを必ず添付する。

公式: https://developer.apple.com/jp/help/app-store-connect/

---

## TestFlight（ベータテスト配布）

### 概要

TestFlight は App Store 公開前のベータ配布基盤。App Store Connect の TestFlight タブからビルドをテスターへ配布し、スクリーンショット付きフィードバックとクラッシュレポートを収集する。iOS/iPadOS を含む全 Apple プラットフォームと App Clip に対応。

### 🔴 必須（遵守事項）— 上限値と要件の確認時点スナップショット

次表は2026-07-13時点の作業用スナップショットである。人数、端末、build数、有効期間、Beta App Reviewの条件は配布開始時にTestFlight公式ページとApp Store Connect Helpで再確認し、確認した値だけを運用計画へ使用する。

| 項目 | 値 |
|------|-----|
| 内部テスター | 最大 **100 人**（Account Holder / Admin / App Manager / Developer / Marketing ロールのチームメンバー） |
| 外部テスター | 最大 **10,000 人** |
| テスターあたりのデバイス数 | 最大 **30 台** |
| 同時共有可能なビルド数 | 最大 **100 個** |
| ビルドの有効期間 | アップロードから **90 日**（期限後はテスター側で起動不可。長期テストは新ビルドを配り直すこと） |
| 外部テストの審査 | **最初のビルドは Beta App Review の承認が必須**。グループにビルドを追加すると自動でレビューに送信される |
| 必須メタデータ | ベータ版アプリの説明文・テスター連絡用メールアドレス・レビュー情報（デモアカウント等） |

### テスター種別の使い分け

- **内部テスター**: UDID や Profile の管理不要。新ビルドの自動配信を設定でき、Beta App Review も不要（即配布）。開発チームの日常ビルド確認はこちら。
- **外部テスター**: メール招待（特定個人向け）と**パブリックリンク**（広く募集。デバイスタイプ・OS バージョン等の応募条件を設定可能）の 2 方式。社外ベータはこちら。

### 推奨

- テスターグループを複数作り、グループごとに異なるビルド（安定版/実験版）を配信する。
- パブリックリンクの閲覧数・承諾数・条件不適合数でリクルーティング効果を測定し、**テスター数が上限に達したらリンクを速やかに無効化する**こと。
- テスターメトリクス（セッション数・クラッシュ数・フィードバック数）でエンゲージメントを確認し、非アクティブなテスターは整理する。
- フィードバックはプラットフォーム・OS バージョンでフィルタして傾向を分析する。公開予定ビルドはすべてのフィードバック反映を確認してから App Review へ提出する。
- 段階的な信頼度で流す標準フロー: **内部テスト → 外部ベータ（Beta App Review）→ App Review 提出 → 段階的リリース**。

### よくある違反・注意点

- 外部ベータの初回 Beta App Review には日数がかかることがある。リリース日程に外部ベータ開始を組み込む場合は前倒しで提出する。
- Beta App Review は本審査より軽いが、ガイドライン違反（未完成すぎる・クラッシュ多発）は却下される。内部テストで最低限の安定性を確保してから外部に出すこと。
- TestFlightビルドはあくまでベータであり、恒久的な配布手段として使い続けてはならない。buildの現行有効期間を公式で確認し、期限前に次の配布判断を行う。

公式: https://developer.apple.com/jp/testflight/

---

## バージョニング（CFBundleShortVersionString / CFBundleVersion）

### 概要

iOS アプリのバージョンは 2 系統で管理する。Xcode のターゲット設定では Version（= `CFBundleShortVersionString`）と Build（= `CFBundleVersion`）に対応する。

| キー | Xcode 表示 | 役割 | 例 |
|------|-----------|------|-----|
| `CFBundleShortVersionString` | Version | ユーザー向けリリースバージョン。App Store に表示される | `1.4.0` |
| `CFBundleVersion` | Build | ビルド識別番号。同一バージョン内でビルドを区別する | `1042` / `1.4.0.7` |

### 🔴 必須（遵守事項）

- `CFBundleShortVersionString` は **ピリオド区切りの数値（最大 3 コンポーネント: major.minor.patch）** で構成すること（例: `1.0`, `2.3.1`）。文字列サフィックス（`1.0-beta` 等）を入れてはならない。
- **App Store に提出する新バージョンの `CFBundleShortVersionString` は、公開済みバージョンより大きい値**でなければならない（下げる・同値で再提出は不可）。
- **同一バージョン内で再アップロードするビルドは `CFBundleVersion` を必ず増加**させること。同一 (version, build) の組は App Store Connect に再アップロードできない。
- 2 つの値の大小比較は数値としてコンポーネント単位で行われる。`CFBundleVersion` にゼロ埋めや日付文字列を使う場合も単調増加を保証すること。

### 推奨

- Semantic Versioning（major.minor.patch）を `CFBundleShortVersionString` に採用し、破壊的変更/機能追加/修正で桁を使い分ける。
- `CFBundleVersion` は CI のビルド番号やコミット数から自動採番し（`agvtool next-version -all` や `xcrun agvtool`、fastlane の `increment_build_number` 等）、手動更新を排除する。
- クラッシュレポートや問い合わせ対応のため、アプリ内の「情報」画面には version と build の両方を表示する（`Bundle.main.object(forInfoDictionaryKey:)` で取得）。

### よくある違反・注意点

- 「Processing 後にビルドが消えた/アップロードが弾かれた」は build 番号の重複が典型原因。
- TestFlight 配布中のビルドと審査提出ビルドで version を揃え、build だけ進める運用にすると、テスト済みバイナリをそのまま審査に出せる。
- マーケティング上の「バージョン表記」と `CFBundleShortVersionString` を乖離させない（審査メタデータの「このバージョンの新機能」との不整合を避ける）。

公式: https://developer.apple.com/jp/help/app-store-connect/
公式: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring

---

## 審査提出フローと段階的リリース（App Review & Phased Release）

### 審査提出フロー

標準的な提出手順:

1. App Store Connect で新規バージョンを作成（「このバージョンの新機能」を記載）
2. Processing 済みビルドをバージョンに紐付け
3. 輸出コンプライアンス・広告識別子（IDFA）利用の申告
4. App Review 情報（連絡先・デモアカウント・審査メモ）を記入
5. リリース方法を選択して審査へ提出

### 🔴 必須（遵守事項）

- 提出前に App Review ガイドラインを確認し、よくある却下理由（未完成・クラッシュ・プライバシー申告不備・課金ガイドライン違反）を潰しておくこと。
- **App Reviewからのメッセージには速やかに返信**すること。48時間という記述は確認時点の運用目安であり、固定期限として断定しない。App Store Connectに表示される現行の期限・要求を確認する。
- リリース方法は提出時に選択する: **自動リリース**（承認後即公開）/ **手動リリース**（デベロッパによるリリース待ち）/ **日時指定リリース**。マーケティングと同期する場合は手動または日時指定を選ぶこと。
- 緊急のバグ修正は expedited review（優先審査）を申請できるが、乱用してはならない（常用すると認められなくなる）。

### 段階的リリース（Phased Release for Automatic Updates）

自動アップデートを有効にしているユーザーへ段階的にアップデートを配信する仕組み。問題検知時に被害を限定できるため、ユーザー基盤の大きいアプリでは採用を検討する。期間と割合は変わり得るため、リリース設定時にApp Store Connect Helpで確認する。

次表の7日間と割合は2026-07-13時点のスナップショットであり、固定された将来仕様ではない。

| 経過日 | 自動アップデート対象ユーザーの割合 |
|--------|--------------------------------|
| 1 日目 | 1% |
| 2 日目 | 2% |
| 3 日目 | 5% |
| 4 日目 | 10% |
| 5 日目 | 20% |
| 6 日目 | 50% |
| 7 日目 | 100% |

仕様の要点:

- 対象は**自動アップデートのみ**。App Store から手動で更新するユーザーは割合に関係なく**いつでも新バージョンを取得できる**（= 段階的リリース中も新バージョンは全ユーザーに「見えて」いる）。
- 一時停止の合計期間、回数、再開位置は現行App Store Connect Helpで確認する。30日・回数無制限は確認時点のスナップショットである。
- いつでも「全ユーザーへ即時リリース」に切り替え可能。
- 段階的リリースは提出準備中〜審査中〜デベロッパによるリリース待ち等のステータスで設定できる。
- **アプリを App Store から削除すると段階的リリースは停止し、そのバージョンでは二度と再開できない**。復活時は全ユーザーへ即時リリースされる。
- 完了時に Admin / App Manager ロールへ通知が送られる。

### 推奨

- 段階的リリース中はクラッシュ率・主要 KPI を毎日監視し、異常があれば即座に一時停止 → 修正版を新バージョンとして提出する（**公開済みビルドの差し替えはできない**。ロールバックも不可のため、前方修正が唯一の回復手段）。
- サーバーAPIの互換性を保ち、旧バージョンと新バージョンが段階的リリース期間以上併存する前提で設計する。期間はリリース設定時の現行仕様で決める。
- リリースノート（このバージョンの新機能）はユーザー向けの言葉で書き、審査用の内部メモは App Review 情報欄に分離する。

### よくある違反・注意点

- 段階的リリースを「フィーチャーフラグの代替」と誤解しない。配信割合の制御はできるが、**特定ユーザー群への出し分けはできない**。A/B テストが必要ならアプリ内のリモートフラグで行う。
- 手動リリース待ちのまま長期間放置すると、審査承認が失効して再提出が必要になる場合がある。
- 審査却下時はメッセージで反論・説明が可能（Reply to App Review）。修正不要と考える場合も、まず具体的な根拠を返信すること。

公式: https://developer.apple.com/jp/help/app-store-connect/update-your-app/release-a-version-update-in-phases

---

## App Thinning（アプリサイズ最適化）

### 概要

App Thinning は、App Store がユーザーのデバイスに合わせて最適化されたバイナリ/リソースだけを配信する仕組みの総称。開発者は単一の App Bundle（.ipa）をアップロードするだけでよい。

| 構成要素 | 内容 |
|---------|------|
| App Slicing | デバイスのアーキテクチャ・GPU・画面スケール（@2x/@3x）に応じ、不要なバイナリスライスと画像バリアントを除いて配信する |
| Bitcode（廃止） | かつての中間表現による再最適化機構。Xcode 14以降という廃止時期は履歴情報であり、現行Xcodeの設定とApple公式資料を確認する |
| On-Demand Resources (ODR) | 使用時に初めてダウンロードされるリソース（ゲームの後半ステージ等）をタグ付けして App Store にホストさせる |

### 🔴 必須（遵守事項）

- **画像・カラー・データはアセットカタログ（Asset Catalog）に入れる**こと。App Slicing はアセットカタログを前提に動作する。バンドル直下のばら置き画像はスライスされず全デバイスに配信される。
- App Storeのダウンロード・インストールサイズと、ネットワーク条件に応じた現行のユーザー体験を確認する。約200MBという記述は過去・確認時点の目安としてのみ扱い、現行の閾値や警告動作を固定要件としない。必要ならODRや初回起動後ダウンロードで分割する。
- サイズ計測は自分の Mac 上の .ipa サイズで判断せず、**App Store Connect の「App Store ファイルサイズ」レポート（デバイス別のダウンロード/インストールサイズ）** または Xcode の App Size Report（App Thinning Size Report）で確認すること。

### 推奨

- Universal Purchase / 複数デバイス対応でも、デバイス別サイズは Slicing で自動最適化されるため、手動でターゲットを分割しない。
- 大容量の学習済みモデルや動画チュートリアルは ODR タグを付け、`NSBundleResourceRequest` でプリフェッチ/取得する。ODR は OS がストレージ圧迫時にパージし得るため、再ダウンロード可能な設計にすること。
- ビルド設定では Dead Code Stripping、`SWIFT_OPTIMIZATION_LEVEL` の Release 設定（`-O`）、未使用アーキテクチャ/リソースの削除を確認する。

### よくある違反・注意点

- TestFlight で配布されるビルドは thinning 前の Universal に近いサイズで届く場合があり、TestFlight のサイズ ≠ App Store のサイズ。ユーザー向けサイズは必ずサイズレポートで確認する。
- ODR リソースへ初回アクセスするフローがオフラインだと機能不全になる。ダウンロード失敗時の UI（リトライ・進捗表示）を必ず実装すること。

公式: https://developer.apple.com/documentation/xcode/reducing-your-app-s-size

---

## EU の代替配布（Alternative Distribution・概要のみ）

### 概要

デジタル市場法（DMA）への対応として、Apple は特定地域で App Store 以外の配布経路を提供している。地域により利用可能なオプションが異なる。

| 地域 | 確認時点で案内されていたオプション |
|------|--------------------|
| 欧州連合（EU） | 代替アプリマーケットプレイス経由の配布・Web サイトからの直接配布（Web Distribution）・代替決済 |
| ブラジル | App Store 外での配布・代替決済 |
| 日本 | 代替配布オプション（順次展開） |

この地域表は確認時点の索引である。対象国・地域、利用資格、契約条件、手数料、利用可能なAPIと配布方式は流動的なため、採用前にApple Distributionの現行公式ページで対象ストアフロントを再確認する。

### 実装判断のポイント

- 代替配布を選んでも **Apple の公証（Notarization）に相当する審査（基本的なプラットフォーム要件・マルウェアチェック）は必須**であり、署名・Entitlements の枠組みは App Store 配布と共通。無審査で任意のバイナリを配れる仕組みではない。
- 代替マーケットプレイス配布・Web Distribution には追加の契約条件（Alternative Terms）と手数料体系、および資格要件（Web Distribution はデベロッパの実績要件等）が課される。採用判断はビジネス条件を含めて検討すること。
- 対象は該当地域のユーザーのみ。**グローバル配布の主経路は引き続き App Store** であり、本リファレンスの署名・TestFlight・審査フローはそのまま適用される。
- 仕様・対象地域・条件は流動的なため、着手前に必ず公式の配布ページで最新状態を確認すること。

公式: https://developer.apple.com/jp/distribute/

---

## リリースフロー早見表（推奨標準フロー）

```
1. 自動署名で開発        (Apple Development 証明書 / 実機デバッグ)
2. build 番号を自動採番   (CI で CFBundleVersion 単調増加)
3. アップロード           (Xcode Organizer / Transporter / App Store Connect API)
4. 内部テスター配布       (現行上限・role・review条件を公式で確認)
5. 外部ベータ             (現行上限・Beta App Review・build期限を公式で確認)
6. メタデータ確定         (スクリーンショット仕様準拠・プライバシー申告・年齢制限)
7. 審査提出               (デモアカウント添付・リリース方法を選択)
8. 段階的リリース         (現行の期間・割合・一時停止条件を公式で確認)
9. 監視                   (クラッシュ率/KPI 日次確認 → 異常時は一時停止し修正版を前方提出)
```
