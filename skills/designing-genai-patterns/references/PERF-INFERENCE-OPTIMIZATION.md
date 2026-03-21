# PERF-INFERENCE-OPTIMIZATION: LLM推論最適化・スケーリング・KVキャッシュ

> Ch 15–19 カバー範囲: 分散推論、投機的デコーディング、vLLM、TensorRT-LLM、KVキャッシュ最適化、PagedAttention、プレフィックスキャッシング、適応バッチング、SLO設計

---

## 1. 推論パフォーマンス指標

| 指標 | 略語 | 定義 | 目的 |
|------|------|------|------|
| Time to First Token | TTFT | 最初のトークンが返るまでの時間 | Prefillフェーズのレイテンシ |
| Time Per Output Token | TPOT | トークン1個の生成時間 | Decodeフェーズのレイテンシ |
| Goodput | — | SLO（TTFT+TPOT両方）を満たした有効スループット | 実効的なシステム性能 |
| Tokens per second | TPS | 1秒あたりの生成トークン数 | スループット |

---

## 2. Disaggregated Prefill/Decode（PD分離）アーキテクチャ

### なぜPD分離が必要か

従来の**コロケーション問題**:
- Prefill（大規模並列計算）とDecode（小規模逐次計算）は性質が根本的に異なる
- 長いプロンプトのprefillがdecodeを遅延させる（prefill-decode interference）
- 単一スケジューリング戦略ではどちらかを犠牲にせざるを得ない

### PD分離の効果

| 要素 | 効果 |
|------|------|
| TTFTとTPOTの両立 | 従来は排他的なトレードオフ。PD分離で両方を同時達成可能 |
| 独立スケーリング | Prefillノード数 / Decodeノード数を別々に調整可能 |
| 報告されたGoodput向上 | DistServeシステムで最大7.4×（レイテンシSLO最大12.6×厳格化） |

### KVキャッシュのハンドオフ

```
Prefill GPU → [NIXL] → Decode GPU
  ├── 同一ノード内: NVLink/NVSwitch（device-to-device、ホストステージングなし）
  └── ノード間: GPUDirect RDMA（InfiniBand または RoCEv2）
```

**NIXL (NVIDIA Inference Xfer Library)**:
- ノード内/間のトポロジーに応じて最速パスを自動選択
- vLLM（LMCache経由）、NVIDIA Dynamo、TensorRT-LLM が統合対応
- フォールバック: ホストステージング（非最適だが動作保証）

### Kubernetesによるデプロイ（llm-d プロジェクト）

```
[Inference Gateway]
    ↓ ルーティング
[Variant Autoscaler]
    ├── [Prefill Workers × N] ← 長いプロンプトが増えたら増設
    └── [Decode Workers × M] ← 長い応答要求が増えたら増設
```

KVデータはLMCache + NIXLで移動。Kubernetes ネイティブなオーケストレーション。

---

## 3. 大規模MoEモデルの並列化戦略

### 並列化手法の比較

| 並列化 | パーティション単位 | ユースケース | メリット | デメリット |
|--------|----------------|------------|---------|----------|
| テンソル並列（TP） | 各層の重み行列を分割 | 1層が1GPUに収まらない場合 | コンピュートバウンド層で線形高速化 | 各層でAll-Reduce通信必要・NVLink必須 |
| パイプライン並列（PP） | 異なる層を異なるGPU | 超深層モデル | モデル状態を分散可能 | パイプラインバブル・単一トークンデコードに不向き |
| エキスパート並列（EP） | 異なるMoEエキスパートを分散 | 巨大MoEモデル | モデル規模をGPU数で線形スケール | All-to-All通信オーバーヘッド・負荷不均衡リスク |
| データ並列（DP） | モデルを複製、バッチ分割 | スループットスケールアウト | ほぼ線形スループット向上 | 個別クエリのレイテンシ改善なし |
| コンテキスト並列（CP） | シーケンス長方向に分割 | 超長コンテキスト | 1GPUに収まらない長い入力を処理 | クロスデバイスAttention同期が必要 |

### ハイブリッド並列化の組み合わせ推奨

- **ノード内**: テンソル並列（NVLink高速通信を活用）
- **ノード間**: パイプライン並列またはデータ並列
- **MoE層**: エキスパート並列を追加

---

## 4. 投機的デコーディング（Speculative Decoding）

### 原理

逐次的なトークン生成ボトルネックを克服するための手法群。

```
[通常デコード]  token1 → token2 → token3 → ... (逐次)
[投機的デコード] draft: token1,2,3,4,5 → verify: ✓✓✓✗ → accept: token1,2,3, reject: 4,5
```

### 主要手法の比較

