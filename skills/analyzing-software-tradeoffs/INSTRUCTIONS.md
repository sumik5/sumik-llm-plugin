# ソフトウェア設計トレードオフ分析

## 概要

ソフトウェア設計における意思決定は、常にトレードオフを伴う。パフォーマンス・保守性・拡張性・複雑性などの軸が相互に影響し合い、どちらかを改善すると他方が悪化するケースが多い。「正解」は存在せず、**コンテキストによって最適解が変わる**。

このスキルは、コードレベル・APIレベル・システムレベル・メタ判断という4層でトレードオフを体系的に分析するためのフレームワークと、12の頻出トレードオフへのリファレンスを提供する。

---

## トレードオフ分析フレームワーク

### コンテキスト依存の意思決定

同じパターンやソリューションでも、コンテキストが変わると最適解が変わる。意思決定の前に以下を明確にする：

| 確認軸 | 問い |
|--------|------|
| **規模** | チーム人数・コードベースの大きさ・トラフィック量 |
| **SLA要件** | 可用性・レイテンシ・整合性の要件レベル |
| **変化速度** | 機能追加頻度・チームの拡大予測 |
| **リソース制約** | 開発時間・運用コスト・技術スタック習熟度 |

### トレードオフの多軸評価

設計選択肢を比較する際は、単一指標でなく複数軸で評価する：

- **パフォーマンス**: レイテンシ・スループット・リソース消費
- **保守性**: コード変更コスト・テスト容易性・デバッグしやすさ
- **複雑性**: 認知負荷・依存関係数・障害点の数
- **結合度**: 変更の波及範囲・独立デプロイ可能性

### 判断基準テーブルの使い方

各トレードオフセクションのテーブルは **「どちらを選ぶか」の判断基準** を提供する。テーブルの「採用条件」列に自分のコンテキストが当てはまる方を選択する。

---

## クイックリファレンス（全トレードオフ一覧）

| トピック | コアトレードオフ | 参照 |
|---------|----------------|------|
| コード重複 | 疎結合 vs DRY原則 | [CODE-DUPLICATION.md](references/CODE-DUPLICATION.md) |
| 例外処理 | 検査例外 vs 非検査例外 vs 関数型 | [ERROR-HANDLING.md](references/ERROR-HANDLING.md) |
| 柔軟性 | 拡張性 vs 複雑性・理解コスト | [FLEXIBILITY-COMPLEXITY.md](references/FLEXIBILITY-COMPLEXITY.md) |
| 最適化タイミング | 早期最適化 vs SLA駆動最適化 | [OPTIMIZATION.md](references/OPTIMIZATION.md) |
| API設計 | UXフレンドリー vs メンテナンスコスト | [API-USABILITY.md](references/API-USABILITY.md) |
| 日時データ | ローカル時刻 vs UTC vs タイムゾーン対応 | [DATETIME.md](references/DATETIME.md) |
| データローカリティ | 処理をデータに近づける vs 柔軟な分散 | [DATA-LOCALITY.md](references/DATA-LOCALITY.md) |
| 分散一貫性 | 強整合性 vs 結果整合性 | [CONSISTENCY-ATOMICITY.md](references/CONSISTENCY-ATOMICITY.md) |
| 配信セマンティクス | at-least-once vs exactly-once | [DATA-DELIVERY.md](references/DATA-DELIVERY.md) |
| バージョン管理 | 前方互換 vs 破壊的変更 | [VERSIONING.md](references/VERSIONING.md) |
| ライブラリ選定 | 外部依存 vs 自前実装 | [THIRD-PARTY-LIBS.md](references/THIRD-PARTY-LIBS.md) |
| トレンド追従 | 新技術採用 vs 安定性・メンテナンスコスト | [TRENDS-AND-PARADIGMS.md](references/TRENDS-AND-PARADIGMS.md) |

---

## コードレベルのトレードオフ

### コード重複 vs 疎結合

DRY原則（Don't Repeat Yourself）の適用は常に正しいわけではない。共通化がコンポーネント間の結合度を高める場合、意図的な重複が保守性を向上させることがある。特にマイクロサービス間でのコード共有はデプロイの独立性を損なうリスクがある。

→ 詳細: [CODE-DUPLICATION.md](references/CODE-DUPLICATION.md)

### 例外処理パターン

検査例外・非検査例外・関数型エラー型（Either/Result型）はそれぞれ異なるトレードオフを持つ。ライブラリのパブリックAPIでは、エラー処理を呼び出し元に委ねるか、ライブラリ内で吸収するかの設計判断が使いやすさと安全性に大きく影響する。

→ 詳細: [ERROR-HANDLING.md](references/ERROR-HANDLING.md)

### 柔軟性 vs 複雑性

抽象化・設定化・プラグイン機構はコードの柔軟性を高めるが、認知負荷と実装コストを増大させる。YAGNI（You Ain't Gonna Need It）の観点から、現時点で必要な拡張ポイントのみを設計に含める判断が重要。

→ 詳細: [FLEXIBILITY-COMPLEXITY.md](references/FLEXIBILITY-COMPLEXITY.md)

### 最適化タイミング

「早すぎる最適化は諸悪の根源」という格言があるが、SLAが明確に定義されている場合は早期にパフォーマンス特性を把握する価値がある。パレートの法則（80%の問題は20%のコードに起因）を活用し、ホットパスを計測・特定してから最適化する。

