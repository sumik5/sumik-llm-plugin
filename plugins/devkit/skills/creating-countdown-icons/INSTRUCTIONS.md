# creating-countdown-icons — 実行ワークフロー

カウントダウンアプリ用アイコン（512×512 PNG）を対話フローで生成する手順。

---

## 全体フロー概要

```
① text 受領 → ② 絵文字候補4つをClaudeが考案 → ③ 候補グリッド生成・提示
→ ④ AskUserQuestion（絵文字4択）→ ⑤ AskUserQuestion（背景パレット4択）
→ ⑥ 最終アイコン生成 → ⑦ clean版＋preview版を表示・出力パス報告
```

---

## Step 1: text の受領

スキル起動時の引数（または会話の文脈）から `text`（アイコンに入れる文字列）を取得する。

- 引数として与えられた場合はそのまま使用する（例: 「知財検定」）。
- 指定がない場合は次の質問をする:
  > 「アイコンに入れる文字列を教えてください（例: 知財検定、TOEIC、N2試験）」

---

## Step 2: 絵文字候補4つを考案する

`text` の意味・用途・イメージから連想して、**絵文字を4つ考案**する。

### 考え方のガイド

| 連想軸 | 例 |
|--------|-----|
| テーマの本質的概念 | 「知財検定」→ 💡（発明・アイデア）、⚖️（権利・法律） |
| 学習・試験の汎用表現 | 📚（学習）、🎓（資格・卒業） |
| カウントダウン・期限の緊張感 | ⏰（締め切り）、🔥（熱量・追い込み） |
| テーマ固有のビジュアル | 「英検」→ 🗣️、「数検」→ 🔢、「簿記」→ 📊 |
| 達成・合格のポジティブ感 | 🏆（勝利）、✨（輝き）、🎯（目標達成） |

各候補に対して「意味の説明」を1行添えて候補リストを作成しておく（Step 4の選択肢ラベルで使用）。

**例（「知財検定」の場合）:**
```
💡 電球（ひらめき・発明）
⚖️  天秤（法律・権利）
📚 本（学習・知識）
🎓 角帽（資格・合格）
```

---

## Step 3: 候補グリッド画像を生成して提示

以下のコマンドで4絵文字の候補グリッド画像を生成する（`--mode candidates`）。

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/generate_icon.py \
  --mode candidates \
  --candidates "💡,⚖️,📚,🎓" \
  --palette I \
  --text "知財検定" \
  --out /tmp/candidates.png
```

生成後、Read ツールで `/tmp/candidates.png` を読み込みユーザーに表示する。

> **注意**: `--candidates` にはカンマ区切りで4つの絵文字を指定する。スペースは不要。

---

## Step 4: AskUserQuestion — 絵文字を4択で選ぶ

```
question: アイコンの絵文字を選択してください。

options:
  - value: "💡"
    label: "💡 電球（ひらめき・発明）"
  - value: "⚖️"
    label: "⚖️  天秤（法律・権利）"
  - value: "📚"
    label: "📚 本（学習・知識）"
  - value: "🎓"
    label: "🎓 角帽（資格・合格）"
```

ユーザーの回答を `selected_emoji` として保持する。

---

## Step 5: AskUserQuestion — 背景パレットを4択で選ぶ

```
question: 背景パレットを選択してください。

options:
  - value: "I"
    label: "I — 濃紺 × ゴールド（#1B2A4A × #E8B53C）落ち着き・信頼感"
  - value: "J"
    label: "J — チャコール × シアン（#2B2F33 × #36C5D6）モダン・テック感"
  - value: "K"
    label: "K — 深緑 × 淡ゴールド（#10403B × #EAD27A）上品・ナチュラル"
  - value: "L"
    label: "L — インディゴ × コーラル（#2E2A55 × #F0865A）エネルギッシュ・情熱"
