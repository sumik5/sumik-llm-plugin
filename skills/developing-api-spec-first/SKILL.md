---
name: developing-api-spec-first
description: >-
  API Spec First development methodology covering spec writing, E2E test framework architecture,
  technical debt repayment, and defensive programming for APIs.
  Use when adopting spec-first API development, building E2E test frameworks for backend services,
  documenting undocumented APIs, or writing comprehensive API specifications.
  For HTTP REST API design patterns, use designing-web-apis instead.
  For testing strategy and test pyramid, use testing-web-apis instead.
---

# API仕様ファースト開発

API仕様を先に記述し、E2Eテストフレームワークで検証しながら実装を進める開発方法論のスキル。

詳細な手順・ガイドラインは INSTRUCTIONS.md を参照してください。

## 参照ファイル

| ファイル | 内容 |
|---------|------|
| `INSTRUCTIONS.md` | API仕様ファースト開発の方法論・E2Eテストフレームワーク・技術的負債返済 |
| `references/GRPC-SPEC-WRITING.md` | gRPC (.proto) API仕様の書き方 |
| `references/GO-E2E-IMPLEMENTATION.md` | Go言語でのE2Eテストフレームワーク実装 |
| `references/OVERNIGHT-TESTING.md` | 長時間夜間ランニングテスト |
