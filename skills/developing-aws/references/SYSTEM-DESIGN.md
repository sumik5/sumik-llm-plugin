# AWSシステム設計の基礎

AWSでの大規模システム設計における基本概念、トレードオフ、設計ガイドライン、およびアーキテクチャパターンを解説します。

---

## システム設計の基本概念

### Communication（通信）

大規模ソフトウェアシステムは、複数の小さなサブシステム（サーバー）で構成され、それらがネットワークを介して互いに通信します。

#### 同期通信（Synchronous Communication）
- 送信者は呼び出しが完了するまで待機（ブロック）
- リアルタイムレスポンスが必要な場合に適用（例: フロントエンドUIとバックエンド間の通信）
- 応答を待つため、ユーザーからはレイテンシーとして知覚される可能性

#### 非同期通信（Asynchronous Communication）
- 送信者は応答を待たずに処理を継続
- コールバック関数で結果を受信
- 柔軟性と障害耐性が重要な場合に適用（例: 長時間実行ジョブのステータス確認）

| 比較項目 | 同期通信 | 非同期通信 |
|---------|---------|----------|
| ブロッキング | あり（待機） | なし |
| レイテンシー | 高い可能性 | 低い |
| 適用場面 | リアルタイム応答 | 柔軟性・耐障害性 |

---

### Consistency（一貫性）

#### 分散システムにおける一貫性
複数のレプリカノードが同じデータビューを持つことを保証する特性。

**一貫性確保の手法:**
- **データレプリケーション**: 複数ノードでデータコピーを同期的に更新
- **コンセンサスプロトコル**: 投票やリーダー選出でノード間の合意を形成
- **コンフリクト解決**: 同時更新発生時にLast Writer WinsやMerge Algorithmを適用

#### データストレージ・取得における一貫性
各読み取りリクエストが最新の書き込み値を返すことを保証。

**一貫性確保の手法:**
- **Write-Ahead Logging**: 書き込み前にログに記録し、障害時に復元可能に
- **Locking**: 1つの書き込み操作のみを許可
- **Data Versioning**: 各書き込みにバージョン番号を割り当て

#### 一貫性スペクトルモデル

| 一貫性レベル | 説明 | トレードオフ |
|------------|------|------------|
| **Strong Consistency** | すべてのレプリカが常に同じデータビュー | 高遅延、複雑性増加 |
| **Monotonic Read Consistency** | クライアントは常に同じか新しい値を読む | - |
| **Monotonic Write Consistency** | 書き込み確認後、常に更新値を返す | - |
| **Causal Consistency** | 因果関係のある操作の順序を保持 | - |
| **Eventual Consistency** | 最終的にすべてのレプリカが同じビューに | 一時的な不一致 |

一貫性レベルが厳格になるほど、システムの複雑性、レイテンシー、運用コストが増加します。

---

### Availability（可用性）

システムがクライアントリクエストに応答できる能力。

#### 可用性の計算

```
Availability % = (Total Time − Downtime) / Total Time × 100
```

| 可用性 | 年間ダウンタイム | 月間ダウンタイム | 週間ダウンタイム |
|-------|----------------|----------------|----------------|
| 90% (1 nine) | 36.5日 | 72時間 | 16.8時間 |
| 99% (2 nines) | 3.65日 | 7.2時間 | 1.68時間 |
| 99.9% (3 nines) | 8.76時間 | 43.8分 | 10.1分 |
| 99.99% (4 nines) | 52.56分 | 4.32分 | 1.01分 |
| 99.999% (5 nines) | 5.26分 | 25.9秒 | 6.05秒 |

#### 並列vs直列での可用性

**直列システム**:
```
全体可用性 = Component1可用性 × Component2可用性
例: 99.9% × 99.9% = 99.8%
```

**並列システム**:
```
全体可用性 = 1 − (Component1不可用性 × Component2不可用性)
例: 1 − (0.001 × 0.001) = 99.9999%
```

#### 可用性確保の手法
- **Redundancy（冗長性）**: 重要コンポーネントの複数コピー
- **Fault Tolerance（耐障害性）**: エラーハンドリング機構、自己修復システム
- **Load Balancing**: 複数サーバー間でリクエスト分散

---

### Reliability（信頼性）

システムが一定期間にわたって意図された機能を一貫して実行する能力。

#### 信頼性の測定

**MTBF (Mean Time Between Failures)**:
```
MTBF = (Total Elapsed Time − Total Downtime) / Total Number of Failures
```

**MTTR (Mean Time To Repair)**:
```
MTTR = Total Maintenance Time / Total Number of Repairs
```

| 指標 | 説明 | 目標 |
|-----|------|------|
| MTBF | 平均故障間隔 | 高いほど良い（例: 50,000時間以上） |
| MTTR | 平均修復時間 | 低いほど良い（迅速な復旧） |

高MTBFかつ低MTTRのシステムが最も信頼性が高いと評価されます。

---

### Scalability（スケーラビリティ）

増加するワークロードに対してリソースを追加することでパフォーマンスを向上させる能力。

