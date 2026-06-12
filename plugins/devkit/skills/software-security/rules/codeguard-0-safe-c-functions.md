---
description: C/C++における安全なメモリ・文字列関数の使用ガイドライン
languages:
- c
- cpp
alwaysApply: false
---

rule_id: codeguard-0-safe-c-functions

# C/C++におけるメモリ安全・文字列安全関数の優先使用

C/C++コードを処理する際の最優先事項はメモリ安全の確保です。コードベース内の安全でない関数を積極的に特定・フラグ付けし、安全なリファクタリング案を提示してください。新規コードを生成する際は、常に該当タスクに対して最も安全な関数をデフォルトとして使用してください。


### 1. 回避すべき安全でない関数とその安全な代替手段

「安全でない」として列挙された関数は非推奨かつ高リスクとして扱わなければなりません。以下の箇条書きに示す「推奨される安全な代替手段」のいずれかへの置き換えを常に推奨してください。

• `gets()` は絶対に使用してはならない - これは致命的なセキュリティリスクです。境界チェックが一切なく、古典的なバッファオーバーフロー脆弱性の典型例です。代わりに必ず `fgets(char *str, int n, FILE *stream)` を使用してください。

• `strcpy()` は避ける - 境界チェックを行わない高リスク関数です。ヌル終端に達するまでバイトをコピーし続けるため、宛先バッファを容易に超過して書き込む可能性があります。`snprintf()`、`strncpy()`（ただし注意して使用）、または `strcpy_s()`（C11 Annex K サポートがある場合）を使用してください。

• `strcat()` は使用しない - 境界チェックのない別の高リスク関数です。文字列にバイトを追加し、確保したメモリを容易に超過して書き込む可能性があります。`snprintf()`、`strncat()`（慎重に扱う）、または `strcat_s()`（C11 Annex K）に置き換えてください。

• `sprintf()` と `vsprintf()` は置き換える - 出力バッファの境界チェックを行わない高リスク関数です。フォーマット後の文字列がバッファより大きい場合、バッファオーバーフローが発生します。代わりに `snprintf()`、`snwprintf()`、または `vsprintf_s()`（C11 Annex K）を使用してください。

• `scanf()` ファミリーには注意する - これは中程度のリスクです。幅制限のない `%s` フォーマット指定子はバッファオーバーフローを引き起こす可能性があります。推奨される対処法：
  1. `scanf("%127s", buffer)` のように幅指定子を使用する
  2. より良い方法：`fgets()` で行を読み込み、`sscanf()` でパースする

• `strtok()` は避ける - リエントラントでなくスレッドセーフでないため中程度のリスクです。静的な内部バッファを使用するため、マルチスレッドコードや複雑なシグナル処理で予測不能な動作を引き起こす可能性があります。代わりに `strtok_r()`（POSIX）または `strtok_s()`（C11 Annex K）を使用してください。

• `memcpy()` と `memmove()` は注意して使用する - これらは本質的に安全でないわけではありませんが、サイズ引数の計算ミスや適切な検証不足により一般的なバグの原因となります。推奨される対処法：
  1. サイズ計算を再確認する
  2. 利用可能な場合は `memcpy_s()`（C11 Annex K）を優先する
  3. ソースバッファと宛先バッファが重複する可能性がある場合は `memmove()` を使用する

### 2. 実践的な実装ガイドライン

#### 新規コード生成時：

- `gets()`、`strcpy()`、`strcat()`、`sprintf()` を使用するコードは絶対に生成してはならない。

- 文字列のフォーマットと連結には `snprintf()` をデフォルトとして使用する。最も柔軟で安全な選択肢であることが多い。

- ファイルや標準入力からの文字列入力読み込みには `fgets()` をデフォルトとして使用する。


#### コード解析とリファクタリング時：

1. 特定：コードをスキャンし、「安全でない」列の関数のすべてのインスタンスにフラグを立てる。

2. リスクの説明：安全でない関数にフラグを立てる際、具体的な脆弱性について簡潔に説明する。

    - _説明例：_ `警告: 'strcpy' 関数は境界チェックを行わず、ソース文字列が宛先バッファより大きい場合にバッファオーバーフローを引き起こす可能性があります。これは一般的なセキュリティ脆弱性です。`

3. コンテキストに応じた置き換えを提示する：提案は周囲のコードの文脈を考慮した、ドロップイン可能な安全な代替手段でなければならない。


#### コンパイラフラグの使用：

コンパイル時およびランタイムでバッファオーバーフロー脆弱性を検出するために、以下の保護コンパイラフラグを有効にする：

