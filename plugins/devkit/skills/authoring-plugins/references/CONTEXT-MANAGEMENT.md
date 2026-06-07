# Context圧迫防止の設計原則

スキル数が増えると、すべてのdescriptionがsystem promptに注入されてcontextを圧迫する。
本ページでは `disable-model-invocation` の正しい使い方と、スキルポートフォリオのサイズ管理戦略を解説する。

---

## `disable-model-invocation` のベストプラクティス

`disable-model-invocation: true` を設定すると、descriptionがcontextから**完全に除外**される（context消費 = ゼロ）。
ただし、設定するとClaudeはスキルの存在自体を認識しなくなり、ユーザーが `/name` で明示呼び出しした時のみ動作する。

### 設定すべき場面

| 条件 | 理由 |
|------|------|
| Agent `skills:` でプリロードされていないスキル | descriptionがcontextに常駐する必要がない |
| ユーザーが `/skill-name` で明示呼び出しするスキル | ユーザーが存在を知っているため、自動検出不要 |
| CLAUDE.mdルールで呼び出しが定義されているスキル | ルール経由で確実にロードされるため自動検出は冗長 |
| ニッチ・低頻度のスキル | contextを常時消費するほどの使用頻度がない |

### 設定すべきでない場面

| 条件 | 理由 |
|------|------|
| Agent定義の `skills:` でプリロードされるスキル | プログラム的呼び出しもブロックされる可能性がある |
| 「Always Required」カテゴリのスキル | Claudeが自動判断でロードする必要がある |
| REQUIRED/MUST パターンのスキル | descriptionのキーワードでトリガーされるため除外不可 |

### 判断フローチャート

```
新規スキルを作成 or 既存スキルのdisable-model-invocationを見直す
│
├─ Agentの skills: フロントマターで参照されている?
│   └─ Yes → disable-model-invocation: false（デフォルト）
│
├─ descriptionに「REQUIRED」「MUST load when」が含まれる?
│   └─ Yes → disable-model-invocation: false（自動ロード必須）
│
├─ CLAUDE.mdのルールテーブルで呼び出しが定義されている?
│   └─ Yes → disable-model-invocation: true（ルール経由で十分）
│
├─ ユーザーが /name で明示呼び出しするワークフロー型スキル?
│   └─ Yes → disable-model-invocation: true（明示呼び出しのみ）
│
└─ 上記以外（汎用・バックグラウンド知識スキル）
    └─ 頻度・重要度で判断。不明な場合は false（デフォルト）を維持
```

---

## スキル統合の判断基準

### 統合すべき場合

| 条件 | 例 |
|------|----|
| 同じタチコマが両方をプリロードしている | 同一AgentのSKILL.md `skills:` に両方が列挙されている |
| descriptionの「For X, use Y instead」で相互参照しているペア | スキルAが「For B→use skill-b」、スキルBが「For A→use skill-a」と記載している |
| 同一ドメインで「設計」と「実装」が分かれているだけ | `designing-foo` と `implementing-foo` が95%以上の対象ユーザーで一緒に使われる |
| 片方が明らかに他方の上位互換 | skill-bを呼び出すとskill-aも呼び出したくなるケースがほぼ100% |

### 分離を維持すべき場合

| 条件 | 理由 |
|------|------|
| 異なるタチコマが別々にプリロードしている | マージするとどちらかのタチコマに不要な知識が混入する |
| トリガー条件が完全に異なる | 異なるユースケース・対象者を持つスキルは分離が明快 |
| 統合するとINSTRUCTIONS.mdが500行を超える | Progressive Disclosure原則を維持するために分離を保つ |
| 一方がAgent定義に `disable-model-invocation: false`、他方が `true` | 呼び出し制御の設計が根本的に異なる |

### 統合実施手順（チェックリスト）

- [ ] 統合先スキルを選定（より一般的な名前・高頻度利用を優先）
- [ ] 統合元スキルのコンテンツをマージ（Progressive Disclosure原則に従う）
- [ ] `plugin.json` から統合元スキルのエントリを削除
- [ ] `hooks/detect-project-skills.sh` を更新（統合元スキルの参照を置き換え）
- [ ] `README.md` のスキルカウント・テーブルを更新
- [ ] 統合元スキルのディレクトリを削除
- [ ] コミット: `chore(skills): <skill-a>を<skill-b>に統合`

---

## スキル数の管理ガイドライン

### 適切なスキル数の目安

| スキル数 | 状態 | 対応 |
|---------|------|------|
| 〜80 | 最適 | 維持 |
| 81〜100 | 適切 | 新規追加時は重複チェックを徹底 |
| 101〜120 | 要注意 | 統合・廃止候補を積極的にピックアップ |
| 121〜 | 過多 | 四半期レビューで棚卸しを優先実施 |

> **背景**: 107スキルが存在した際、全descriptionのsystem prompt注入がcontextを圧迫する問題が発生。
> 36スキルを14スキルに統合（-22ディレクトリ）し、33スキルに `disable-model-invocation: true` を設定することで解消した（2026-03-16実施）。

### 新スキル追加時のチェック

新規スキルを追加する前に以下を確認する:

1. **重複確認**: `skills/` ディレクトリの全スキルとスコープ比較（[NAMING-STRATEGY.md](NAMING-STRATEGY.md) の§3参照）
2. **統合候補の検討**: 既存スキルへの追記で要件を満たせないか検討
3. **disable-model-invocation の設定**: 本ページの判断フローチャートで設定値を決定
4. **スキル総数の確認**: 上表の目安に照らして追加可否を判断

### 定期的なスキル棚卸し

月次・四半期での棚卸し手順は [USAGE-REVIEW.md](USAGE-REVIEW.md) を参照。
特に `disable-model-invocation: false` のまま長期未使用のスキルは、`true` への変更か廃止を検討する。