#### Vertical Scaling（垂直スケーリング）
- 単一サーバーのリソース（CPU、RAM、GPU、ストレージ）を増強
- 予測可能なトラフィックに適用
- **制約**: ハードウェアの上限、高コスト

#### Horizontal Scaling（水平スケーリング）
- コモディティサーバーを追加して負荷分散
- 予測不可能なトラフィックに適用
- **利点**: コスト効率的
- **課題**: 複数サーバーの管理複雑性

| 比較項目 | 垂直スケーリング | 水平スケーリング |
|---------|----------------|----------------|
| 拡張方法 | リソース増強 | サーバー追加 |
| トラフィック | 予測可能 | 予測不可能 |
| コスト | 高い | 効率的 |
| 複雑性 | 低い | 高い |

---

### Maintainability（保守性）

システムが変化するニーズに適応できる能力。

#### 保守性の3要素

**Operability（運用性）**:
- 通常条件下でスムーズに動作
- 障害後、規定時間内に正常動作に復帰
- システムの安定性、信頼性、可用性に寄与

**Lucidity（明瞭性）**:
- システムがシンプルで理解しやすい
- 機能追加やバグ修正が容易
- 効率的なコラボレーション、知識共有を促進

**Modifiability（変更容易性）**:
- モジュール化された構造
- 他のサブシステムに影響を与えず変更可能
- ビジネスニーズ、技術進歩に適応

---

### Fault Tolerance（耐障害性）

ハードウェア・ソフトウェア障害からの復旧能力。

#### データ安全確保のメカニズム

**Replication（レプリケーション）**:
- 複数レプリカサーバー・ストレージで冗長化
- 障害ノードを正常レプリカノードに置換

**Checkpointing（チェックポイント）**:
- データの定期的なバックアップ
- システム状態の復元によりデータ損失を防止

| 方式 | 説明 | メリット | デメリット |
|-----|------|---------|-----------|
| Synchronous Checkpointing | データ変更停止後、全ノードで完了待機 | 一貫性保証 | スループット低下 |
| Asynchronous Checkpointing | 変更継続しながら非同期実行 | スループット維持 | 不一致の可能性 |

#### RPO/RTOの考慮

**RPO (Recovery Point Objective)**:
- 許容できるデータ損失量（時間単位）
- チェックポイント頻度を決定（例: RPO 15分 → 15分ごとにチェックポイント）

**RTO (Recovery Time Objective)**:
- 障害後の許容最大ダウンタイム
- チェックポイントからの復元速度に依存

---

## 分散システムの8つの誤謬

L. Peter Deutschによって提唱された、分散システム実装時の誤った前提。

| 誤謬 | 説明 | 対策 |
|-----|------|------|
| **Reliable Network** | ネットワークは常に信頼できる | ネットワーク障害耐性を設計初期から組み込む |
| **Zero Latency** | レイテンシーはゼロ | Edge Computing、地理的に近いデータセンター利用 |
| **Infinite Bandwidth** | 帯域幅は無限 | 軽量データフォーマット使用、ネットワーク輻輳回避 |
| **Secure Network** | ネットワークは常に安全 | セキュリティファーストの設計、脅威モデリング |
| **Fixed Topology** | トポロジーは変化しない | トポロジーを抽象化、変更に耐性を持つ設計 |
| **Single Administrator** | 管理者は1人 | 疎結合設計、修復・トラブルシューティングの分散化 |
| **Zero Transport Cost** | 転送コストはゼロ | ネットワークインフラコストを予算に計上 |
| **Homogeneous Network** | ネットワークは均質 | 異種性を考慮、相互運用性を確保 |

**AWS Well-Architected Frameworkでの対応:**
- **Operational Excellence**: Single Administrator、Homogeneous Network
- **Security**: Secure Network
- **Reliability**: Reliable Network、Fixed Topology
- **Performance Efficiency**: Zero Latency、Infinite Bandwidth
- **Cost Optimization & Sustainability**: Zero Transport Cost

---

## システム設計のトレードオフ

### Time Versus Space（時間 vs 空間）

アルゴリズム実装における根本的なトレードオフ。

**例**: ルックアップテーブルを使用して再計算を回避
- メモリ/ストレージを追加消費
- リクエスト処理速度を向上

---

### Latency Versus Throughput（レイテンシー vs スループット）

#### 基本概念

**Latency（レイテンシー）**: リクエストが処理されるまでの待機時間
**Processing Time（処理時間）**: リクエスト処理にかかる時間
**Response Time（応答時間）**:
```
Response Time = Latency + Processing Time
```

**Throughput（スループット）**: 単位時間内に処理されるデータ量
**Bandwidth（帯域幅）**: 理論的最大データ転送量

| 概念 | 説明 | 関係 |
|-----|------|------|
| Bandwidth | 理論的上限 | - |
| Throughput | 実測値 | 常にBandwidth以下 |
| Latency | パケット到達時間 | 高いとThroughput低下 |

#### パーセンタイル指標
- **p50**: 最速50%のリクエストの最大レイテンシー
- **p90**: 最速90%のリクエストの最大レイテンシー
- **p99**: 最速99%のリクエストの最大レイテンシー

