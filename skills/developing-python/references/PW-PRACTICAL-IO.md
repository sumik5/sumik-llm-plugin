---
title: Practical File I/O Patterns
description: >-
  Practical file I/O patterns covering CSV/JSON processing, structured text parsing,
  file discovery with pathlib/glob, StringIO for testing, and context manager best practices.
category: python-practical-patterns
---

# ファイルI/O実践パターン

Pythonのファイル入出力に関する実践的なパターンを体系的にまとめる。標準ライブラリだけで
CSV/JSONの読み書き、構造化テキスト解析、ファイル探索、テスト用I/Oを実現できる。

---

## 1. テキストファイルの読み書き基礎

### open()のモード指定

```python
# 読み込み（デフォルト）
f = open("data.txt", "r", encoding="utf-8")

# 書き込み（ファイルを新規作成 or 上書き）
f = open("output.txt", "w", encoding="utf-8")

# 追記
f = open("log.txt", "a", encoding="utf-8")

# 読み書き両用
f = open("data.txt", "r+", encoding="utf-8")

# バイナリ読み込み
f = open("image.png", "rb")
```

| モード | 意味 | ファイルが存在しない場合 |
|--------|------|----------------------|
| `r` | 読み込み（デフォルト） | エラー |
| `w` | 書き込み（上書き） | 新規作成 |
| `a` | 追記 | 新規作成 |
| `r+` | 読み書き | エラー |
| `rb`/`wb` | バイナリ | — |

### コンテキストマネージャ（with文）の必須使用

```python
# 推奨: with文でファイルを自動クローズ
with open("data.txt", encoding="utf-8") as f:
    content = f.read()
# ブロックを抜けると自動的にclose()が呼ばれる

# 複数ファイルを同時に開く
with open("input.txt") as infile, open("output.txt", "w") as outfile:
    for line in infile:
        outfile.write(line.upper())
```

`with`文はコンテキストマネージャプロトコル（`__enter__`/`__exit__`）を利用する。
例外が発生してもブロックを抜ける際に必ず`__exit__`が呼ばれ、ファイルがクローズされる。

### 行イテレーションのパターン

```python
# パターン1: 全行を処理
with open("data.txt", encoding="utf-8") as f:
    for line in f:
        # lineには末尾の\nが含まれる
        line = line.rstrip("\n")
        print(line)

# パターン2: 全内容を一括読み込み
with open("data.txt", encoding="utf-8") as f:
    content = f.read()       # 文字列として取得

# パターン3: 行リストとして読み込み
with open("data.txt", encoding="utf-8") as f:
    lines = f.readlines()    # ['line1\n', 'line2\n', ...]

# パターン4: 最終行を取得
def get_last_line(filename: str) -> str:
    last = ""
    with open(filename, encoding="utf-8") as f:
        for line in f:
            last = line
    return last.rstrip()
```

**行イテレーション vs read()/readlines()**:
- 行イテレーション: メモリ効率が良い。大きなファイルでも1行ずつ処理する
- `read()`: 全内容をメモリに展開。小さなファイルや全体処理に向く
- `readlines()`: 行のリストを返す。インデックスアクセスが必要な場合に使う

**エンコーディング**: `encoding="utf-8"`を必ず明示する。日本語CSVは`encoding="utf-8-sig"`(BOM付き)が安全。

---

## 2. 構造化テキスト解析

### 区切り文字ベースの解析

コロン区切りや空白区切りのテキストファイルを辞書に変換するパターン。

```python
def parse_colon_separated(filename: str) -> dict[str, str]:
    """コロン区切りのテキストを辞書に変換する。"""
    result: dict[str, str] = {}
    with open(filename, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # コメント行と空行をスキップ
            if not line or line.startswith("#"):
                continue
            parts = line.split(":")
            if len(parts) >= 2:
                key = parts[0]
                value = parts[1]
                result[key] = value
    return result
```

### 複数フィールドの型変換

```python
def parse_tsv_with_types(filename: str) -> list[dict[str, object]]:
    """タブ区切りファイルを型変換しながら読み込む。"""
    rows: list[dict[str, object]] = []
    with open(filename, encoding="utf-8") as f:
        headers = f.readline().strip().split("\t")
        for line in f:
            values = line.strip().split("\t")
            record: dict[str, object] = {}
            for header, value in zip(headers, values):
                try:
                    record[header] = int(value)
                except ValueError:
                    try:
                        record[header] = float(value)
                    except ValueError:
                        record[header] = value
            rows.append(record)
    return rows
```

---

## 3. CSVモジュール

### csv.reader / csv.writer

