# データ駆動とコードレイアウト（DATA-DRIVEN-AND-CODE-LAYOUT）

「変わるものをデータに、変わらないものをコードに」という分離がコードを簡潔にする。さらに、コードの物理的な配置（レイアウト）を整えることで、エラーの発見・変更の容易さ・読みやすさが向上する。本リファレンスはその実践を集める。

---

## 1. データ駆動の簡素化

### 1.1 what（データ）と how（コード）の分離

反復しているコードを発見したとき、「変わる部分（what）」と「変わらない部分（how）」を明確に分ける。変わる部分をデータ構造に抽出し、変わらない部分を単一の関数に集約する。

**Before: 変わる部分と変わらない部分が混在している**

```python
# 擬似コード
register_handler("GET",  "/users",        UsersListHandler)
register_handler("POST", "/users",        UsersCreateHandler)
register_handler("GET",  "/users/:id",    UsersShowHandler)
register_handler("PUT",  "/users/:id",    UsersUpdateHandler)
register_handler("DELETE","/users/:id",   UsersDeleteHandler)
```

**After: データ（ルートテーブル）＋単一の登録ループ**

```python
# 擬似コード
ROUTES = [
  ("GET",    "/users",      UsersListHandler),
  ("POST",   "/users",      UsersCreateHandler),
  ("GET",    "/users/:id",  UsersShowHandler),
  ("PUT",    "/users/:id",  UsersUpdateHandler),
  ("DELETE", "/users/:id",  UsersDeleteHandler),
]

for method, path, handler in ROUTES:
    register_handler(method, path, handler)
```

新しいルートの追加は「テーブルに1行追加するだけ」になる。コードを変えずに振る舞いが変えられる。

### 1.2 ネストのフラット化

条件のネストが深くなるパターンを、ステップのシーケンスをデータで表現することでフラットにできる。

**Before: 深いネスト（各ステップが成功した場合のみ次へ進む）**

```python
# 擬似コード
result = validate(payload)
if result.ok:
    result = transform(result.value)
    if result.ok:
        result = persist(result.value)
        if result.ok:
            notify(result.value)
```

**After: パイプラインをデータで表現**

```python
# 擬似コード
PIPELINE = [validate, transform, persist, notify]

current = payload
for step in PIPELINE:
    result = step(current)
    if not result.ok:
        break
    current = result.value
```

ステップの追加・削除・並び替えが「リストの編集」だけで完結する。

### 1.3 データ駆動コードは小さなインタプリタ

「データが what を表現し、コードが how を実行する」構造は、本質的にインタプリタと同じである。インタプリタというと複雑な言語処理系を想像しがちだが、テーブルを走査してアクションを呼び出すだけの小さな構造でも「インタプリタ」と言える。

この設計の利点：
- データを外部から渡せる（設定ファイル・API・ユーザー入力）
- 同じデータを別の文脈で再利用できる
- データの単位でテストできる

### 1.4 外部・動的データの活用

データはソースコード内のリテラルでなくてもよい。外部ファイル（YAML / JSON / TOML）・データベース・API レスポンス・ユーザー入力もデータ駆動の源泉になる。

> 反復しているコードを見つけたとき、まず「このコードの "変わる部分" はどこか」を特定し、それをデータ構造に抽出できないか検討する。

---

## 2. テーブル駆動テスト

同じ形式のテストが複数存在するとき、テストロジックを1つの関数に集め、入力と期待値をテーブルとして渡す。

### 2.1 基本パターン

**Before: 同形式のテストを個別に記述**

```python
# 擬似コード
def test_status_200():
    assert classify_status(200) == "success"

def test_status_404():
    assert classify_status(404) == "not_found"

def test_status_500():
    assert classify_status(500) == "server_error"
```

**After: テーブル駆動**

```python
# 擬似コード
STATUS_CASES = [
    (200, "success"),
    (201, "created"),
    (301, "redirect"),
    (400, "bad_request"),
    (404, "not_found"),
    (500, "server_error"),
]

for code, expected in STATUS_CASES:
    result = classify_status(code)
    assert result == expected, f"code={code}: expected {expected}, got {result}"
```

新しいケースの追加はテーブルへの1行追加。失敗時は「どの入力で失敗したか」をエラーメッセージに含める。

### 2.2 多段階テストをテーブルで

状態変化を伴うテスト（ある操作の後、次の操作の結果が変わる）も、ステップごとの入力・期待値をテーブル構造で表現できる。

```python
# 擬似コード（注文状態遷移のテスト例）
ORDER_STEPS = [
    ("step1_create",  {"event": "created"},  {"status": "pending"}),
    ("step2_pay",     {"event": "paid"},     {"status": "confirmed"}),
    ("step3_ship",    {"event": "shipped"},  {"status": "in_transit"}),
    ("step4_deliver", {"event": "delivered"},{"status": "completed"}),
]

state = initial_state()
for name, event, expected in ORDER_STEPS:
    state = apply_event(state, event)
    assert state == expected, f"At {name}: {state} != {expected}"
```

