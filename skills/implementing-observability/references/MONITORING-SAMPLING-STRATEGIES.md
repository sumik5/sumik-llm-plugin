# サンプリング戦略

## 概要

オブザーバビリティデータの量が増大すると、すべてのイベントを保存・処理するコストが現実的でなくなります。サンプリングは、データの再現性を保ちながらリソース消費を最適化する手法です。適切なサンプリング戦略により、小規模から大規模まで、効率的なオブザーバビリティを実現できます。

---

## サンプリングの必要性

### データ量とコストのトレードオフ

**規模拡大時の課題**:
```
100,000 リクエスト/秒 × 1KB/イベント × 86,400秒/日 = 8.6 TB/日
月間コスト: ストレージ、処理、転送費用が膨大に
```

**サンプリングの利点**:
- リソースコスト削減（ストレージ、CPU、ネットワーク）
- 小規模でも貴重なコスト削減
- データの統計的代表性は維持

### 精度と効率のバランス

**メトリクスとの違い**:

| アプローチ | データ保持 | 粒度 | カーディナリティ |
|----------|----------|-----|----------------|
| **メトリクス** | 集計値のみ | 粗い | 低（事前に固定） |
| **サンプリング** | 代表イベント | 細かい | 高（完全保持） |

**重要**: サンプリングされたイベントは各ディメンションのカーディナリティを完全に保持します。集計されたメトリクスのように「これ以上分解できない」ことはありません。

### 大半のイベントは「正常動作」

**観測される事実**:
- イベントの大半は同じ「正常動作」パターン
- デバッグで重要なのは異常パターンの検出
- 全イベントの100%転送は無駄

**サンプリングの本質**:
- 発生イベントを代表するサンプルを選択
- メタデータとともに送信し元の分布を再構築
- 「良い」イベントのサンプルと「悪い」イベントを比較

---

## ヘッドサンプリング vs テールサンプリング

### 定義

| 手法 | 判断タイミング | 判断基準 | 実装場所 |
|------|-------------|---------|---------|
| **ヘッドサンプリング** | トレース開始時 | 静的プロパティ（エンドポイント、顧客ID等） | 計装コード |
| **テールサンプリング** | トレース完了後 | 動的プロパティ（ステータスコード、レイテンシ等） | 外部コレクター |

### ヘッドサンプリング（アップフロントサンプリング）

**仕組み**:
1. トレース開始時にサンプリング判定
2. 決定を下流に伝搬（例: `Sampling-ID`ヘッダー）
3. トレース全体が一貫してサンプリング/破棄される

**メリット**:
- 実装がシンプル
- 計算コストが低い
- トレース全体の一貫性保証

**デメリット**:
- レスポンスステータスやレイテンシーでフィルタリング不可
- 実行完了後にしかわからない情報を使えない

**適したシナリオ**:
- エンドポイント別にサンプリング割合を変えたい
- 顧客ID別にサンプリングしたい
- トラフィック量が安定している

### テールサンプリング

**仕組み**:
1. 全スパンを一時バッファに収集
2. トレース完了後にサンプリング判定
3. 動的フィールド（ステータス、レイテンシ）を使用可能

**メリット**:
- エラーや高レイテンシーイベントを確実にキャプチャ
- 実行結果に基づく高度な判定

**デメリット**:
- バッファリングに高い計算コスト
- 外部コレクター必須
- 実装が複雑

**適したシナリオ**:
- エラーイベントを確実に保存したい
- レイテンシー異常値を重視
- リソースに余裕がある

### 判断基準テーブル

| 要件 | 推奨手法 | 理由 |
|------|---------|------|
| エラーイベント重視 | テール | ステータスコードは実行後にしかわからない |
| エンドポイント別制御 | ヘッド | URLは開始時点でわかる |
| 顧客ID別制御 | ヘッド | リクエスト開始時に識別可能 |
| レイテンシー異常値重視 | テール | 実行時間は完了後にしかわからない |
| 低コスト実装 | ヘッド | 外部コレクター不要 |
| 高度な判定 | テール | 複数条件の複雑な組み合わせ可能 |
| トレース一貫性必須 | ヘッド | 下流伝搬で全スパン統一 |

