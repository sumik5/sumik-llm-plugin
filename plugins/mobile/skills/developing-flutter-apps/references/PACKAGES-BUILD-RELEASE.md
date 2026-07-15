# パッケージエコシステム・ビルド・リリース

## 概要

このリファレンスは、pub.dev パッケージエコシステムのカテゴリ別選定基準、入力・フォームのバリデーション、flavor によるビルド環境分離、各プラットフォームのリリースビルド、ストア公開手順、オンデバイス AI/ML 統合を扱う。

状態管理パッケージ（Provider/Riverpod/BLoC 等）は [STATE-MANAGEMENT.md](STATE-MANAGEMENT.md)、ルーティングパッケージ（go_router/auto_route 等）は [NAVIGATION-ROUTING.md](NAVIGATION-ROUTING.md)、ローカル永続化パッケージ（shared_preferences/sqflite/hive/drift/secure_storage 等）は [DATA-NETWORKING.md](DATA-NETWORKING.md) を参照する。本ファイルではこれらを重複掲載せず、ポインタのみとする。

## 1. パッケージ選定の基準

pub.dev の個々のパッケージページで確認できる指標をもとに採否を判断する。

| 観点 | 確認内容 |
|---|---|
| Pub Points / Popularity / Likes | 静的解析適合度・利用実績・コミュニティ評価の目安 |
| null safety 対応 | sound null safety に対応しているか |
| 最終更新日・メンテナンス頻度 | 放置されていないか、Issue への応答があるか |
| ライセンス | 商用利用可否、OSS ライセンスの互換性 |
| プラットフォーム対応表 | pub.dev の Platform 欄で iOS/Android/Web/Desktop の対応可否を確認する |
| 依存の重さ | 推移的依存が過多でビルドサイズ・競合リスクを増やさないか |

同じ用途のパッケージが複数ある場合は、まず公式パッケージ（Flutter/Dart チームや Firebase 等が公開しているもの）を優先し、次にメンテナンス状況が良好なコミュニティパッケージを検討する。

## 2. カテゴリ別代表パッケージ

### 通信

| パッケージ | 特徴 | 選定基準 |
|---|---|---|
| `http` | Dart チーム公式、薄い REST クライアント | シンプルな API 呼び出し中心のアプリ |
| `dio` | インターセプター、リクエストキャンセル、フォームデータ、リトライ拡張が豊富 | 認証トークン付与やリトライ等、横断的な通信制御が必要なアプリ |

具体的な実装パターンは [DATA-NETWORKING.md](DATA-NETWORKING.md) を参照する。

### Firebase 連携

| パッケージ | 用途 |
|---|---|
| `firebase_core` | 全 Firebase パッケージ利用の前提となる初期化 |
| `firebase_auth` | メール/パスワード・ソーシャルログイン等の認証 |
| `cloud_firestore` | ドキュメント指向のリアルタイムデータベース |
| `firebase_messaging` | プッシュ通知（FCM） |

Firebase プラットフォーム自体の詳細（セキュリティルール、Functions、コンソール設定等）は cloud:developing-firebase を参照する。本ファイルでは Flutter 側パッケージの位置づけのみを扱う。

### メディア再生

| パッケージ | 用途 | 選定基準 |
|---|---|---|
| `video_player` | Flutter 公式の動画再生基盤 | シンプルな動画再生、他パッケージの土台 |
| `chewie` | `video_player` に標準的な再生コントロール UI を付与 | 既製の UI（シークバー・全画面切替等）が欲しい場合 |
| `just_audio` | 音声のストリーミング・プレイリスト・バックグラウンド再生に強い | 音楽プレイヤーなど高度な音声制御が必要な場合 |
| `audioplayers` | 複数の短い効果音を同時再生しやすい軽量 API | 効果音・通知音等、単純な音声再生 |

```dart
final player = AudioPlayer();

Future<void> playNotificationSound() async {
  await player.play(AssetSource('sounds/notification.mp3'));
}
```

### UI 拡張

