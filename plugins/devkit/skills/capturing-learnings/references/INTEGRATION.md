# 既存自己改善エコシステムとの棲み分け・連携

このリポジトリには複数の自己改善機構が共存する。本スキル `capturing-learnings` は「あらゆるプロジェクトの汎用キャプチャ層」として設計されており、各機構とは役割が明確に分かれている。

---

## 1. 機構の役割分担

### 全体像

| 機構 | 位置づけ | 起動タイミング | 対象 | 置き場所 |
|------|---------|--------------|------|---------|
| **capturing-learnings（本スキル）** | 受動的・汎用キャプチャ層 | 常時（作業中のあらゆる気づき） | あらゆるプロジェクトの学び・エラー・訂正・機能要望 | `.learnings/` ディレクトリ（プロジェクトローカル） |
| **CLAUDE.md inbox → authoring-plugins/IMPROVEMENT-INTAKE** | メタループ（このプラグイン自身を改善するループ） | セッション中に sumik-claude-plugin スキルを読み込んだ時 | このプラグインのスキル本体の改善提案 | `~/.claude/CLAUDE.md` の「📥 スキル改善提案」セクション |
| **authoring-plugins/USAGE-REVIEW** | バッチ棚卸し | 月次・四半期 | スキルポートフォリオ全体の利用状況・未使用スキル・統合候補 | セッションログ（`~/.claude/projects/*/*.jsonl`）を入力源とする |
| **managing-claude-md** | 生きた文書の整備 | CLAUDE.md の新規作成・見直し・繰り返しミス発生時 | CLAUDE.md という特定ファイルそのもの | `~/.claude/CLAUDE.md` および各プロジェクトの `CLAUDE.md` |
| **Claude Code memory システム** | ユーザー横断・永続化 | 複数セッションに渡る事実を記録すべき時 | セッションを跨ぐユーザー固有の事実・罠・パターン | `~/.claude/projects/<key>/memory/MEMORY.md`（索引） + 個別ファイル |

### 棲み分けの核心

- **capturing-learnings** は「いま取り組んでいるプロジェクトで起きた出来事」を記録する。その記録が価値を持てば、他機構へ昇格する。
- **INTAKE** は「このプラグイン自身のスキルをより良くする提案」を消費する。一般プロジェクトの学びはここへ流さない。
- **USAGE-REVIEW** は「利用実績データを見てポートフォリオ全体を俯瞰する」定期棚卸しであり、個別の気づきの記録ではない。
- **managing-claude-md** は「CLAUDE.md というファイルをどう書くか・直すか」の専門スキルであり、学びの一次記録ではない。
- **memory システム** は「ユーザーレベルの恒久的な事実」を置く場所であり、プロジェクトローカルの一時記録ではない。

---

## 2. 学びのルーティング判断フロー

得た学びを「どこへ流すか」は以下の決定木で判断する。

```
得た学び（気づき・訂正・エラー・機能要望・パターン）
        │
        ├─ Q1: sumik-claude-plugin のスキル本体を改善すべき内容か？
        │       (スキルの記述が不正確・肥大・知見漏れ・参照切れ等)
        │   │
        │   YES → CLAUDE.md 📥 inbox に [PROPOSAL] 形式で捕捉
        │           → open 3件以上で authoring-plugins/IMPROVEMENT-INTAKE が消費
        │
        └─ Q2: あらゆるプロジェクトで再利用できる汎用知識か？
                │
                YES → Q3: 新スキル化の価値があるか？
                │           (Recurrence-Count >= 3 かつ汎用性が高い)
                │       YES → authoring-plugins スキルで新スキル抽出を検討
                │       NO  → .learnings/LEARNINGS.md に記録（昇格候補として管理）
                │
                NO → Q4: 複数セッション・プロジェクトを跨ぐユーザー固有の事実か？
                        │
                        YES → Q5: Codex AGENTS.md 向けのワークフロー/ツール規則か？
                        │       YES → AGENTS.md に追記
                        │       NO  → Claude Code memory
                        │               (~/.claude/projects/<key>/memory/)
                        │
                        NO → Q6: そのプロジェクト固有の規約・落とし穴か？
                                │
                                YES → そのプロジェクトの CLAUDE.md に追記
                                │       (managing-claude-md スキルを参照)
                                │
                                NO → .learnings/ に留置
                                        (一過性・プロジェクトローカル)
```

