# スキル命名戦略

> ソースファイル（Markdown/PDF/EPUB）のファイル名・コンテンツから、適切なスキル名を自動推定するためのルール集。

---

## 1. ファイル名からのキーワード抽出

### 抽出手順

1. 拡張子を除去（`.md`, `.pdf`, `.epub`, `.txt` 等）
2. 区切り文字（ハイフン`-`、アンダースコア`_`、スペース）で分割
3. ストップワードを除去（`guide`, `notes`, `summary`, `draft`, `v1`, `v2`, `final`等）
4. 残ったキーワードをドメイン候補とする

### 例

| ファイル名 | 抽出キーワード | ドメイン |
|-----------|--------------|---------|
| `docker-best-practices.md` | docker, best, practices | Docker |
| `react_performance_notes.md` | react, performance | React性能 |
| `typescript-strict-guide.md` | typescript, strict | TypeScript型安全 |
| `api-security-checklist.md` | api, security, checklist | APIセキュリティ |
| `golang-concurrency.md` | golang, concurrency | Go並行処理 |
| `nextjs-app-router.md` | nextjs, app, router | Next.js App Router |
| `clean-code.pdf` | clean, code | クリーンコード |
| `effective-typescript.epub` | effective, typescript | TypeScript |

---

## 2. コンテンツパターン → gerund動詞マッピング

ソースMarkdownの内容を分析し、以下のパターンに基づいてgerund動詞を決定する。

### 主要マッピング表

| コンテンツパターン | 特徴・キーワード | gerund動詞 | 既存スキル例 |
|------------------|----------------|-----------|-------------|
| フレームワーク・言語の開発ガイド | 環境構築、API、ルーティング、設定 | `developing-` | developing-nextjs, developing-go, developing-python |
| フルスタック・複合開発 | フロント+バック+デプロイ | `developing-fullstack-` | developing-fullstack-javascript |
| コンテナ・インフラ・CI/CD運用 | Docker, k8s, 監視, ログ | `managing-` | managing-docker |
| 品質ルール・制約の強制 | 「禁止」「必須」「strict」が頻出 | `enforcing-` | enforcing-type-safety |
| ライブラリ・技術の調査・評価 | 比較表、pros/cons、選定基準 | `researching-` | researching-libraries |
| ファイル・ドキュメント・設定の生成 | テンプレート、生成手順、フォーマット | `writing-` | writing-latex, writing-effective-prose |
| UI・画面・デザインの作成 | コンポーネント、レイアウト、色、フォント | `designing-` | designing-frontend |
| テスト戦略・手法 | テストケース、カバレッジ、TDD、モック | `testing` / `testing-` | testing |
| セキュリティ対策 | 脆弱性、認証、暗号化、OWASP | `securing-` | securing-code |
| ツール・ライブラリの使い方 | コマンド一覧、設定方法、API使用法 | `using-` | using-serena, using-next-devtools |
| 実装手順・ワークフロー | ステップバイステップ、手順書 | `implementing-` | implementing-as-tachikoma |
| データ変換・処理 | 入出力変換、パース、マイグレーション | `converting-` / `processing-` | convert-to-skill |
| Web検索・情報収集 | 検索クエリ、情報源、調査手法 | `searching-` | searching-web |
| ベストプラクティス集 | パターン集、アンチパターン、最適化Tips | `[topic]-best-practices` | (developing-nextjsに統合済み) |
| ガイドライン・原則集 | 設計原則、コーディング規約 | `applying-` / `[topic]-guidelines` | applying-design-guidelines |
| ブラウザ自動化 | スクレイピング、E2Eテスト、操作自動化 | `automating-` | automating-browser |
| Git・バージョン管理 | ブランチ戦略、ワークフロー | `managing-git-` | managing-git-worktrees |
| レビュー・分析 | コードレビュー、品質分析 | `reviewing-` / `analyzing-` | reviewing-with-coderabbit |

### 動詞選択のフローチャート

```
ソース内容の主目的は？
├─ 「何かを作る・書く方法」 → writing- / designing-
├─ 「技術Xで開発する方法」 → developing-
├─ 「ツールXの使い方」 → using-
├─ 「ルール・制約を守らせる」 → enforcing- / applying-
├─ 「運用・管理する方法」 → managing-
├─ 「セキュリティ対策」 → securing-
├─ 「テスト手法」 → testing-
├─ 「調査・評価方法」 → researching-
├─ 「変換・処理手順」 → converting- / processing-
├─ 「実装手順・ワークフロー」 → implementing-
└─ 「ベストプラクティス集」 → [topic]-best-practices / [topic]-guidelines
```

---

## 3. 既存スキルとのスコープ比較

### 比較手順

1. `skills/` ディレクトリの全スキルフォルダ名を取得
2. 各スキルの `SKILL.md` frontmatterからdescriptionを読み取る
3. ソースMarkdownの主要トピックと既存スキルのスコープを比較
4. 以下の判断基準で分類

### 判断基準テーブル

| 状況 | 重複度 | 推奨アクション | 具体例 |
|------|--------|--------------|--------|
| 完全に同じドメイン・スコープ | 高 | **既存に追記** | Docker運用ノート → managing-docker に追加 |
| 既存スキルの一部トピックを深掘り | 中〜高 | **既存にサブファイルとして追加** | React Hooks詳細 → developing-nextjs にHOOKS.mdとして追加 |
| 部分的に重複するが独立性あり | 中 | **AskUserQuestionで確認** | Tailwind CSS設計 → designing-frontend の一部 or 新規 `using-tailwind`？ |
| 完全に新しいドメイン | なし | **新規作成** | Rust開発ガイド → developing-rust（新規） |

### 追記時の注意事項

既存スキルに追記する場合:
- 既存スキルの構造・命名規則に合わせる
- 新規サブファイルは既存のUPPER-CASE-HYPHEN.md命名規則に従う
- SKILL.mdのサブファイル一覧セクションにリンクを追加
- frontmatter descriptionの更新が必要か確認（カバー範囲が広がった場合）

---

## 4. スキル名候補の生成ルール

### 候補生成アルゴリズム

1. **ファイル名ベース候補**: ファイル名キーワード + gerund動詞 → 候補1
2. **コンテンツベース候補**: 主要トピック + gerund動詞 → 候補2
3. **既存パターンベース候補**: 類似既存スキルの命名パターンに合わせる → 候補3

### 例

| ソースファイル | 主要コンテンツ | 候補1（ファイル名ベース） | 候補2（コンテンツベース） | 候補3（既存パターンベース） |
|-------------|-------------|----------------------|---------------------|--------------------------|
| `terraform-patterns.md` | Terraform設計パターン | `designing-terraform` | `implementing-terraform-patterns` | `developing-terraform` ※既存に追記 |
| `react-hooks-patterns.md` | React Hooks設計パターン | `designing-react-hooks` | `implementing-react-hooks` | `developing-nextjs` ※既存に追記 |
| `rust-intro.md` | Rust言語入門 | `developing-rust` | `developing-rust` | `developing-rust`（新規） |
| `api-auth-guide.md` | API認証実装ガイド | `implementing-api-auth` | `securing-api-auth` | `securing-code` ※既存に追記の可能性 |

### 重複時のスキル名候補の扱い

- 既存スキルと同名の候補が出た場合、**必ず「既存に追記」オプションも提示**
- 差別化できる場合のみ新規スキル名として提示
- ユーザーが「既存に追記」を選んだ場合、スキル名の質問はスキップ
