# EXAMPLES.md — capturing-learnings エントリ記入例

このファイルは `.learnings/` 配下の各ファイルへの記入例を示す。
実際の運用では日付・IDを実値に置き換えること。

---

## 1. 学びエントリ（.learnings/LEARNINGS.md）

### 例1: correction（訂正）

```markdown
## [LRN-YYYYMMDD-001] correction

**記録日時**: YYYY-MM-DDTHH:MM:SS+09:00
**優先度**: high
**ステータス**: pending
**領域**: infra

### 要約
Docker Compose v2 では `docker-compose` コマンドが廃止され `docker compose`（スペース区切り）が正しい。

### 詳細
CI スクリプト内で `docker-compose up -d` を使用していたところ、ユーザーから
「それは v1 の書き方で今は動かない環境がある」と指摘を受けた。
Docker Engine 23.0 以降では Compose プラグインが標準統合されており、
旧 `docker-compose` バイナリは別途インストールが必要。
スクリプトを `docker compose` に修正することで CI/CD 環境での互換性が担保される。

### 推奨アクション
- `scripts/ci/build.sh` 内の `docker-compose` を `docker compose` に一括置換する
- README の前提条件に「Docker Engine 23.0 以上」を追記する
- 他スクリプトを `grep -r "docker-compose" .` で検索し同様箇所を修正する

### メタデータ
- 発生源: user_feedback
- 関連ファイル: scripts/ci/build.sh, docs/SETUP.md
- タグ: docker, ci, deprecation
- 関連(See Also): ERR-YYYYMMDD-001
- Pattern-Key: docker-compose-v1-usage
- Recurrence-Count: 1 / First-Seen: YYYY-MM-DD / Last-Seen: YYYY-MM-DD
```

---

### 例2: best_practice（より良い方法）

```markdown
## [LRN-YYYYMMDD-002] best_practice

**記録日時**: YYYY-MM-DDTHH:MM:SS+09:00
**優先度**: medium
**ステータス**: pending
**領域**: backend

### 要約
型安全な環境変数アクセスは起動時に一括バリデーションするパターンが最善。

### 詳細
環境変数を `process.env.FOO` で直接アクセスしていたため、
設定漏れが実行時エラーとして発覚していた（デプロイ後に発覚するケースが複数あった）。
アプリケーション起動時に zod 等のスキーマバリデーションで全環境変数を検証し、
欠落時はプロセスを即終了させるパターンに切り替えることで、
「どの環境変数が必要か」が明示されデプロイ前に問題が発見できるようになった。

### 推奨アクション
- `src/config/env.ts` に zod スキーマを作成し起動時バリデーションを実装する
- 環境変数アクセスを `process.env.*` 直接参照から config モジュール経由に統一する
- `.env.example` を自動生成するスクリプトを追加する

### メタデータ
- 発生源: conversation
- 関連ファイル: src/config/env.ts, .env.example
- タグ: typescript, configuration, validation, best-practice
- 関連(See Also):
- Pattern-Key: env-var-runtime-access
- Recurrence-Count: 2 / First-Seen: YYYY-MM-DD / Last-Seen: YYYY-MM-DD
```

---

## 2. エラーエントリ（.learnings/ERRORS.md）

### 例: npm スクリプト実行時の ENOENT エラー

```markdown
## [ERR-YYYYMMDD-001] build-script

**記録日時**: YYYY-MM-DDTHH:MM:SS+09:00
**優先度**: high
**ステータス**: pending
**領域**: config

### 要約
`npm run build` が ENOENT で失敗。`node_modules/.bin/tsc` が存在しない状態だった。

### エラー
```
> my-project@1.0.0 build
> tsc --project tsconfig.build.json

sh: tsc: command not found
npm ERR! code 1
npm ERR! path /Users/dev/my-project
npm ERR! command failed
npm ERR! errno 1
```

### 状況
- 試行コマンド: `npm run build`
- 入力: 新規クローン後に `npm install` をスキップして即 `npm run build` を実行
- 環境: macOS 14, Node.js 20.x, npm 10.x
- `node_modules/` が存在しなかった

### 推奨修正
- `npm install` 後に `npm run build` を実行する
- README の「Getting Started」に `npm install` ステップを明記する
- CI スクリプトで `npm install` → `npm run build` の順序を強制する

### メタデータ
- 再現可否: yes
- 関連ファイル: package.json, tsconfig.build.json
- 関連(See Also): LRN-YYYYMMDD-001
```

---

## 3. 機能要望エントリ（.learnings/FEATURE_REQUESTS.md）

### 例: ドライランモードの追加要望

```markdown
## [FEAT-YYYYMMDD-001] dry-run-mode

**記録日時**: YYYY-MM-DDTHH:MM:SS+09:00
**優先度**: medium
**ステータス**: pending
**領域**: config

### 要望された機能
マイグレーションスクリプトに `--dry-run` フラグを追加し、
実際にDBを変更せずに適用予定の変更内容だけを確認できるようにする。

### ユーザー状況（なぜ必要か）
本番環境へのマイグレーション適用前に変更内容を安全にレビューしたい。
現状は開発環境で試してから本番適用しているが、
環境差異でサプライズが起きることがある。
ドライランがあれば本番接続したまま影響範囲を事前確認できる。

### 複雑度見積
medium

### 想定実装
- `scripts/migrate.ts` に `--dry-run` 引数を追加
- `--dry-run` 時は SQL を実行せず `console.log` で出力のみ行う
- 既存の Prisma `$executeRaw` 呼び出しを `dryRun ? log(sql) : execute(sql)` に置き換える

### メタデータ
- 頻度: recurring
- 関連機能: マイグレーションスクリプト（scripts/migrate.ts）
```