```python
import csv

# 書き込み
def write_csv(filename: str, rows: list[list[object]]) -> None:
    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(rows)

# 読み込み
def read_csv(filename: str) -> list[list[str]]:
    rows: list[list[str]] = []
    with open(filename, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            rows.append(row)
    return rows
```

**`newline=""`を必ず指定する理由**: CSVモジュール内部で改行文字を制御するため、
`open()`側での変換を無効化する必要がある。省略すると二重改行になる場合がある。

### カスタム区切り文字

```python
# タブ区切りで読む
with open("data.tsv", newline="", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter="\t")
    for row in reader:
        print(row)

# コロン区切りで読む（/etc/passwd形式）
def passwd_to_records(passwd_path: str) -> list[tuple[str, str]]:
    records: list[tuple[str, str]] = []
    with open(passwd_path, newline="") as f:
        reader = csv.reader(f, delimiter=":")
        for row in reader:
            if len(row) > 2:  # コメント行を除外
                records.append((row[0], row[2]))  # username, uid
    return records
```

### csv.DictReader / csv.DictWriter

ヘッダー行を持つCSVを辞書として扱う。

```python
# DictReader: 各行を辞書として取得
def read_csv_as_dicts(filename: str) -> list[dict[str, str]]:
    with open(filename, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader)

# DictWriter: 辞書のリストをCSVに書き込む
def write_dicts_to_csv(
    filename: str,
    records: list[dict[str, object]],
    fieldnames: list[str],
) -> None:
    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)

# 使用例
products = [
    {"name": "apple", "price": 150, "category": "fruit"},
    {"name": "carrot", "price": 80, "category": "vegetable"},
]
write_dicts_to_csv("products.csv", products, ["name", "price", "category"])
```

---

## 4. JSONモジュール

### json.load / json.dump（ファイル操作）

```python
import json

# ファイルからJSONを読み込む
def load_json_file(filename: str) -> object:
    with open(filename, encoding="utf-8") as f:
        return json.load(f)

# PythonオブジェクトをJSONファイルに書く
def save_json_file(data: object, filename: str) -> None:
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
```

### json.loads / json.dumps（文字列操作）

```python
# 文字列からPythonオブジェクトに変換
json_string = '{"name": "田中", "score": 95}'
data = json.loads(json_string)
print(data["name"])  # 田中

# PythonオブジェクトをJSON文字列に変換
record = {"user": "yamada", "scores": [85, 92, 78]}
json_string = json.dumps(record, ensure_ascii=False)
```

### ensure_ascii=False（日本語対応）

```python
data = {"message": "こんにちは", "count": 42}

# ensure_ascii=True（デフォルト）: \uXXXXにエスケープ
json.dumps(data)
# '{"message": "\\u3053\\u3093\\u306b\\u3061\\u306f", "count": 42}'

# ensure_ascii=False: 日本語をそのまま出力
json.dumps(data, ensure_ascii=False)
# '{"message": "こんにちは", "count": 42}'
```

### 複数JSONファイルの集計パターン

```python
import glob

def aggregate_json_scores(directory: str) -> dict[str, dict[str, float]]:
    """ディレクトリ内の全JSONファイルからスコアを集計する。"""
    summary: dict[str, dict[str, float]] = {}

    for filepath in glob.glob(f"{directory}/*.json"):
        with open(filepath, encoding="utf-8") as f:
            records: list[dict[str, int]] = json.load(f)

        subject_scores: dict[str, list[int]] = {}
        for record in records:
            for subject, score in record.items():
                subject_scores.setdefault(subject, []).append(score)

        summary[filepath] = {
            subject: sum(scores) / len(scores)
            for subject, scores in subject_scores.items()
        }

    return summary
```

---

## 5. ファイル探索と操作

### os.listdir / os.path.join

```python
import os

def list_text_files(directory: str) -> list[str]:
    """ディレクトリ内の.txtファイルのフルパスを返す。"""
    result: list[str] = []
    for filename in os.listdir(directory):
        if filename.endswith(".txt"):
            full_path = os.path.join(directory, filename)
            if os.path.isfile(full_path):  # ディレクトリを除外
                result.append(full_path)
    return result
```

**`os.path.join()`を必ず使う理由**: OS間でパス区切り文字（`/`と`\`）が異なるため、
文字列連結（`directory + "/" + filename`）は使わない。

### pathlib.Pathの活用

`pathlib`はオブジェクト指向APIでファイルシステムを操作できる現代的な方法。

```python
from pathlib import Path

# Pathオブジェクトの作成
data_dir = Path("/data/logs")

# ディレクトリ内のファイルを列挙
for path in data_dir.iterdir():
    if path.is_file():
        print(path.name)       # ファイル名のみ
        print(path.suffix)     # 拡張子（.txt等）
        print(path.stem)       # 拡張子なしのファイル名

