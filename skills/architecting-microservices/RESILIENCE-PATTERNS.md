# レジリエンスパターン

## 概要

レジリエンスパターンは、分散システムにおいて依存サービスやリソースの障害時に、システム全体の連鎖的な障害を防ぎ、**graceful degradation（段階的な機能縮退）** を実現するための設計パターンです。

マイクロサービスアーキテクチャでは、1つのサービスの障害が他のサービスに伝播し、システム全体がダウンする「**カスケード障害**」が発生しやすくなります。レジリエンスパターンはこれを防ぐための必須技術です。

---

## 「鎖は最も弱いリンクと同じ強度しか持たない」原則

**ソフトウェアアプリケーションは、最も脆弱なマイクロサービスまたはインフラコンポーネントと同じレベルのレジリエンス・可用性しか持たない。**

この原則は、分散アプリケーション設計における最重要指針です。

### 設計指針

- **すべての依存サービスが障害を起こす前提で設計する**
- **単一障害点（Single Point of Failure）を排除する**
- **障害時の代替戦略（Fallback）を必ず用意する**
- **障害が伝播しないよう隔離（Isolation）する**

---

## Circuit Breaker（サーキットブレーカー）

### 概要

Circuit Breakerは、依存サービスへの呼び出しが失敗し続ける場合、一定期間そのサービスへの呼び出しを遮断し、システムリソースの無駄遣いを防ぐパターンです。

電気回路のブレーカーと同じく、「過負荷を検知したら回路を遮断し、復旧後に再接続を試みる」動作をします。

### 状態遷移

Circuit Breakerは3つの状態を持ちます:

```
┌──────────┐
│  Closed  │ ← 正常動作（リクエストを通す）
└─────┬────┘
      │ 失敗率が閾値超過
      ↓
┌──────────┐
│   Open   │ ← 即座に失敗応答（リクエストを遮断）
└─────┬────┘
      │ 待機時間経過
      ↓
┌──────────┐
│Half-Open │ ← 試験的にリクエストを通す
└─────┬────┘
      │ 成功 → Closed
      │ 失敗 → Open
```

| 状態 | 動作 | 遷移条件 |
|------|------|---------|
| **Closed（閉）** | リクエストを正常に通す | 失敗率が閾値を超える → Open |
| **Open（開）** | リクエストを即座に拒否（Fallbackに切り替え） | 待機時間（Wait Duration）経過 → Half-Open |
| **Half-Open（半開）** | 少数のリクエストを試験的に通す | 成功 → Closed / 失敗 → Open |

### 設定パラメータ

| パラメータ | 説明 | 推奨値 |
|-----------|------|--------|
| **Failure Rate Threshold** | エラー率の閾値（%） | 50%（過半数の失敗でOpen） |
| **Sliding Window Size** | 評価対象の直近リクエスト数 | 10〜100 |
| **Minimum Number of Calls** | 評価開始までの最低呼び出し数 | 5〜20 |
| **Wait Duration in Open State** | Open状態の待機時間 | 10〜60秒 |
| **Permitted Calls in Half-Open** | Half-Openで許可するリクエスト数 | 3〜10 |

### 実装例（擬似コード）

```
@CircuitBreaker(
  name = "payment-service",
  fallbackMethod = "fallbackPayment"
)
function processPayment(orderId) {
  // 外部決済サービスを呼び出し
  return paymentServiceClient.charge(orderId);
}

function fallbackPayment(orderId, exception) {
  // フォールバック処理
  log("Payment service unavailable. Using fallback.");
  return { status: "PENDING", orderId: orderId };
}
```

### Circuit Breaker適用シナリオ

- **外部API呼び出し**: 決済API、配送API等の外部サービス
- **データベースアクセス**: レプリカDBへのフェイルオーバー
- **マイクロサービス間通信**: 依存サービスが一時的にダウンした場合

---

## Retry（リトライ）戦略

### 概要

Retryパターンは、一時的な障害（ネットワーク瞬断、タイムアウト等）に対して、一定回数リクエストを再試行するパターンです。

