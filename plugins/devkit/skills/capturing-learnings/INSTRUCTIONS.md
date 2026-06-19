# capturing-learnings — 作業中の学びを構造化記録するスキル

## 1. 概要と位置づけ

このスキルは**汎用の受動的学習キャプチャ層**として機能する。あらゆるプロジェクトで作業中に生じた学び・エラー・ユーザー訂正・機能要望を `.learnings/` ディレクトリに構造化記録し、反復パターンを検出してプロジェクトメモリや新スキルへ昇格させることで継続的改善を実現する。

### 自己改善機構との棲み分け

| 機構 | 役割 |
|------|------|
| **capturing-learnings**（本スキル） | 汎用・受動キャプチャ。`.learnings/` に蓄積し昇格を判断 |
| **authoring-plugins / IMPROVEMENT-INTAKE** | sumik-claude-plugin 自身のスキル改善提案（`[PROPOSAL]` 形式） |
| **managing-claude-md** | CLAUDE.md の整備・If X then Y ルール追記 |
| **Claude Code memory** | ユーザー横断・複数セッションにわたる事実の永続化 |

詳細な棲み分けと昇格ルーティングは [INTEGRATION.md](references/INTEGRATION.md) を参照。

---

## 2. セットアップ

プロジェクトルートに `.learnings/` ディレクトリを作成し、テンプレートをコピーする。

```bash
mkdir -p .learnings
# 空ヘッダーテンプレートをスキルの assets/ からコピー
cp <skill_assets>/LEARNINGS.md     .learnings/LEARNINGS.md
cp <skill_assets>/ERRORS.md        .learnings/ERRORS.md
cp <skill_assets>/FEATURE_REQUESTS.md .learnings/FEATURE_REQUESTS.md
```

`<skill_assets>` は本スキルの `assets/` ディレクトリを指す。

---

## 3. ログ記録フォーマット

### 学びエントリ（`.learnings/LEARNINGS.md` に追記）

```markdown
## [LRN-YYYYMMDD-XXX] <category>

**記録日時**: <ISO-8601>
**優先度**: low | medium | high | critical
**ステータス**: pending
**領域**: frontend | backend | infra | tests | docs | config

### 要約
1行で何を学んだか

### 詳細
何が起きたか・何が誤りで何が正しいか（フルコンテキスト）

### 推奨アクション
具体的な修正・改善（「調査する」ではなく実行可能な内容）

### メタデータ
- 発生源: conversation | error | user_feedback
- 関連ファイル: path/to/file.ext
- タグ: tag1, tag2
- 関連(See Also): LRN-YYYYMMDD-001
- Pattern-Key: <任意・反復追跡キー>
- Recurrence-Count: 1 / First-Seen: YYYY-MM-DD / Last-Seen: YYYY-MM-DD（任意）
```

`category` は `correction`（訂正）/ `knowledge_gap`（知識ギャップ）/ `best_practice`（より良い方法）のいずれか。

### エラーエントリ（`.learnings/ERRORS.md` に追記）

```markdown
## [ERR-YYYYMMDD-XXX] <skill_or_command_name>

**記録日時**: <ISO-8601>
**優先度**: low | medium | high | critical
**ステータス**: pending
**領域**: frontend | backend | infra | tests | docs | config

### 要約
1行でエラーの概要

### エラー
```
実際のエラーメッセージをそのまま記載
```

### 状況
試行したコマンド・入力・環境（OS/バージョン等）

### 推奨修正
具体的な回避策・根本解決手順

### メタデータ
- 再現可否: yes | no | unknown
- 関連ファイル: path/to/file.ext
- 関連(See Also): ERR-YYYYMMDD-001
```

### 機能要望エントリ（`.learnings/FEATURE_REQUESTS.md` に追記）

```markdown
## [FEAT-YYYYMMDD-XXX] <capability_name>

**記録日時**: <ISO-8601>
**ステータス**: pending

### 要望された機能
何ができるようにしたいか

### ユーザー状況
なぜ必要か・どんな文脈で求められたか

### 複雑度見積
simple | medium | complex

### 想定実装
実装アプローチの概要

### メタデータ
- 頻度: first_time | recurring
- 関連機能: 既存コマンド名・スキル名
```