| パッケージ | 用途 |
|---|---|
| `flutter_svg` | SVG 画像のレンダリング |
| `fl_chart` | 折れ線・棒・円グラフ等のデータ可視化 |
| `carousel_slider` | 画像・カード等のカルーセル表示 |
| `flutter_spinkit` | 多様なローディングインジケーター |

```dart
SizedBox(
  height: 200,
  child: LineChart(
    LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: const [FlSpot(0, 1), FlSpot(1, 3), FlSpot(2, 2)],
          isCurved: true,
        ),
      ],
    ),
  ),
)
```

汎用的な UI コンポーネントの選定判断そのもの（デザインシステムとの整合等）は design:building-design-systems も参照する。

### 国際化（i18n）

| パッケージ | 特徴 | 選定基準 |
|---|---|---|
| `intl` | Dart/Flutter チーム公式。ICU メッセージフォーマット、日付・数値のロケール依存フォーマットに強い | ARB ファイルによる公式ワークフローに乗せたい場合 |
| `easy_localization` | JSON/YAML の翻訳ファイルを直接読み込み、セットアップが簡便 | 翻訳ファイル管理を軽量に始めたい場合 |

```dart
// easy_localization の例
Text(context.tr('home.welcome_message'));
```

### コード生成

| パッケージ | 用途 |
|---|---|
| `build_runner` | コード生成タスクの実行基盤（他の *_generator パッケージの土台） |
| `json_serializable` | `toJson`/`fromJson` の自動生成 |
| `freezed`（任意） | イミュータブルなデータクラス・共用体型の生成。`json_serializable` と併用されることが多い |

```dart
// build_runner でコードを再生成する
// dart run build_runner build --delete-conflicting-outputs
```

```dart
@JsonSerializable()
class UserProfile {
  UserProfile({required this.id, required this.name});

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

  final String id;
  final String name;

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
```

### 権限・接続状態・デバイス情報

| パッケージ | 用途 |
|---|---|
| `permission_handler` | カメラ・位置情報・通知等のランタイム権限確認・要求 |
| `connectivity_plus` | ネットワーク接続状態（Wi-Fi/モバイル回線/オフライン）の監視 |
| `device_info_plus` | デバイス・OS バージョン等のメタデータ取得 |
| `package_info_plus` | アプリ自身のバージョン・ビルド番号の取得 |

```dart
final status = await Permission.camera.request();
if (status.isPermanentlyDenied) {
  await openAppSettings();
}
```

権限要求は必要になった箇所で最小限に行い、拒否時の代替導線を必ず用意する。機密情報や個人情報の取り扱いに関する一般的な注意は devkit:securing-code も参照する。

## 3. 入力・フォームのバリデーション

`Form` と `TextFormField`、`GlobalKey<FormState>` を組み合わせるのが標準的な構成である。

```dart
class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
    if (!value.contains('@')) return 'メールアドレスの形式が正しくありません';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            validator: _validateEmail,
            decoration: const InputDecoration(labelText: 'メールアドレス'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // バリデーション成功時の処理
              }
            },
            child: const Text('送信'),
          ),
        ],
      ),
    );
  }
}
```

複雑な入力項目（動的なフィールド追加、ステップ形式のフォーム等）が多い場合は `flutter_form_builder` の採用を検討する。

## 4. Flavor によるビルド環境分離

開発・ステージング・本番のように環境ごとに API エンドポイントやアプリ ID を切り替える場合、flavor（Android の product flavor、iOS のスキーム）と `--dart-define` を組み合わせる。

```dart
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.dev.example.com');
```

```bash
flutter run --dart-define=API_BASE_URL=https://api.staging.example.com
flutter build appbundle --release --flavor production --dart-define=API_BASE_URL=https://api.example.com
```

環境ごとに値が多い場合は `--dart-define-from-file` で JSON ファイルにまとめる。Android 側は `android/app/build.gradle` の `productFlavors`、iOS 側は Xcode の Scheme／Configuration をそれぞれ環境の数だけ用意する。

## 5. リリースビルド