```

ユーザーの回答を `selected_palette` として保持する。

---

## Step 6: 最終アイコンを生成する

出力先のパスを決定したうえで、以下のコマンドを実行する。

### 出力パスの決定ルール

- ユーザーが出力先を指定していればそのパスを使用する。
- 指定がない場合はカレントディレクトリに次のファイル名で出力する:
  `countdown-icon-{text}-{palette}.png`（例: `countdown-icon-知財検定-I.png`）

### 最終生成コマンド

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/generate_icon.py \
  --text "知財検定" \
  --emoji "💡" \
  --palette I \
  --out /path/to/countdown-icon-知財検定-I.png
```

このコマンドは以下の2ファイルを自動生成する:

| ファイル | 内容 |
|---------|------|
| `countdown-icon-知財検定-I.png` | clean版（絵文字＋テキストのみ） |
| `countdown-icon-知財検定-I_preview.png` | preview版（白数字「30」重ね合わせ） |

---

## Step 7: 生成結果を表示・報告する

1. Read ツールで `{out}` と `{out_stem}_preview.png` を読み込み、ユーザーに表示する。
2. 出力パスを報告する:

```
生成完了:
  clean版:   /path/to/countdown-icon-知財検定-I.png
  preview版: /path/to/countdown-icon-知財検定-I_preview.png
```

---

## スクリプト引数リファレンス

`generate_icon.py` の CLI 引数一覧。

| 引数 | 必須 | 既定値 | 説明 |
|------|:----:|--------|------|
| `--text` | ○ | — | アイコンに入れる文字列 |
| `--palette` | ○ | — | パレットID（`I` / `J` / `K` / `L`） |
| `--out` | ○ | — | 出力 PNG ファイルパス（絶対パス推奨） |
| `--emoji` | final 時 ○ | — | 表示する絵文字（1文字） |
| `--mode` | — | `final` | `final`（clean版＋preview版生成）/ `candidates`（4択グリッド生成） |
| `--candidates` | candidates 時 ○ | — | カンマ区切り4絵文字（例: `💡,⚖️,📚,🎓`） |
| `--icon-style` | — | `silhouette` | `silhouette`（シルエット）/ `color`（カラー） |
| `--preview-number` | — | `30` | preview版に重ねる数字 |

---

## パレット一覧

| ID | 背景色 | アクセントカラー | イメージ |
|----|--------|-----------------|---------|
| `I` | `#1B2A4A`（濃紺） | `#E8B53C`（ゴールド） | 落ち着き・信頼感・高級感 |
| `J` | `#2B2F33`（チャコール） | `#36C5D6`（シアン） | モダン・テック感・クール |
| `K` | `#10403B`（深緑） | `#EAD27A`（淡ゴールド） | 上品・ナチュラル・安定感 |
| `L` | `#2E2A55`（インディゴ） | `#F0865A`（コーラル） | エネルギッシュ・情熱・行動力 |

---

## 実行例（まとめ）

```bash
# 候補グリッド生成（Step 3）
python3 ${CLAUDE_SKILL_DIR}/scripts/generate_icon.py \
  --mode candidates \
  --candidates "💡,⚖️,📚,🎓" \
  --palette I \
  --text "知財検定" \
  --out /tmp/candidates.png

# 最終生成（Step 6）
python3 ${CLAUDE_SKILL_DIR}/scripts/generate_icon.py \
  --text "知財検定" \
  --emoji "💡" \
  --palette I \
  --out /path/to/countdown-icon-知財検定-I.png
```

---

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `generate_icon.py` が存在しない | `${CLAUDE_SKILL_DIR}/scripts/` を確認。スクリプト未配置の場合は別タスクで生成が必要 |
| 絵文字が正しく描画されない | `--icon-style color` を試す |
| 出力先ディレクトリが存在しない | `mkdir -p` で事前作成 |
| 文字列が長すぎて収まらない | `--text` を短縮するか省略形を使用 |
