# AIによるログ分析

## 機械学習の基礎

### 学習の種類とログ分析での使い分け

| 種類 | 概要 | ログ分析での用途 |
|------|------|-----------------|
| 教師あり学習 | 正解ラベル付きデータで学習 | 「正常/異常」ラベルが付与済みのログを分類 |
| 教師なし学習 | 正解なしでデータを自律分類 | ラベル不要の異常検知・クラスタリング |
| 強化学習 | 報酬最大化を目指すエージェント学習 | リアルタイムな時系列ログへの適用 |

**選択指針:** 異常データが少ない・未知の攻撃を検知したい場合は教師なし学習が有効。ラベル付きデータが揃っている場合は教師あり学習で精度を高める。

### MLパイプライン

```
課題定義 → データ収集 → 前処理 → 特徴量抽出 → モデル選択 → 学習 → 評価 → 運用・再学習
```

各ステップのポイント:
- **課題定義**: 異常検知なのか障害予測なのかで、必要データと手法が変わる
- **前処理**: 最も手作業が多い工程。正規表現・ログパーサーで構造化
- **特徴量抽出**: TF-IDF、出現頻度、時間的特徴などを設計
- **評価**: 混同行列・classification_report で精度確認
- **交差検証**: 過学習防止のため、データを複数グループに分けて検証

---

## ログの前処理・特徴量エンジニアリング

### データの尺度（4種類）

| 尺度 | 例 | 演算 |
|------|-----|------|
| 名義尺度 | ログレベル名（INFO/ERROR）、血液型 | 分類のみ（平均不可） |
| 順序尺度 | 星5評価、重要度ランク | 大小比較のみ（間隔は不等） |
| 間隔尺度 | 時刻、温度 | 加減算可（比率は不可） |
| 比例尺度 | レスポンス時間(ms)、バイト数 | 全演算可 |

尺度の種類に合わせた数値化がモデルの性能を大きく左右する。

### Pythonによる前処理・特徴量化

```python
import pandas as pd
from sklearn.preprocessing import LabelEncoder
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer

# ログのリスト（実際はファイルから読み込む）
logs = [
    "2025-06-15 12:34:56 INFO User 123 logged in",
    "2025-06-18 09:01:45 ERROR Failed to load resource",
    "2025-06-20 13:50:21 INFO User 456 logged out",
    "2025-06-22 18:42:33 WARN Disk space low",
    "2025-06-25 01:51:18 ERROR Failed to log in",
    "2025-07-01 08:18:09 INFO User 789 logged in"
]

# ログをDataFrameに整形
data = []
for log in logs:
    parts = log.split(' ', 4)  # 日時、レベル、メッセージに分割
    timestamp = parts[0] + ' ' + parts[1]
    level = parts[2]
    message = parts[4]
    data.append([timestamp, level, message])

df = pd.DataFrame(data, columns=['timestamp', 'level', 'message'])

# 時系列特徴量の抽出（時間帯・曜日）
df['timestamp'] = pd.to_datetime(df['timestamp'])
df['hour'] = df['timestamp'].dt.hour
df['minute'] = df['timestamp'].dt.minute
df['second'] = df['timestamp'].dt.second
df['weekday'] = df['timestamp'].dt.weekday  # 0=月曜, 6=日曜

# ログレベルのエンコーディング（LabelEncoder）
le = LabelEncoder()
df['level_encoded'] = le.fit_transform(df['level'])

# ログレベルの手動マッピング（順序を意識する場合）
df['level_code'] = df['level'].map({'INFO': 0, 'WARN': 1, 'ERROR': 2})

# メッセージのTF-IDFベクトル化
vectorizer = TfidfVectorizer(stop_words='english')
X_text = vectorizer.fit_transform(df['message'])

# 数値特徴量の抽出
X_numeric = df[['hour', 'minute', 'second', 'weekday', 'level_encoded']].values
```

### 時間帯別ログ件数の集計

```python
# 時間帯ごとのログ件数を集計（異常なスパイクの検出に使える）
log_counts = df.groupby('hour').size()
print(log_counts)
```

---

## ランダムフォレストによる分類

### 決定木とランダムフォレストの関係

- **決定木（Decision Tree）**: 木構造の条件分岐でデータを分類。量的・質的データ両方を扱える。解釈しやすいが過学習しやすい
- **ランダムフォレスト**: 複数の決定木を構築し、多数決で予測。単体の決定木より精度が高く、過学習に強い

