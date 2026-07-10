---
name: pursuing-simplicity
description: >-
  Discipline for recognizing and cutting self-induced complexity to keep software sustainable and effective.
  Covers the orient-step-learn loop and a rubric for judging which option is simpler (easier to understand,
  fewer parts, reflects the problem); technology minimalism (dependency decision chains, minimal-and-stable
  framework choice, feature-as-liability restraint, incremental delivery, conservative tech adoption);
  personal automation and environment mastery (automate-first, day-zero deploy, terminal/shell/editor
  fluency, reproducible machine provisioning); collaboration for simplicity (asynchronous decoupled work,
  lean meetings, skill spreading, dialectical reasoning, empathy, listening to code, analogies); and
  data-driven simplification with error-revealing code layout.
  Use when code or workflows feel more complicated than warranted, when weighing a new
  dependency/framework/feature, when setting up developer tooling, or when untangling logic.
when_to_use: >-
  For SOLID, code smells, and refactoring mechanics, use writing-clean-code instead.
  For broad engineering practices (project foundations, team topologies, developer habits), use
  practicing-software-engineering instead. For TDD/test design, use testing-code instead.
  For CI/CD pipeline configuration, use cloud:practicing-devops instead. This skill focuses on
  the judgment and habits of simplicity: cutting self-induced complexity, technology minimalism,
  personal automation, and simplicity-oriented collaboration.
---

# シンプリシティを追求する（Pursuing Simplicity）

ソフトウェア開発は本来、複雑なものだ。そこに自分たちが無用な**複雑さ（complication）** をさらに積み上げているとしたら——それは取り除ける。このスキルは、自己誘発の複雑化を見つけて削る**判断と習慣**を鍛えることを目的とする。

---

## complexity と complication の違い

| 種類 | 説明 | 対処 |
|------|------|------|
| **complexity（本質的複雑さ）** | 問題領域が本来持つ複雑さ。ルールがある | 設計で管理する |
| **complication（自己誘発の複雑化）** | 判断の先送り・過剰な依存・不要な機能が生む複雑さ。ルールがない | **取り除くべき対象** |

シンプリシティは「単純すぎる設計」ではない。理解しやすく、変更しやすく、「しっくりくる」状態を意図的に選び取ることだ。

---

## このスキルの使い方（ナビゲーション）

状況に応じて参照先を選ぶ。

| 状況 | 参照先 |
|------|--------|
| 「複雑さを感じた」を起点に何から手を付けるかわからない | [CUTTING-COMPLEXITY.md](references/CUTTING-COMPLEXITY.md) |
| 依存・フレームワーク・機能を追加すべきか迷っている | [TECHNOLOGY-MINIMALISM.md](references/TECHNOLOGY-MINIMALISM.md) |
| 開発環境の自動化・ツール整備・マシンセットアップ | [AUTOMATION-AND-ENVIRONMENT.md](references/AUTOMATION-AND-ENVIRONMENT.md) |
| チーム連携・会議・対話・コミュニケーション改善 | [COLLABORATION-AND-SOFT-SKILLS.md](references/COLLABORATION-AND-SOFT-SKILLS.md) |
| 反復コードをデータで表す・コードレイアウト改善 | [DATA-DRIVEN-AND-CODE-LAYOUT.md](references/DATA-DRIVEN-AND-CODE-LAYOUT.md) |

---

## 核となる2つの道具

### 1. Orient-Step-Learn ループ

複雑さに気づいてから行動するまでの基本的なサイクル。

```
Orient（気づく）
  ↓
  複雑すぎると感じた箇所を特定する。
  「どうすれば簡潔になるか」「簡潔になったとわかる基準は何か」を考える。

Step（小さく試す）
  ↓
  仮説を検証するための最小の実験を実施する。
  コストが低ければ低いほど、素早く判断できる。

Learn（学ぶ）
  ↓
  実験結果を振り返り、次のステップに活かす。
  一回で解決することはまれ——繰り返しがパターンを身につかせる。
```

詳細は [CUTTING-COMPLEXITY.md](references/CUTTING-COMPLEXITY.md) を参照。

---

### 2. S vs C の評価ルーブリック

「S（候補 A）は C（候補 B）より簡潔か」を判断する3観点。

| 観点 | 問いかけ |
|------|---------|
| **理解しやすさ** | S は C より早く把握できるか？他者への説明が短くなるか？ |
| **部品の少なさ** | S のコンポーネント・依存・条件は C より少ないか？ |
| **問題の直接反映** | S は問題領域の言葉により忠実か？余分なノイズを排除しているか？ |

絶対的な正解はない——文脈と状況に依存する。「しっくりくるか」という感覚も判断の一部として認める。

詳細は [CUTTING-COMPLEXITY.md](references/CUTTING-COMPLEXITY.md) を参照。

---

## 他スキルとの棲み分け

| スキル | 扱う範囲 |
|--------|---------|
| `writing-clean-code` | SOLID・コードスメル・リファクタリング機構・フォーマット原則・境界管理 |
| `practicing-software-engineering` | チーム構造・プロジェクト基盤・キャリア・持続可能なパフォーマンス・AI活用ワークフロー |
| `testing-code` | TDD・テスト設計・カバレッジ戦略 |
| `cloud:practicing-devops` | CI/CD パイプライン構成・デプロイインフラ |
| **`pursuing-simplicity`（本スキル）** | 簡潔さの**判断と習慣**——複雑化の検出・技術選定の抑制・自動化・協働 |

---

## AskUserQuestion: 状況ごとの分岐

### 依存・フレームワーク・機能を追加すべきか？

```
1. 本当に必要か? ─ No → 追加しない
         ↓ Yes
2. 自分で書けるか? ─ Yes → 自作を検討
         ↓ No
3. 付随する大きな依存はないか?
         ↓
4. ローカルコピーや隔離（ラッパー）が必要か?
         ↓
5. バージョン固定・セキュリティ監査を計画しているか?
```

→ 詳細チェックリストは [TECHNOLOGY-MINIMALISM.md](references/TECHNOLOGY-MINIMALISM.md)

### 複雑さを感じた、どこから手を付けるか？

```
1. 複雑に見える箇所を1つ特定 (Orient)
2. 「これを変えたら何が改善するか」を1行で書く
3. 最小の変更・実験を1つ実施 (Step)
4. 改善したか確認、次の箇所を探す (Learn)
```

→ パターンと定着法は [CUTTING-COMPLEXITY.md](references/CUTTING-COMPLEXITY.md)

---

## クイックスタート

### 複雑さを感じたとき

1. 「複雑に感じる」箇所をメモに書き出す
2. Orient-Step-Learn を1サイクル実行する
3. S vs C ルーブリックで変更前後を比較する

### 依存・フレームワーク・機能を足す前に

1. 決定チェーン（5問）を確認する → [TECHNOLOGY-MINIMALISM.md](references/TECHNOLOGY-MINIMALISM.md)
2. 「追加しない」が最初の選択肢
3. 追加する場合は隔離・バージョン固定・棚卸し計画をセットで

### 新規プロジェクト開始時

1. 環境を Day Zero でデプロイ可能な状態にする
2. 依存は最小限からスタートし増分で追加
3. フレームワークは「安定・実績・必要十分な機能」の基準で選ぶ