テストの「形式」と「データ」が分離されているため、新しいシナリオを追加するときにコードを書かずに済む。

> **テスト設計全般（TDD・AAAパターン・テストピラミッド）については、`testing-code` を参照。**

---

## 3. ステートマシン

イベントのシーケンスを処理するとき、「どのイベントが来たとき、現在の状態に応じて、どの状態に遷移するか」をテーブルで表現するのがステートマシンである。複雑なネスト条件を線形な構造に置き換えられる。

### 3.1 いつステートマシンを使うか

- イベントが時間をまたいで発生し、前のイベントが次のイベントの処理に影響する
- 同じイベントでも「現在の状態」によって対応が異なる
- ネストした if/switch が深くなってきた

### 3.2 実装: ライブラリ不要・テーブル1枚

ステートマシンに専用のライブラリやデザインパターンは不要。ネストした辞書（または2次元テーブル）で遷移表を定義し、ループで1行のコードにできる。

```python
# 擬似コード（注文ステータスのステートマシン）
TRANSITIONS = {
    "pending": {
        "pay":    "confirmed",
        "cancel": "cancelled",
    },
    "confirmed": {
        "ship":   "in_transit",
        "cancel": "cancelled",
    },
    "in_transit": {
        "deliver": "completed",
    },
    "completed": {},
    "cancelled":  {},
}

state = "pending"

def process_event(event):
    global state
    next_state = TRANSITIONS.get(state, {}).get(event)
    if next_state:
        state = next_state
    else:
        raise ValueError(f"Invalid event '{event}' in state '{state}'")
```

状態を追加・削除・リネームするとき、変更箇所は**テーブル定義だけ**で済む。

### 3.3 ステートマシンの構成要素

| 要素 | 説明 |
|------|------|
| **状態（State）** | 現在の文脈を表す値 |
| **イベント（Event）** | 状態を変化させるトリガー |
| **遷移（Transition）** | 「状態 × イベント → 次の状態」のマッピング |
| **アクション（任意）** | 遷移時に実行する副作用（ログ・通知・外部 API 等） |

遷移にアクションを紐づける場合も、テーブルの値に関数や文字列を載せるだけで対応できる。長時間実行・状態永続化・ワークフロー制御への応用も同じ原理で拡張できる。

---

## 4. コードレイアウト

### 4.1 コメントの最小化と4つの正当な用途

コメントはコードとは別に維持しなければならない。コードが変わればコメントも変える必要があり、テストされないため古くなっても気づかれにくい。コメントが多いほど変更コストが増す。

**コメントの正当な4用途:**

| 用途 | 説明 | 例 |
|------|------|-----|
| **ドキュメント生成** | ツールが抽出してAPIドキュメントを生成する | JSDoc / rustdoc / pydoc |
| **なぜ（why）の説明** | 予想外の実装を選んだ理由。コードだけでは伝わらない背景 | `# 外部APIが負数を正値として返すため符号反転` |
| **TODO マーカー** | 後で対処が必要な課題を記録する | `# TODO: null ケースの処理を追加` |
| **構造の区切り** | 大きなファイルやセクションの境界を視覚的に強調する | `# ─── 公開API ─────────────` |

コードに「how（どのように動くか）」を説明するコメントがあるとしたら、その説明はコード自体で表現できないか検討する。関数名・変数名・型・構造を整えることで、多くのコメントは不要になる。

### 4.2 TODO の有効活用

作業中に気づいた別の問題を即座に修正しようとすると、現在の文脈を失う。代わりに TODO コメントを置いてから元の作業を続ける。

```python
# 擬似コード
price = base_price + tax   # TODO: 割引クーポン適用ロジックを追加

# ... 現在作業中のコード ...
```

**TODO 運用の指針:**

- エディタのハイライト機能で TODO を常に視認できる状態にしておく
- プロジェクト全体の TODO を一覧表示できる機能を活用する（多くのエディタ・IDE に存在する）
- 積み上がった TODO はスプリントの合間・会議前の5分などで消化する
- 「いつか対処する」が「永遠に対処しない」になるリスクがあるため、重要度の高い TODO はタスクトラッカーに移す

### 4.3 整列でエラーを視覚的に発見する

人間の脳はパターンの逸脱を自動的に検出する。類似した行を縦に揃えると、タイポや欠落がすぐ目に入る。

**整列前（問題が見えにくい）:**

```python
# 擬似コード
server_host = "api.example.com"
port = 8080
connection_timeout = 30
max_retry = 3
auth_token = secret_token
```

**整列後（不一致がパターンの乱れとして浮かぶ）:**

```python
# 擬似コード
server_host        = "api.example.com"
port               = 8080
connection_timeout = 30
max_retry          = 3
auth_token         = secret_token      # ← クォートがないことに気づきやすい
```

**実践のポイント:**
- エディタの整列プラグイン（EasyAlign / Align / 各種 formatter）を活用する
- 名前の長さが極端に異なる行をまとめて揃えると読みにくくなる場合は、長さの似た行をグループに分けて整列する

### 4.4 末尾カンマ（Trailing Comma）