### ルーティングの実例

| 学びの内容 | 正しいルーティング先 |
|-----------|-------------------|
| `git commit -m` に全角記号を含めると不発になる（このプロジェクト固有の罠）| このプロジェクトの `CLAUDE.md` |
| あるスキルの description が不正確だと気づいた | `~/.claude/CLAUDE.md` の 📥 inbox（INTAKE 経由で修正） |
| TypeScript で `any` を使わない実装パターンを新たに習得 | 汎用性が高ければ新スキル抽出、低ければ `.learnings/LEARNINGS.md` |
| 本番環境で特定の npm パッケージが失敗するエラー | `.learnings/ERRORS.md` |
| ユーザーが「〜もできる?」と機能を要望した | `.learnings/FEATURE_REQUESTS.md` |
| セッションを跨いで繰り返し忘れる環境の罠 | Claude Code memory |
| Codex でのツール利用パターンの最適化 | `AGENTS.md` |

---

## 3. 重複させない原則

### 本スキルと INTAKE の混同を防ぐ

最も混同しやすい2機構を明確に分ける。

| 観点 | capturing-learnings（本スキル） | CLAUDE.md inbox → INTAKE |
|------|--------------------------------|--------------------------|
| **対象** | あらゆるプロジェクトの作業で生じた学び | このプラグイン（sumik-claude-plugin）のスキル本体の改善 |
| **誰が記録するか** | hook が自動検出 or 開発者が手動記録 | Claude Code 本体が捕捉ルールに従って記録 |
| **記録場所** | `.learnings/{LEARNINGS,ERRORS,FEATURE_REQUESTS}.md` | `~/.claude/CLAUDE.md` の 📥 セクション |
| **消費タイミング** | プロジェクト節目のレビュー or 昇格判断時 | open 3件以上 or 「スキル改善まわして」指示時 |
| **記録フォーマット** | `[LRN/ERR/FEAT-YYYYMMDD-XXX]` エントリ | `[PROPOSAL] <skill> / <種別> / <日付>` エントリ |

**判断に迷った時の一問**: 「このプラグインの特定のスキルファイルを編集することで解決するか？」→ YES なら INTAKE、NO なら `.learnings/`。

### capturing-learnings と memory の混同を防ぐ

| 観点 | capturing-learnings | Claude Code memory |
|------|--------------------|--------------------|
| **ライフサイクル** | プロジェクト単位・一時保存（昇格まで） | ユーザー恒久・複数セッション継続 |
| **プロジェクト跨ぎ** | しない（プロジェクトローカル） | する（ユーザー全プロジェクト共通） |
| **書式制約** | エントリ形式（IDあり・ステータス管理あり） | 1ファイル1事実 + frontmatter + MEMORY.md 索引 |
| **昇格方向** | memory や CLAUDE.md へ昇格できる | 最終置き場（更に上位はない） |

---

## 4. マルチエージェント対応

### Claude Code（メイン）

hook が自動統合されているため、開発者は意識せずに使い始められる。

- **learnings-reminder.sh** (UserPromptSubmit): タスク後に記録リマインダーを表示
- **learnings-error-detector.sh** (PostToolUse/Bash): bash エラーを自動検出して記録促進

Claude Code 環境では hook が常時登録済みのため、プロジェクトで `.learnings/` ディレクトリを作成するだけで機能する。詳細設定は `references/HOOKS-SETUP.md` を参照。

### Codex（オプトイン）

Codex の hook は experimental 機能（`codex_hooks=true` 環境変数が必要）のため、デフォルトでは無効。

