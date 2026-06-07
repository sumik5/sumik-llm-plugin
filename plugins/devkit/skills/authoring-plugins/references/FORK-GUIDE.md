# context: fork 機能の詳細ガイド

Claude Code 固有拡張 `context: fork` を活用してスキルをサブエージェントに分離実行し、
親会話のコンテキスト圧迫を劇的に軽減するための完全ガイド。

---

## 1. 概要・効果

### 何をするか

`context: fork` をスキルのフロントマターに追加すると、スキルの実行が**サブエージェント（子会話）に分離**される。

```yaml
context: fork
agent: general-purpose   # 省略時のデフォルト
```

### 効果の実測値

| 指標 | fork なし | fork あり | 削減率 |
|------|---------|---------|--------|
| 親会話への出力 | 10,633 字 | 806 字 | **約 92%** |

> 出典: [DevelopersIO 検証記事](https://dev.classmethod.jp/articles/claude-code-context-fork/)（2026-05-15 確認）

### 仕組み

```
親会話
  └─ スキル呼び出し
       └─ [context: fork] サブエージェント（分離コンテキスト）
            ├─ grep 結果・API 応答・中間ログ（親会話には渡さない）
            └─ 最終サマリーのみ → 親会話に返却
```

### 基本仕様

| 項目 | 内容 |
|------|------|
| フィールド分類 | **Claude Code 固有拡張**（Agent Skills 標準仕様には存在しない） |
| 追加方法 | フロントマターに `context: fork` を 1 行追加 |
| 実行場所 | サブエージェント（親会話と分離されたコンテキスト） |
| 親会話アクセス | 不可（履歴・他スキル・ユーザー指示も取得不可） |
| 戻り値 | スキル実行の最終結果のみ |

---

## 2. Agent Skills 標準 vs Claude Code 拡張

### 出典

| 仕様 | URL |
|------|-----|
| Agent Skills 標準 | <https://agentskills.io/specification> |
| Claude Code 拡張 | <https://code.claude.com/docs/en/skills> |

### 標準準拠フィールド（クロスクライアント互換）

| フィールド | Required | 制約 |
|---------|----------|------|
| `name` | Yes | Max 64 chars。親ディレクトリ名と一致必須 |
| `description` | Yes | **Max 1,024 chars** |
| `license` | No | ライセンス名 or ファイル参照 |
| `compatibility` | No | Max 500 chars |
| `metadata` | No | 任意の key-value マップ |
| `allowed-tools` | No | 事前承認ツール（Experimental） |

### Claude Code 固有拡張フィールド（他クライアント非互換）

| フィールド | 目的 |
|---------|------|
| **`context: fork`** | サブエージェント分離（本ガイドの主役） |
| **`agent`** | fork 時のサブエージェント種類 |
| `when_to_use` | description 補完（合算 1,536 chars まで） |
| `disable-model-invocation` | 自動呼び出し禁止・preload 抑制 |
| `user-invocable` | / メニュー表示制御 |
| `model` | モデル切替 |
| `effort` | 実行強度 |
| `hooks` | スキル単位 hook |
| `paths` | glob 発火条件 |
| `shell` | bash / powershell 切替 |

> 🔴 **移植性警告**: `context: fork` および `agent` は Claude Code 専用拡張。他クライアントでは無視または解釈エラーになる。詳細は [第 9 章](#9-他クライアントとの互換性) を参照。

---

## 3. 必須前提: アクション型スキルのみ有効

### 🔴 最重要ルール

**リファレンス型スキルに `context: fork` を付けると機能停止する。**

| スキル種別 | fork 適用 | 結果 |
|---------|---------|------|
| **アクション型**（タスク実行・生成・変換・検索） | ✅ 有効 | 中間ログ隔離・92% 削減 |
| **リファレンス型**（ガイドライン・規約・原則） | ❌ 禁止 | サブエージェントが空応答で機能停止 |

### 公式警告（原文）

> `context: fork` only makes sense for skills with explicit instructions. If your skill contains
> guidelines like "use these API conventions" without a task, the subagent receives the guidelines
> but no actionable prompt, and returns without meaningful output.

### 判別のキーワード

| 種別 | キーワード例 |
|------|-----------|
| アクション型 ✅ | search / find / convert / generate / create / evaluate / fetch / orchestrate |
| リファレンス型 ❌ | guide / reference / principles / patterns / conventions / standards |

---

## 4. 判定マトリクス（5軸評価）

`context: fork` を付けるかどうかは 5 軸を**上から順に**評価する。

### 評価軸

| 軸 | 質問 | fork 不可条件 |
|----|------|-------------|
| **🔴 軸0. 移植性要件** | このスキルは Claude Code 専用で良いか？ | クロスクライアント互換が必要 → **fork 不可** |
| **🔴 軸D. スキル種別** | 明示的タスクの実行（アクション型）か？ | リファレンス型 → **fork 不可（機能停止）** |
| **軸A. 文脈依存度** | 親会話のコード・議論・前段結果を参照するか？ | 高依存 → **fork 不可（文脈喪失）** |
| **軸B. 中間出力量** | 大量のログ・grep 結果・API 応答が発生するか？ | 小量 → **現状維持** |
| **軸C. サマリー可能性** | 最終結果のみで親会話の意思決定が可能か？ | 不可 → **現状維持** |

### 4段階判定ルール

| 判定 | 条件 | アクション |
|------|------|-----------|
| 🔴 **fork 不可（互換性）** | 軸0 = 互換必須 | `context: fork` 不採用 |
| 🔴 **fork 不可（種別）** | 軸D = リファレンス型 **または** 軸A = 高 | 絶対に fork を付けない |
| ✅ **fork 化** | 軸0=CC専用OK かつ 軸D=アクション型 かつ 軸A=低 かつ 軸B=大 かつ 軸C=可 | `context: fork` + `agent:` を追加 |
| ⚡ **fork 推奨** | 軸0=CC専用OK かつ 軸D=アクション型 かつ 軸A=低〜中 かつ 軸B=中〜大 かつ 軸C=可〜部分可 | 追加（要モニタリング） |
| **現状維持** | 上記以外 | 変更しない |

### 迷ったときの保守的原則

- 軸0「互換必須」 → fork 一切不可
- 軸D「リファレンス型」 → 即 fork 不可（過剰適用は機能停止）
- 不明なら「現状維持」を優先

---

## 5. agent フィールド指定戦略

`agent:` は fork 時のサブエージェント種類を指定する。省略時は `general-purpose` 相当。

| 値 | 特徴 | 推奨用途 |
|----|------|---------|
| `Explore` | 読取専用・調査系 | Web 検索、ファイル走査、ライブラリ調査 |
| `Plan` | 計画立案系 | アーキテクチャ設計、タスク分解 |
| `general-purpose` | 書込み有・生成変換系 | コード生成、変換、ブラウザ自動化 |
| カスタム Agent | agents/ 配下の定義を指定 | 専門タチコマ活用 |

### 選択フロー

```
スキルが読取専用・調査系?
  → Explore

書込み・生成・変換が必要?
  → general-purpose

専門ドメインの実装?
  → カスタムエージェント名
```

---

## 6. 適用例

### 6.1 fork 化が有効なケース（本プラグイン実績）

| スキル | 軸D | 軸A | 軸B | agent | 根拠 |
|-------|----|----|-----|-------|------|
| `find-skills` | アクション | 低 | 大 | `Explore` | `npx skills find` の出力フィルタ |
| `searching-web` | アクション | 低 | 大 | `Explore` | Web 検索結果を要約 |
| `chronicle` | アクション | 低 | 大 | `Explore` | OCR 履歴・スクリーン録画走査 |
| `researching-libraries` | アクション | 低 | 大 | `Explore` | npm/pip/Go モジュール検索 |
| `converting-content` | アクション | 低 | 大 | `general-purpose` | EPUB→OCR→翻訳パイプライン |
| `orchestrating-codex` | アクション | 低 | 大 | `general-purpose` | Codex CLI 実行ログ極大 |
| `gws-slides` | アクション | 低 | 大 | `general-purpose` | Google Slides API batchUpdate |

### 6.2 fork 化が逆効果・機能停止するケース

| スキル/カテゴリ | 問題の軸 | 理由 |
|---------------|---------|------|
| `writing-clean-code` 等のリファレンス型 | 軸D | ガイドライン提供型 → サブエージェントが空応答 |
| `reviewing-code` | 軸A（高） | 親会話のコードレビュー文脈に直接使用 |
| `orchestrating-teams` | 軸A（高） | タチコマ並列管理は本体と密結合 |
| `managing-claude-md` | 軸A（高） | 親会話で発見した問題に基づく改善 |
| `commit-msg` / `pull-request` | 軸A（高） | 親会話の差分・議論が必須 |

---

## 7. 他フィールドとの相互作用

### 7.1 disable-model-invocation との関係

| 組み合わせ | 動作 | 推奨 |
|---------|------|------|
| `context: fork` + `disable-model-invocation: false` | Claude が自動判断でも fork 実行可 + Agent preload 維持 | ✅ **標準推奨** |
| `context: fork` + `disable-model-invocation: true` | ユーザーの明示的呼び出し（/skill）のみ + Agent preload 抑制 | ⚡ 手動専用スキル向け |
| `disable-model-invocation: true` のみ | description を context から除外 | — |

> 🔴 **Agent preload 対象スキルに fork を追加する場合**: `disable-model-invocation: false` を必ず維持すること。`true` に変えると preload も停止する。

### 7.2 Agent プリロードとの共存

Agent の `skills:` フィールドでプリロードされたスキルに `context: fork` を追加しても、
プリロード（description の注入）は `disable-model-invocation: false` の限り維持される。

```yaml
# SKILL.md フロントマター（Agent preload 対象 + fork 化）
context: fork
agent: general-purpose
disable-model-invocation: false   # ← 必ず false を明示
```

### 7.3 when_to_use との関係

`when_to_use` は Claude Code 固有拡張で、description と合算して 1,536 文字まで拡張できる。
fork 化スキルでも併用可能。

```yaml
description: >-                  # max 1,024 chars（標準）
  What it does. Use when [trigger].
when_to_use: >-                  # 追加トリガー文（合算 1,536 chars まで）
  Also use when [extended trigger].
context: fork
agent: general-purpose
```

### 7.4 その他の Claude Code 拡張フィールドとの共存

| フィールド | fork との共存 | 用途 |
|---------|-------------|------|
| `paths` | ✅ 可 | `["*.ts", "*.tsx"]` でファイル種別限定 |
| `effort` | ✅ 可 | `high` / `xhigh` で重い処理を明示 |
| `hooks` | ✅ 可 | スキル実行前後の hook 定義 |
| `shell` | ✅ 可 | `bash` / `powershell` 切替 |
| `user-invocable` | ✅ 可 | `true` で / メニュー表示 |

---

## 8. 既存スキルへの fork 追加手順

```
Step 1: 5軸判定マトリクスで評価（軸0 → 軸D → 軸A → 軸B → 軸C の順）
Step 2: アクション型 + Claude Code 専用と確認できたら SKILL.md を Read
Step 3: フロントマターに以下を追加
          context: fork
          agent: <Explore or general-purpose>
        挿入位置: description の直後（disable-model-invocation より前）
Step 4: YAML 構文検証
          python3 -c "import yaml, re; src=open('SKILL.md').read(); m=re.match(r'---\n(.*?)\n---', src, re.S); yaml.safe_load(m.group(1)); print('OK')"
Step 5: description 文字数確認（1,024 文字以内）
Step 6: Agent preload 対象なら disable-model-invocation: false 維持を確認
Step 7: （任意）skills-ref validate ./skills/<skill-name> で標準準拠を検証
```

### 追加前後の例

```yaml
# Before
---
name: searching-web
description: >-
  Web検索統合スキル。...
disable-model-invocation: true
---

# After
---
name: searching-web
description: >-
  Web検索統合スキル。...
context: fork
agent: Explore
disable-model-invocation: true
---
```

---

## 9. 他クライアントとの互換性

### 🔴 移植性警告

`context: fork`・`agent`・`when_to_use`・`disable-model-invocation` 等は
**Claude Code 固有拡張**であり、Agent Skills 標準仕様には存在しない。

| クライアント | context: fork の扱い |
|---------|-------------------|
| **Claude Code** | ✅ 動作（サブエージェント分離） |
| **Cursor** | ❌ 非互換（フィールド無視または解釈エラー） |
| **Gemini CLI** | ❌ 非互換 |
| **OpenCode** | ❌ 非互換 |
| **Goose** | ❌ 非互換 |

### 対処方針

| ケース | 推奨アクション |
|---------|-------------|
| Claude Code 専用プラグイン | `context: fork` + `agent:` を積極活用。`compatibility: Designed for Claude Code` を任意で記載 |
| クロスクライアント配布予定 | 軸0=互換必須として fork 不採用。標準フィールド（name / description / license / compatibility / metadata / allowed-tools）のみで設計 |

本プラグイン `sumik-claude-plugin` は **Claude Code 専用配布**前提のため fork 適用に問題なし。
将来クロスクライアント配布する場合は軸0を再評価すること。

---

## 10. アンチパターンとトラブルシューティング

### 10.1 アンチパターン

| ❌ アンチパターン | 結果 | 正しい対処 |
|----------------|------|-----------|
| リファレンス型スキルに fork | サブエージェントが空応答で機能停止 | 軸D でアクション型かを確認 |
| クロスクライアント配布スキルに fork | 他クライアントで動作しない | 軸0で互換必須なら fork 不採用 |
| `disable-model-invocation: true` + Agent preload 期待 | preload が抑制される | `disable-model-invocation: false` を維持 |
| 親会話のコード/議論に依存するスキルに fork | 親文脈を喪失して誤動作 | 軸A=高なら fork 不可 |
| `agent:` 未指定 | 意図しないエージェントで動作 | 明示的に `Explore` / `general-purpose` を指定 |

### 10.2 トラブルシューティング

| 症状 | 確認事項 | 対処 |
|-----|---------|------|
| fork 化後にスキルが空応答を返す | 軸D: リファレンス型になっていないか | リファレンス型なら `context: fork` を削除 |
| Agent preload が効かない | `disable-model-invocation` の値 | `false` に設定（または省略） |
| fork 化後に親会話文脈が欠落する | 軸A: 親会話への依存度 | 軸A=高なら fork を外す |
| 他クライアントで動作しない | 軸0: 移植性要件 | 標準準拠版を別途用意、または fork を外す |
| `agent:` 未指定で挙動がおかしい | `agent:` フィールドの存在確認 | `Explore` または `general-purpose` を明示指定 |
| YAML 構文エラー | フロントマターのインデント | `context: fork` と `agent:` は同一インデントレベルで追加 |

### 10.3 YAML 検証コマンド

```bash
# YAML 構文検証
python3 -c "import yaml, re; src=open('skills/<name>/SKILL.md').read(); m=re.match(r'---\n(.*?)\n---', src, re.S); yaml.safe_load(m.group(1)); print('OK')"

# description 文字数確認（1,024 文字以内）
python3 -c "
import yaml, re
src = open('skills/<name>/SKILL.md').read()
m = re.match(r'---\n(.*?)\n---', src, re.S)
fm = yaml.safe_load(m.group(1))
desc = fm.get('description', '') or ''
print(f'description: {len(desc)} chars ({'OK' if len(desc) <= 1024 else 'NG: 1024超'})')
"

# context: fork + agent: の追加確認
grep -q "^context: fork$" skills/<name>/SKILL.md && grep -q "^agent: " skills/<name>/SKILL.md && echo "OK" || echo "NG"

# Agent Skills 標準準拠検証（skills-ref ツール）
skills-ref validate ./skills/<name>
# 出典: https://github.com/agentskills/agentskills/tree/main/skills-ref
```

---

## 11. 仕様鮮度の維持

`context: fork` を含む Claude Code 拡張フィールドは進化中です。authoring-plugins スキルの Step 0「最新仕様確認」と連動し、以下を定期的にチェックしてください。

### チェック対象

| 仕様変更の種類 | 確認 URL | 影響 |
|-------------|---------|------|
| `context` 値の追加（fork 以外の値が将来追加される可能性） | <https://code.claude.com/docs/en/skills> | 第4章・第5章の更新 |
| `agent` で指定可能な built-in agent の追加 | 同上 | 第5章の agent 指定戦略を更新 |
| `disable-model-invocation` 等の関連フィールドの制約変更 | 同上 | 第7章の相互作用表を更新 |
| Agent Skills 標準への昇格（fork が標準化された場合） | <https://agentskills.io/specification> | 第9章の移植性警告を緩和 |

### 確認手順

```
# 1. Agent Skills 標準仕様を確認
WebFetch(url: "https://agentskills.io/specification", prompt: "context/agent フィールドが標準に追加されていないか確認")

# 2. Claude Code 拡張を確認  
WebFetch(url: "https://code.claude.com/docs/en/skills", prompt: "context: fork の仕様変更・新規 agent 値の追加を確認")
```

確認結果は authoring-plugins/INSTRUCTIONS.md の Step 0 ログに記録してください。

---

*このガイドは `docs/plan-skill-fork-migration.md` v3 に基づいて作成（2026-05-15）。*
*最新の Agent Skills 標準仕様: <https://agentskills.io/specification>*
*最新の Claude Code 拡張仕様: <https://code.claude.com/docs/en/skills>*