---

## 固定サンプリング

### 一定割合サンプリング

**最もシンプルな手法**: 一定割合（例: 1/1000）でデータを保持

**実装例**（擬似コード）:
```
sampleRate = 1000  // 1,000回に1回サンプリング
r = random(0, 1)
if r < 1.0 / sampleRate:
    recordEvent(event, sampleRate)
```

**メリット**:
- 理解しやすい
- 実装が簡単

**デメリット**:
- エラーケースを見逃す可能性
- トラフィック急増時に対応できない
- 大容量ソースが小容量ソースを隠してしまう

**適したシナリオ**:
- 十分なデータ量があり、エラーが再発する環境
- トラフィックが安定している
- 初期導入段階

### サンプル割合の記録

**問題**: 受信側がサンプル割合を知らないと正確な集計ができない

**解決策**: 各イベントにサンプル割合を含める

```
if r < 1.0 / sampleRate:
    event.sampleRate = sampleRate  // サンプル割合を記録
    recordEvent(event)
```

**データ再構築**:
- **総数計算**: 各イベント数 × そのイベントのsampleRate を合計
- **合計値計算**: 各イベントの値 × そのイベントのsampleRate を合計
- **パーセンタイル**: イベントをsampleRate倍に拡張して計算

**例**:
```
収集イベント: [(値:1, rate:5), (値:3, rate:2), (値:7, rate:9)]
総数 = 5 + 2 + 9 = 16イベント
拡張: [1,1,1,1,1, 3,3, 7,7,7,7,7,7,7,7,7]
中央値 = 7
```

### 一貫したサンプリング

**トレースの課題**: 各サービスで独立にランダム判定すると、トレースが壊れる

**問題例**:
```
親スパン: サンプリング割合 1/10 → 破棄
子スパン: サンプリング割合 1/1000 → 保持
結果: 孤立した子スパンのみ（コンテキスト欠落）
```

**解決策**: `Sampling-ID`を生成して下流に伝搬

```
// ルートスパン
samplingID = random(0, 1)
header["Sampling-ID"] = samplingID

// 下流スパン
samplingID = header["Sampling-ID"]  // 同じIDを使用
if samplingID < 1.0 / sampleRate:
    recordEvent(event, sampleRate)
```

**効果**:
- トレース全体が一貫して保持/破棄される
- 親が保持されるなら子も保持
- 親が破棄されるなら子も破棄

---

## 動的サンプリング

### 目標割合サンプリング

**目的**: トラフィック量に応じてサンプル割合を自動調整

**仕組み**:
```
目標: 5イベント/秒を送信したい
過去1分間のリクエスト数を追跡
sampleRate = 過去1分間のリクエスト数 / (60秒 × 5イベント/秒)
```

**実装パターン**:
```
毎分:
    newRate = requestsInPastMinute / (60 * targetEventsPerSec)
    sampleRate = max(1.0, newRate)
    requestsInPastMinute = 0  // リセット
```

**メリット**:
- リソースコストが予測可能
- トラフィック急増時に自動的に割合を下げる
- 手動調整不要

**デメリット**:
- キー別の柔軟な調整ができない
- すべてのイベントが同じ割合

**適したシナリオ**:
- コスト予測が重要
- トラフィック変動が大きい
- シンプルな制御で十分

### 複数の静的サンプリング割合

**目的**: イベントの種類によって異なる割合を適用

**実装例**:
```
baseRate = 1000        // 通常イベント: 1/1000
outlierRate = 5        // 異常イベント: 1/5

if error != nil OR latency > 500ms:
    if random() < 1.0 / outlierRate:
        recordEvent(event, outlierRate)
else:
    if random() < 1.0 / baseRate:
        recordEvent(event, baseRate)
```

