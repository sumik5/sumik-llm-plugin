---
name: auditing-app-store-compliance
description: >-
  What: iOS/iPadOS/macOSアプリのコードベース（Info.plist、entitlements、Xcodeプロジェクト設定、ソースコード）をApp Review Guidelines（Safety/Performance/Business/Design/Legal）、In-App Purchase実装（StoreKit 2）、macOS/Mac App Store固有要件に照らして実地検査し、「必須(Blocking)/推奨/手動確認要」の3段階で判定した審査提出可否レポートを作成する。REQUIRED when 審査提出前の最終チェック、リリース可否判断、既存コードベースの審査対応状況監査を行うとき。Differentiation: App Review Guidelines本文の解説、Privacy Manifest詳細、署名・TestFlight・技術実装手順はdeveloping-ios-appsを使い、HIGに基づくUI/UX判断はapplying-apple-higを使う。本スキルは実際のプロジェクトファイルを検査するアクション型の監査に特化し、ガイドライン本文の再解説はしない。FlutterアプリがビルドするiOS/macOSのXcodeプロジェクトにも同様に適用できる。
---

詳細な監査ワークフロー・レポート出力形式・参照資料ルーティングは [INSTRUCTIONS.md](INSTRUCTIONS.md) を参照してください。