リスト・配列・オブジェクトの最後の要素にもカンマを付ける（言語が許す場合）。

**末尾カンマなし:**

```python
# 擬似コード
ENVIRONMENTS = [
    "development",
    "staging",
    "production"   # ← 末尾要素が特別扱い
]
```

**末尾カンマあり:**

```python
# 擬似コード
ENVIRONMENTS = [
    "development",
    "staging",
    "production",  # ← 全要素が同等
]
```

末尾カンマがあると：

- 要素の並び替え（ソート）が安全（どの要素を末尾に持ってきてもカンマが付いている）
- 新しい要素の追加が「1行追加」だけで済む（追加前の末尾行を変更する必要がない）
- git diff が追加した行だけを示す（カンマ追加の変更が混入しない）

### 4.5 リテラルのソート

順序に意味がないリスト（列挙型・import 文・設定キー等）はソートして並べる。

**メリット:**
- 重複追加に気づきやすい（同じ値が隣接する）
- 特定の値がすでに存在するか確認しやすい
- 差分が読みやすい（変更が位置に依存しない）

エディタが「選択範囲をソート」するコマンドを持っていることを確認し、そのキーバインドを覚えておく。

### 4.6 縦長 > 横長（45〜75文字の行幅）

可読性の研究では、1行あたり45〜75文字が読みやすさの最適範囲とされている。長い行は読む際に折り返しが起き、行の先頭を見失いやすい。

**短い行の利点:**
- フォントサイズを大きくできる（目が疲れにくい）
- 画面を縦に分割して複数ファイルを並べやすい
- コードレビューや diff ツールでの表示が整いやすい

長い式や SQL・メソッドチェーンは、論理的な区切りで折り返す。

```python
# 擬似コード（メソッドチェーンを縦に並べる）
result = (
    query
        .filter(active=True)
        .order_by("created_at")
        .limit(50)
        .execute()
)
```

### 4.7 局所化：単一ファイル先行→安定後に分割

新しいコードを書き始めるとき、まず単一ファイルに全体を収める。構造を試行錯誤しているあいだは、一箇所にあることで移動・リネーム・再構成が速くなる。

**局所化の手順:**

| フェーズ | アプローチ |
|---------|-----------|
| **探索期（初期実装）** | 1ファイルにモジュール・クラス・ヘルパーをすべて収める |
| **安定期（設計が固まった）** | 「6ヶ月後に読み返したとき理解しやすいか」を問い、必要なら分割 |
| **共有が生じたとき** | 他のモジュールが同じコードを必要としたら、そこで初めて切り出す |

「先に分割してから書く」のではなく「書いてから必要に応じて分割する」。

> **フォーマット原則全般・コードスメル・境界管理については、`writing-clean-code` を参照。**

---

## 5. データ駆動とレイアウトのシナジー

テーブル駆動・ステートマシン・整列・末尾カンマ・リテラルソートは互いに組み合わさる。

**例: ステートマシン + 整列 + 末尾カンマ + リテラルソート**

```python
# 擬似コード（整形されたステートマシン遷移表）
TRANSITIONS = {
    "cancelled":  {},
    "completed":  {},
    "confirmed":  {
        "cancel": "cancelled",
        "ship":   "in_transit",
    },
    "in_transit": {
        "deliver": "completed",
    },
    "pending":    {
        "cancel": "cancelled",
        "pay":    "confirmed",
    },
}
```

- 状態名をアルファベット順ソート → 重複が見つけやすい
- イベント名もソート → 欠落が視覚的に浮かびやすい
- 末尾カンマ → 状態・イベントの追加が1行の変更で済む
- 整列 → 「状態名 → 遷移先」の対応が縦の視線で追える

---

## 6. 実践チェックリスト

### データ駆動

- [ ] 反復しているコードを見つけたとき、「変わる部分」をデータ構造に抽出した
- [ ] 深いネストを、処理ステップのリスト＋ループで平坦化した
- [ ] テーブル駆動テストで、入力・期待値のペアをリストとして管理している

### ステートマシン

- [ ] 「イベントのシーケンスを扱い、前のイベントが次の処理に影響する」コードでステートマシンを検討した
- [ ] ネストした辞書やテーブルで遷移を定義し、ライブラリなしで実装した

### コードレイアウト

- [ ] コメントは4用途のどれかに当たるか確認してから追加している
- [ ] 「how」を説明するコメントを、コードの名前改善で不要にした
- [ ] TODO コメントを一覧で可視化できる環境を整えた
- [ ] 整列プラグインを使って類似行を縦に揃えている
- [ ] リスト・配列・オブジェクトに末尾カンマを使っている
- [ ] 順序に意味がないリテラルをソートしている
- [ ] 行幅を75文字以下に抑え、縦長のコードを書いている
- [ ] 新規コードは単一ファイルで始め、安定してから分割している

---

関連: [`testing-code`](../../testing-code/SKILL.md)（テスト設計全般・TDD・AAA・テストピラミッド） / [`writing-clean-code`](../../writing-clean-code/SKILL.md)（フォーマット原則・コードスメル・境界管理）
