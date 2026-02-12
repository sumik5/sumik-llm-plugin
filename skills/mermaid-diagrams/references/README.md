# Mermaid Diagrams Reference Library

Comprehensive syntax guides for all 22+ Mermaid diagram types. Each reference file provides detailed syntax, examples, and best practices.

---

## リファレンス一覧（カテゴリ別）

### 🏗️ 構造・設計 (Structure & Design)

| リファレンス | 説明 |
|------------|------|
| **[class-diagrams.md](class-diagrams.md)** | クラス図 - ドメインモデル、OOP設計、関係性（association/composition/aggregation/inheritance）、多重度、メソッド/プロパティ |
| **[erd-diagrams.md](erd-diagrams.md)** | ER図 - データベーススキーマ、エンティティ、リレーションシップ、カーディナリティ、キー、属性 |
| **[c4-diagrams.md](c4-diagrams.md)** | C4アーキテクチャ図 - システムコンテキスト、コンテナ、コンポーネント、境界 |
| **[architecture-diagrams.md](architecture-diagrams.md)** | アーキテクチャ図 - クラウドサービス、インフラ、CI/CD、デプロイメント |
| **[block-diagrams.md](block-diagrams.md)** | ブロック図 - コンポーネント構成、ネスト構造、階層ビュー |

### 🔄 フロー・プロセス (Flow & Process)

| リファレンス | 説明 |
|------------|------|
| **[flowcharts.md](flowcharts.md)** | フローチャート - プロセス、アルゴリズム、決定木、ノード形状、サブグラフ |
| **[sequence-diagrams.md](sequence-diagrams.md)** | シーケンス図 - アクター、参加者、メッセージ（同期/非同期）、アクティベーション、ループ、alt/opt/parブロック |
| **[state-diagrams.md](state-diagrams.md)** | 状態図 - ステートマシン、状態遷移、ライフサイクル、FSMモデリング |
| **[user-journey-diagrams.md](user-journey-diagrams.md)** | ユーザージャーニー図 - カスタマーエクスペリエンス、満足度マッピング、タッチポイント分析 |

### 📅 プロジェクト管理 (Project Management)

| リファレンス | 説明 |
|------------|------|
| **[gantt-charts.md](gantt-charts.md)** | ガントチャート - プロジェクトタイムライン、タスク依存関係、マイルストーン、リソース配分 |
| **[timeline-diagrams.md](timeline-diagrams.md)** | タイムライン図 - 時系列イベント、製品ロードマップ、バージョン履歴 |
| **[kanban-diagrams.md](kanban-diagrams.md)** | カンバン図 - 作業中タスク可視化、タスクボード、スプリント計画 |

### 📊 データ可視化 (Data Visualization)

| リファレンス | 説明 |
|------------|------|
| **[pie-charts.md](pie-charts.md)** | 円グラフ - 割合データ、市場シェア、カテゴリ分布 |
| **[xy-charts.md](xy-charts.md)** | XYチャート - 時系列、相関、パフォーマンスメトリクス |
| **[quadrant-charts.md](quadrant-charts.md)** | 四象限図 - 優先度マトリクス、リスク評価、戦略ポジショニング |
| **[radar-charts.md](radar-charts.md)** | レーダーチャート - 多次元比較、機能比較、成熟度モデル |
| **[sankey-diagrams.md](sankey-diagrams.md)** | サンキー図 - フロー量、エネルギーフロー、予算配分、トラフィック分析 |
| **[treemap-diagrams.md](treemap-diagrams.md)** | ツリーマップ - 階層データ、ネストされた矩形、ディスク使用量、ポートフォリオ配分 |

### 🌳 バージョン管理 (Version Control)

| リファレンス | 説明 |
|------------|------|
| **[git-graphs.md](git-graphs.md)** | Gitグラフ - ブランチ戦略、マージ履歴、Gitflow、トランクベース開発 |

### 🧠 思考整理 (Mind Organization)

| リファレンス | 説明 |
|------------|------|
| **[mindmaps.md](mindmaps.md)** | マインドマップ - ブレインストーミング、コンセプトマッピング、アイデア整理 |

### 🔧 専門用途 (Specialized)

| リファレンス | 説明 |
|------------|------|
| **[zenuml-diagrams.md](zenuml-diagrams.md)** | ZenUML図 - 高度なUMLシーケンス図（代替シンタックス） |
| **[packet-diagrams.md](packet-diagrams.md)** | パケット図 - ネットワークプロトコル、ヘッダー構造、ビットレベルフォーマット |

### ⚙️ 高度な機能 (Advanced Features)

| リファレンス | 説明 |
|------------|------|
| **[advanced-features.md](advanced-features.md)** | テーマ、スタイリング、設定、レイアウトオプション、カスタムテーマ変数 |

---

## クイックスタートガイド

1. **目的に応じたダイアグラムタイプを選択** - 上記カテゴリから選択
2. **対応するリファレンスファイルを参照** - 詳細シンタックスと例を確認
3. **シンプルから開始** - コア要素から追加していく
4. **[Mermaid Live Editor](https://mermaid.live)** で検証
5. **Markdown/ドキュメントに埋め込み** または画像エクスポート

---

## ベストプラクティス

- **1ダイアグラム = 1コンセプト** - 複雑な場合は複数ダイアグラムに分割
- **意味のある名前** - コード/データベースの命名と一致させる
- **コメント活用** - `%%` で関係性を説明
- **バージョン管理** - `.mmd`ファイルをコードと一緒に管理
- **段階的詳細化** - 最初はシンプルに、必要に応じて詳細を追加

---

## ツール＆リソース

- **[Mermaid Live Editor](https://mermaid.live)** - オンラインエディタ（プレビュー＆エクスポート）
- **[公式ドキュメント](https://mermaid.js.org)** - 最新機能・シンタックス参照
- **Mermaid CLI** - `npm install -g @mermaid-js/mermaid-cli` でバッチエクスポート
- **VS Code拡張** - "Markdown Preview Mermaid Support"
- **GitHub/GitLab** - `.md`ファイルで自動レンダリング

---

## サポート

- **[SKILL.md](../SKILL.md)** - クイックリファレンス・ダイアグラム選択ガイド
- **各リファレンスファイル** - 詳細シンタックス・例
- **[Mermaid公式ドキュメント](https://mermaid.js.org)** - 最新情報