**有効化方法（Codex）:**
1. `codex_hooks=true` を環境変数に設定
2. `.codex/hooks.json` を作成（`HOOKS-SETUP.md` の Codex 設定セクション参照）
3. または `AGENTS.md` に手動トリガーのガイドを記述（後述）

**AGENTS.md によるフォールバック:**
hook を有効化しない場合、`AGENTS.md` に以下を追記することで手動運用できる。

```markdown
## 学びのキャプチャ

作業中に以下が発生したら `.learnings/` に記録する:
- コマンドがエラーで失敗した → `.learnings/ERRORS.md` に [ERR-YYYYMMDD-XXX] 形式で
- ユーザーが訂正した → `.learnings/LEARNINGS.md` に [LRN-YYYYMMDD-XXX] 形式で
- 新機能要望があった → `.learnings/FEATURE_REQUESTS.md` に [FEAT-YYYYMMDD-XXX] 形式で
```

### 汎用 agent-agnostic 運用

Claude Code / Codex のどちらでもない環境（GitHub Copilot・外部エージェント等）では hook に依存しない手動運用となる。`INSTRUCTIONS.md` 第9章の「検出トリガー」（日本語フレーズ一覧）を参照し、対話中に検出したら即記録する。

---

## 5. 昇格フローの詳細

### .learnings/ → プロジェクト CLAUDE.md

**条件**: プロジェクト固有の規約・落とし穴・ツール設定の罠で、チーム全員（または将来の自分）が知るべき事実。

**手順**:
1. `.learnings/LEARNINGS.md` の対象エントリを確認
2. managing-claude-md スキルを参照して「If X then Y」形式に整形
3. CLAUDE.md の適切な表に追記
4. エントリの `status` を `promoted` に更新

### .learnings/ → Claude Code memory

**条件**: プロジェクトを跨ぐユーザー固有の事実（ツールの罠・環境依存の挙動・繰り返しミス）。

**手順**:
1. `~/.claude/projects/<key>/memory/` に 1ファイル1事実で作成
2. `MEMORY.md` の索引に追記
3. エントリの `status` を `promoted` に更新

### .learnings/ → 新スキル抽出（authoring-plugins）

**条件**: Recurrence-Count >= 3 かつ複数プロジェクトで観測された汎用的なパターン。

**手順**:
1. authoring-plugins スキルをロードして新スキル作成フローを開始
2. 蓄積エントリを素材として活用（固有名は持ち込まない・🔴 絶対ルール遵守）
3. 元エントリの `status` を `promoted_to_skill` に更新

### .learnings/ → CLAUDE.md 📥 inbox（sumik-claude-plugin 自身の改善）

**条件**: 作業中に sumik-claude-plugin のスキル本体に問題（記述不正確・規約違反・肥大等）を発見。

**重要**: これは一般プロジェクトの `.learnings/` に書くのではなく、直接 `~/.claude/CLAUDE.md` の 📥 セクションに [PROPOSAL] 形式で記録する。authoring-plugins の IMPROVEMENT-INTAKE が消費する。

---

## 6. 定期レビューでの活用

プロジェクト節目（スプリント終了・リリース・フェーズ移行時）に `.learnings/` を見直す際の観点:

| 確認項目 | コマンド例 |
|---------|----------|
| 未解決エントリ（pending）の棚卸し | `grep -c "ステータス: pending" .learnings/LEARNINGS.md` |
| 反復パターンの検出（Recurrence-Count） | `grep "Recurrence-Count:" .learnings/LEARNINGS.md \| sort -t: -k2 -rn \| head -10` |
| 昇格候補の抽出（high/critical） | `grep -A3 "優先度: high\|優先度: critical" .learnings/LEARNINGS.md` |
| 昇格済みエントリの整理（promoted） | `grep -c "ステータス: promoted" .learnings/LEARNINGS.md` |

昇格候補が見つかったら「2. 学びのルーティング判断フロー」の決定木を参照して適切な機構へ流す。
