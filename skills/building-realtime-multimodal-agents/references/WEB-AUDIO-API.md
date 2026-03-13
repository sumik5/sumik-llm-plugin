# Web Audio API リファレンス

## AudioWorklet — 高パフォーマンス音声処理

### なぜAudioWorkletが必要か

音声処理（フォーマット変換・バッファリング）はCPU負荷が高い。メインスレッドで実行するとUIが固まり音声が途切れる。

`AudioWorklet` は専用の高優先度オーディオスレッドで動作し、メインスレッドのUIをブロックしない。

### audio-processor.js の実装パターン

```javascript
// ブラウザの別スレッドで動作するAudioWorkletProcessor
class AudioProcessor extends AudioWorkletProcessor {
    buffer = new Int16Array(2048);  // 送信バッファ
    bufferIndex = 0;

    process(inputs) {
        const channelData = inputs[0][0];  // 第1入力の第1チャンネル
        if (!channelData) return true;

        for (let i = 0; i < channelData.length; i++) {
            // Float32 (-1.0〜1.0) → Int16 (-32768〜32767) 変換
            this.buffer[this.bufferIndex++] = channelData[i] * 0x7FFF;

            // バッファが満杯 → メインスレッドへ送信
            if (this.bufferIndex === this.buffer.length) {
                this.port.postMessage(this.buffer.buffer.slice(0));  // コピーを送信
                this.bufferIndex = 0;
            }
        }
        return true;  // 処理継続フラグ
    }
}

registerProcessor('audio-processor', AudioProcessor);
```

**重要ポイント**:
- `0x7FFF` = 32767（Int16の最大値）= Float32正規化係数
- `slice(0)` でバッファのコピーを作成（元バッファの再利用と競合防止）
- `return true` で処理ループ継続
- バッファサイズ2048は遅延と効率のバランスを取った値

---

## AudioRecorder クラス

### 責務

- マイクアクセス取得
- AudioContext設定（16kHz）
- AudioWorklet読み込みと接続
- ミュート/アンミュート制御

### 実装パターン

```javascript
class AudioRecorder {
    constructor() {
        this.audioContext = null;
        this.workletNode = null;
        this.stream = null;
        this.source = null;
    }

    async start() {
        // 1. マイクアクセス（ここでブラウザAECが自動適用）
        this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });

        // 2. AudioContext（Gemini APIは16kHzを期待）
        this.audioContext = new AudioContext({ sampleRate: 16000 });

        // 3. AudioWorkletを別スレッドとして読み込み
        await this.audioContext.audioWorklet.addModule('audio-processor.js');
        this.workletNode = new AudioWorkletNode(this.audioContext, 'audio-processor');

        // 4. マイク → WorkletNode に接続
        this.source = this.audioContext.createMediaStreamSource(this.stream);
        this.source.connect(this.workletNode);

        // 5. WorkletからのメッセージをWebSocket送信に接続
        this.workletNode.port.onmessage = (event) => {
            const base64String = btoa(String.fromCharCode(...new Uint8Array(event.data)));
            ws.send(JSON.stringify({
                realtimeInput: {
                    mediaChunks: [{ mime_type: "audio/pcm", data: base64String }]
                }
            }));
        };
    }

    mute() {
        if (this.source && this.workletNode) {
            this.source.disconnect(this.workletNode);  // 接続切断でミュート
        }
    }

    unmute() {
        if (this.source && this.workletNode) {
            this.source.connect(this.workletNode);  // 再接続でアンミュート
        }
    }
}
```

**サンプルレート**: `16000` Hz。Gemini Live APIが期待するフォーマット。AIレスポンスの再生側は `24000` Hz（異なるので注意）。

### セットアップメッセージのフォーマット

```javascript
const setupMessage = {
    setup: {
        model: "gemini-2.0-flash-live-preview-04-09",
        generation_config: {
            response_modalities: ["audio"]  // 音声レスポンスを要求
        }
    }
};
ws.send(JSON.stringify(setupMessage));
```

セッション開始時に最初に送信する必要がある。プロキシはこのメッセージを待機してからGemini接続を確立する。