| 手法 | メカニズム | 報告済み速度向上 | 必要条件 |
|------|-----------|---------------|---------|
| ドラフトモデル（標準） | 小モデルでdraft、大モデルでverify | 2–3× | 別のドラフトモデルが必要 |
| EAGLE-2 | EAGLE-1の発展形、コンテキスト認識型木推測 | 最大3.5×（EAGLE-1比20–40%改善） | ファインチューニング済みドラフトヘッド |
| Medusa | 複数のデコーダヘッドを追加して並列予測 | 2.2–3.6× | モデル再学習が必要（ヘッド追加） |
| 自己投機的デコーディング | 同一モデルが半分の層でdraftし全層でverify | 約2× | なし（同一モデル内で完結） |
| 一貫デコーディング | 生成と検証を1モデルで訓練済み | 約3× | 専用学習済みモデル |

### Medusa の仕組み

```
[通常LLM本体] ← バックボーンは変更なし
  ├── Medusa Head 1 → 次のトークン候補
  ├── Medusa Head 2 → 2番目のトークン候補
  └── Medusa Head N → N番目のトークン候補
→ 木構造バッチでN候補を一度にverify
```

**実用的ヒント**: Medusa head が予測した4トークンのうち検証失敗があっても、成功した分はそのまま採用し次へ進む。

### 投機的デコーディング適用判断基準

| 要素 | 値 | 適用推奨 |
|------|----|----|
| 受容率（acceptance rate） | >0.7 | はい |
| タスクの多様性 | 低い（特定ドメイン） | はい |
| モデルサイズ | 70B+ | はい |
| レイテンシ重要度 | 高い（インタラクティブ） | はい |

---

## 5. 制約付きデコーディング（Constrained Decoding）

### 概要と用途

JSONスキーマ・カスタム文法・禁止トークンなどの制約を生成中に適用する手法。

```
用途例: OpenAI function calling, 構造化出力, 安全フィルタリング
```

### パフォーマンスへの影響

| 実装 | オーバーヘッド |
|------|-------------|
| 素朴な実装（バックトラッキング多用） | 数十ms/トークン |
| コンパイル済み文法マスク（XGrammar等） | 小規模制約で1桁%台 |
| 複雑文法または小バッチ | 2桁%のオーバーヘッド |

```
TensorRT-LLM の XGrammar バックエンド:
→ JSON schema と CFG をGPU上でコンパイル
→ softmax最終ステップでトークンマスクを注入
→ Python側のトークンマスクオーバーヘッドを回避
```

**推奨**: 制約は必要最小限に。過度に厳しい制約 → バックトラッキング増加 → 大幅な速度低下。

---

## 6. MoE動的ルーティング最適化

### エキスパート通信最適化

```
問題: 各MoE層でトークンのAll-to-All通信が発生 → システム性能に大きく影響

最適化手法:
1. 階層型ルーティング
   ├── イントラノード（NVLink）: 同一ノード内エキスパートへ直接
   └── インターノード（InfiniBand/RoCE）: ノードをまたぐ場合のみ

2. 非同期通信（ダブルバッファリング）
   └── バッチNのエキスパート計算 ← バッチN+1の通信と並列

3. バタフライ（Shifted All-to-All）スケジュール
   └── 全リンクを段階的に利用 → 同期バリアによるアイドル削減

4. 活性化の圧縮
   └── FP8/NVFP4でAll-to-All前にキャスト → NIC負荷削減
```

### 負荷分散と容量ファクター

```
問題: 特定エキスパートへのトークン集中（ホットスポット）→ GPU 99% 対 60%

対策1: 容量ファクター（Capacity Factor）
├── 各エキスパートの最大処理トークン数を制限
├── 超過分は次点エキスパートへルーティング
└── 実用値: 1.2（top-2 ゲーティング、20%オーバーフロー余裕）

対策2: エキスパートレプリケーション
├── ホットスポットのエキスパートを別GPUにクローン
├── ゲーティング関数がオリジナルとクローン間でトークンを分散
└── 全レプリカは同一重み（モデル更新時に同期必須）

対策3: 適応型ルーティング
├── エキスパートごとのGPU使用率をリアルタイム監視
├── 過負荷エキスパートへのゲーティングスコアを補正
└── Prometheus/Grafanaで各エキスパートの使用率をモニタリング
```

---

## 7. vLLM – PagedAttention とコア最適化

### PagedAttention の概要

仮想メモリのページング概念をKVキャッシュに適用:

```
問題: 従来のKVキャッシュ
├── 各シーケンスに連続メモリを事前確保
├── シーケンス長の予測が困難 → メモリ断片化・浪費

PagedAttention の解決:
├── KVキャッシュを固定サイズ「ブロック」に分割（デフォルト16トークン/ブロック）
├── ブロックテーブルで物理ブロックを論理ブロックにマッピング
├── 不連続な物理メモリで連続シーケンスを表現
└── 非アクティブなブロックをCPU/NVMeにページアウト可能
```