**メリット**:
- エラーや高レイテンシーを重視できる
- 実装が比較的シンプル

**デメリット**:
- エラー急増時に対応できない
- 固定割合なのでトラフィック変動に弱い

**適したシナリオ**:
- エラーイベントを確実に保存したい
- トラフィックが比較的安定
- 異常値の検出が重要

### キーと目標割合を組み合わせたサンプリング

**最も実践的なアプローチ**: イベントの内容別に目標割合を動的調整

**仕組み**:
```
キーの組み合わせ: [顧客ID, データセットID, エラーコード]
過去30秒間にそのキーが何回出現したかを追跡
そのキーのサンプル割合 = 出現回数 / (30秒 × 目標イベント/秒)
```

**実装パターン**:
```
keyから割合を計算:
    key = (customerID, datasetID, errorCode)
    count[key]++

毎30秒:
    for each key:
        rate[key] = count[key] / (30 * targetRate[key])
    count = {}  // リセット
```

**メリット**:
- キー別に柔軟な制御
- トラフィック変動に自動対応
- レアなキーも適切にサンプリング

**デメリット**:
- 実装が複雑
- メモリ使用量が増加（キー数に比例）

**適したシナリオ**:
- 多様な顧客・エンドポイント
- トラフィック分布が不均一
- 高度な制御が必要

### 任意数のキーに対応する動的サンプリング

**実装の工夫**: マップ構造で任意のキー組み合わせに対応

```go
type SampleKey struct {
    ErrMsg        string
    BackendShard  int
    LatencyBucket int
}

counts := make(map[SampleKey]int)
sampleRates := make(map[SampleKey]float64)
targetRates := make(map[SampleKey]int)

// 各イベントでキーを生成
key := SampleKey{
    ErrMsg:       errorMessage,
    BackendShard: shardID,
    LatencyBucket: roundLatency(latency),
}
counts[key]++

// 定期的にレート更新
for key, count := range counts {
    sampleRates[key] = float64(count) / (interval * targetRates[key])
}
```

**ライブラリの活用**:
- Go: `dynsampler-go` (Honeycomb提供)
- 任意数のキーに対応
- 目標割合の自動計算
- 新規キーへの公平な領域割り当て

---

## サンプリング実装パターン

> **出典**: オブザーバビリティ・エンジニアリング Ch.17「サンプリング戦略をコードに置き換える」の知見を再構成

### 概要

前節の概念を実際のコードに落とし込む方法を示す。実装言語はGoを参考にしているが、連想配列・疑似乱数生成・並行処理をサポートする言語であれば移植可能。

---

### パターン1: 固定割合サンプリングの実装

**最も基本的な形**:

```
sampleRate = 1000  // 設定ファイルから読み込む

function handler(request):
    r = randomFloat(0.0, 1.0)
    if r < 1.0 / sampleRate:
        recordEvent(request)
```

**問題点**: 受信側がサンプリング割合を「知らない」ため、イベント数を誤ってレポートする。

---

### パターン2: SampleRateフィールドの記録

**改善**: イベント送信時にサンプル割合を含める

```
sampleRate = 1000

function handler(request):
    r = randomFloat(0.0, 1.0)
    if r < 1.0 / sampleRate:
        recordEvent(request, sampleRate=sampleRate)  // 割合を含めて送信
```

**受信側での再構築**:
- イベント総数 = 各イベント数 × そのイベントの `sampleRate` の合計
- レイテンシー合計 = 各イベントの値 × `sampleRate` の合計
- パーセンタイル = 各イベントを `sampleRate` 倍に展開してから計算

**ポイント**: サンプル割合が途中で変更された場合でも、各イベントに記録された割合を使えば正確に再構築できる。

---

### パターン3: 一貫したサンプリング（Sampling-ID伝搬）

**目的**: 分散トレースで親スパンと子スパンの判定を統一する