- スタック保護：スタックバッファオーバーフローを検出するために `-fstack-protector-all` または `-fstack-protector-strong` を使用する
- Address Sanitizer：開発中にメモリエラーを検出するために `-fsanitize=address` を使用する
- オブジェクトサイズチェック（OSC）：`strcpy`、`strcat`、`sprintf` 等の関数のバッファオーバーフローに対するランタイムチェックを有効にするために `-D_FORTIFY_SOURCE=2` を使用する。これにより上記の多くの安全でない関数に境界チェックが追加される
- フォーマット文字列保護：フォーマット文字列の脆弱性を検出するために `-Wformat -Wformat-security` を使用する

### 3. リファクタリング例

提案は具体的かつ実践的であること。

例1：`strcpy` の置き換え

- 元の安全でないコード：

    ```
    char destination[64];
    strcpy(destination, source_string);
    ```

- 推奨リファクタリング：

    ```
    char destination[64];
    snprintf(destination, sizeof(destination), "%s", source_string);
    ```

- 説明：`'strcpy' を 'snprintf' に置き換えることで、宛先バッファへの書き込みをヌル終端文字を含む最大63文字に制限し、潜在的なバッファオーバーフローを防止しました。`


例2：`strncpy` 使用の修正

`strncpy` 関数は一般的ではあるが不完全な代替手段です。宛先バッファをヌル終端しない場合があります。使用している場合またはコード中に見つけた場合は、正しい処理を必ず強制してください。

- 元の（潜在的に安全でない）`strncpy`：

    ```
    // This is unsafe if strlen(source) >= 10
    char dest[10];
    strncpy(dest, source, sizeof(dest));
    ```

- 修正案：

    ```
    char dest[10];
    strncpy(dest, source, sizeof(dest) - 1);
    dest[sizeof(dest) - 1] = '\0';
    ```

- 説明：`'strncpy' に明示的なヌル終端を追加しました。'strncpy' 関数は、ソースが宛先バッファと同じ長さの場合にヌル終端文字列を保証しません。この修正により、後続の文字列操作でのバッファ超過読み取りを防止します。`


例3：`scanf` のセキュア化

- 元の安全でないコード：

    ```
    char user_name[32];
    printf("Enter your name: ");
    scanf("%s", user_name);
    ```

- 推奨リファクタリング：

    ```
    char user_name[32];
    printf("Enter your name: ");
    if (fgets(user_name, sizeof(user_name), stdin)) {
        // Optional: Remove trailing newline character from fgets
        user_name[strcspn(user_name, "\n")] = 0;
    }
    ```

- 説明：`ユーザー入力の読み取りに 'scanf("%s", ...)' の代わりに 'fgets()' を使用しました。'fgets' は入力をバッファサイズに制限するためより安全であり、バッファオーバーフローを防止します。元の 'scanf' にはこのような保護がありませんでした。`


### メモリ・文字列安全ガイドライン

#### 安全でないメモリ関数 - 使用禁止
入力パラメータの境界チェックを行わない以下の安全でないメモリ関数は絶対に使用してはならない：

##### 禁止されたメモリ関数：
- `memcpy()` → `memcpy_s()` を使用する
- `memset()` → `memset_s()` を使用する
- `memmove()` → `memmove_s()` を使用する
- `memcmp()` → `memcmp_s()` を使用する
- `bzero()` → `memset_s()` を使用する
- `memzero()` → `memset_s()` を使用する

##### 安全なメモリ関数の代替：
```c
// Instead of: memcpy(dest, src, count);
errno_t result = memcpy_s(dest, dest_size, src, count);
if (result != 0) {
// Handle error
}

// Instead of: memset(dest, value, count);
errno_t result = memset_s(dest, dest_size, value, count);

// Instead of: memmove(dest, src, count);
errno_t result = memmove_s(dest, dest_size, src, count);

// Instead of: memcmp(s1, s2, count);
int indicator;
errno_t result = memcmp_s(s1, s1max, s2, s2max, count, &indicator);
if (result == 0) {
// indicator contains comparison result: <0, 0, or >0
}
```

#### 安全でない文字列関数 - 使用禁止
バッファオーバーフローを引き起こす可能性のある以下の安全でない文字列関数は絶対に使用してはならない：

##### 禁止された文字列関数：
- `strstr()` → `strstr_s()` を使用する
- `strtok()` → `strtok_s()` を使用する
- `strcpy()` → `strcpy_s()` を使用する
- `strcmp()` → `strcmp_s()` を使用する
- `strlen()` → `strnlen_s()` を使用する
- `strcat()` → `strcat_s()` を使用する
- `sprintf()` → `snprintf()` を使用する