### ログ異常判定の実装例

```python
import numpy as np
from sklearn.ensemble import RandomForestClassifier

# 特徴量としてメッセージベクトルとログレベルコードを結合
X = np.hstack([X_text.toarray(), df[['level_code']].values])
y = (df['level'] == 'ERROR').astype(int)  # 1=異常, 0=正常

model = RandomForestClassifier()
model.fit(X, y)

# 新しいログの異常判定
new_log = ["Failed to connect to database"]
new_vec = vectorizer.transform(new_log).toarray()
new_level_code = np.array([[1]])  # ERRORレベルと仮定
new_X = np.hstack([new_vec, new_level_code])

pred = model.predict(new_X)
print("異常判定結果:", "異常" if pred[0] == 1 else "正常")
```

### classification_report による評価

```python
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

y_pred = model.predict(X_test)
print(classification_report(y_test, y_pred))
# precision（適合率）、recall（再現率）、f1-score を確認
```

---

## Isolation Forest による教師なし異常検知

### 原理

異常データは正常データより「孤立しやすい」性質を利用。決定木でランダムに分割したとき、少ない分割回数で孤立するデータを異常と判定する。ラベル不要のため、大規模ログにも適用しやすい。

### 実装例

```python
from sklearn.ensemble import IsolationForest

# contamination: データ全体に占める異常の割合（事前推定値）
model = IsolationForest(contamination=0.1, random_state=42)
model.fit(X)

# -1 が異常、1 が正常
pred = model.predict(X)
print(pred)
# 例: [ 1  1  1 -1  1  1] → 4件目が異常
```

**パラメータ調整のポイント:**
- `contamination=0.05` → 異常が全体の5%と想定
- 値を大きくすると異常検知の感度が上がるが誤検知も増える

---

## LSTM による時系列異常検知

### RNN / LSTM の概要

| モデル | 特徴 |
|--------|------|
| RNN（再帰型NN） | 過去の情報を記憶して次の出力に利用 |
| LSTM | 長期記憶と短期記憶を組み合わせ、長期的な依存関係を学習可能 |

ログは時間順に発生するため、時系列モデルが異常パターンの検出に有効。

### 教師あり二値分類（ラベルあり）

```python
import numpy as np
import keras

# 10タイムステップ、5特徴量の時系列データを1000件
X = np.random.rand(1000, 10, 5)
y = np.random.randint(0, 2, 1000)  # 0=正常, 1=異常

model = keras.Sequential()
model.add(keras.layers.Input(shape=(10, 5)))
model.add(keras.layers.LSTM(32))
model.add(keras.layers.Dense(1, activation='sigmoid'))
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
model.fit(X, y, epochs=5, batch_size=32)

# 新しいデータの予測
X_new = np.random.rand(1, 10, 5)
y_pred_prob = model.predict(X_new)
y_pred_class = (y_pred_prob > 0.5).astype(int)
print("予測確率:", y_pred_prob)
print("予測クラス:", y_pred_class)
```

### LSTMオートエンコーダ（ラベル不要）

正常データのパターンを学習し、再構成誤差（入力と復元の差）が大きいデータを異常と判定する。

```python
import numpy as np
import keras

X_train = np.random.rand(1000, 10, 5)
X_test = np.random.rand(100, 10, 5)
timesteps = X_train.shape[1]
features = X_train.shape[2]

# エンコーダ + デコーダ構成
inputs = keras.layers.Input(shape=(timesteps, features))
encoded = keras.layers.LSTM(32)(inputs)
decoded = keras.layers.RepeatVector(timesteps)(encoded)
decoded = keras.layers.LSTM(features, return_sequences=True)(decoded)

autoencoder = keras.models.Model(inputs, decoded)
autoencoder.compile(optimizer='adam', loss='mse')
autoencoder.fit(X_train, X_train, epochs=10, batch_size=32)

# 再構成誤差で異常検知
X_pred = autoencoder.predict(X_test)
mse = np.mean(np.power(X_test - X_pred, 2), axis=(1, 2))
threshold = np.percentile(mse, 95)  # 上位5%を異常とする閾値
anomalies = mse > threshold
print("異常検知結果:", anomalies)
```

---

## BERT によるログ意味解析

### トランスフォーマーモデルの特徴

