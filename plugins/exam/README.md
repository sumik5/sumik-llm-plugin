# exam

**生成AI活用試験の問題画像から「対話の要点」と回答提出物を自動生成するプラグイン**

---

## 概要

exam は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。生成AI活用に関する資格試験の問題画像（左=問題文・右=回答欄の見開きスクリーンショット）を読み取り、各小問について **対話の要点**（`自分: ○○ → AI: ○○ → …` 形式・最大1000字）と **提出物**（提出物名の拡張子で分岐: markdown 回答本文 / 図の画像生成指示 / ソースコード）を生成し、入力画像と同じディレクトリの `answers/<問番号>/` 配下にファイルとして保存します。

複数の問題画像を渡された場合は、**Workflow で問（画像）ごとに並列求解**します（第一推奨）。Workflow が使えない環境では `exam-solver` agent を画像ごとに background 並列起動する代替経路、agent も Workflow も使えない単一エージェント環境（Codex 等）では逐次処理にフォールバックします。スキルは特定の試験ブランド・主催団体に依存しない汎用設計で、同様な問題形式であれば何にでも対応します。

---

## インストール

### Claude Code

```bash
/plugin install exam@sumik
```

### Codex

```bash
codex plugin add exam@sumik-marketplace
```

> Codex では **skills のみ配布** されます。`exam-solver` agent は Claude Code 専用のため、Codex 環境では並列起動を行わず、スキル単体で画像を逐次処理します。

---

## ディレクトリ構成

```
plugins/exam/
├── .claude-plugin/
│   └── plugin.json              # Claude Code 用 manifest（plugin 名 exam / version 同期必須）
├── .codex-plugin/
│   └── plugin.json              # Codex CLI 用 manifest（skills "./skills/"・MCP/agents なし）
├── README.md
├── agents/
│   └── exam-solver.md           # 1画像=1大問を解く実装系 agent（Claude Code 専用）
└── skills/
    └── answering-genai-exam/
        ├── SKILL.md             # フロントマター + INSTRUCTIONS.md ポインター
        ├── INSTRUCTIONS.md      # 解答生成ワークフロー本文（Step 0〜5・経路A=Workflow/B=background-Agent/C=逐次）
        ├── references/
        │   ├── WORKFLOW-SCRIPT.md # Workflow 並列求解（第一推奨）のスクリプト雛形・args 仕様・求解契約
        │   └── OUTPUT-FORMAT.md # 出力ファイル名規則・拡張子分岐・対話要点/画像生成指示テンプレート
        └── assets/
            └── answer-template.md  # 1大問分の出力サンプル（穴埋めテンプレート）
```

---

## コンポーネント一覧

### Skills (1個)

| スキル | 説明 |
|--------|------|
| `answering-genai-exam` | 生成AI活用試験の問題画像（見開きスクショ）を読み取り、各小問の対話の要点（≤1000字）と提出物（拡張子分岐: markdown回答 / 画像生成指示 / コード）を生成して `answers/<問番号>/` に保存。複数画像は Workflow で問ごとに並列求解（第一推奨）、Workflow 不可時は exam-solver agent で background 並列、agent も Workflow も不可なら逐次フォールバック。曖昧点は並列起動前に AskUserQuestion で一括解消 |

### Agents (1体)

| Agent | 説明 |
|-------|------|
| `exam-solver` | 1画像=1大問を解く実装系 Tachikoma agent。本体から「問題抽出メモ・確定方針・出力先・問番号」を受領し、各小問の対話の要点と提出物を生成して出力。並列起動されるため AskUserQuestion は使わず、不明点は自己判断 + 完了報告に明記（`answering-genai-exam`・`writing-clean-code` を preload・model: sonnet・Claude Code 専用） |

---

## 依存関係メモ

- exam は devkit と**常に併設インストールされること**を前提とします。`exam-solver` agent は preload 対象として `answering-genai-exam`（同一プラグイン・bare 参照）と `writing-clean-code`（devkit 提供・コード提出物の品質確保）を読み込むため、devkit 不在ではスキル preload が解決されません。
- `exam-solver` agent は **Claude Code 専用** です。Codex CLI へは skills のみ配布され、agent は配布されません。Codex 環境では `answering-genai-exam` スキル単体が画像を逐次処理するフォールバック手順で完結します。