**KVキャッシュサイズの計算式**:
```
bytes_per_token = 2 × n_layers × n_kv_heads × head_dim × bytes_per_element
例: Llama-13B, FP16, 4096トークン → ~3.36 GB
   Llama-13B, FP8, 4096トークン → ~1.68 GB
   GQA (8 kv heads), FP16, 4096トークン → ~0.671 GB
```

### 連続バッチング（Continuous Batching）

```
静的バッチング:
[リクエスト1,2,3 が揃うまで待機] → バッチ実行

連続バッチング（vLLM, SGLang, TensorRT-LLM）:
イテレーション毎に: [完了済みシーケンスを除去 + 新規シーケンスを追加]
→ GPU は常に最大化されたバッチで実行
→ 高負荷時: 高スループット、低負荷時: 低レイテンシ（両立）
```

### vLLM の主要設定パラメータ

| パラメータ | 説明 |
|-----------|------|
| `--max-seq-len-to-capture` | CUDA Graphs でキャプチャする最大シーケンス長（デフォルト8192） |
| `--max-num-seqs` | 1イテレーションの最大シーケンス数 |
| `--max-num-batched-tokens` | 1イテレーションの最大トークン数 |
| `enable_prefix_caching=True` | プレフィックスキャッシング有効化 |

### Prefillの分離デプロイ時の注意

```python
# vLLM disaggregated prefill: LMCache + NIXL を使用
# 同一KV layout と dtype が prefill-decode 間で一致していることを確認
# 異なる場合: レシーバ側でlayout変換カーネルを挿入
```

---

## 8. プレフィックスキャッシング（Prefix Caching）

### 基本概念

複数のリクエストが共有するプロンプトプレフィックスのKVを再利用:

```
ユースケース:
1. 同一システムプロンプト（全リクエストが共有）
2. マルチターン会話（会話履歴が次のターンのプレフィックス）
3. 長文書への複数質問（文書部分を1度だけ計算）
```

**効果**: 10個の質問を同一文書に問う場合 → 最大10×高速化（文書部分のKV再計算なし）

### vLLM のプレフィックスキャッシング

```python
# enable_prefix_caching=True で有効化
# GPU KV とCPU KV の比率調整（LMCache経由）

# 監視指標
# vllm:gpu_prefix_cache_queries
# vllm:gpu_prefix_cache_hits
# ヒット率 = hits / queries
```

### SGLang RadixAttention

ラジックスツリー（圧縮プレフィックスツリー）でKVページを管理:

```python
# 疑似コード: RadixAttention KV キャッシュルックアップ
def generate_with_radix(prompt_tokens):
    # 1. 最長キャッシュプレフィックスを検索
    node, prefix_len = radix.longest_prefix(prompt_tokens)
    model_state = ModelState.from_cache(node.cache)  # KVをクローン

    # 2. 残りのサフィックスのみ処理
    for token in prompt_tokens[prefix_len:]:
        model_state = model.forward(token, state=model_state)
        node = radix.insert(prompt_tokens[:prefix_len+1], cache=model_state.kv_cache)
        prefix_len += 1

    # 3. 自己回帰デコード
    output_tokens = []
    while not model_state.is_finished():
        token, model_state = model.generate_next(model_state)
        output_tokens.append(token)
    return output_tokens
```

**LRU退避**: GPUメモリが逼迫した場合、最も最近使われていないラジックスツリーのリーフを退避。

---

## 9. 推論スケールでの監視

### 主要メトリクス（Prometheus/Grafana）

| メトリクス | ツール | 目的 |
|-----------|--------|------|
| GPU SM利用率 | `DCGM_FI_DEV_GPU_UTIL` | コンピュートバウンドか確認 |
| GPU メモリ使用量 | `DCGM_FI_DEV_FB_USED` | KVキャッシュ枯渇を検知 |
| NVLink/NIC スループット | DCGM + Nsight | 通信ボトルネックを検知 |
| KVキャッシュ利用率 | vLLM内部メトリクス | ページングの必要性を判断 |
| プレフィックスヒット率 | vllm:gpu_prefix_cache_hits | キャッシュ有効性 |
| p95/p99 レイテンシ | Prometheus histograms | SLO遵守の確認 |

### 観測-仮説-チューニングのループ

```
1. 観測: GPU利用率低下 → ボトルネック特定
2. 仮説: バッチサイズを増やすとSM利用率が向上するはず
3. 実装: max-batch-size 調整
4. 検証: ステージング環境でNsight Systemsでプロファイル
5. デプロイ: カナリアロールアウト（小トラフィックで先行検証）
6. 監視: Grafanaでp99 latency とGPU utilization を確認
```

