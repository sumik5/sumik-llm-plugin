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

---

## ゲームインフラ向けGLB特性

ゲームインフラはトランザクション量が多く、アクセスのスパイクが激しいため、ロードバランシングの選択がサービス品質に直結する。GCPのGlobal Load Balancingはゲームインフラの課題を解決する複数の特性を持つ。

### IP Anycast（BGPベースのグローバルルーティング）

GCPのExternal HTTP(S) LBは**IP Anycast**方式を採用しており、単一のグローバルIPアドレスで世界中のリージョンへのルーティングを実現する。

```
ユーザー（北米）    → 同一グローバルIP → 北米のGCPデータセンター
ユーザー（欧州）    → 同一グローバルIP → 欧州のGCPデータセンター
ユーザー（アジア）  → 同一グローバルIP → アジアのGCPデータセンター
```

**仕組み**: BGP（Border Gateway Protocol）経路情報をリージョンによって異なる設定にすることで、アクセス元に近いデータセンターへ自動的にルーティングされる（Google Public DNS「8.8.8.8」と同様の仕組み）。

| 比較項目 | DNS ラウンドロビン | GCP IP Anycast |
|---------|-----------------|----------------|
| **仕組み** | DNSレベルで複数IPを返す | 単一IP、BGPで最近傍DCへルーティング |
| **フェイルオーバー速度** | DNS TTL依存（数分〜数十分） | ほぼ即時（BGPレベル） |
| **クライアント対応** | 複数IPのキャッシュ問題 | 透過的（クライアント変更不要） |
| **リージョン間フェイルオーバー** | 手動DNS変更が必要な場合あり | 自動 |

### ゲームインフラへの適用メリット

**スパイク耐性**:
- ウォーミングアップ不要で秒間100万リクエストに即座に対応（Google社内サービスと同一インフラ）
- ゲームリリース直後やイベント時のアクセス急増にも事前準備不要
- 通常のクラウドLBでは事前にインスタンスを起動・ウォーミングアップが必要だが、GCP GLBは不要

**低レイテンシ**:
- ユーザーのアクセス元から最も近いGCPエッジで接続を受け付け、TLSハンドシェイクもエッジで完結
- バックエンドまでの実効RTT（Round Trip Time）を大幅に削減
- リアルタイム性が重要なゲームでのプレイ体感向上に直結

**グローバルゲームタイトルでの活用**:

| ゲームタイプ | 推奨LB構成 | 理由 |
|------------|-----------|------|
| **グローバル展開モバイルゲーム** | External HTTP(S) LB（Anycast） | 単一エンドポイントで全リージョン対応、VPN不要 |
| **リアルタイム対戦ゲーム（TCP/UDP）** | Network LB（リージョン別） | UDP対応、独自プロトコル対応、低レイテンシ優先 |
| **ランディングページ・静的配信** | HTTP(S) LB + Cloud CDN | スパイク対応 + キャッシュでコスト最適化 |
| **アーケードゲーム（地域固定）** | リージョナル Network LB | 特定地域への固定配置、UDP利用可能 |

### HTTP(S) LB vs Network LB のゲームでの使い分け

```
ゲームサーバへのルーティング判断

HTTP(S) or HTTPS?
  YES → External HTTP(S) LB（グローバル対応、URLルーティング可能）
  NO  ↓
UDP利用 or 独自プロトコル?
  YES → Network LB（リージョン固定、80/443/8080以外のポート利用可能）
  NO  ↓
TCP（非HTTP）?
  YES → TCP Proxy LB（グローバル対応）
```

**注意**: HTTP(S) LBで開放可能な外部ポートは **80, 443, 8080** のみ。ゲームで独自ポートを使う場合はNetwork LBが必要だが、Network LBはリージョン固定になる。

### ゲームインフラ固有の設定推奨事項

| 設定項目 | 推奨値・方針 | 理由 |
|---------|------------|------|
| **インスタンスグループのサイズ** | 余裕を持った台数で構成 | HTTP(S) LBはHTTPヘルスチェック以外の要因でもインスタンス割り振りを決定するため |
| **バランシングモード** | Rate（リクエストレートベース） | ゲームAPIは各リクエストの処理時間が均一なため |
| **ヘルスチェック間隔** | 短め（10秒以下）+ 閾値3以上 | スパイク時の誤判定防止と迅速な異常検出のバランス |
| **CDN併用** | 静的アセット（画像・音声）はCDN有効化 | 動的APIはCDN不可、静的ファイル配信はCDNでスループット大幅向上 |
