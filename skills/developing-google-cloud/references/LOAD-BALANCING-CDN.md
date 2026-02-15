# GCP ロードバランシング・CDN リファレンス

GCPのロードバランシングサービス選択・設定パターンとCloud CDNによるレイテンシ最適化。

---

## ロードバランサー分類

### External vs Internal

| カテゴリ | スコープ | トラフィック方向 |
|---------|---------|---------------|
| **External** | グローバル or リージョナル | インターネット → VPC |
| **Internal** | リージョナル（Global Access可） | VPC内部 |

### ロードバランサー選択テーブル

| LBタイプ | レイヤー | スコープ | プロトコル | ユースケース |
|---------|--------|---------|----------|------------|
| **External HTTP(S)** | L7 | グローバル | HTTP/HTTPS/HTTP2 | グローバルWebアプリ、URLベースルーティング |
| **External SSL Proxy** | L4 | グローバル | SSL（非HTTPS） | SSL オフロード |
| **External TCP Proxy** | L4 | グローバル | TCP | グローバルTCPサービス、クライアントIP取得（PROXY_PROTOCOL） |
| **External TCP/UDP Network** | L4 | リージョナル | TCP/UDP | 外部UDP、パススルーLB |
| **Internal HTTP(S)** | L7 | リージョナル | HTTP/HTTPS/HTTP2 | 内部マイクロサービス、URLベースルーティング |
| **Internal TCP/UDP** | L4 | リージョナル | TCP/UDP | 内部L4トラフィック |

### 選択フロー

```
トラフィック種別
    ↓
【External or Internal?】
    ├─ External
    │   ├─ HTTP(S)? → External HTTP(S) LB（グローバル）
    │   ├─ SSL（非HTTPS）? → SSL Proxy LB（グローバル）
    │   ├─ TCP? → TCP Proxy LB（グローバル）
    │   └─ UDP or パススルー? → TCP/UDP Network LB（リージョナル）
    │
    └─ Internal
        ├─ HTTP(S)? → Internal HTTP(S) LB（リージョナル）
        └─ TCP/UDP? → Internal TCP/UDP LB（リージョナル）
```

---

## External HTTP(S) Global Load Balancing

### アーキテクチャ構成要素

| 構成要素 | 説明 | 設定ポイント |
|---------|------|------------|
| **Frontend** | パブリックIP + ポート | Anycast IPv4/IPv6、Premium Tier推奨 |
| **URL Map** | ホスト・パスルール | ホスト/パスベースのルーティング、リダイレクト、リライト |
| **Backend Service** | バックエンドグループ定義 | MIG/NEG、バランシングモード、タイムアウト |
| **Health Check** | バックエンドヘルスチェック | TCP/HTTP、チェック間隔、しきい値 |
| **Backend** | Compute Engine MIG/NEG | リージョン分散、オートスケーリング |

### バランシングモード

| モード | 容量指定 | ユースケース |
|--------|---------|------------|
| **Utilization** | max-utilization（オプション） | CPU使用率ベース（デフォルト） |
| **Rate** | max-rate or max-rate-per-instance（必須） | リクエストレートベース |

### セットアップ手順（gcloud）

```bash
# 1. ヘルスチェック作成
gcloud compute health-checks create http my-health-check \
  --port=80 \
  --check-interval=10s \
  --unhealthy-threshold=3

# 2. バックエンドサービス作成
gcloud compute backend-services create my-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=my-health-check \
  --global

# 3. バックエンド追加（MIG）
gcloud compute backend-services add-backend my-backend-service \
  --instance-group=us-web-mig \
  --instance-group-zone=us-central1-a \
  --balancing-mode=UTILIZATION \
  --max-utilization=0.8 \
  --global

# 4. URLマップ作成
gcloud compute url-maps create my-url-map \
  --default-service=my-backend-service

# 5. ターゲットHTTPプロキシ作成
gcloud compute target-http-proxies create my-http-proxy \
  --url-map=my-url-map

# 6. フォワーディングルール作成
gcloud compute forwarding-rules create my-http-rule \
  --load-balancing-scheme=EXTERNAL \
  --target-http-proxy=my-http-proxy \
  --ports=80 \
  --global
```

### ファイアウォールルール（必須）

```bash
# ヘルスチェック用（GCPヘルスチェッカーからのトラフィック許可）
gcloud compute firewall-rules create allow-health-check \
  --network=my-vpc \
  --action=ALLOW \
  --direction=INGRESS \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=http-server \
  --rules=tcp

# ユーザートラフィック用
gcloud compute firewall-rules create allow-http \
  --network=my-vpc \
  --action=ALLOW \
  --direction=INGRESS \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server \
  --rules=tcp:80
```

### URLマップ（ホスト・パスルール）

URLマップはリクエストのホストとパスに基づいてバックエンドサービスまたはバックエンドバケットにルーティングする。

```
# ルーティング例
https://example.com/video  → video-backend-service
https://example.com/audio  → audio-backend-service
https://example.com/images → cloud-storage-bucket
*（デフォルト）            → default-backend-service
```

Advanced modeでは URL リダイレクトやリライトも設定可能。

---

## Internal TCP/UDP Load Balancing

### 特徴

- **リージョナル**（L4、パススルー型）
- Maglev アルゴリズムによる高性能ロードバランシング
- **Global Access** オプションで他リージョンのVMからもアクセス可能
- フロントエンドIPはサブネット内の静的内部IPを予約