```
function handler(request):
    // 上流からSampling-IDがあれば使用（ルートスパンが生成した値）
    if request.header["Sampling-ID"] exists:
        r = hexToFloat(request.header["Sampling-ID"])
    else:
        r = randomFloat(0.0, 1.0)  // このハンドラーがルートスパン

    // 下流サービスへSampling-IDを伝搬
    downstreamRequest.header["Sampling-ID"] = r

    result = callDownstreamService(downstreamRequest)

    if r < 1.0 / sampleRate:
        recordEvent(request, sampleRate=sampleRate)
```

**効果**:
- 同一の `r` 値をトレース全体で共有 → 全スパンが同じ判定結果に
- 親スパンが破棄 → 子スパンも破棄（孤立スパン防止）
- 親スパンが保持 → 子スパンも保持（完全なトレース保証）

---

### パターン4: 目標割合サンプリング（自動レート調整）

**目的**: 手動でサンプル割合を調整せず、目標スループットを自動維持する

```
targetEventsPerSec = 5     // 1秒あたり送信したいイベント数
sampleRate = 1.0           // 初期値（全イベント送信）
requestsInPastMinute = 0   // 前の1分間のリクエスト数

// バックグラウンドで毎分実行
background every 60 seconds:
    newRate = requestsInPastMinute / (60 * targetEventsPerSec)
    sampleRate = max(1.0, newRate)
    requestsInPastMinute = 0  // カウンターリセット

function handler(request):
    r = hexToFloat(request.header["Sampling-ID"]) or randomFloat(0.0, 1.0)
    requestsInPastMinute++

    if r < 1.0 / sampleRate:
        recordEvent(request, sampleRate=sampleRate)
```

**注意**: カウンターのインクリメントとリセットの並行アクセスによるレースコンディションに注意。本番環境では atomic 操作やロック機構を使用すること。

---

### パターン5: キー+目標割合の組み合わせ

**目的**: 通常リクエストと異常リクエストで独立した目標割合を設定する

```
targetEventsPerSec = 4     // 通常リクエストの目標
outlierEventsPerSec = 1    // 異常リクエストの目標（エラー/高レイテンシー）

sampleRate = 1.0
outlierSampleRate = 1.0
requestsInPastMinute = 0
outliersInPastMinute = 0

background every 60 seconds:
    sampleRate = max(1.0, requestsInPastMinute / (60 * targetEventsPerSec))
    outlierSampleRate = max(1.0, outliersInPastMinute / (60 * outlierEventsPerSec))
    requestsInPastMinute = 0
    outliersInPastMinute = 0

function handler(request):
    r = hexToFloat(request.header["Sampling-ID"]) or randomFloat(0.0, 1.0)
    result = callDownstreamService(r)

    if result.error != nil or result.latency > 500ms:
        outliersInPastMinute++
        if r < 1.0 / outlierSampleRate:
            recordEvent(request, sampleRate=outlierSampleRate)
    else:
        requestsInPastMinute++
        if r < 1.0 / sampleRate:
            recordEvent(request, sampleRate=sampleRate)
```

---

### パターン6: 任意キー数への対応（マップベース動的サンプリング）

**目的**: 固定カテゴリではなく、任意のキー組み合わせに対して動的に割合を管理する

```
// データ構造
counts = {}       // SampleKey → 発生回数
sampleRates = {}  // SampleKey → 現在のサンプル割合
targetRates = {}  // SampleKey → 目標割合（設定値）

SampleKey = {
    errorMessage: string,    // エラーメッセージ（正常時は空文字）
    backendShard: int,       // バックエンドシャードID
    latencyBucket: int       // レイテンシーを100ms単位に丸めた値
}

background every interval:
    for each key in counts:
        newRate = counts[key] / (interval * targetRates[key])
        sampleRates[key] = max(1.0, newRate)
    counts = {}  // リセット

function checkSampleRate(request, result):
    key = SampleKey {
        errorMessage: result.error?.message or "",
        backendShard: result.header["Backend-Shard"],
        latencyBucket: roundTo100ms(result.latency)
    }

    if shouldNeverSample(key):  // ヘルスチェック等を除外
        return -1.0

    counts[key]++
    return sampleRates[key] or 1.0  // 未知のキーは全件サンプリング

function handler(request):
    r = hexToFloat(request.header["Sampling-ID"]) or randomFloat(0.0, 1.0)
    result = callDownstreamService(r)

    rate = checkSampleRate(request, result)
    if rate > 0 and r < 1.0 / rate:
        recordEvent(request, sampleRate=rate)
```

