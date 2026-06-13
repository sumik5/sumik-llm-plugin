# アーキテクチャリファレンス

## Two-Server Skeletonパターン

### なぜ2サーバーが必要か

| 課題 | 解決策 |
|------|------|
| **AEC（音響エコーキャンセレーション）** | ブラウザWebアプリとして実装 → ブラウザの内蔵AECを無償利用 |
| **認証情報の保護** | Pythonプロキシがサーバーサイドで認証 → ブラウザにAPIキー不要 |
| **ツール実行** | プロキシがFunction Callを受信・実行 → ブラウザに処理を持ち込まない |

**CORSの問題**: ブラウザはローカルファイル（`file:///`）からのサーバー通信をセキュリティポリシーでブロックする。フロントエンドサーバーが`http://localhost:8000`で配信することで解決。

### サーバー構成

```
ブラウザクライアント
    │ HTTP GET (静的ファイル)
    ↕ Port 8000
Frontend Server (backend/server.py)
    └─ SimpleHTTPRequestHandler + CORSヘッダー

ブラウザクライアント
    │ WebSocket双方向ストリーム
    ↕ ws://localhost:8081 (開発) / wss://...run.app (本番)
WebSocket Proxy (backend/proxy/proxy.py)
    │ google-genai SDK
    ↕ WebSocket → Gemini Live API
Gemini Live API (Vertex AI / Gemini API)
```

### WebSocket双方向接続の2段構成

**重要**: 接続は2本存在する。

1. **Browser ↔ Proxy**: `ws://localhost:8081`（開発）/ `wss://xxx.run.app`（本番）
2. **Proxy ↔ Gemini Live API**: google-genaiライブラリが管理

ブラウザは直接Gemini Live APIに接続しない。プロキシが信頼された中間者として機能。

---

## プロキシ設計パターン

### 接続ライフサイクル

```python
async def handle_connection(client_ws, path):
    # Phase 1: セットアップメッセージ待機（タイムアウト10秒）
    setup_message = await asyncio.wait_for(client_ws.recv(), timeout=10)
    session_config = json.loads(setup_message)['setup']

    # Phase 2: Gemini Live APIセッション確立
    async with client.aio.live.connect(
        model=session_config['model'],
        config=build_config(session_config)
    ) as gemini_session:
        # Phase 3: 双方向フォワーダーを並列実行
        await asyncio.gather(
            forward_client_to_gemini(client_ws, gemini_session),
            forward_gemini_to_client(client_ws, gemini_session),
        )
```

`asyncio.gather()` の並列実行が"電話回線"の核心。両方向が独立して非同期処理できる。

### フォワーダーパターン

**client → Gemini方向**:
```python
async def forward_client_to_gemini(client_ws, gemini_session):
    async for message in client_ws:  # ブラウザメッセージを無限受信
        data = json.loads(message)
        if 'realtimeInput' in data:
            # 音声チャンクを転送
            audio_blob = types.Blob(data=decoded_bytes, mime_type='audio/pcm;rate=16000')
            await gemini_session.send_realtime_input(audio=audio_blob)
        elif 'image' in data:
            # 画像フレームを転送
            image_blob = types.Blob(data=decoded_bytes, mime_type='image/jpeg')
            await gemini_session.send_realtime_input(video=image_blob)
```

**Gemini → client方向**:
```python
async def forward_gemini_to_client(client_ws, gemini_session):
    while True:  # 複数会話ターンを継続
        async for response in gemini_session.receive():  # 1ターン内のレスポンス
            if response.tool_call:
                # Function Callingの処理
                result = execute_tool(response.tool_call)
                await gemini_session.send_tool_response(result)
            else:
                # 音声・テキストレスポンスをブラウザに転送
                await client_ws.send(json.dumps(response.model_dump(), cls=BytesJSONEncoder))
```

**外側の `while True` ループが重要**: 内側の `async for` が1ターン分のレスポンスを処理し、外側ループで次のターンを待つ。これがないと1回の応答で終了する。

### BytesJSONEncoderの必要性

Geminiレスポンスにはバイナリ（音声データ）が含まれ、そのままJSONシリアライズできない。

```python
class BytesJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, bytes):
            return base64.b64encode(obj).decode('utf-8')
        return super().default(obj)
```

### フロントエンドサーバーのCORS設定

```python
class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        return super().end_headers()
```

---

## 認証パス

### Path 1: Vertex AI（ADC）— 本番推奨

```env
GOOGLE_GENAI_USE_VERTEXAI=1
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1
```

```bash
gcloud auth application-default login
```

ADCは認証情報をコードに埋め込まずに済む企業標準パターン。

### Path 2: Gemini API Key — 開発・検証向け

```env
GOOGLE_GENAI_USE_VERTEXAI=0
GOOGLE_API_KEY=your-api-key
```

---

## ファイル構成リファレンス

| ファイル | 役割 | 重要度 |
|---------|------|-------|
| `backend/proxy/proxy.py` | セキュアゲートウェイ・認証・双方向転送 | 🔴最重要 |
| `frontend/app.js` | UIオーケストレーター・WebSocket管理 | 🔴最重要 |
| `frontend/audio-processor.js` | AudioWorklet（別スレッド音声変換） | 🟡重要 |
| `frontend/audio-streamer.js` | シームレス再生エンジン | 🟡重要 |
| `frontend/media-handler.js` | カメラ/スクリーン管理 | 🟢オプション |
| `backend/server.py` | フロントエンド配信（開発のみ） | 🟢開発のみ |
| `backend/tool_handler.py` | ツール実装集 | 🟢ツール使用時 |
| `backend/system-instructions.txt` | AIペルソナ・ルール定義 | 🟢推奨 |
