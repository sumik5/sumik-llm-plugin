# Writing Conventional Commits

## 基本フォーマット

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## type一覧

| type | 用途 | SemVer |
|------|------|--------|
| `feat` | 新機能追加 | MINOR |
| `fix` | バグ修正 | PATCH |
| `docs` | ドキュメントのみ変更 | - |
| `style` | コードの意味に影響しない変更（空白・フォーマット・セミコロン等） | - |
| `refactor` | バグ修正でも機能追加でもないコード変更 | - |
| `perf` | パフォーマンス改善 | PATCH |
| `test` | テストの追加・修正 | - |
| `build` | ビルドシステム・外部依存関係の変更 | - |
| `ci` | CI設定ファイル・スクリプトの変更 | - |
| `chore` | その他（ビルドプロセス補助・ライブラリ管理等） | - |

## BREAKING CHANGE（SemVer MAJOR）

3つの表記方法:

| 方法 | 例 |
|------|-----|
| フッター | `BREAKING CHANGE: <説明>` |
| 記号 | `feat!: <description>` または `feat(scope)!: <description>` |
| 併用 | `feat!:` + `BREAKING CHANGE:` フッター |

## scopeのルール

- 括弧で囲まれた名詞: `feat(auth): ...`
- プロジェクト固有の命名規則に従う

## bodyとfooterのルール

| 要素 | ルール |
|------|--------|
| body | タイトルから1行空行後に開始、自由形式 |
| footer | bodyから1行空行後、`token: value` または `token #value` 形式 |
| footerトークン | 空白の代わりに `-` を使用（`BREAKING CHANGE` は例外） |

## 良い例・悪い例

```
# 良い例（シンプル）
feat(auth): add JWT token validation

# 良い例（BREAKING CHANGE付き）
feat(api)!: change response format from XML to JSON

BREAKING CHANGE: response format changed from XML to JSON

# 良い例（body + footer付き）
fix(parser): handle edge case in date parsing

The parser previously failed when encountering dates before 1970.
This fix adds proper handling for pre-epoch timestamps.

Reviewed-by: Z
Refs: #123

# 悪い例（typeなし）
added new feature

# 悪い例（過去形。descriptionは命令形で）
feat: added new validation
```

## SemVerとの連携

| コミット | SemVer影響 |
|---------|-----------|
| `fix:` | PATCH |
| `feat:` | MINOR |
| `BREAKING CHANGE` / `!` | MAJOR |
| 上記以外のtype | SemVerに直接影響しない |

詳細は `applying-semantic-versioning` を参照。

## このプロジェクトでの運用

| コマンド | 説明 |
|---------|------|
| `gcauto -y` | AI生成メッセージによるコミット（Conventional Commits準拠・非対話式） |
| `jj describe -m "type(scope): description"` | 手動でメッセージ設定 |
| `jj commit -m "type(scope): description"` | メッセージ設定と新規change作成 |

## Related Skills

- `applying-semantic-versioning`（SemVer仕様とバージョン判断: `fix:` → PATCH, `feat:` → MINOR, `BREAKING CHANGE` → MAJOR）