- 文章を双方向に処理して学習（片方向のRNNより文脈理解が高い）
- ログの自然言語メッセージ部分（エラー文など）のベクトル化に有効
- `transformers` ライブラリで手軽に利用可能

### ログメッセージのベクトル化

```python
from transformers import BertTokenizer, BertModel
import torch

tokenizer = BertTokenizer.from_pretrained('bert-base-uncased')
model = BertModel.from_pretrained('bert-base-uncased')

log_message = "Failed to load resource"
inputs = tokenizer(log_message, return_tensors='pt')
outputs = model(**inputs)

# [CLS]トークンのベクトルを特徴量として使用
cls_vector = outputs.last_hidden_state[:, 0, :]
print(cls_vector.shape)  # (1, 768)
# この768次元ベクトルを分類・クラスタリングの入力として利用
```

---

## 障害予測

### LSTMによる二値分類（障害あり/なし）

過去のログ特徴量を時系列として入力し、一定期間内に障害が発生するかどうかを予測する。

```python
import numpy as np
import keras
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# 20タイムステップ、10特徴量のログデータ
X = np.random.rand(1000, 20, 10)
y = np.random.randint(0, 2, 1000)  # 0=障害なし, 1=障害あり

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

model = keras.Sequential()
model.add(keras.layers.Input(shape=(20, 10)))
model.add(keras.layers.LSTM(64))
model.add(keras.layers.Dense(1, activation='sigmoid'))
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
model.fit(X_train, y_train, epochs=10, batch_size=32)

y_pred = (model.predict(X_test) > 0.5).astype(int)
print(classification_report(y_test, y_pred))
```

### ラベル付けの課題と半自動化

- 「障害が起きたかどうか」の判定は人間の確認が必要
- **半自動化の手段**: Jira / ServiceNow / Redmine などのITSMツールと連携、エラーメッセージを正規表現で抽出、Fluentd / Elastic Stackで検索してラベルを自動付与

---

## 根本原因分析のAI活用

### 特徴量重要度分析（RandomForest）

どの特徴量が障害発生に影響しているかを可視化する。

```python
import numpy as np
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier

# 20種類の特徴量を持つデータ（例: CPU使用率、メモリ使用率、エラー件数 etc.）
X = np.random.rand(1000, 20)
y = np.random.randint(0, 5, 1000)

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X, y)

importances = model.feature_importances_
indices = np.argsort(importances)[::-1]

# 上位10特徴量をプロット
plt.figure(figsize=(10, 6))
plt.title("Feature Importances")
plt.bar(range(10), importances[indices][:10], align='center')
plt.xticks(range(10), indices[:10])
plt.show()
```

### SHAP / LIME による説明可能性

| ツール | 概要 | 用途 |
|--------|------|------|
| SHAP（SHapley Additive exPlanations） | 各特徴量が予測に与えた影響を全体で公平に数値化 | 「CPU温度がこの予測に+0.8影響している」など全体評価 |
| LIME（Local Interpretable Model-agnostic Explanations） | 個別の予測1件を単純モデルで近似して説明 | 「この1件の障害予測はCPU使用率が高いから」と局所説明 |

どちらもブラックボックスのモデルを人間が理解できる形で説明するための手法。取引先への報告やインシデント分析に必要。

---

## 行動分析とパターン認識

### セッション分割（30分ルール）

ユーザーのアクセスログをセッション単位に区切ることで、行動パターンを把握しやすくなる。

```python
import pandas as pd

data = {
    'user_id': [1, 1, 1, 2, 2, 1],
    'timestamp': [
        '2025-06-15 10:00:00',
        '2025-06-15 10:05:00',
        '2025-06-15 11:30:00',  # 85分後 → 新セッション
        '2025-06-15 10:10:00',
        '2025-06-15 10:20:00',
        '2025-06-15 11:40:00'
    ],
    'action': ['login', 'view', 'purchase', 'login', 'view', 'logout']
}

df = pd.DataFrame(data)
df['timestamp'] = pd.to_datetime(df['timestamp'])
df = df.sort_values(['user_id', 'timestamp'])

# 同一ユーザーで30分以上空いたら新セッション
df['prev_time'] = df.groupby('user_id')['timestamp'].shift(1)
df['diff'] = (df['timestamp'] - df['prev_time']).dt.total_seconds().div(60)
df['new_session'] = (df['diff'] > 30) | (df['diff'].isnull())
df['session_id'] = df.groupby('user_id')['new_session'].cumsum()

print(df[['user_id', 'timestamp', 'action', 'session_id']])
```

