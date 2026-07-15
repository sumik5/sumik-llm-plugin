# mobile

**Apple公式資料およびFlutter/Dart公式資料に基づく、iPhone/iPad/クロスプラットフォームアプリのインターフェイス設計と開発のためのプラグイン**

---

## 概要

mobile は、iPhone/iPad/Mac アプリ（ネイティブSwift/SwiftUIおよびFlutter/Dartによるクロスプラットフォーム）を設計・実装・レビュー・審査対応・配布するときに使う5つのスキルを提供します。Apple Human Interface Guidelines（HIG）、Apple Developer Documentation、App Review Guidelines、Flutter/Dart公式ドキュメントを一次資料とし、Codex が次の区別を保ったまま判断できるように構成します。

- **必須要件**: App Review、プラットフォーム/API契約、法令、プライバシー申告、署名・配布で満たす必要がある事項
- **HIGの標準・強い推奨**: Appleプラットフォームらしい一貫性、理解しやすさ、操作性、アクセシビリティを確保するため原則として採用する事項
- **条件付き判断**: アプリの目的、対象OS、デバイス、入力方式、ウインドウサイズ、採用技術（ネイティブ or Flutter/Dart）によって選択が変わる事項

Appleおよびflutter.dev/dart.devの資料は更新されるため、スキル内の参照資料だけを固定的な規則として扱いません。時限的な要件、数値、審査、プライバシー、SDK/APIの可用性は、実作業時にスキルが案内する公式ページで再確認します。

skills のみを持つ構成で、plugin レベルの MCP / agents / commands / hooks / bin は持ちません。Codex 配布は subdirectory 方式です。

---

## インストール

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add mobile@sumik-marketplace
```

### Claude Code

```bash
/plugin install mobile@sumik
```

---

## ディレクトリ構成

```text
plugins/mobile/
├── .claude-plugin/
│   └── plugin.json
├── .codex-plugin/
│   └── plugin.json
├── README.md
└── skills/
    ├── applying-apple-hig/
    │   ├── SKILL.md
    │   ├── INSTRUCTIONS.md
    │   └── references/
    ├── developing-ios-apps/
    │   ├── SKILL.md
    │   ├── INSTRUCTIONS.md
    │   └── references/
    ├── auditing-app-store-compliance/
    │   ├── SKILL.md
    │   ├── INSTRUCTIONS.md
    │   └── references/
    ├── developing-dart/
    │   ├── SKILL.md
    │   ├── INSTRUCTIONS.md
    │   └── references/
    └── developing-flutter-apps/
        ├── SKILL.md
        ├── INSTRUCTIONS.md
        └── references/
```

---

## Skills（5個）

| スキル | 使用する場面 | 主な範囲 |
|--------|--------------|----------|
| `applying-apple-hig` | iPhone/iPadの画面、操作、ナビゲーション、コンポーネント、ビジュアル、入力、アクセシビリティを設計・実装・レビューするとき | Appleのデザイン原則、iOS/iPadOS差分、適応レイアウト、タイポグラフィ、カラー、モーション、コンポーネント、パターン、入力方式、アクセシビリティ、プライバシーを尊重する体験 |
| `developing-ios-apps` | SwiftUI/UIKitアプリの新規作成・改修、アーキテクチャ、ライフサイクル、データ、品質、プライバシー、署名、TestFlight、App Store配布を扱うとき | 技術選定、状態とデータフロー、scene/app lifecycle、端末・性能・テスト品質、Privacy Manifest、Required Reason API、署名・配布・審査準備 |
| `auditing-app-store-compliance` | App Store提出前の最終チェック、リリース可否判断、既存コードベースの審査対応状況を監査するとき | Info.plist/entitlements/ソースコードの実地検査、StoreKit 2でのIAP実装レベル準拠、macOS/Mac App Store固有要件（サンドボックス・公証・Hardened Runtime）、必須/推奨/手動確認要の3段階判定レポート |
| `developing-dart` | Dartコードを書く・レビューする・修正するとき、`pubspec.yaml`/`.dart`ファイル検出時 | Dart言語の型システム、null安全性、関数型・OOP両スタイル、generics、コレクション操作、非同期処理（Future/Stream/isolate）、エラー処理、`test`パッケージ、pub/依存管理、CLI・Webランタイム、ツールチェーン |
| `developing-flutter-apps` | Flutterアプリの新規作成・実装・修正・テスト・配布、`pubspec.yaml`にflutter SDK検出時 | Widget体系、レイアウト・テーマ・アニメーション、状態管理（setState/Provider/Riverpod/BLoC/Redux/GetX）、ナビゲーション、ネットワーキング・Firebase連携、ローカル永続化、マルチプラットフォーム対応、アーキテクチャパターン、pub.devパッケージエコシステム、テスト、性能最適化、ビルド・ストア公開 |

UIを伴うiOS/iPadOSのネイティブ実装では、原則として`developing-ios-apps`と`applying-apple-hig`の両方を使用します。`developing-ios-apps` が実装・品質・配布を担当し、`applying-apple-hig` がユーザー体験とインターフェイス判断を担当します。提出前の最終監査には `auditing-app-store-compliance` を使用します。

Flutter/Dartによるクロスプラットフォーム実装では、`developing-flutter-apps`と`developing-dart`の両方を使用します。`developing-flutter-apps` がWidget・状態管理・配布を担当し、`developing-dart` がDart言語そのものの設計判断を担当します。Flutterアプリのビルド成果物（iOS/macOS向けXcodeプロジェクト）を提出する際の最終監査にも `auditing-app-store-compliance` を使用します。

---

## 主要な公式入口

### Apple（ネイティブiOS/iPadOS/macOS）

- [Apple Human Interface Guidelines（日本語）](https://developer.apple.com/jp/design/human-interface-guidelines/)
- [Apple Developer Documentation（日本語）](https://developer.apple.com/jp/documentation/)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [UIKit（日本語）](https://developer.apple.com/jp/documentation/uikit/)
- [App Review Guidelines（日本語）](https://developer.apple.com/jp/app-store/review/guidelines/)
- [Appのプライバシーに関する詳細](https://developer.apple.com/jp/app-store/app-privacy-details/)

### Flutter/Dart（クロスプラットフォーム）

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart公式サイト](https://dart.dev/)
- [pub.dev（パッケージエコシステム）](https://pub.dev/)

各スキルは、タスクに応じてより具体的な公式ページへ案内します。

---

## バージョンと配布

mobile は独立した Semantic Versioning 系列を持ちます。version を変更するときは、次の3箇所を同じ値に同期します。

1. `plugins/mobile/.claude-plugin/plugin.json`
2. `plugins/mobile/.codex-plugin/plugin.json`
3. `.agents/plugins/marketplace.json` の `mobile` エントリ

Codex marketplace は `.cache/sumik-marketplace/mobile -> ../../plugins/mobile` を通して本ディレクトリを参照します。