**SLOアラートのポイント**:
- GPU Memoryスパイク + SM利用率低下 → KVキャッシュがCPUにスワップ中
- p99レイテンシスパイク + RPS急増 → ダイナミックバッチサイズが大きすぎる
- capacity factor 1.2–1.5 でエキスパートオーバーフロー → テールレイテンシを平滑化

---

## 10. アプリケーション層の最適化

### 適応バッチング（Adaptive Batching）

```
低負荷時: バッチサイズ=1 で即時実行（レイテンシ最小化）
高負荷時: 2–10ms の収集ウィンドウでマイクロバッチ化（スループット最大化）
SLO制約: p90 TTFT ≤ X ms を満たす最大バッチサイズを自動選択
```

### モデルカスケーディング（Model Cascading）

```
60%の単純クエリ → 小モデル（70Bパラメータ） → 50ms応答
40%の複雑クエリ → 大モデル（700Bパラメータ） → 500ms応答
→ 平均コスト最大5×削減

判断基準:
├── 短い・事実的クエリ → 小モデル
├── 50トークン以上 または "explain/analyze/elaborate" を含む → 大モデル
└── 信頼度スコア低い → 小モデルの結果を破棄して大モデルに再ルーティング
```

### レスポンスストリーミング

人間の読書速度: 4–13 トークン/秒
→ これを下回るとユーザー体験が著しく低下

```
最適化:
├── WebSocket / SSE / HTTP Streaming で逐次送信
├── 2–5トークンのミニバッチでフラッシュ
├── TCP_NODELAY + quick-ack でトークンフラッシュレイテンシを最小化
└── バックプレッシャー管理（クライアントが遅い場合の処理）
```

### プロンプト最適化

| 手法 | 効果 |
|------|------|
| プロンプトクレンジング | 不要な空白・HTMLタグを除去 → トークン削減 |
| 会話履歴の要約・トランケーション | O(N²)のself-attentionコストを削減 |
| コンフィグトークン | 長いシステムプロンプトを短いメタデータに置換（モデル再学習が必要） |
| プレフィックスキャッシング | 共有プレフィックス部分を一度だけ計算 |

---

## 11. KVキャッシュの高度な最適化

### メモリ階層設計

```
GPU HBM  → 最速（例: B200 180GB、B300 288GB）
CPU DRAM → 中速（LMCache経由でティアリング）
NVMe SSD → 最遅（高I/Oレイテンシに注意）
```

### KVキャッシュ削減手法

| 手法 | 削減量 | 注意事項 |
|------|--------|---------|
| FP16 → FP8 | 2× | 軽微な精度低下あり |
| FP16 → FP4 | 4× | より大きな精度影響 |
| MQA（Multi-Query Attention） | ヘッド数倍 | モデルアーキテクチャ変更が必要 |
| GQA（Grouped-Query Attention） | ヘッドグループ倍 | モデルアーキテクチャ変更が必要 |
| MLA（DeepSeek Multi-Latent Attention） | 大幅削減 | DeepSeek系モデルのみ |

### トポロジー対応スケジューリング

```
同一ノード内エキスパート → NVLink（高速）
ノード間エキスパート → InfiniBand/RoCEv2（低速）

最適化:
├── 頻繁に同時活性化するエキスパートを同一GPU/ノードに配置（Expert Collocation）
├── インターノードトラフィックを最小化
└── NVL72 ラック内: 72GPU間でNVLink Switchメッシュを最大活用
```

---

## 12. 推論エンジン選択ガイド

| エンジン | 強み | 主なユースケース |
|---------|------|---------------|
| vLLM | PagedAttention・プレフィックスキャッシング・disaggregated PD | 汎用LLM推論・Open Source |
| SGLang | RadixAttention・高度なプレフィックスツリー | 多段階推論・コンプレックスワークフロー |
| TensorRT-LLM | NVIDIA最適化・最高のGPU効率 | NVIDIAハードウェア特化・本番デプロイ |
| NVIDIA Dynamo | 統合オーケストレーション・NIXL統合 | 大規模クラスター・マルチノード |

---

## 関連ファイル

- `PERF-PYTORCH-TUNING.md` — PyTorchプロファイリング・torch.compile・分散学習
- `PERF-CUDA-FUNDAMENTALS.md` — CUDA基礎・メモリ階層・Occupancy
- `PERF-SCALING-FUTURE.md` — 大規模スケーリング・AI支援最適化
- `PERF-CHECKLIST.md` — 175+項目のパフォーマンスチェックリスト