### セッション特徴量の例

| 特徴量 | 説明 |
|--------|------|
| 操作回数 | セッション内のイベント数 |
| 購入回数 | ECサイトでの購入イベント数 |
| セッション時間（分） | 最初から最後のイベントまでの経過時間 |
| ページ種別の比率 | 商品ページ閲覧 vs 管理ページアクセスの比率 |
| エラー発生回数 | セッション中のエラーイベント数 |

### k-means クラスタリング

セッション特徴量をクラスタリングして、一般的な行動グループと異常グループを分離する。

```python
from sklearn.cluster import KMeans
import numpy as np

# セッション特徴量: [操作回数, 購入回数, セッション時間(分)]
X = np.array([
    [5, 1, 30],   # 通常ユーザー
    [3, 0, 10],   # 通常ユーザー
    [10, 2, 60],  # 高活動ユーザー（異常候補）
    [4, 0, 20]    # 通常ユーザー
])

kmeans = KMeans(n_clusters=2, random_state=42)
labels = kmeans.fit_predict(X)
print("クラスタリング結果:", labels)
# 例: [0 0 1 0] → 3件目が別グループ（異常候補）
```

---

## AIログ分析の自動化

### 定期分析パイプライン

```python
import time
import pandas as pd
from sklearn.ensemble import IsolationForest

def load_log(file_path):
    # CSV形式のログを読み込む
    return pd.read_csv(file_path)

def preprocess(df):
    # ログレベルを数値化し、分析対象の特徴量を返す
    df['level_code'] = df['level'].map({'INFO': 0, 'WARN': 1, 'ERROR': 2})
    return df[['level_code', 'value']]  # 'value' はログの数値的特徴量の例

def analyze(df):
    model = IsolationForest(contamination=0.05, random_state=42)
    model.fit(df)
    preds = model.predict(df)
    return df[preds == -1]  # 異常と判定されたもの

def alert(anomalies):
    if not anomalies.empty:
        print("異常検知！以下のログを確認してください:")
        print(anomalies)
    else:
        print("異常なし")

def main_loop(log_path, interval_sec=60):
    while True:
        df = load_log(log_path)
        df_pre = preprocess(df)
        anomalies = analyze(df_pre)
        alert(anomalies)
        time.sleep(interval_sec)

# 実行例（実際はファイルパスを指定）
# main_loop('system_log.csv', interval_sec=300)
```

### cron による定期実行

```bash
# crontab -e で設定

# 書式: 分 時 日 月 曜日 コマンド

# 毎分実行
* * * * * python /opt/log_analyzer.py

# 毎時0分に実行
0 * * * * python /opt/log_analyzer.py

# 毎日10時30分に実行
30 10 * * * python /opt/log_analyzer.py
```

---

## AIログ分析の課題と対策

### データの偏り（バイアス）

ログの大半は正常データ。異常データが少ないと学習が偏り、誤検知が増える。

| 対策 | 概要 |
|------|------|
| アンダーサンプリング | 多数派（正常）データを間引いてバランスを調整する。例: 正常950件 → 200件に削減 |
| オーバーサンプリング | 少数派（異常）データを増やす（データの水増し）。SMOTE等のアルゴリズムで人工的に生成 |
| クロスバリデーション | データを複数グループに分けて検証し、汎化性能を評価 |

### 過学習（オーバーフィッティング）

学習データに過剰適合し、新しいデータに対して精度が低下する現象。

| 対策 | 概要 |
|------|------|
| 学習データ量を増やす | 多様なパターンを学習させて汎化性能を向上させる |
| L1正則化（ラッソ回帰） | 損失関数に `λ * Σ|w|` を加算。不要な特徴量の係数をゼロにしやすい |
| L2正則化（リッジ回帰） | 損失関数に `λ * Σw²` を加算。係数の極端な値を抑制する |
| 早期終了（Early Stopping） | 検証データの精度が改善しなくなった時点で学習を打ち切る |

### 説明可能性の問題

ニューラルネットワーク等の高精度モデルはブラックボックスになりやすく、結果の根拠を説明できない。

**対策:**
- 決定木・ランダムフォレストなど、構造が見えるモデルを優先的に採用する
- SHAP / LIME を活用してモデルの判断根拠を可視化する
- インシデントレポートや取引先への説明に「なぜ異常と判定されたか」を示せるようにする