→ 詳細: [OPTIMIZATION.md](references/OPTIMIZATION.md)

---

## APIレベルのトレードオフ

### APIわかりやすさ vs メンテナンスコスト

UXフレンドリーなAPI（デフォルト値の自動補完、文脈依存の動作、多様な入力形式の受け入れ）は利用者の体験を向上させるが、内部の条件分岐が増えてメンテナンスコストが上昇する。公開APIの設計では「驚き最小の原則」と「メンテナンス性」のバランスが問われる。

→ 詳細: [API-USABILITY.md](references/API-USABILITY.md)

### バージョンと互換性

APIの進化において、前方互換性（古いクライアントが新しいサーバーと通信できる）と後方互換性（新しいクライアントが古いサーバーと通信できる）をどこまで保証するかを設計段階で決定する必要がある。シリアライゼーション形式（JSON・Protobuf・Avro等）の選択もこのトレードオフに直結する。

→ 詳細: [VERSIONING.md](references/VERSIONING.md)

---

## システムレベルのトレードオフ

### データローカリティ

ビッグデータ処理においては、データを計算ノードに移動させるよりも計算をデータの近くで実行する方がI/Oコストを削減できる（データローカリティ）。一方、データのパーティショニング戦略（ハッシュ・レンジ・ラウンドロビン）は処理の分散効率に大きく影響し、ホットスポット問題を生じさせることがある。

→ 詳細: [DATA-LOCALITY.md](references/DATA-LOCALITY.md)

### 分散システムの一貫性

CAP定理に基づき、分散システムでは強整合性・可用性・分断耐性をすべて同時に満たすことはできない。結果整合性モデルを採用する場合、べき等性の確保・競合状態の検出・補償トランザクションの設計が必要になる。

→ 詳細: [CONSISTENCY-ATOMICITY.md](references/CONSISTENCY-ATOMICITY.md)

### データ配信セマンティクス

分散メッセージングにおける3つの配信保証：
- **at-most-once**: 損失はあるが重複なし（ログ等の非重要データ向け）
- **at-least-once**: 重複はあるが損失なし（べき等処理が必要）
- **exactly-once**: 損失も重複もなし（高コスト・複雑性が高い）

→ 詳細: [DATA-DELIVERY.md](references/DATA-DELIVERY.md)

---

## メタ判断

### 日時データの扱い

日時は「簡単そうに見えて難しい」代表的な領域。タイムゾーン・サマータイム・うるう秒・カレンダー体系の違いにより、誕生日・ログタイムスタンプ・スケジューリングなど用途ごとに適切な表現形式が異なる。UTCで保存・表示時に変換が基本原則だが、「誕生日」のようなローカル時刻が本質的な意味を持つ場合は別の扱いが必要。

→ 詳細: [DATETIME.md](references/DATETIME.md)

### サードパーティーライブラリ

外部ライブラリの採用は開発速度を上げるが、ライブラリのコードは実質的に自分たちのコードになる。ライセンス・メンテナンス状況・脆弱性対応速度・APIの安定性・バンドルサイズを評価した上で、小機能のために大きな依存を取り込まない判断基準を持つことが重要。

→ 詳細: [THIRD-PARTY-LIBS.md](references/THIRD-PARTY-LIBS.md)

### トレンド追従 vs メンテナンスコスト

新しい技術トレンド（リアクティブプログラミング・新フレームワーク等）への追従は競争力を維持するが、学習コスト・移行コスト・コミュニティ成熟度のリスクを伴う。現状の技術スタックで解決できない具体的な問題があるかを評価基準にし、「解決すべき問題ありき」でトレンド採用を判断する。

→ 詳細: [TRENDS-AND-PARADIGMS.md](references/TRENDS-AND-PARADIGMS.md)

---

## ユーザー確認の原則（AskUserQuestion）

設計判断において以下のいずれかに該当する場合は、実装前にAskUserQuestionで確認する：

1. **コンテキスト情報が不明**: チーム規模・SLA・トラフィック規模が不明な場合
2. **複数の有効な選択肢が並立**: どちらも合理的で、どちらが「より良い」かがコンテキスト次第な場合
3. **後から変更が困難**: APIの公開・データスキーマ設計・アーキテクチャ分割のような後戻りコストが高い決断

```
AskUserQuestion(
    questions=[{
        "question": "この機能のSLA要件を教えてください。設計方針が変わります。",
        "header": "SLA要件",
        "options": [
            {"label": "高可用性優先", "description": "99.99%可用性・強整合性が必要"},
            {"label": "性能優先", "description": "レイテンシ最小化・結果整合性許容"},
            {"label": "開発速度優先", "description": "スタートアップ段階・シンプルさ重視"}
        ],
        "multiSelect": False
    }]
)
```

---

## 関連スキル

- **writing-clean-code**: SOLID原則・クリーンコード規範（コードレベルの実装品質）
- **architecting-microservices**: マイクロサービスアーキテクチャパターン・CQRS・Saga
- **designing-web-apis**: APIエンドポイント設計・RESTベストプラクティス
- **modernizing-architecture**: レガシーシステム刷新・社会技術的トレードオフ分析手法