**設計目標**: 許容レイテンシー内で最大スループットを実現

---

### Performance Versus Scalability（パフォーマンス vs スケーラビリティ）

**Performance（パフォーマンス）**: 単一リクエストへの応答速度
**Scalability（スケーラビリティ）**: リソース追加に比例したパフォーマンス向上

**判断基準**:
- **パフォーマンス問題**: 単一ユーザーで遅い（p50 = 100ms）
- **スケーラビリティ問題**: 軽負荷では速いが高負荷で遅い（100リクエスト: p50 = 1ms、10万リクエスト: p50 = 100ms）

---

### Consistency Versus Availability（一貫性 vs 可用性）

#### CAP定理（Brewer's Theorem）

分散システムでは以下の3つの保証を同時に満たすことは不可能:
- **Consistency（C）**: すべての読み取りが最新の書き込みを返す
- **Availability（A）**: すべてのリクエストがエラーなしで応答を返す
- **Partition Tolerance（P）**: ネットワーク分断に耐性がある

**実際の選択**: ネットワーク分断は避けられないため、**CかAを選択**

#### PACELC定理

CAPの拡張版:
```
IF Partition occurs THEN choose between Availability and Consistency
ELSE (normal operation) choose between Latency and Consistency
```

**理由**: レプリケーションにより、一貫性とレイテンシーのトレードオフが発生
- **Strong Consistency**: 同期レプリケーション → 高レイテンシー
- **Eventual Consistency**: 非同期レプリケーション → 低レイテンシー

| トレードオフ | Strong Consistency | Eventual Consistency |
|------------|-------------------|---------------------|
| レイテンシー | 高い | 低い |
| データ精度 | 高い | 一時的不一致 |
| システム複雑性 | 高い | 低い |

---

## システム設計のガイドライン

### Guideline of Isolation: Build It Modularly（モジュール化の原則）

複雑なシステムを独立した小さなモジュールに分解。

#### メリット
- **Maintainability（保守性）**: 個別更新・置換が可能
- **Reusability（再利用性）**: 異なるプロジェクトで再利用
- **Scalability（スケーラビリティ）**: 独立したスケーリング
- **Reliability（信頼性）**: 個別テスト・検証でシステム全体の障害リスク削減

**実装方法**: Microservice Architecture、Component-Based Development、Modular Programming

---

### Guideline of Simplicity: Keep It Simple, Silly（KISS原則）

複雑性を避け、シンプルな設計を維持。

#### 実践方法
1. **コア要件の特定**: 必須機能を優先順位付け
2. **コンポーネント数の最小化**: 各コンポーネントが明確な目的を持つ
3. **過剰設計の回避**: 不要な機能を追加しない
4. **使いやすさ**: 直感的で理解しやすいシステム
5. **テストと改善**: 意図通り動作するか検証し、必要に応じて簡素化

---

### Guideline of Performance: Metrics Don't Lie（メトリクス重視の原則）

測定してから構築し、メトリクスを信頼。

#### Metrics（メトリクス）
パフォーマンスを評価する定量的指標:
- リソース使用率
- 応答時間
- エラー率

**目的**: パフォーマンスボトルネックや異常を検出し、是正措置を実施

#### Observability（オブザーバビリティ）
外部から見える出力からシステム状態を推測できる度合い。

**重要性**:
- リアルタイムでのシステム健全性監視
- 問題の診断
- 複雑システムの挙動監視

---

### Guideline of Trade-offs: TINSTAAFL（トレードオフの原則）

**TINSTAAFL（There Is No Such Thing As A Free Lunch）**: すべての決定にはトレードオフが伴う。

#### 考慮すべき要素
- パフォーマンス vs スケーラビリティ
- 信頼性 vs メンテナンス容易性
- コスト vs 複雑性

**例**:
- 高度に最適化されたソリューション → 保守性低下、複雑性増加
- シンプルなソリューション → パフォーマンス低下、レイテンシー増加

---

### Guideline of Use Cases: It Always Depends（ユースケース依存の原則）

システム設計は常に状況に依存する。

#### 影響要因
- 要件
- ユーザーニーズ
- 技術的制約
- コスト
- スケーラビリティ
- メンテナンス
- 規制

**真実**: システム設計に「ベストな方法」は存在しない → **銀の弾丸は存在しない**

---

## 結論

システム設計は、競合する要素間のバランスを取るプロセス。設計者は以下を慎重に検討する必要があります:

1. **基本概念の理解**: Communication、Consistency、Availability、Reliability、Scalability、Maintainability、Fault Tolerance
2. **誤謬の回避**: 分散システムの8つの誤謬を認識し対策
3. **トレードオフの評価**: Time vs Space、Latency vs Throughput、Performance vs Scalability、Consistency vs Availability
4. **ガイドラインの適用**: Isolation、Simplicity、Performance、Trade-offs、Use Cases

最終的に、特定の要件、リソース、コスト、トレードオフを評価し、効果的で効率的なシステムを構築することが目標です。
