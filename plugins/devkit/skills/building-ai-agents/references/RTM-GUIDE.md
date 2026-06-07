# リアルタイムマルチモーダルAgent 実装ガイド

## 1. 概要

### 第1世代との根本的な違い

旧世代（Siri/Alexa）は **Intent/Slot** モデルに基づいており、定義済みコマンドの「フォーム入力」でしかなかった。コンテキストを要求した瞬間に破綻する。

現代のリアルタイムAgentは2つの柱で成立する:

| 技術 | 役割 |
|------|------|
| **Transformer / LLM** | 会話コンテキストの理解・推論 |
| **WebSocket** | 双方向・持続的ストリーミング接続（"電話回線"） |

REST APIは「手紙のやり取り」→ WebSocketは「電話」。双方向リアルタイムストリーミングなしに自然な会話は実現できない。

### リアルタイムAgentの必須コンポーネント

1. 強力なLLM（コンテキスト理解）
2. 持続的WebSocket接続
3. VAD（Voice Activity Detection）— ターン検出
4. セッション管理（会話履歴）
5. マルチモーダル入力（音声/映像/テキスト）

---

## 2. アーキテクチャ原則

### Two-Server Model

**なぜ2サーバーか？** ブラウザのAEC（Acoustic Echo Cancellation）を無償で活用するため。

```
ブラウザ (port 8000)
    ↕  WebSocket (ws://localhost:8081)
Python Proxy (port 8081)
    ↕  WebSocket → Gemini Live API
Gemini Live API
```

**ブラウザAECの価値**: マイクがAIの音声を拾う「音響エコー問題」を、Google/Mozilla/Appleが完璧に実装済みのAEC機能が自動解決。ヘッドフォン不要で自然な会話体験。

### プロジェクト構造

```
gemini-live-agent/
├── frontend/
│   ├── index.html         # 開発UI
│   ├── mobile.html        # モバイルファーストUI（本番）
│   ├── app.js             # メインアプリロジック
│   ├── audio-processor.js # AudioWorklet（別スレッド処理）
│   ├── audio-streamer.js  # AIレスポンス再生エンジン
│   └── media-handler.js   # カメラ/スクリーン管理
└── backend/
    ├── server.py          # フロントエンド配信サーバー
    ├── system-instructions.txt  # AIペルソナ定義
    ├── tool_handler.py    # ツール実装
    └── proxy/
        ├── proxy.py       # セキュアWebSocketプロキシ
        ├── requirements.txt
        └── .env           # 認証設定
```

詳細: [ARCHITECTURE.md](./references/ARCHITECTURE.md)

---

## 3. Gemini Live APIコア機能

### セッション確立フロー

```python
async with client.aio.live.connect(
    model="gemini-2.0-flash-live-preview-04-09",
    config={
        "response_modalities": ["audio"],
        "system_instruction": system_instruction_text,
        "speech_config": { "voice_config": { "prebuilt_voice_config": { "voice_name": "Puck" } } },
        "tools": [{ "function_declarations": [...] }]
    }
) as gemini_session:
    await asyncio.gather(
        forward_client_to_gemini(client_ws, gemini_session),
        forward_gemini_to_client(client_ws, gemini_session),
    )
```

`asyncio.gather()` が双方向の「電話回線」を実現する核心。

### マルチモーダル知覚

単一セッションで同時入力可能:
- **Audio**: 16kHz PCM → `types.Blob(data=bytes, mime_type="audio/pcm;rate=16000")`
- **Video**: JPEG Base64 → `types.Blob(data=bytes, mime_type="image/jpeg")`
- **Text**: テキストコマンド（フォールバック）

### VAD・割り込み・ターン管理

| 機能 | 説明 |
|------|------|
| **API-Side VAD** | 音声ストリームを常時解析、自然な間を検出してターン終了 |
| **Fluid Interruption** | ユーザーが発話した瞬間 `{ "interrupted": true }` 送信 |
| **Turn Complete** | `server_content.turn_complete` でターン完了通知 |

詳細: [GEMINI-LIVE-API.md](./references/GEMINI-LIVE-API.md)

---

## 4. Web Audio APIパターン

### AudioWorkletによる高パフォーマンス処理

音声処理をメインスレッドで行うとUIが固まる。`AudioWorklet` は専用の高優先度オーディオスレッドで動作。

**audio-processor.js（AudioWorklet）の責務**:
1. Float32（-1.0〜1.0）→ Int16（-32768〜32767）変換
2. 2048サンプルバッファに蓄積、満杯でメインスレッドへ送信

**AudioRecorder（メインスレッド）の責務**:
- `navigator.mediaDevices.getUserMedia()` でマイクアクセス
- `AudioContext({ sampleRate: 16000 })` — Gemini APIは16kHz期待
- `AudioWorkletNode` でワークレットと接続
- `mute()`/`unmute()` — セッション維持しつつマイク制御

### AudioStreamer — シームレス再生エンジン

**なぜキューが必要か**: 個々のチャンクを即再生するとクリック/ポップ音が発生。

```
AIレスポンス受信 → Base64 → Int16配列 → Float32配列 → AudioBuffer → キュー → シーケンシャル再生
```