---

## 4. 解決時のステータス更新例

pending 状態のエントリが解決したとき、以下のフィールドと `### 解決` ブロックを追記する。

```markdown
## [LRN-YYYYMMDD-001] correction

**記録日時**: YYYY-MM-DDTHH:MM:SS+09:00
**優先度**: high
**ステータス**: resolved   ← pending → resolved に変更
**領域**: infra

### 要約
Docker Compose v2 では `docker-compose` コマンドが廃止され `docker compose`（スペース区切り）が正しい。

（... 以下、元の詳細・推奨アクション・メタデータは据え置き ...）

### 解決
- **解決日時**: YYYY-MM-DDTHH:MM:SS+09:00
- **Commit/PR**: feat(ci): migrate docker-compose to docker compose plugin (abc1234)
- **メモ**: `scripts/ci/build.sh` と `docs/SETUP.md` を更新。`grep -r "docker-compose" .` で残存箇所ゼロを確認。
```

> **ポイント**: `**ステータス**: resolved` に書き換えるだけでなく `### 解決` ブロックを末尾に**追記**する。
> 元の詳細は残し変更履歴として読めるようにする（削除しない）。

---

## 5. 昇格の前後例

### 昇格例1: エラーログ → CLAUDE.md 予防ルール

**昇格前（.learnings/ERRORS.md の長い記録）**

```markdown
## [ERR-YYYYMMDD-002] git-push

**ステータス**: promoted
...
### エラー
```
error: failed to push some refs to 'origin/main'
hint: Updates were rejected because the remote contains work that you do not have locally.
```
### 状況
サンドボックス下で `git commit && git push` を実行したところ exit=0 が返ったが
実際には push が不発だった。その後 `git log` で確認すると remote に届いていなかった。

### 推奨修正
git 書込操作の exit コードを鵜呑みにせず `git ls-remote` で実検証する。
```

**昇格後（CLAUDE.md に追記する短い予防ルール）**

```markdown
| git push 後 exit=0 を見た時 | `git ls-remote origin refs/heads/main` で実リモートコミットを検証する（サンドボックス下は偽 exit=0 を返すことがある） |
```

> **ポイント**: 長い再現手順・エラーログは `.learnings/` に残し、
> CLAUDE.md には「コーディング前に何をすべきか」だけを If-Then 形式で昇格する。

---

### 昇格例2: 反復 best_practice → AGENTS.md ワークフロールール

**昇格前（.learnings/LEARNINGS.md の記録・Recurrence-Count: 4）**

```markdown
## [LRN-YYYYMMDD-003] best_practice

**ステータス**: promoted_to_skill 以前に promoted
**Recurrence-Count**: 4 / First-Seen: YYYY-MM-DD / Last-Seen: YYYY-MM-DD
...
### 要約
テストを後回しにするとリグレッションの修正コストが3倍になる。
実装完了直後にユニットテストを書く習慣が長期的なベロシティを高める。
```

**昇格後（AGENTS.md に追記するワークフロールール）**

```markdown
## 実装後の自動アクション

機能実装が完了したら、次の順序でアクションを実行する:
1. ユニットテストを作成し `npm test` でグリーンを確認する
2. `npm run lint` でリントエラーがないことを確認する
3. 完了報告に「テスト追加: <ファイル名>」を明記する
```

---

## 6. 反復パターンの See Also 連結と Recurrence-Count 増加例

同じ根本原因を持つ複数のエントリを連結し、反復回数をカウントアップする。

**初回発生（LRN-YYYYMMDD-010）**

```markdown
## [LRN-YYYYMMDD-010] knowledge_gap

**ステータス**: resolved
**Recurrence-Count**: 1 / First-Seen: YYYY-MM-DD / Last-Seen: YYYY-MM-DD

### 要約
zsh では `for f in $FILES` がファイルリストを単一引数として展開してしまう（IFS 分割なし）。

### メタデータ
- Pattern-Key: zsh-word-splitting
```

**2回目発生（LRN-YYYYMMDD-025）— 前のエントリも更新する**

```markdown
## [LRN-YYYYMMDD-025] correction

**ステータス**: pending
**Recurrence-Count**: 2 / First-Seen: YYYY-MM-DD / Last-Seen: YYYY-MM-DD

### 要約
bash スクリプトをzshで実行したとき `for f in $LIST` が全要素を1つの変数に詰めた。

### メタデータ
- Pattern-Key: zsh-word-splitting
- 関連(See Also): LRN-YYYYMMDD-010   ← 初回エントリを参照
```

**LRN-YYYYMMDD-010 の Recurrence-Count も更新する（追記）**

```markdown
<!-- 2回目発生時に更新 -->
- Recurrence-Count: 2 / First-Seen: YYYY-MM-DD / Last-Seen: YYYY-MM-DD（更新）
- 関連(See Also): LRN-YYYYMMDD-025   ← 追記
```

> Recurrence-Count が3以上・2つ以上の異なるタスク・30日以内の窓を満たしたら
> 昇格候補として CLAUDE.md または AGENTS.md へのルール化を検討する
>（昇格ルールの詳細は INSTRUCTIONS.md 第7章を参照）。
