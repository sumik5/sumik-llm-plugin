---
name: practicing-software-engineering
description: >-
  Comprehensive software engineering practices guide covering project foundations (fast feedback,
  small steps, learning optimization), team organization (team sizing, platform teams, collaboration),
  pair programming patterns (Driver/Navigator, Ping Pong, Strong-Style), and developer habits/pitfalls
  (GREAT habits framework, common antipatterns).
  Use when starting new projects, organizing dev teams, adopting pair programming, or establishing developer habits.
  For test methodologies (TDD/BDD/ATDD), use testing-code instead.
  For SOLID/code smells/refactoring, use writing-clean-code instead.
  For CI/CD pipeline configuration, use practicing-devops instead.
  For DDD/Clean Architecture patterns, use applying-clean-architecture instead.
---

# ソフトウェアエンジニアリングプラクティス

新しいプロジェクトを成功させるための基盤構築から、チーム組織設計、ペアプログラミング、
優れた開発者習慣まで、ソフトウェア開発の横断的プラクティスを体系化したガイド。

---

## このスキルの使い方

| 状況 | 参照先 |
|------|--------|
| 新規プロジェクト開始時の基盤設計 | [FOUNDATIONS.md](./FOUNDATIONS.md) |
| チーム組織設計・チームトポロジー | [TEAM-ORGANIZATION.md](./TEAM-ORGANIZATION.md) |
| ペアプログラミング導入・パターン選択 | [TEAM-ORGANIZATION.md](./TEAM-ORGANIZATION.md) |
| 開発者習慣の確立・悪習慣の排除 | [DEVELOPER-HABITS.md](./DEVELOPER-HABITS.md) |

---

## 他スキルとの差別化

| スキル | 扱う内容 |
|--------|---------|
| **本スキル** | プロジェクト基盤・チーム組織・ペアプロ・開発者習慣 |
| `testing-code` | TDD/BDD/ATDD の具体的手法・テスト設計 |
| `writing-clean-code` | SOLID原則・コードスメル・リファクタリング手法 |
| `practicing-devops` | Deployment Pipeline設定・CI/CD具体構成 |
| `applying-clean-architecture` | DDD・Clean Architecture・マイクロサービス |

---

## クイックスタート

### 新規プロジェクト開始

```
1. ビジョン作成 → Fast Feedback ループ確立 → Walking Skeleton 構築
2. Deployment Pipeline（最小版）を最初のフィーチャーと同時に構築
3. DORA メトリクス（Throughput / Stability）計測開始
4. チーム構造を確定
```

### チーム組織設計

```
1. Stream-Aligned Team を中心に設計（大多数のチームがこれ）
2. Platform Team は Stream-Aligned Team の自律性を高める目的のみ
3. Enabling Team は専門知識の一時的な貸し出し役
4. チームサイズ: 5〜9人を目標
```

---

## AskUserQuestion: チーム構造選択

チーム構造を設計する際は以下を確認すること:

**機能横断チーム vs コンポーネントチーム** — どちらが適しているかはプロジェクト規模と依存構造による:

- 小〜中規模プロジェクト → 全員が全体を担う機能横断チーム
- 大規模・複雑なシステム → Stream-Aligned + Platform + Enabling の3層構成

## AskUserQuestion: ペアプログラミングパターン選択

用途に応じてパターンを使い分けること:

- 通常の開発 → Driver & Navigator（デフォルト）
- TDD実践時 → Ping Pong
- ナレッジ移転・オンボーディング → Strong-Style
- ❌ Parent-Child は避けるべきアンチパターン

---

## 概要

### プロジェクト基盤（FOUNDATIONS.md）

- **Fast Feedback**: ビルド・テスト・デプロイ・プロダクションからの高速フィードバック
- **学習最適化**: レトロスペクティブ・実験的アプローチ・エビデンス基盤の意思決定
- **小さなステップ**: Walking Skeleton から始め、インクリメンタルに拡大
- **目標設定**: TIME か SCOPE を固定（両方同時は禁止）
- **計測**: DORA メトリクス（Throughput / Stability）を最初期から導入

### チーム組織（TEAM-ORGANIZATION.md）

- **チームサイズ**: 5〜9人。認知負荷と通信複雑性を最小化
- **チームトポロジー**: Stream-Aligned / Enabling / Complex Subsystem / Platform
- **Platform Team の原則**: Stream-Aligned Team の自律性向上が目的
- **ペアプログラミング**: 4つのパターン + Pair Rotation + 成功のコツ

### 開発者習慣（DEVELOPER-HABITS.md）

- **GREAT Habits**: Code as Communication / エンジニア思考 / 設計としてのコーディング / 品質優先 / チームワーク / 小さなステップ
- **よくある落とし穴**: Happy Path 思考 / コードオーナーシップ / 責任回避 / 変更恐怖 / ツール崇拝 / 神話への執着