##### 安全な文字列関数の代替：
```c
// String Search
errno_t strstr_s(char *dest, rsize_t dmax, const char *src, rsize_t slen, char **substring);

// String Tokenization
char *strtok_s(char *dest, rsize_t *dmax, const char *src, char **ptr);

// String Copy
errno_t strcpy_s(char *dest, rsize_t dmax, const char *src);

// String Compare
errno_t strcmp_s(const char *dest, rsize_t dmax, const char *src, int *indicator);

// String Length (bounded)
rsize_t strnlen_s(const char *str, rsize_t strsz);

// String Concatenation
errno_t strcat_s(char *dest, rsize_t dmax, const char *src);

// Formatted String (always use size-bounded version)
int snprintf(char *s, size_t n, const char *format, ...);
```

#### 実装例：

##### 安全な文字列コピーのパターン：
```c
// Bad - unsafe
char dest[256];
strcpy(dest, src); // Buffer overflow risk!

// Good - safe
char dest[256];
errno_t result = strcpy_s(dest, sizeof(dest), src);
if (result != 0) {
// Handle error: src too long or invalid parameters
EWLC_LOG_ERROR("String copy failed: %d", result);
return ERROR;
}
```

##### 安全な文字列連結のパターン：
```c
// Bad - unsafe
char buffer[256] = "prefix_";
strcat(buffer, suffix); // Buffer overflow risk!

// Good - safe
char buffer[256] = "prefix_";
errno_t result = strcat_s(buffer, sizeof(buffer), suffix);
if (result != 0) {
EWLC_LOG_ERROR("String concatenation failed: %d", result);
return ERROR;
}
```

##### 安全なメモリコピーのパターン：
```c
// Bad - unsafe
memcpy(dest, src, size); // No boundary checking!

// Good - safe
errno_t result = memcpy_s(dest, dest_max_size, src, size);
if (result != 0) {
EWLC_LOG_ERROR("Memory copy failed: %d", result);
return ERROR;
}
```

##### 安全な文字列トークン化のパターン：
```c
// Bad - unsafe
char *token = strtok(str, delim); // Modifies original string unsafely

// Good - safe
char *next_token = NULL;
rsize_t str_max = strnlen_s(str, MAX_STRING_SIZE);
char *token = strtok_s(str, &str_max, delim, &next_token);
while (token != NULL) {
// Process token
token = strtok_s(NULL, &str_max, delim, &next_token);
}
```

#### メモリ・文字列安全コードレビューチェックリスト：

##### コードレビュー前（開発者）：
- [ ] 安全でないメモリ関数（`memcpy`、`memset`、`memmove`、`memcmp`、`bzero`）を使用していないこと
- [ ] 安全でない文字列関数（`strcpy`、`strcat`、`strcmp`、`strlen`、`sprintf`、`strstr`、`strtok`）を使用していないこと
- [ ] すべてのメモリ操作で適切なサイズパラメータを持つ `*_s()` バリアントを使用していること
- [ ] バッファサイズが `sizeof()` または既知の上限を使って正しく計算されていること
- [ ] 変更される可能性のあるハードコードされたバッファサイズがないこと

##### コードレビュー（レビュアー）：
- [ ] メモリ安全：すべてのメモリ操作で安全なバリアントを使用していることを確認する
- [ ] バッファ境界：宛先バッファサイズが適切に指定されていることを確認する
- [ ] エラーハンドリング：すべての `errno_t` 戻り値が処理されていることを確認する
- [ ] サイズパラメータ：`rsize_t dmax` パラメータが正しいことを検証する
- [ ] 文字列終端：文字列が適切にヌル終端されていることを確認する
- [ ] 長さ検証：操作前にソース文字列の長さが検証されていることを確認する

##### 静的解析の統合：
- [ ] 安全でない関数の使用に対するコンパイラ警告を有効にする
- [ ] 静的解析ツールを使用して安全でない関数呼び出しを検出する
- [ ] 安全でない関数の警告をエラーとして扱うようビルドシステムを設定する
- [ ] 禁止された関数をスキャンするプリコミットフックを追加する

#### よくある落とし穴と解決策：

##### 落とし穴1：誤ったサイズパラメータ
```c
// Wrong - using source size instead of destination size
strcpy_s(dest, strlen(src), src); // WRONG!

// Correct - using destination buffer size
strcpy_s(dest, sizeof(dest), src); // CORRECT
```

##### 落とし穴2：戻り値の無視
```c
// Wrong - ignoring potential errors
strcpy_s(dest, sizeof(dest), src); // Error not checked

// Correct - checking return value
if (strcpy_s(dest, sizeof(dest), src) != 0) {
// Handle error appropriately
}
```

##### 落とし穴3：ポインタに対する `sizeof()` の使用
```c
// Wrong - sizeof pointer, not buffer
void func(char *buffer) {
strcpy_s(buffer, sizeof(buffer), src); // sizeof(char*) = 8!
}

// Correct - pass buffer size as parameter
void func(char *buffer, size_t buffer_size) {
strcpy_s(buffer, buffer_size, src);
}
```

このルールがどのように、なぜ適用されたかを必ず説明しなければならない。
