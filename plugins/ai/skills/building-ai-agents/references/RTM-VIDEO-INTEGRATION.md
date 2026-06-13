# ビデオ統合リファレンス

## "Show, Don't Tell" パターン

### なぜビデオが強力か

口で説明するより見せる方が速くて正確。

| ユースケース | 音声のみ | ビデオあり |
|------------|---------|----------|
| 機械部品の確認 | 詳細な言語描写が必要 | カメラを向けて「これは何？」 |
| 数式の間違い確認 | 数式をすべて口述 | ノートを見せて「どこが間違い？」 |
| エラーメッセージ | 画面を読み上げ | スクリーン共有で「これは？」 |

### モバイルでの優位性

- ノートPCカメラ → 自分を映す
- スマートフォンカメラ → **世界を映す**

フィールドエンジニア・教育・観光など実世界との対話に最適。

---

## MediaHandler クラス

### 責務

- Webcam/ScreenShare の起動・停止
- 複数ストリームの管理
- 周期的フレームキャプチャ
- カメラ切替（モバイル向け）

### 実装パターン

```javascript
class MediaHandler {
    constructor() {
        this.currentStream = null;
        this.videoElement = null;
        this.captureInterval = null;
        this.onFrame = null;  // フレームコールバック
    }

    initialize(videoElement) {
        this.videoElement = videoElement;
    }

    async startWebcam(facingMode = 'user') {
        this.currentStream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode }  // 'user'=前面, 'environment'=背面
        });
        this.videoElement.srcObject = this.currentStream;
        this.videoElement.classList.remove('hidden');
    }

    async startScreenShare() {
        this.currentStream = await navigator.mediaDevices.getDisplayMedia({
            video: true
        });
        this.videoElement.srcObject = this.currentStream;
        this.videoElement.classList.remove('hidden');
    }

    stopAll() {
        if (this.currentStream) {
            this.currentStream.getTracks().forEach(track => track.stop());
            this.currentStream = null;
        }
        this.stopFrameCapture();
        this.videoElement.classList.add('hidden');
    }

    // モバイル向けカメラ切替
    async switchCamera() {
        const currentFacing = this.currentFacingMode || 'user';
        const newFacing = currentFacing === 'user' ? 'environment' : 'user';
        this.stopAll();
        await this.startWebcam(newFacing);
        this.currentFacingMode = newFacing;
        this.startFrameCapture(this.onFrame);
    }
}
```

---

## 周期的フレームキャプチャ戦略

### なぜ1FPSか

| アプローチ | 帯域 | コスト | モデル処理 |
|----------|------|------|----------|
| 30FPS動画ストリーム | 非常に高い | 非常に高い | 過剰 |
| **1FPS静止画（採用）** | **低い** | **低い** | **十分** |

モデルは「動きの流れ」ではなく「現在の環境の状態」を理解すればよい。1秒ごとのスナップショットで十分な視覚推論が可能。

### Canvas経由のフレームキャプチャ

```javascript
startFrameCapture(onFrameCallback) {
    this.onFrame = onFrameCallback;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    this.captureInterval = setInterval(() => {
        if (!this.videoElement || !this.currentStream) return;

        // 1. CanvasにビデオのCurrentフレームを描画
        canvas.width = this.videoElement.videoWidth;
        canvas.height = this.videoElement.videoHeight;
        ctx.drawImage(this.videoElement, 0, 0);

        // 2. JPEG Base64として出力（効率的なエンコード）
        const base64Jpeg = canvas.toDataURL('image/jpeg', 0.8);  // 品質0.8
        const base64Data = base64Jpeg.split(',')[1];  // "data:image/jpeg;base64," を除去

        // 3. コールバックでWebSocket送信
        onFrameCallback(base64Data);
    }, 1000);  // 1秒ごと = 1FPS
}

stopFrameCapture() {
    if (this.captureInterval) {
        clearInterval(this.captureInterval);
        this.captureInterval = null;
    }
}
```

**ユーザーには30FPSのスムーズなプレビューが表示される**。AIには1FPSの静止画が送られる。両立を実現する設計。

---

## フロントエンドからプロキシへの画像メッセージ

### メッセージフォーマット

```javascript
// app.jsでのフレーム送信
const mediaHandler = new MediaHandler();
mediaHandler.initialize(document.getElementById('videoPreview'));

mediaHandler.startFrameCapture((base64Data) => {
    if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
            type: "image",
            data: base64Data
        }));
    }
});
```

---

## プロキシでの画像転送

### forward_client_to_gemini の更新

```python
async def forward_client_to_gemini(client_ws, gemini_session):
    async for message in client_ws:
        data = json.loads(message)

        if 'realtimeInput' in data:
            # 既存: 音声転送
            audio_bytes = base64.b64decode(
                data['realtimeInput']['mediaChunks'][0]['data']
            )
            audio_blob = types.Blob(data=audio_bytes, mime_type='audio/pcm;rate=16000')
            await gemini_session.send_realtime_input(audio=audio_blob)

        elif 'image' in data:  # 追加: 画像転送
            image_bytes = base64.b64decode(data['image']['data'])
            image_blob = types.Blob(data=image_bytes, mime_type='image/jpeg')
            await gemini_session.send_realtime_input(video=image_blob)
```

プロキシは透過的なゲートウェイとして機能。音声と画像の両方を正しいMIMEタイプでGeminiへ転送するだけ。

---

## UI制御パターン

### Webcam / ScreenShare のトグル

```javascript
let isWebcamActive = false;

webcamButton.addEventListener('click', async () => {
    if (!isWebcamActive) {
        await mediaHandler.startWebcam();
        mediaHandler.startFrameCapture((base64Data) => {
            ws.send(JSON.stringify({ type: "image", data: base64Data }));
        });
        webcamButton.textContent = 'Stop Webcam';
        isWebcamActive = true;
    } else {
        mediaHandler.stopAll();
        webcamButton.textContent = 'Webcam';
        isWebcamActive = false;
    }
});
```

### モバイルUI: Switch Camera

モバイルデバイス検出後、カメラアクティブ時のみ「Switch Camera」ボタンを表示。

```javascript
const isMobile = /Android|iPhone|iPad/i.test(navigator.userAgent);

if (isMobile && isWebcamActive) {
    switchCameraButton.classList.remove('hidden');
}

switchCameraButton.addEventListener('click', () => {
    mediaHandler.switchCamera();
});
```

---

## マルチモーダル入力の同時処理

Gemini Live APIは単一セッションで音声と映像を**同時に**処理できる。

```
ユーザー: 「この部品は何ですか？」 [音声]
カメラ: [1FPSで部品の画像を送信中]
        ↓
Gemini: 音声 + 最新の画像フレームを組み合わせて推論
        ↓
応答: 「画面に映っているのはウォーターポンプのインペラーです。」
```

開発者は特別な同期処理を書く必要はない。APIが自動的にコンテキストを統合する。