---

## AudioStreamer クラス

### 責務

- AIレスポンス音声のキュー管理
- シームレスな連続再生
- 割り込み時の即座停止

### なぜキューが必要か

Geminiはレスポンス音声を小さなチャンクとして順次送信する。チャンクごとに即再生すると:
- チャンク間にクリック音・ポップ音
- 無音の隙間
- 途切れる再生

キューを使い、`onended` イベントでチェーンさせることでシームレスな再生を実現。

### 実装パターン

```javascript
export class AudioStreamer {
    constructor() {
        this.audioContext = new AudioContext({ sampleRate: 24000 });  // AIレスポンスは24kHz
        this.audioQueue = [];
        this.isPlaying = false;
        this.sourceNode = null;
    }

    async receiveAudioChunk(base64Audio) {
        // 1. Base64 → Uint8Array → Int16Array
        const bytes = Uint8Array.from(atob(base64Audio), c => c.charCodeAt(0));
        const int16Array = new Int16Array(bytes.buffer);

        // 2. Int16 → Float32（Web Audio APIはFloat32を使用）
        const float32Array = new Float32Array(int16Array.length);
        for (let i = 0; i < int16Array.length; i++) {
            float32Array[i] = int16Array[i] / 32768.0;  // 正規化
        }

        // 3. AudioBuffer作成
        const audioBuffer = this.audioContext.createBuffer(1, float32Array.length, 24000);
        audioBuffer.getChannelData(0).set(float32Array);

        // 4. キューに追加し、再生開始
        this.audioQueue.push(audioBuffer);
        if (!this.isPlaying) {
            this.isPlaying = true;
            this.playNextChunk();
        }
    }

    playNextChunk() {
        if (this.audioQueue.length === 0) {
            this.isPlaying = false;
            return;
        }
        const audioChunk = this.audioQueue.shift();
        this.sourceNode = this.audioContext.createBufferSource();
        this.sourceNode.buffer = audioChunk;
        this.sourceNode.connect(this.audioContext.destination);
        this.sourceNode.onended = () => this.playNextChunk();  // チェーン
        this.sourceNode.start();
    }

    // 割り込み処理 — "緊急ブレーキ"
    stop() {
        this.isPlaying = false;
        this.audioQueue = [];  // ペンディング音声をすべてクリア
        if (this.sourceNode) {
            this.sourceNode.onended = null;  // チェーンを断ち切る（重要）
            this.sourceNode.stop();
            this.sourceNode = null;
        }
    }
}
```

**`onended = null` の重要性**: stopした後にもonendedが発火すると `playNextChunk()` が呼ばれてしまう。必ずnullに設定してからstop()する。

---

## ブラウザAEC（Acoustic Echo Cancellation）

### 問題: 音響エコー

AIがスピーカーから音声を出力 → マイクがAIの音声を拾う → VADが「ユーザーが話している」と誤検知 → AIが自分の声で割り込んでしまう

### ブラウザAECの仕組み

`getUserMedia({ audio: true })` を呼ぶだけで、ブラウザが自動的に:
1. スピーカー出力音声を参照信号として取得
2. マイク入力からスピーカー信号をリアルタイムでサブトラクト
3. 純粋なユーザー音声のみをJavaScriptに渡す

Google Meet・Discord・FaceTimeの基盤技術。ハードウェアアクセラレーション済み。

### 設計トレードオフ

| アプローチ | 複雑さ | AEC品質 |
|----------|--------|---------|
| **ブラウザWebアプリ（採用）** | 2サーバー構成 | 無償・最高品質 |
| Python PyAudio直接実装 | 単純 | ヘッドフォン必須 or 自前AEC実装（困難） |

---

## サンプルレートの整理

| コンポーネント | サンプルレート | 理由 |
|--------------|-------------|------|
| マイク録音（AudioRecorder） | **16,000 Hz** | Gemini Live APIの要求フォーマット |
| AI音声再生（AudioStreamer） | **24,000 Hz** | Geminiレスポンスの出力フォーマット |