記入例の全パターンは [EXAMPLES.md](references/EXAMPLES.md) を参照。

---

## 4. ID生成規則

| 種別 | フォーマット | 例 |
|------|------------|-----|
| 学び | `LRN-YYYYMMDD-XXX` | `LRN-20260619-001` |
| エラー | `ERR-YYYYMMDD-XXX` | `ERR-20260619-001` |
| 機能要望 | `FEAT-YYYYMMDD-XXX` | `FEAT-20260619-001` |

`XXX` は当日の連番（001 から開始）。日付は記録した日のローカル日付（ISO-8601 形式・例: `2026-06-19T14:30:00+09:00`）。

---

## 5. エントリの解決とステータス遷移

```
pending → in_progress → resolved
                      → wont_fix
                      → promoted        （CLAUDE.md / memory / AGENTS.md へ昇格）
                      → promoted_to_skill（新スキルとして抽出）
```

- **resolved**: 推奨アクションを実施し問題が解消した
- **wont_fix**: 対応コストに見合わないと判断した（理由をコメントで記録する）
- **promoted**: プロジェクトメモリ・CLAUDE.md などへ昇格した（昇格先 URL/パスを記録）
- **promoted_to_skill**: 新スキルとして authoring-plugins 経由で抽出した

---

## 6. プロジェクトメモリへの昇格

### 昇格先の選択基準

| 昇格先 | 何を置くか |
|--------|-----------|
| プロジェクト CLAUDE.md | そのプロジェクト固有の事実・規約・落とし穴（全員が知るべき） |
| Claude Code memory（`~/.claude/projects/<key>/memory/`） | ユーザー横断・複数セッションにわたる事実。memory 規約に従う |
| AGENTS.md | Codex 向けのワークフロー・ツール利用パターン・自動化ルール |
| CLAUDE.md inbox / IMPROVEMENT-INTAKE | sumik-claude-plugin 自身のスキル改善は `.learnings/` ではなくここへ |
| 新スキル（authoring-plugins） | 再利用価値が高く汎用的な学びは新スキル化を検討 |

### 昇格の実施

昇格時は元エントリの `ステータス` を `promoted` または `promoted_to_skill` に更新し、昇格先のパスまたはスキル名を記録する。

---

## 7. 反復パターン検出

### 昇格ルール

次の **3条件をすべて満たす** 反復学びはプロジェクトメモリ / CLAUDE.md へ昇格する:

1. `Recurrence-Count >= 3`
2. 2つ以上の異なるタスクで観測された
3. 30日以内の窓で発生した

### 昇格文の書き方

昇格文は「コーディング前/中に何をすべきか」の短い予防ルールとして書く（長い事後検証録にしない）。

### 関連エントリの紐付け

同じ根本原因を持つエントリには `Pattern-Key` に同じキーを付与し、`See Also` で相互参照する。`Recurrence-Count` を更新するたびに `Last-Seen` も更新する。

---

## 8. 定期レビュー

節目（スプリント終了・大型リリース前・週次）に `.learnings/` を見直す。

```bash
# pending 件数を確認
grep -c "ステータス\|Status.*pending" .learnings/LEARNINGS.md .learnings/ERRORS.md .learnings/FEATURE_REQUESTS.md

# 高優先度の未解決エントリを一覧
grep -n "優先度.*critical\|優先度.*high" .learnings/LEARNINGS.md | grep -A2 "pending"

# 昇格候補を探す（Recurrence-Count >= 3）
grep -n "Recurrence-Count: [3-9]\|Recurrence-Count: [0-9][0-9]" .learnings/LEARNINGS.md
```

---

## 9. 検出トリガー

以下のシグナルを検出したら、対応するエントリを `.learnings/` に記録する。

