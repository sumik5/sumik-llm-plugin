# Gemini Live API リファレンス

## 概要

Gemini Live APIは従来のREST APIとは根本的に異なる。単なるエンドポイントではなく、リアルタイムアプリケーション構築のための完全なツールキット。

| コンポーネント | 役割 |
|--------------|------|
| **Persistent Streaming Connection** | "脳" — WebSocket上の永続セッション、会話コンテキスト維持 |
| **Multimodal Perception** | "感覚" — 音声・映像・テキストの同時入力処理 |
| **Conversational Dynamics** | "反射" — VAD・割り込み・ターン管理 |

---

## 接続とセッション確立

### google-genai クライアント初期化

```python
from google import genai
from dotenv import load_dotenv

load_dotenv()

# Vertex AI（本番推奨）
client = genai.Client(
    vertexai=True,
    project=os.environ["GOOGLE_CLOUD_PROJECT"],
    location=os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")
)

# または Gemini API Key（開発向け）
client = genai.Client(api_key=os.environ["GOOGLE_API_KEY"])
```

### Live API セッション設定

```python
async with client.aio.live.connect(
    model="gemini-2.0-flash-live-preview-04-09",
    config={
        # 必須: レスポンス形式
        "response_modalities": ["audio"],  # "audio" | "text" | ["audio", "text"]

        # オプション: AIペルソナ
        "system_instruction": "You are a helpful assistant...",

        # オプション: 音声設定
        "speech_config": {
            "voice_config": {
                "prebuilt_voice_config": {
                    "voice_name": "Puck"  # Puck, Charon, Kore, Fenrir, Aoede 等
                }
            }
        },

        # オプション: ツール定義
        "tools": [{ "function_declarations": [...] }],

        # オプション: VAD制御
        "realtime_input_config": {
            "automatic_activity_detection": {
                "disabled": False  # TrueでVAD無効化（カスタムPTT実装向け）
            }
        }
    }
) as gemini_session:
    # セッション内でのストリーミング処理
    ...
```

---

## VAD（Voice Activity Detection）

### API-Side VAD の動作

Gemini Live APIはデフォルトでサーバーサイドVADを実装。

1. クライアントが音声チャンクを継続的に送信
2. APIが音声ストリームをリアルタイム解析
3. 自然な発話の間（ポーズ）を検出してターン終了と判断
4. ターン終了後、AIが応答生成を開始

**ユーザーはボタンを押す必要がない** — "Hot Mic"体験の基盤。

### カスタムVAD（Push-to-Talk向け）

VADを無効化して独自のターン制御を実装する場合:

```python
config = {
    "realtime_input_config": {
        "automatic_activity_detection": { "disabled": True }
    }
}
```

ただしほとんどのユースケースでAPIのVADで十分。

---

## 割り込み処理

### フロー

```
AI音声レスポンス生成中
    ↓ ユーザーが発話開始
API側VADがユーザー音声を検出
    ↓
{"server_content": {"interrupted": true}} をプロキシへ送信
    ↓
プロキシがブラウザへ転送
    ↓
ブラウザが AudioStreamer.stop() を呼び出し
    ↓
スピーカー停止 + キュークリア
    ↓ ユーザーの発話を受信処理
```

### クライアント側の割り込みハンドリング

```javascript
ws.onmessage = async (event) => {
    const response = JSON.parse(event.data);

    // 割り込みシグナル検出（optional chainingで安全にアクセス）
    if (response.server_content?.interrupted) {
        console.log('AI interrupted. Stopping playback.');
        streamer.stop();
        return;  // 他の処理をスキップ
    }

    // 音声データ処理
    const audioData = response.server_content?.model_turn?.parts?.[0]?.inline_data?.data;
    if (audioData) {
        await streamer.receiveAudioChunk(audioData);
    }

    // ターン完了
    if (response.server_content?.turn_complete) {
        console.log('Turn complete.');
    }
};
```

---

## メッセージフォーマット

### クライアント → API（音声）

```javascript
// ブラウザからプロキシへ
{
    realtimeInput: {
        mediaChunks: [{
            mime_type: "audio/pcm",
            data: "<base64_encoded_pcm_16kHz>"
        }]
    }
}
```

プロキシがデコードし `types.Blob` でgemini_sessionへ転送:

```python
audio_blob = types.Blob(
    data=base64.b64decode(chunk_data),
    mime_type='audio/pcm;rate=16000'
)
await gemini_session.send_realtime_input(audio=audio_blob)
```

### クライアント → API（画像）

```javascript
// ブラウザからプロキシへ
{ type: "image", data: "<base64_encoded_jpeg>" }
```

```python
image_blob = types.Blob(
    data=base64.b64decode(image_data),
    mime_type='image/jpeg'
)
await gemini_session.send_realtime_input(video=image_blob)
```

### API → クライアント（レスポンス構造）

```json
{
    "server_content": {
        "model_turn": {
            "parts": [{
                "inline_data": {
                    "data": "<base64_encoded_audio_24kHz>",
                    "mime_type": "audio/pcm;rate=24000"
                }
            }]
        },
        "turn_complete": true,
        "interrupted": true
    }
}
```

---

## セッション管理

### 初期セットアップシーケンス

```
ブラウザ接続確立
    ↓ 最初のメッセージ（必須）
{ setup: { model: "...", generation_config: {...} } }
    ↓ プロキシがValidate
Gemini Live APIへ接続（setup情報でconfigure）
    ↓
双方向ストリーミング開始
```

**初期セットアップメッセージは最初に送信必須**。プロキシは`asyncio.wait_for(..., timeout=10)`で10秒以内のセットアップを要求。

### セッション持続性

- Live APIセッションは会話コンテキストを維持（"メモリトリック"）
- WebSocket接続が切れるとセッションも終了
- マイクミュートはセッションを終了しない（接続は維持）

### コンテキストウィンドウ

長い会話でコンテキストウィンドウが溢れる場合、APIが自動的に古いコンテキストを圧縮・要約する。明示的な管理は不要。

---

## System Instructions と Voice Config

### System Instructions

```python
# proxy.pyでファイルから読み込み
with open('system-instructions.txt', 'r') as f:
    system_instruction = f.read()

config = {
    "system_instruction": system_instruction,
    ...
}
```

**使用例** (system-instructions.txt):
```
You are a helpful and friendly assistant.
When asked about the weather, you must use the get_weather tool.
Always provide concise, spoken-friendly responses.
```

### 利用可能なVoice

| Voice名 | 特徴 |
|---------|------|
| Puck | カジュアル・フレンドリー |
| Charon | プロフェッショナル |
| Kore | 落ち着いた |
| Fenrir | 力強い |
| Aoede | 優しい |

---

## Python依存関係

```text
# requirements.txt
websockets
google-genai
python-dotenv
```

```bash
pip install -r requirements.txt
```