# パターンマッチ
for log_file in data_dir.glob("*.log"):
    print(log_file)

# 再帰的なパターンマッチ
for py_file in data_dir.rglob("*.py"):
    print(py_file)

# パスの連結（/演算子で直感的）
config_path = Path("/etc") / "myapp" / "config.json"

# ファイルの直接読み書き
content = config_path.read_text(encoding="utf-8")
config_path.write_text("new content", encoding="utf-8")
```

### glob.globパターンマッチング

```python
import glob

# 特定パターンのファイルを取得
csv_files = glob.glob("/data/*.csv")
all_logs = glob.glob("/var/log/**/*.log", recursive=True)

# 複数ディレクトリにまたがるファイル検索
def find_files_by_extension(root: str, ext: str) -> list[str]:
    pattern = f"{root}/**/*{ext}"
    return glob.glob(pattern, recursive=True)
```

---

## 6. StringIOによるテスト

### io.StringIOでファイルオブジェクトをモック

`io.StringIO`はファイルと同じAPIを持つが、実際にはメモリ上の文字列バッファ。
ユニットテストで実際のファイルI/Oを避けられる。

```python
import io

# StringIOの基本
buf = io.StringIO("line1\nline2\nline3\n")
for line in buf:
    print(line.rstrip())  # line1, line2, line3

# 書き込みモード
buf = io.StringIO()
buf.write("hello\n")
buf.write("world\n")
content = buf.getvalue()  # "hello\nworld\n"
```

### ファイルI/O関数のユニットテスト

```python
import io

def count_words(fileobj) -> int:
    """ファイルオブジェクト（実ファイルまたはStringIO）から単語数を数える。"""
    total = 0
    for line in fileobj:
        total += len(line.split())
    return total

def test_count_words():
    fake_file = io.StringIO("hello world\nfoo bar baz\n")
    assert count_words(fake_file) == 5
```

**設計原則**: ファイルI/O関数は「ファイルパス」ではなく「ファイルオブジェクト」を
受け取るシグネチャにすると、`StringIO`で簡単にテストできる。これは依存性注入の一形態。

---

## 7. 実践パターン集

### ジェネレータによる複数ファイル横断処理

```python
import os
from collections.abc import Generator

def all_lines(directory: str) -> Generator[str, None, None]:
    """ディレクトリ内の全ファイルから行を順次生成する。"""
    for filename in os.listdir(directory):
        filepath = os.path.join(directory, filename)
        if os.path.isfile(filepath):
            try:
                with open(filepath, encoding="utf-8") as f:
                    for line in f:
                        yield line.rstrip()
            except (UnicodeDecodeError, PermissionError):
                # バイナリファイルや権限のないファイルをスキップ
                pass

# 使用例: 全ファイルからエラーログを抽出
error_lines = [
    line for line in all_lines("/var/log")
    if "ERROR" in line
]
```

**ジェネレータの利点**: 全行をメモリに展開せず、大量ファイルも省メモリで逐次処理できる。

### 設定ファイル読み込みパターン

```python
def load_config(filepath: str) -> dict[str, str]:
    """KEY=VALUE形式の設定ファイルを辞書として読み込む。"""
    config: dict[str, str] = {}
    with open(filepath, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                config[key.strip()] = value.strip()
    return config
```

### ワードカウントパターン

```python
from collections import Counter

def word_count(filepath: str) -> Counter[str]:
    """ファイル内の単語出現頻度を返す。"""
    counts: Counter[str] = Counter()
    with open(filepath, encoding="utf-8") as f:
        for line in f:
            counts.update(line.lower().split())
    return counts
```

### 行の反転書き込み

```python
def reverse_file_lines(input_path: str, output_path: str) -> None:
    """ファイルの行順を逆にして新しいファイルに書き込む。"""
    with open(input_path, encoding="utf-8") as f:
        lines = f.readlines()
    with open(output_path, "w", encoding="utf-8") as f:
        for line in reversed(lines):
            f.write(line)
```

---

## クイックリファレンス

| 操作 | コード |
|------|--------|
| テキスト読み込み | `with open(path) as f: content = f.read()` |
| 行ループ | `for line in f:` |
| CSV読み込み | `csv.DictReader(f)` |
| CSV書き込み | `csv.DictWriter(f, fieldnames=[...])` |
| JSON読み込み | `json.load(f)` |
| JSON書き込み | `json.dump(data, f, ensure_ascii=False)` |
| ファイル一覧 | `Path(dir).glob("*.txt")` |
| テスト用ファイル | `io.StringIO("content")` |
| 複数ファイル横断 | `yield`によるジェネレータ |