**ライブラリ活用**: Goでは `dynsampler-go`（Honeycomb製）がこのパターンを実装済み。新規キーへの公平な領域割り当てや、目標割合自動計算も備える。

---

### パターン7: ヘッド+テール統合サンプリング

**目的**: ヘッドサンプリングの効率性とテールサンプリングの精度を両立する

```
// headSampleRates, tailSampleRates, headCounts, tailCounts は
// パターン6と同様のマップ構造

function handler(request):
    r = hexToFloat(request.header["Sampling-ID"]) or randomFloat(0.0, 1.0)

    // 上流からヘッドサンプリング済みか確認
    upstreamRate = request.header["Upstream-Sample-Rate"]

    if upstreamRate > 0:
        // 上流の決定に従う（下流サービスもこのリクエストを保持）
        headSampleRate = upstreamRate
    else:
        // このスパンでヘッドサンプリング判定
        headSampleRate = checkHeadSampleRate(request, headSampleRates, headCounts)
        if headSampleRate > 0 and r < 1.0 / headSampleRate:
            // ヘッドサンプリング成功 → 決定を下流に伝搬
            downstreamRequest.header["Upstream-Sample-Rate"] = headSampleRate
        else:
            headSampleRate = -1.0  // ヘッドサンプリング対象外

    result = callDownstreamService(r, headSampleRate)

    if headSampleRate > 0:
        // ヘッドサンプリングで採択 → 記録
        recordEvent(request, sampleRate=headSampleRate)
    else:
        // ヘッドでは除外 → テールサンプリングで救済判定（下流伝搬はしない）
        tailRate = checkTailSampleRate(result, tailSampleRates, tailCounts)
        if tailRate > 0 and r < 1.0 / tailRate:
            recordEvent(request, sampleRate=tailRate)
```

**フロー整理**:

| ケース | 処理 |
|-------|------|
| 上流がヘッドサンプリング済み | 上流の割合をそのまま使用して記録 |
| 自スパンでヘッドサンプリング成功 | 下流に `Upstream-Sample-Rate` を伝搬して記録 |
| ヘッドで除外 → テールで採択 | 下流に伝搬せず、このスパンのみ記録 |
| 両方で除外 | 破棄 |

**さらなる発展**: コレクター側でバッファー付きサンプリングを組み合わせると、トレース全体が揃ってからサンプリング判定でき、ヘッドの効率とテールの精度を最大化できる。

---

## 統合アプローチ

### キー、目標割合、ヘッドとテイルを全部使う

**最も高度な手法**: ヘッドサンプリングとテールサンプリングを組み合わせ

**仕組み**:
1. **ヘッドサンプリング**: リクエスト開始時に判定、下流に伝搬
2. **テールサンプリング**: 完了後に追加判定、ヘッドで破棄された場合のみ

```
if upstreamSampleRate > 0:
    // 上流でヘッドサンプリング済み → そのまま使用
    recordEvent(event, upstreamSampleRate)
else:
    // ヘッドサンプリングで破棄された
    // テールサンプリングで救済可能か判定
    if error != nil OR latency > threshold:
        tailRate = calculateTailRate(event)
        if random() < 1.0 / tailRate:
            recordEvent(event, tailRate)
```

**伝搬の実装**:
```
// ルートスパン
if headSampled:
    header["Upstream-Sample-Rate"] = headSampleRate
else:
    header["Upstream-Sample-Rate"] = -1  // サンプリングしない

// 下流スパン
if upstreamRate := header["Upstream-Sample-Rate"]; upstreamRate > 0:
    // 上流の決定に従う
    recordEvent(event, upstreamRate)
```

