# Firebase テスト & 配布リファレンス

Firebase Test Lab と App Distribution を組み合わせ、品質担保からテスター配布、CI/CD統合まで一気通貫で実現するガイド。

---

## 1. Firebase Test Lab

Googleのデータセンター上の実機/エミュレーターでモバイルアプリを自動テストするクラウドサービス。

### テストタイプ選択

| タイプ | 対象 | 説明 |
|--------|------|------|
| **Robo** | Android | コードなしで自動探索。UIイベントを生成してクラッシュを検出 |
| **Instrumentation** | Android/iOS | Espresso (Android) / XCTest (iOS) で書いた検証テストを実行 |
| **Game Loop** | Android/iOS | ゲームアプリ向け。連続プレイをシミュレートしてパフォーマンス・安定性を検証 |

### テストマトリクス設計

複数デバイス × OS バージョンでマトリクスを組む。

```bash
# Firebase CLI でテスト実行（Android）
firebase test android run \
  --type instrumentation \
  --app app/build/outputs/apk/debug/app-debug.apk \
  --test app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
  --device model=Pixel6,version=33,locale=ja,orientation=portrait \
  --device model=galaxy_s23,version=33,locale=ja,orientation=portrait \
  --device model=Pixel4,version=30,locale=en,orientation=portrait
```

```bash
# iOS XCTest
firebase test ios run \
  --test MyApp.zip \
  --device model=iphone14pro,version=16.6,locale=ja_JP,orientation=portrait \
  --device model=iphone13,version=15.8,locale=ja_JP,orientation=portrait
```

### Roboテスト（コードなし自動探索）

```bash
# 最小構成：APKを渡すだけで動作
firebase test android run \
  --type robo \
  --app app-debug.apk \
  --robo-directives username_field=test@example.com,password_field=password123 \
  --timeout 5m
```

Roboスクリプト（特定シナリオを誘導する場合）:
```json
[
  {
    "eventType": "VIEW_TEXT_CHANGED",
    "elementDescriptors": [{ "resourceName": "com.example:id/email_input" }],
    "replacementText": "test@example.com"
  },
  {
    "eventType": "VIEW_CLICKED",
    "elementDescriptors": [{ "resourceName": "com.example:id/login_button" }]
  }
]
```

### テスト結果の読み方

テスト完了後、Firebase Console から以下を確認:

| 成果物 | 内容 |
|--------|------|
| スクリーンショット / 動画 | UIの見た目の問題、予期しない遷移を視覚的に確認 |
| デバイスログ | `logcat` (Android) / `syslog` (iOS) でクラッシュ前後の挙動を追跡 |
| パフォーマンスメトリクス | CPU/メモリ/ネットワーク/バッテリー消費のデバイスごとの比較 |
| クラッシュレポート | スタックトレース + 発生デバイス・OSバージョン |

**テスト結果ステータス:**
- `Passed` — 全テストが正常完了
- `Failed` — クラッシュ・ANR・アサーション失敗が発生
- `Skipped` — デバイス非互換等でスキップ
- `Timed out` — タイムアウト制限超過

---

## 2. App Distribution

プレリリースビルドをテスターへ素早く届けるための配布サービス。iOS (IPA) / Android (APK/AAB) 両対応。

### 初期セットアップ

```bash
# Firebase CLI インストール・ログイン
npm install -g firebase-tools
firebase login

# App Distribution 初期化
firebase init appdistribution
```

### ビルド配布

**Android APK の配布:**
```bash
firebase appdistribution:distribute app-debug.apk \
  --app YOUR_FIREBASE_APP_ID \
  --groups "internal-qa,beta-testers" \
  --release-notes "修正内容: ログイン画面のUIバグを修正、パフォーマンス改善"
```

**iOS IPA の配布:**
```bash
firebase appdistribution:distribute MyApp.ipa \
  --app YOUR_FIREBASE_APP_ID \
  --testers "tester1@example.com,tester2@example.com" \
  --release-notes "新機能: ダークモード対応"
```

### テスターグループ管理

```bash
# グループへのテスター追加
firebase appdistribution:testers:add \
  --app YOUR_FIREBASE_APP_ID \
  --group "beta-testers" \
  tester@example.com

# グループ一覧確認
firebase appdistribution:group:list --app YOUR_FIREBASE_APP_ID
```

**グループ設計のベストプラクティス:**

| グループ名 | 対象 | 配布タイミング |
|-----------|------|--------------|
| `internal-dev` | 開発チーム | 毎コミット |
| `qa-team` | QAエンジニア | PR マージ時 |
| `beta-external` | 外部ベータテスター | リリース候補 |
| `stakeholders` | PM・経営陣 | マイルストーン単位 |

---

## 3. CI/CD 統合

### GitHub Actions での完全パイプライン

```yaml
# .github/workflows/firebase-test-distribute.yml
name: Firebase Test & Distribute

on:
  push:
    branches: [main, release/*]

jobs:
  test-and-distribute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Build APK
        run: ./gradlew assembleDebug assembleDebugAndroidTest

      - name: Firebase Test Lab
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS }}

      - name: Run Tests on Test Lab
        run: |
          npm install -g firebase-tools
          firebase test android run \
            --type instrumentation \
            --app app/build/outputs/apk/debug/app-debug.apk \
            --test app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
            --device model=Pixel6,version=33,locale=ja,orientation=portrait \
            --timeout 10m

      - name: Distribute via App Distribution
        if: success()
        run: |
          firebase appdistribution:distribute \
            app/build/outputs/apk/debug/app-debug.apk \
            --app ${{ secrets.FIREBASE_APP_ID }} \
            --groups "qa-team" \
            --release-notes "Build: ${{ github.sha }}"
```

### Fastlane 連携

```ruby
# Fastfile
lane :test_and_distribute do
  # テスト実行
  sh "firebase test android run --app app-debug.apk --type robo"

  # 配布
  firebase_app_distribution(
    app: ENV["FIREBASE_APP_ID"],
    groups: "qa-team,beta-testers",
    release_notes: "Version: #{git_branch} - #{last_git_commit[:message]}",
    apk_path: "app/build/outputs/apk/release/app-release.apk"
  )
end
```

---

## 4. テスト戦略ベストプラクティス

```
開発段階別テスト戦略:
│
├─ 単体テスト（Emulator）
│   Firebase Emulator Suite で毎コミット高速実行
│   Auth / Firestore / Functions の動作確認
│
├─ 統合テスト（Test Lab - 少数デバイス）
│   PRマージ時: 代表デバイス2-3台でInstrumentationテスト
│
└─ リリーステスト（Test Lab - フルマトリクス）
    リリース前: 10台以上のデバイス × OS バージョンで網羅
    Roboテストで未カバー画面のクラッシュ検出
```

**重要な注意点:**
- テストマトリクスは広げすぎると課金が膨らむ → ターゲットユーザーのデバイス統計を Analytics で確認してから選択
- Roboテストは `--robo-directives` で認証情報を注入してログイン後の画面もカバーする
- Test Lab の結果は Google Cloud Storage に保存されるため、テスト履歴は `gsutil` でも取得可能