- `AudioContext({ sampleRate: 24000 })` — AIレスポンスは24kHz
- `onended` チェーンで途切れのない連続再生
- **`stop()` メソッド**: キューをクリア + 現在のSourceNode停止 → 即座の割り込み対応

詳細: [WEB-AUDIO-API.md](./references/WEB-AUDIO-API.md)

---

## 5. "Hot Mic" インタラクションモデル

### プッシュトークではなく常時傾聴

```
1回目クリック: セッション開始 + マイクON（"Hot Mic"状態）
2回目クリック: マイクミュート（セッション維持）
3回目クリック: マイクアンミュート
```

### 割り込み処理フロー

```javascript
ws.onmessage = async (event) => {
    const response = JSON.parse(event.data);

    // 割り込み検出 → 即座に再生停止
    if (response.server_content?.interrupted) {
        streamer.stop();
        return;
    }

    // 音声データ → キューに追加して再生
    const audioData = response.server_content?.model_turn?.parts?.[0]?.inline_data?.data;
    if (audioData) {
        await streamer.receiveAudioChunk(audioData);
    }

    // ターン完了
    if (response.server_content?.turn_complete) {
        // ステータスUI更新
    }
};
```

---

## 6. ビデオ統合

### "Show, Don't Tell" パターン

ユーザーが口で説明する代わりにカメラで見せる。モバイルでは特に強力（ラップトップのカメラ=自分を映す、スマホのカメラ=世界を映す）。

### 効率的フレームキャプチャ戦略

**なぜ1FPSか**: 30FPSの動画を丸ごと送信は帯域・コスト・処理の無駄。モデルは「静止スナップショット」で十分に視覚推論できる。

```javascript
// MediaHandler.startFrameCapture()
setInterval(() => {
    canvas.drawImage(videoElement, ...);
    const base64Jpeg = canvas.toDataURL('image/jpeg');
    ws.send(JSON.stringify({ type: "image", data: base64Jpeg }));
}, 1000);  // 1秒ごと
```

### プロキシでの画像転送

```python
elif 'image' in data:
    image_bytes = base64.b64decode(data['image']['data'])
    await gemini_session.send_realtime_input(
        video=types.Blob(data=image_bytes, mime_type='image/jpeg')
    )
```

詳細: [VIDEO-INTEGRATION.md](./references/VIDEO-INTEGRATION.md)

---

## 7. リアルタイムFunction Calling

### ツール定義 → 実行 → レスポンスのループ

```
モデルがツール必要と判断
    ↓
tool_call エミット（function名 + 引数）
    ↓
プロキシがtool_call検出 → ローカル関数実行
    ↓
LiveClientToolResponse でgemini_sessionに結果返送
    ↓
モデルがリアルタイムデータを組み込んで音声応答生成
```

### function_declaration の定義

```python
{
    "tools": [{
        "function_declarations": [{
            "name": "get_weather",
            "description": "Get current weather information for a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": { "type": "string", "description": "City name" }
                },
                "required": ["city"]
            }
        }]
    }]
}
```

### System InstructionsとツールのL整合

`system-instructions.txt` でツール使用ルールを明記:
```
When asked about the weather, you must use the get_weather tool.
```

詳細: [FUNCTION-CALLING.md](./references/FUNCTION-CALLING.md)

---

## 8. デプロイメント

### Cloud Run選択理由

- **Scale-to-Zero**: アイドル時コスト¥0
- **自動HTTPS**: wss://プロトコル自動提供
- **WebSocket対応**: 長時間接続サポート
- **自動スケール**: トラフィック急増に対応

### デプロイフロー

```bash
# 1. バックエンドデプロイ
gcloud builds submit --config backend/cloudbuild.yaml
# → https://backend-xxx.a.run.app

# 2. フロントエンドデプロイ（wss://に変換して渡す）
gcloud builds submit --config frontend/cloudbuild.yaml \
  --substitutions=_BACKEND_URL='wss://backend-xxx.a.run.app'
```

### wss://への変換の重要性

Cloud RunがHTTPSを提供するため、WebSocket接続も `wss://`（暗号化）が必須。`ws://` では動作しない。

詳細: [DEPLOYMENT.md](./references/DEPLOYMENT.md)

---

## 9. モバイルファーストUI設計原則

| 原則 | 実装 |
|------|------|
| **Streamlined Start** | 単一の「Play」ボタンでセッション開始 |
| **Touch-Friendly** | 大型・円形・十分な間隔のコントロール |
| **Contextual UI** | アクティブな機能に応じてボタン表示/非表示 |
| **Responsive Layout** | CSSフレックスボックス、縦画面/横画面対応 |
| **Switch Camera** | モバイルでのみ表示（前面/背面カメラ切替） |

---

## クイックスタートチェックリスト

- [ ] `.env` 設定（Vertex AI ADC または Gemini API Key）
- [ ] `pip install -r requirements.txt`
- [ ] `python backend/server.py` → http://localhost:8000
- [ ] `python backend/proxy/proxy.py` → ws://localhost:8081
- [ ] マイクアクセス許可を確認
- [ ] ブラウザ開発者ツールでWebSocketメッセージを確認
