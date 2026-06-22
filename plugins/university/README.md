# university

**大学で使う Processing (Java Mode) のスケッチ開発と CLI 自動コンパイル・実行・検証を支援するプラグイン**

---

## 概要

university は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。大学の授業・課題で扱う **Processing (Java Mode)** のスケッチ開発を支援します。スケッチの設計・実装に加え、ローカルにインストールされた Processing の CLI を用いて **コンパイル・実行・検証まで自動化**し、構文エラーや実行時エラーを早期に発見できるようにします。

skills のみを持つ構成で、plugin レベルの MCP / agents / commands / hooks / bin は持ちません（補助スクリプトはスキル内に bundle します）。Codex 配布は studio などと同じ subdirectory 方式です。

---

## インストール

### Claude Code

```bash
/plugin install university@sumik
```

### Codex

```bash
codex plugin add university@sumik-marketplace
```

---

## ディレクトリ構成

```
plugins/university/
├── .claude-plugin/
│   └── plugin.json          # Claude Code 用 manifest（plugin 名 university / version 同期必須）
├── .codex-plugin/
│   └── plugin.json          # Codex CLI 用 manifest（skills "./skills/"・MCP/agents なし）
├── README.md
└── skills/
    └── developing-processing/   # Processing スケッチ開発 + CLI 自動コンパイル・実行・検証スキル
```

---

## コンポーネント一覧

### Skills (1個)

| スキル | 説明 |
|--------|------|
| `developing-processing` | Processing (Java Mode) のスケッチ開発と、ローカル Processing CLI による自動コンパイル・実行・検証を支援。スケッチの設計・実装からビルド検証までを一貫してカバーする。 |

---

## 依存関係メモ

- **Processing 4.4.3 以降がローカルにインストールされていること**を前提とします。macOS では `/Applications/Processing.app` が存在することを期待し、その同梱 CLI のサブコマンド `processing cli`（4.4.3+ で旧 `processing-java` から改名）を呼び出してコンパイル・実行・検証を行います。
- Processing の実行ファイルのパスは環境変数 **`PROCESSING_BIN`** で上書きできます。標準とは異なる場所にインストールしている場合や、CI 等で別パスから呼び出したい場合に指定してください。
- 既定では macOS を前提としていますが、`PROCESSING_BIN`（または相当の binary パス）を環境に合わせて変更すれば、他 OS（Windows / Linux）でも同様に動作します。