| プラットフォーム | コマンド | 備考 |
|---|---|---|
| Android | `flutter build appbundle --release` | Play Store 提出は AAB（App Bundle）が標準。署名は `key.properties` と `signingConfigs` で設定する |
| iOS | `flutter build ipa --release` | Xcode の署名・プロビジョニングが前提。詳細は developing-ios-apps を参照 |
| Web | `flutter build web --release` | 静的ホスティング（Firebase Hosting 等）へそのままデプロイできる |
| macOS/Windows/Linux | `flutter build macos` / `flutter build windows` / `flutter build linux` | デスクトップは配布形式（notarization、インストーラ形式）がプラットフォームごとに異なる |

Android の署名鍵は `keytool` で生成し、`key.properties` に平文で残さないよう CI のシークレットストアで管理する。iOS の署名・証明書・entitlements の詳細な運用は developing-ios-apps を参照する。

## 6. ストア公開

### Google Play Store

1. Google Play Console でアプリを作成し、AAB をアップロードする。
2. ストア掲載情報（説明文・スクリーンショット・プライバシーポリシー URL）を入力する。
3. 対象の配信トラック（内部テスト・クローズドテスト・本番）を選び審査へ提出する。

### Apple App Store

1. App Store Connect でアプリレコードを作成する。
2. Xcode または Transporter で IPA をアップロードする。
3. メタデータ・スクリーンショット・審査用情報を入力し審査へ提出する。

Flutter の iOS ビルドも内部的には通常の Xcode プロジェクトであるため、証明書・プロビジョニング・TestFlight の運用は developing-ios-apps の方式がそのまま適用できる。**App Store 提出前の最終監査（Info.plist・entitlements・StoreKit 実装等の pass/fail 判定）は auditing-app-store-compliance を使う。**

## 7. オンデバイス AI/ML

### TensorFlow Lite（`tflite_flutter`）

`tflite_flutter` は TensorFlow Lite Interpreter を Flutter から利用するための現行パッケージである（旧 `tflite` パッケージはメンテナンスが終了しているため新規採用しない）。

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

class ImageClassifier {
  ImageClassifier._(this._interpreter);

  final Interpreter _interpreter;

  static Future<ImageClassifier> load() async {
    final interpreter = await Interpreter.fromAsset('assets/model.tflite');
    return ImageClassifier._(interpreter);
  }

  List<double> classify(List<List<List<List<double>>>> input) {
    final output = List.filled(1 * 1000, 0.0).reshape([1, 1000]);
    _interpreter.run(input, output);
    return output.first.cast<double>();
  }

  void close() => _interpreter.close();
}
```

### Google ML Kit（`google_mlkit_*`）

Firebase ML Kit は Google ML Kit（`google_mlkit_text_recognition`、`google_mlkit_face_detection`、`google_mlkit_barcode_scanning` 等の機能別パッケージ）へ移行しており、オンデバイスでテキスト認識・顔検出・バーコード読み取り等を実行できる。

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String> recognizeText(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await recognizer.processImage(inputImage);
    return result.text;
  } finally {
    await recognizer.close();
  }
}
```

`Interpreter` や `TextRecognizer` 等のリソースは使用後に必ず `close()` する。モデルファイルはアプリサイズを増やすため、対象デバイスの性能とダウンロードサイズのバランスを踏まえてモデルを選定する。

## チェックリスト

- [ ] 採用パッケージの pub.dev スコア・メンテナンス状況・プラットフォーム対応を確認した
- [ ] 状態管理／ルーティング／永続化パッケージは各専用ファイルの判断基準に従って選定した（本ファイルで重複判断しない）
- [ ] フォーム入力にバリデーションとエラー表示を実装した
- [ ] 環境別設定（API エンドポイント等）を flavor / `--dart-define` で分離した
- [ ] Android の署名鍵と `key.properties` を安全に管理している
- [ ] 対象プラットフォームのリリースビルドコマンドを確認した
- [ ] ストア掲載情報（説明・スクリーンショット・プライバシーポリシー）を用意した
- [ ] App Store 提出前に auditing-app-store-compliance の監査を通した
- [ ] オンデバイス AI/ML 利用時にモデルサイズと解放処理（`close()`）を確認した