**メリット**:
- トレース一貫性とエラー検出を両立
- 通常イベントはヘッドで効率的に
- 異常イベントはテールで確実に

**デメリット**:
- 実装が非常に複雑
- デバッグが困難
- パフォーマンスオーバーヘッド

**適したシナリオ**:
- 大規模システム
- エラー検出が最重要
- リソースに余裕がある

### バッファー付きサンプリング

**外部コレクター側での実装**:
```
コレクター:
    1. 全スパンをバッファに収集
    2. トレース完了を検出
    3. トレース全体を評価してサンプリング判定
    4. 保持するトレースのみ送信
```

**判定例**:
```
if trace.hasError():
    keep = True
elif trace.maxLatency() > 500ms:
    keep = True
elif random() < 1.0 / baseRate:
    keep = True
else:
    keep = False
```

**メリット**:
- トレース全体の情報で判定
- ヘッドとテイルの利点を統合
- 計装コードへの影響なし

**デメリット**:
- コレクターが必要
- バッファリングコストが高い
- レイテンシーが増加

---

## 判断基準テーブル（統合）

### 状況別推奨サンプリング戦略

| 状況 | 推奨戦略 | 理由 |
|------|---------|------|
| **初期導入** | 一定割合 | シンプル、理解しやすい |
| **トラフィック安定** | 固定複数割合 | エラー重視、実装容易 |
| **トラフィック変動** | 目標割合 | コスト予測可能 |
| **多様な顧客** | キー別動的 | 不均一分布に対応 |
| **エラー検出重視** | テール | ステータスコードで判定 |
| **トレース一貫性重視** | ヘッド | 下流伝搬で統一 |
| **大規模システム** | 統合（ヘッド+テール） | 効率と精度を両立 |
| **コスト最優先** | 目標割合 | リソース使用量を制御 |
| **デバッグ優先** | バッファー付き | 最高の精度 |

### サービスタイプ別推奨

| サービスタイプ | 推奨戦略 | 理由 |
|-------------|---------|------|
| **アプリトップページ** | 一定割合 | トラフィック均一 |
| **リードスルーキャッシュ** | 一定割合（高） | 大半がキャッシュミス |
| **DBプロキシ** | キー別動的 | クエリパターン多様 |
| **決済API** | 統合（エラー重視） | エラー検出が最重要 |
| **分析バッチ** | 目標割合 | 処理量変動大 |

---

## まとめ

### サンプリングの基本原則

1. **サンプル割合を記録**: 各イベントに割合を含めてデータ再構築可能に
2. **一貫性を保つ**: トレース全体で統一した判定
3. **動的に調整**: トラフィック変動に自動対応
4. **キー別制御**: イベントの重要度に応じて柔軟に

### 実装の進め方

**ステップ1: 一定割合サンプリングから開始**
- シンプルで理解しやすい
- 効果を確認しながら次に進む

**ステップ2: 複数割合に拡張**
- エラーイベントを重視
- 異常値の検出を改善

**ステップ3: 動的サンプリングを導入**
- 目標割合でコスト制御
- キー別に柔軟な調整

**ステップ4: ヘッド/テールの組み合わせ（必要に応じて）**
- 大規模システムで真価を発揮
- 実装・運用コストとのバランスを検討

### ライブラリとツールの活用

**推奨アプローチ**:
- OpenTelemetryなどの標準ライブラリを使用
- 車輪の再発明を避ける
- 内部動作を理解した上でライブラリに任せる

**実装時の注意**:
- レースコンディションに注意（並行処理）
- メモリ使用量を監視（キー数増加）
- パフォーマンス影響を測定

---

## 次のステップ

- `implementing-opentelemetry` スキルでサンプリングを実装
- `SLO-RELIABILITY.md` でイベントベースSLOとサンプリングを統合
- テレメトリーパイプラインでサンプリング戦略を一元管理