### 指数バックオフ（Exponential Backoff）

**指数バックオフ** は、リトライ間隔を指数的に増加させる戦略です。

```
1回目: 即座にリトライ
2回目: 2秒後
3回目: 4秒後
4回目: 8秒後
5回目: 16秒後
```

### リトライ戦略の比較

| 戦略 | 説明 | メリット | デメリット |
|------|------|---------|-----------|
| **即座リトライ** | 待機なしで再試行 | 高速 | サーバー負荷増大 |
| **固定間隔** | 毎回同じ間隔でリトライ | シンプル | 最適でない |
| **指数バックオフ** | リトライ間隔を指数的に増加 | 負荷分散、復旧時間確保 | 最大待機時間が長くなる |
| **ジッター付き指数バックオフ** | ランダムな揺らぎを追加 | 同時リトライによるサーバー負荷集中回避 | 実装やや複雑 |

### リトライ設定の推奨値

| パラメータ | 推奨値 | 説明 |
|-----------|--------|------|
| **最大リトライ回数** | 3〜5回 | 過度なリトライは遅延を招く |
| **初期待機時間** | 1〜2秒 | 最初のリトライ前の待機時間 |
| **最大待機時間** | 30〜60秒 | 指数バックオフの上限 |
| **リトライ対象エラー** | 5xx、タイムアウト、ネットワークエラー | 4xxクライアントエラーはリトライしない |

### 実装例（擬似コード）

```
@Retry(
  name = "inventory-service",
  maxAttempts = 3,
  waitDuration = 2s,
  exponentialBackoff = true
)
function checkInventory(productId) {
  return inventoryServiceClient.getStock(productId);
}
```

---

## Bulkhead（バルクヘッド）

### 概要

Bulkheadパターンは、船の隔壁（バルクヘッド）からの命名で、システムリソース（スレッドプール、コネクション等）を分離し、1つの障害が他の機能に影響しないよう隔離するパターンです。

### スレッドプール隔離

異なる依存サービスごとに専用のスレッドプールを割り当てます。

```
┌──────────────────┐
│ Payment Service  │ → Thread Pool A (10 threads)
├──────────────────┤
│ Inventory Service│ → Thread Pool B (20 threads)
├──────────────────┤
│ Shipping Service │ → Thread Pool C (5 threads)
└──────────────────┘
```

**効果**: Payment Serviceがハングアップしても、Inventory ServiceとShipping Serviceは影響を受けません。

### セマフォ隔離

セマフォ（カウンティングセマフォ）を使って、同時実行数を制限します。

```
Semaphore (Max Concurrent Calls = 10)
├─ Request 1
├─ Request 2
├─ ...
├─ Request 10
└─ Request 11 → Rejected (Limit exceeded)
```

### スレッドプール vs セマフォ

| 特性 | スレッドプール隔離 | セマフォ隔離 |
|------|------------------|-------------|
| **リソース消費** | 大（専用スレッド確保） | 小（カウンター管理のみ） |
| **タイムアウト制御** | 可能 | 不可（呼び出し元スレッドで実行） |
| **オーバーヘッド** | 高（スレッド切り替え） | 低 |
| **適用シナリオ** | 外部API呼び出し | 内部リソースアクセス |

### 実装例（擬似コード）

```
@Bulkhead(
  name = "external-api",
  type = Bulkhead.Type.THREADPOOL,
  maxConcurrentCalls = 10,
  maxWaitDuration = 500ms
)
function callExternalAPI(request) {
  return externalClient.call(request);
}
```

---

## Fallback / Degradation（フォールバック / 機能縮退）

### 概要

Fallbackパターンは、依存サービスが利用不可の場合に、代替手段を提供するパターンです。

### Fallback戦略

