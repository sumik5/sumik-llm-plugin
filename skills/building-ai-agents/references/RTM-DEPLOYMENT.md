# デプロイメント・モバイルUI リファレンス

## Cloud Run 選択理由

### なぜCloud RunがリアルタイムAgentに最適か

| 要件 | Cloud Runの対応 |
|------|----------------|
| **WebSocket長時間接続** | デフォルト60分、設定で延長可能 |
| **HTTPS/WSS自動化** | デプロイ即時にhttps://・wss://が利用可能 |
| **アイドル時コスト** | Scale-to-Zeroで非使用時は¥0 |
| **トラフィック急増** | 自動スケールアウト |
| **コンテナ化** | Dockerfileで環境差異を排除 |

### Scale-to-Zeroの重要性

個人プロジェクト・少量トラフィックのAgentでは、使用していない時間のサーバーコストは無駄。Cloud Runは接続がなければ0インスタンス（コスト¥0）、接続が来ると即時起動（コールドスタート〜数秒）。

---

## Dockerコンテナ化パターン

### バックエンドDockerfile

```dockerfile
# backend/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# 依存関係インストール（レイヤーキャッシュ活用）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコード
COPY . .

# Cloud Runはポート8080を使用
ENV PORT=8080
EXPOSE 8080

CMD ["python", "proxy.py"]
```

```python
# proxy.py: ポートを環境変数から取得
import os
PORT = int(os.environ.get("PORT", 8081))

async def main():
    async with websockets.serve(handle_connection, "0.0.0.0", PORT):
        print(f"WebSocket proxy started on port {PORT}")
        await asyncio.Future()
```

**重要**: `localhost` ではなく `0.0.0.0` でバインドする必要がある。Dockerコンテナ内からの外部アクセスに対応。

### フロントエンドDockerfile

```dockerfile
# frontend/Dockerfile
FROM nginx:alpine

# 静的ファイルをnginxで配信
COPY . /usr/share/nginx/html

# バックエンドURLを環境変数から注入（ビルド時）
ARG BACKEND_URL
RUN sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /usr/share/nginx/html/app.js

EXPOSE 8080
```

---

## Cloud Build 自動化

### cloudbuild.yaml のパターン

```yaml
# backend/cloudbuild.yaml
steps:
  # 1. Dockerイメージのビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/gemini-agent-backend', './backend']

  # 2. Container Registryへプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/gemini-agent-backend']

  # 3. Cloud Runへデプロイ
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'gemini-agent-backend'
      - '--image=gcr.io/$PROJECT_ID/gemini-agent-backend'
      - '--region=us-central1'
      - '--platform=managed'
      - '--allow-unauthenticated'
      - '--set-env-vars=GOOGLE_CLOUD_PROJECT=$PROJECT_ID'

images:
  - 'gcr.io/$PROJECT_ID/gemini-agent-backend'
```

### デプロイコマンド

```bash
# バックエンドデプロイ
gcloud builds submit --config backend/cloudbuild.yaml

# → デプロイ完了後にService URLが表示される
# 例: https://gemini-agent-backend-abcdef-uc.a.run.app
```

---

## https → wss 変換

### なぜ変換が必要か

Cloud Runは HTTPS(`https://...`) でURLを提供。WebSocket接続には WSS(`wss://...`) プロトコルが必要。これは HTTPS の WebSocket バージョン（暗号化WebSocket）。

```bash
# フロントエンドデプロイ: https → wss に変換して渡す
gcloud builds submit --config frontend/cloudbuild.yaml \
  --substitutions=_BACKEND_URL='wss://gemini-agent-backend-abcdef-uc.a.run.app'
```

### app.jsでの動的URL設定

```javascript
// 本番環境では環境変数またはビルド時置換で設定
const PROXY_URL = process.env.BACKEND_URL || 'ws://localhost:8081';
const ws = new WebSocket(PROXY_URL);
```

---

## Cloud Runの重要設定

### WebSocket接続タイムアウト

デフォルト60分。長い会話セッション向けに延長が必要な場合:

```bash
gcloud run services update gemini-agent-backend \
  --timeout=3600  # 1時間
```

### 認証設定

```bash
# 個人・デモ用: 認証なし
--allow-unauthenticated

# 本番: サービスアカウント認証
--no-allow-unauthenticated
--service-account=my-service-account@project.iam.gserviceaccount.com
```

### 環境変数の設定（機密情報）

```bash
# APIキーはSecret Managerで管理
gcloud run services update gemini-agent-backend \
  --set-secrets=OPENWEATHER_API_KEY=openweather-key:latest
```

---

## モバイルファーストUI設計

### 4つの設計原則

**1. Streamlined Start（簡素な開始）**

開始ボタン1つで全機能をアクティベート。接続・マイク許可・セッション確立を1アクションで実行。

```html
<!-- Before: 複数ボタン -->
<button>Connect</button>
<button>Start Mic</button>
<button>Start Session</button>

<!-- After: 1ボタン -->
<button id="connectButton">▶</button>  <!-- PlayアイコンのみでOK -->
```

**2. Touch-Friendly Controls（タッチ対応コントロール）**

- ボタン最小サイズ: 44px × 44px（Apple HIG推奨）
- 円形デザインで視覚的に分かりやすく
- ボタン間の間隔を十分に確保（誤タップ防止）

```css
.control-button {
    width: 64px;
    height: 64px;
    border-radius: 50%;  /* 円形 */
    margin: 0 12px;      /* 間隔 */
}
```

**3. Contextual UI（コンテキスト適応UI）**

状態に応じて表示コントロールを変化。

```javascript
// 非接続時: Playボタンのみ
playButtonContainer.classList.remove('hidden');
mediaButtonsContainer.classList.add('hidden');

// 接続後: メディアコントロール群に切替
playButtonContainer.classList.add('hidden');
mediaButtonsContainer.classList.remove('hidden');

// カメラアクティブ時のみ: Switch Cameraボタン表示（モバイルのみ）
if (isMobile && isWebcamActive) {
    switchCameraButton.classList.remove('hidden');
}
```

**4. Responsive Layout（レスポンシブ）**

```css
/* ビデオプレビューをフルスクリーン背景に */
#videoPreview {
    position: fixed;
    top: 0; left: 0;
    width: 100%; height: 100%;
    object-fit: cover;
    z-index: -1;
}

/* コントロールを画面下部に固定 */
#mediaButtonsContainer {
    position: fixed;
    bottom: 32px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    gap: 16px;
}
```

---

## mobile.html vs index.html

| ファイル | 用途 | 特徴 |
|---------|------|------|
| `index.html` | 開発・デバッグ | テキストログ・多ボタン・開発者向け |
| `mobile.html` | 本番・ユーザー向け | クリーン・タッチフレンドリー・消費者向け |

デプロイ後は `mobile.html` をデフォルトページとして配信する。

---

## デプロイ前チェックリスト

- [ ] `0.0.0.0` でWebSocketサーバーをバインドしている
- [ ] `PORT` 環境変数から動的にポートを取得している
- [ ] Dockerfileで全依存関係を明記している
- [ ] Cloud Run設定でWebSocketタイムアウトを適切に設定
- [ ] APIキー等の機密情報をSecret Managerで管理している
- [ ] フロントエンドURLが `wss://`（`ws://` ではなく）に設定されている
- [ ] CORS設定が本番ドメインに対応している