### セットアップ手順（gcloud）

```bash
# 1. ヘルスチェック作成
gcloud compute health-checks create tcp my-internal-hc \
  --port=80 \
  --check-interval=10s

# 2. バックエンドサービス作成（リージョナル）
gcloud compute backend-services create my-internal-backend \
  --protocol=TCP \
  --health-checks=my-internal-hc \
  --load-balancing-scheme=INTERNAL \
  --region=us-central1

# 3. バックエンド追加
gcloud compute backend-services add-backend my-internal-backend \
  --instance-group=us-central1-mig \
  --instance-group-zone=us-central1-a \
  --region=us-central1

# 4. フォワーディングルール作成（Global Access有効）
gcloud compute forwarding-rules create my-internal-rule \
  --load-balancing-scheme=INTERNAL \
  --backend-service=my-internal-backend \
  --subnet=us-central1-sub1 \
  --region=us-central1 \
  --ports=80,8008,8080,8088,443 \
  --allow-global-access
```

### Global Access

| 設定 | 動作 | ユースケース |
|------|------|------------|
| 無効（デフォルト） | 同一リージョンのVMのみアクセス可能 | リージョン内通信のみ |
| **有効** | 他リージョンのVMからもフロントエンドIPにアクセス可能 | クロスリージョン内部通信 |

---

## Cloud CDN

### 有効化

Cloud CDNはHTTP(S)ロードバランサーのバックエンドサービスまたはバックエンドバケットで有効化する。

```bash
# バックエンドサービスでCDN有効化
gcloud compute backend-services update my-backend-service \
  --enable-cdn \
  --global

# バックエンドバケットでCDN有効化
gcloud compute backend-buckets update my-backend-bucket \
  --enable-cdn
```

### キャッシュモード

| モード | 動作 | 推奨 |
|--------|------|------|
| **Cache static content**（デフォルト） | 静的コンテンツ（JS、画像、動画等）を自動キャッシュ | 一般的なWebアプリ（推奨） |
| **Use origin headers** | Cache-Controlヘッダーに基づくキャッシュ | 細かい制御が必要な場合 |
| **Force cache all content** | 全コンテンツを強制キャッシュ | 静的サイト |

### Cache-Control ディレクティブ

| ディレクティブ | 効果 |
|--------------|------|
| `public` | キャッシュ可能 |
| `private` | キャッシュ不可（ユーザー固有データ） |
| `no-store` | キャッシュ禁止 |
| `max-age=N` | N秒間キャッシュ有効 |
| `s-maxage=N` | 共有キャッシュ（CDN）のTTL |
| `no-cache` | 再検証が必要 |

### TTL（Time To Live）設定

| TTLタイプ | 説明 |
|----------|------|
| **Client TTL** | クライアント（ブラウザ）のキャッシュ有効期間 |
| **Default TTL** | オリジンがTTLを指定しない場合のデフォルト |
| **Maximum TTL** | キャッシュの最大有効期間 |

### キャッシュ無効化

コンテンツ更新時にTTL満了前にキャッシュを無効化する。

```bash
# 特定パスのキャッシュ無効化
gcloud compute url-maps invalidate-cdn-cache my-url-map \
  --path="/images/cdn.png"

# 全キャッシュ無効化
gcloud compute url-maps invalidate-cdn-cache my-url-map \
  --path="/*"
```

### Signed URL / Signed Cookies

コンテンツアクセスを制限するために、期限付きの署名付きURLまたはCookieを使用する。

```bash
# 署名鍵の追加
gcloud compute backend-buckets add-signed-url-key my-backend-bucket \
  --key-name=my-key \
  --key-file=my-key-file
```

---

## レイテンシ最適化ベストプラクティス

### 一般原則

| 最適化項目 | 方法 |
|-----------|------|
| **RTT削減** | ユーザーに近いリージョンにバックエンドを配置 + グローバルLB |
| **TTFB削減** | HTTP(S) or SSL/TCP Proxy LB使用（TCPスロースタート・TLSハンドシェイク軽減、HTTP/2自動昇格） |
| **ティア間レイテンシ** | 全アプリケーションティアを同一リージョンに配置 |
| **静的コンテンツ** | Cloud Storage + HTTP(S) LB + Cloud CDN |

### Cloud CDN最適化

- 静的コンテンツの自動キャッシュを有効化
- コンテンツカテゴリごとにTTLを設定（リアルタイム更新 / 頻繁更新 / 稀な更新）
- **カスタムキャッシュキー** でキャッシュヒット率を向上（プロトコル非依存等）

---

## ユーザー確認の原則（AskUserQuestion）

以下の判断が必要な場合はAskUserQuestionツールで確認すること。

### 確認すべき場面

- **LBタイプ選択**: 上記選択テーブルで複数候補が該当する場合
- **Global vs Regional**: バックエンド配置の地理的要件
- **CDNキャッシュモード**: コンテンツの更新頻度・制御要件
- **Global Access**: 内部LBのクロスリージョンアクセス要否

### 確認不要な場面

- ヘルスチェックのファイアウォールルール設定（`130.211.0.0/22`, `35.191.0.0/16` は必須）
- Premium Tierのグローバルロードバランサー利用（グローバルLB使用時は自動）
- キャッシュ無効化の手順（標準操作）