| 戦略 | 説明 | 適用例 |
|------|------|--------|
| **キャッシュ応答** | ローカルキャッシュからデータを返す | 商品情報、ユーザープロフィール |
| **デフォルト値** | 事前定義されたデフォルト値を返す | おすすめ商品リスト（空リスト返却） |
| **代替サービス** | 別のサービスインスタンスに切り替え | プライマリDB → レプリカDB |
| **機能スキップ** | オプショナル機能を無効化 | レコメンド機能停止（商品一覧は表示） |
| **エラー応答** | ユーザーフレンドリーなエラーメッセージ | 「現在一時的に利用できません」 |

### Graceful Degradation（段階的機能縮退）

システム全体がダウンするのではなく、**一部機能を停止してコア機能だけを維持**する設計思想です。

```
100% 機能 → 決済、在庫、配送、レコメンド、レビュー
  ↓ レコメンドサービス障害
80% 機能 → 決済、在庫、配送、レビュー（レコメンドは非表示）
  ↓ レビューサービス障害
60% 機能 → 決済、在庫、配送（レビューは非表示）
```

### 実装例（擬似コード）

```
function getRecommendations(userId) {
  try {
    return recommendationService.getRecommendations(userId);
  } catch (ServiceUnavailableException e) {
    // Fallback: 人気商品を返す
    return defaultRecommendations;
  }
}
```

---

## Fail-Safeマイクロサービス設計パターン

### 概要

**Fail-Safe** は、障害が発生しても安全な状態を維持する設計原則です。

### Fail-Safe設計原則

| 原則 | 説明 |
|------|------|
| **デフォルトセーフ** | 障害時はデフォルト値で動作継続 |
| **タイムアウト必須** | すべての外部呼び出しにタイムアウト設定 |
| **冪等性保証** | 同じリクエストを複数回実行しても結果が同じ |
| **トランザクション境界** | 部分的失敗を許容する設計（Saga等） |
| **監視・アラート** | 障害検知を自動化 |

### Fail-Safeマイクロサービスのチェックリスト

- [ ] すべての外部呼び出しにタイムアウト設定（推奨: 2〜5秒）
- [ ] Circuit Breakerを実装
- [ ] Retryロジックを実装（指数バックオフ）
- [ ] Fallback戦略を定義
- [ ] ヘルスチェックエンドポイント実装（`/health`）
- [ ] ログ・メトリクスを収集
- [ ] カオスエンジニアリングテスト実施

---

## レジリエンスパターン選択判断基準

| シナリオ | 推奨パターン | 理由 |
|---------|-------------|------|
| 外部API呼び出し | Circuit Breaker + Retry + Fallback | 外部サービスは制御不可、複数防御線必要 |
| データベースアクセス | Retry + Bulkhead | 一時的な接続エラーに対応、スレッド隔離 |
| 長時間処理（バッチ等） | Bulkhead + Timeout | リソース枯渇防止 |
| キャッシュアクセス | Fallback | キャッシュミス時はDBから取得 |
| マイクロサービス間通信 | Circuit Breaker + Retry + Fallback | 依存サービス障害に対する多層防御 |

---

## 実装ライブラリ

| ライブラリ | 言語/フレームワーク | 特徴 |
|-----------|-------------------|------|
| **Resilience4j** | Java（Spring Boot統合） | 軽量、モジュール型、Circuit Breaker/Retry/Bulkhead/RateLimiter |
| **Polly** | .NET | Circuit Breaker、Retry、Timeout、Bulkhead |
| **Hystrix** | Java（非推奨、Resilience4jに移行推奨） | Netflix製、先駆的だがメンテナンス終了 |
| **Tenacity** | Python | Retryロジック特化 |
| **Circuit Breaker（Go）** | Go | `github.com/sony/gobreaker` |

---

## まとめ

レジリエンスパターンは、マイクロサービスアーキテクチャにおいて以下を実現します:

1. **障害の隔離**: 1つのサービス障害が全体に伝播しない
2. **段階的機能縮退**: コア機能を維持しながら一部機能を停止
3. **自己回復**: 障害から自動的に復旧
4. **リソース保護**: スレッド・コネクション枯渇を防ぐ

**Circuit Breaker**、**Retry**、**Bulkhead**、**Fallback** を組み合わせることで、堅牢な分散システムを構築できます。