| シグナル | エントリ種別 | 検出フレーズ例 |
|---------|------------|--------------|
| ユーザー訂正 | `LRN correction` | 「いや、それは違う」「正しくは…」「〜は間違い」「それは古い情報」 |
| 機能要望 | `FEAT` | 「〜もできる?」「〜できたらいいのに」「〜する方法ある?」「なぜ〜できない?」 |
| 知識ギャップ | `LRN knowledge_gap` | ユーザーが知らなかった情報を提供 / 参照ドキュメントが古い / API 挙動が理解と異なる |
| エラー発生 | `ERR` | 非ゼロ終了コード / 例外・スタックトレース / 想定外出力 / タイムアウト・接続失敗 |

---

## 10. 優先度ガイドライン・領域タグ

### 優先度

| レベル | 基準 |
|--------|------|
| `critical` | 中核機能ブロック / データ損失 / セキュリティリスク |
| `high` | 影響範囲が広い・同じミスが反復している |
| `medium` | 回避策はあるが改善が望ましい |
| `low` | 軽微・エッジケース |

### 領域タグ

`frontend` / `backend` / `infra` / `tests` / `docs` / `config`

---

## 11. ベストプラクティス

- **即記録**: 気づいた直後に記録する。後回しにすると文脈が失われる
- **具体性**: 「調査する」ではなく「コマンド X を Y オプションで実行する」のように実行可能な推奨アクションを書く
- **再現手順**: エラーエントリには必ず試行コマンドと環境を記録する
- **関連付け**: 既存エントリと根本原因が同じ場合は `See Also` と `Pattern-Key` で繋げる
- **積極昇格**: 同じ学びを 3 回以上繰り返したら迷わず昇格する

---

## 12. hook 統合

devkit プラグインには 2 つの hook が常時登録されている。

| hook | イベント | 機能 |
|------|---------|------|
| `learnings-reminder.sh` | UserPromptSubmit | タスク後に `.learnings/` への記録を促す日本語リマインダーを出力 |
| `learnings-error-detector.sh` | PostToolUse（Bash） | コマンド失敗・例外を検出し `ERRORS.md` への記録を促す |

Codex での hook 利用（`codex_hooks=true` / `.codex/hooks.json`）は experimental のため opt-in。詳細な設定手順・トラブルシュートは [HOOKS-SETUP.md](references/HOOKS-SETUP.md) を参照。

---

## 13. スキル抽出

反復パターンが高い汎用性を持ち、他プロジェクトでも再利用できると判断した場合は新スキルとして抽出を検討する。

抽出基準の目安:
- 3 つ以上の異なるプロジェクトで同じパターンが出現した
- スキルとして言語化できる汎用的なワークフローが存在する
- 既存スキルでカバーされていない

スキルの実際の作成は **authoring-plugins** スキルに委譲する。本スキルでは抽出候補の識別のみを行い、`ステータス` を `promoted_to_skill` に更新して authoring-plugins へ引き継ぐ。

---

## 14. マルチエージェント対応

| 環境 | hook 動作 | `.learnings/` 書き込み |
|------|----------|----------------------|
| Claude Code | 常時有効（devkit 登録済） | Read/Write ツールで直接編集可 |
| Codex CLI | opt-in（experimental） | `codex_hooks=true` が必要 |

Claude Code と Codex で同一スクリプト（stdin JSON / `additionalContext` 形式）が動作する設計のため、`.learnings/` の書式は両環境で共通。詳細は [INTEGRATION.md](references/INTEGRATION.md) と [HOOKS-SETUP.md](references/HOOKS-SETUP.md) を参照。

---

## 15. gitignore 方針

`.learnings/` の追跡方法は 3 案から選択する:

| 方針 | `.gitignore` 設定 | 用途 |
|------|-----------------|------|
| **ローカル限定** | `.learnings/` を追加 | 個人作業・プライベートな試行錯誤 |
| **チーム共有** | 追加しない（デフォルト追跡） | チームで学びを共有したい場合 |
| **ハイブリッド** | `.learnings/private/` のみ除外 | 公開可能エントリは共有・個人メモは除外 |

推奨: プロジェクトの性質に合わせて選択する。プライベートリポジトリではチーム共有が有効。パブリックリポジトリではローカル限定またはハイブリッドを推奨。
