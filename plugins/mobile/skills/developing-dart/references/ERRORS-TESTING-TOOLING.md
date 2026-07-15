# エラー処理・テスト・パッケージ管理・ツール

## 概要

本ファイルは例外処理・デバッグ技法、`package:test` によるユニットテスト、pub による依存管理と自作パッケージの作成、Dart for Web/コマンドラインの実行基盤、そして Dart SDK 付属ツール群を扱う。言語仕様そのものは [OOP-AND-CLASSES.md](OOP-AND-CLASSES.md)・[ADVANCED-TYPES.md](ADVANCED-TYPES.md)・[ASYNC-AND-COLLECTIONS.md](ASYNC-AND-COLLECTIONS.md) を参照。

## 例外処理

Dart の例外は `Exception`/`Error` の 2 系統に大別される。`Error` は「プログラムのバグ」を示す（`RangeError`・`TypeError` など）ため通常は捕捉して継続せず修正対象とし、`Exception` は「実行時に起こりうる想定内の失敗」（`FormatException`・`TimeoutException` など）を表し呼び出し側で捕捉して回復するのが基本方針。

```dart
class InsufficientFundsException implements Exception {
  InsufficientFundsException(this.shortfall);
  final double shortfall;

  @override
  String toString() => '残高不足: あと${shortfall}円足りません';
}

class Account {
  double balance = 0;

  void withdraw(double amount) {
    if (amount > balance) {
      throw InsufficientFundsException(amount - balance);
    }
    balance -= amount;
  }
}
```

```dart
void main() {
  final account = Account();
  try {
    account.withdraw(1000);
  } on InsufficientFundsException catch (e) {
    print(e); // 具体的な型で先に捕捉する
  } catch (e, stackTrace) {
    print('想定外のエラー: $e');
    print(stackTrace);
  } finally {
    print('処理完了');
  }
}
```

| 節 | 役割 |
|---|---|
| `on ExceptionType` | 型で絞り込んで捕捉（推奨。汎用 `catch` より優先して書く） |
| `catch (e)` | 型を問わず捕捉（`e` の型は `Object`） |
| `catch (e, stackTrace)` | スタックトレースも取得（ログ出力・エラーレポートに必須） |
| `finally` | 例外の有無に関わらず必ず実行（リソース解放） |
| `rethrow` | 捕捉した例外を（スタックトレースを保持したまま）再送出 |

- カスタム例外クラスは `implements Exception`（または `Error`）を実装し、失敗理由をメッセージ文字列ではなく**型と構造化データ**で表現する。呼び出し側が `on SpecificException catch (e) { e.shortfall }` のようにデータへアクセスできる。
- `Error` 系（`ArgumentError`・`StateError` 等）はバグの早期発見が目的のため、握りつぶして処理を継続する `catch` を書かない。

## スタックトレースとデバッグ技法

```dart
void main() {
  try {
    riskyOperation();
  } catch (e, stackTrace) {
    Zone.current.handleUncaughtError(e, stackTrace); // 集中エラーハンドリングに委譲する例
  }
}
```

| 手法 | 用途 |
|---|---|
| `print`/`debugPrint` | 最も手軽だが本番コードに残すとノイズになる。ログフレームワークへの置き換えが基本 |
| `assert(condition, message)` | 開発ビルドでのみ実行される不変条件チェック（リリースビルドでは除去される） |
| `dart run --observe` / DevTools | 実行中プロセスへアタッチしてブレークポイント・変数検査を行う |
| `StackTrace.current` | 例外を送出していない箇所でも現在のコールスタックを取得できる |

- ロギングは `print` の乱用ではなく `package:logging` のような構造化ロガーを使い、レベル（`info`/`warning`/`severe`）と出力先を制御可能にする。
- 非同期コードのデバッグでは、`await` の連鎖でスタックトレースが「実際に呼び出した経路」を反映しづらいことがある。`Chain`（`package:stack_trace`）や `--verbose` 実行で補完する。

## テスト（package:test）

Dart 公式のテストフレームワークは `package:test`。`test()`/`group()`/`setUp()`/`tearDown()` を使い AAA パターン（Arrange-Act-Assert）でユニットテストを書く。

```dart
import 'package:test/test.dart';

void main() {
  group('Account', () {
    late Account account;

    setUp(() {
      account = Account()..balance = 100;
    });

    test('withdraw が残高を減らす', () {
      account.withdraw(30);
      expect(account.balance, equals(70));
    });

    test('残高不足で InsufficientFundsException を送出する', () {
      expect(
        () => account.withdraw(1000),
        throwsA(isA<InsufficientFundsException>()),
      );
    });
  });
}
```

- 実行は `dart test`（Flutter プロジェクトでは `flutter test`）。ファイル名は `*_test.dart` の慣習に従う。
- `throwsA`/`isA<T>()`/`predicate(...)` 等の matcher を組み合わせることで、例外の型・メッセージ・状態を柔軟に検証できる。
- 依存を持つクラスのテストには、手書きの fake か `package:mocktail`（null safety 対応・コード生成不要）などのモックライブラリを使い、実際の外部 I/O を発生させない。

```dart
class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}
```

| 項目 | コマンド |
|---|---|
| テスト実行 | `dart test` |
| 特定ファイルのみ実行 | `dart test test/account_test.dart` |
| カバレッジ計測 | `dart test --coverage=coverage` → `package:coverage` の `format_coverage` で lcov 化 |
| CI 統合 | 上記コマンドを GitHub Actions 等の非対話環境でそのまま実行できる（終了コードで成否判定） |

## pub と依存関係管理

`pubspec.yaml` がプロジェクトのメタデータと依存関係を定義する。

```yaml
name: my_package
description: サンプルパッケージ
version: 0.1.0
environment:
  sdk: '^3.5.0'

dependencies:
  http: ^1.2.0

dev_dependencies:
  test: ^1.25.0
  lints: ^4.0.0
```

| コマンド | 役割 |
|---|---|
| `dart pub get` | `pubspec.yaml` に基づき依存を解決し `pubspec.lock` を生成/更新 |
| `dart pub upgrade` | 制約範囲内で依存を最新化 |
| `dart pub outdated` | 古い依存・メジャーバージョン更新の有無を一覧表示 |
| `dart pub add <package>` | 依存を追加して `pubspec.yaml` を自動更新 |
| `dart pub publish` | pub.dev へパッケージを公開（`--dry-run` で事前検証） |

- バージョン制約は `^1.2.0`（caret 構文）が基本。「1.2.0 以上、次のメジャーバージョン未満」を意味し、後方互換性のある更新を自動的に許容する。
- 自作パッケージを作るには `dart create -t package <name>` で雛形を生成し、`lib/<name>.dart` を公開エントリポイントとする。内部実装は `lib/src/` 配下に置き、エントリポイントからのみ `export` して公開範囲を制御する。
- `pubspec.lock` はアプリケーションでは commit し（再現可能なビルドのため）、ライブラリパッケージでは通常 commit しない（利用側の依存解決に委ねるため）。
- private な依存（社内パッケージ等）は `git:`/`path:` 依存として `pubspec.yaml` に記述できる（pub.dev への公開が不要な場合）。

## Dart for Web とコマンドライン

Dart は VM 上のネイティブ実行（`dart run`）に加え、Web（コンパイル先 JavaScript/Wasm）とスタンドアロン CLI ツールの両方をターゲットにできる。

```dart
import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln('usage: greet <name>');
    exit(64);
  }
  stdout.writeln('Hello, ${arguments.first}!');
}
```

- CLI ツールでは `package:args` で引数パースを行うのが標準的（`ArgParser` でフラグ・オプション・サブコマンドを定義する）。
- `dart compile exe` でスタンドアロン実行ファイルへ、`dart compile js`/`dart compile wasm` で Web 向け成果物へコンパイルできる。

### Web ターゲットの現行方針

- `dart:html` は非推奨（deprecated）。新規の Web 開発では **`package:web`**（型付けされた薄いバインディング）と **`dart:js_interop`** の組み合わせが現行の推奨経路。
- `dart:html` を使った既存コードを移行する場合は、`package:web` の型に置き換えつつ、JS 相互運用が必要な箇所を `dart:js_interop` の `JSAny`/`JSObject` 系 API で書き直す。
- ブラウザ実行が主目的ではなく、DOM 操作を伴わない純粋なロジックのみを Web ターゲットにコンパイルする場合は、`dart:html`/`package:web` いずれにも依存しない設計にできないか検討する（プラットフォーム非依存のコードほど再利用性が高い）。

## ツール（SDK・DartPad・analyzer・formatter）

| ツール | 役割 |
|---|---|
| Dart SDK（`dart` コマンド） | `run`/`test`/`analyze`/`format`/`compile`/`pub`/`fix` を統合した単一 CLI |
| DartPad | ブラウザ上で実行できるオンラインエディタ。インストール不要の動作確認・共有に有効 |
| analyzer（`dart analyze`） | 静的解析。`analysis_options.yaml` でリントルールを設定する |
| formatter（`dart format`） | コードスタイルを自動整形。フォーマット論争を機械的に解消する |
| `dart fix --apply` | analyzer が検出した機械的に直せる指摘を一括修正 |

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml

linter:
  rules:
    - prefer_final_locals
    - unnecessary_null_checks
```

- `analysis_options.yaml` で `package:lints`（公式基本セット）や `package:very_good_analysis`（より厳格なセット）を `include` し、必要に応じて個別ルールを追加/無効化する。
- CI では `dart format --output=none --set-exit-if-changed .` と `dart analyze --fatal-infos` を組み合わせ、フォーマット崩れとリント違反をマージ前に機械的にブロックする。

## チェックリスト

- [ ] カスタム例外を型として定義し、メッセージ文字列だけに失敗理由を押し込めていないか
- [ ] `catch (e)` の前に、捕捉すべき具体的な例外型を `on` で優先して書いているか
- [ ] `Error` 系（バグを示す例外）を握りつぶして処理を継続していないか
- [ ] 外部 I/O に依存するテストをフェイク/モックで隔離しているか
- [ ] `pubspec.yaml` のバージョン制約が意図した後方互換範囲になっているか
- [ ] 自作パッケージの公開 API を `lib/<name>.dart` に集約し、内部実装を `lib/src/` に隠しているか
- [ ] Web ターゲットで非推奨の `dart:html` ではなく `package:web`/`dart:js_interop` を使っているか
- [ ] CI で `dart format`/`dart analyze` を強制する仕組みがあるか

## 公式ドキュメント入口

- 例外処理: https://dart.dev/language/error-handling
- テスト: https://dart.dev/tools/dart-test / https://pub.dev/packages/test
- pub とパッケージ: https://dart.dev/tools/pub/cmd / https://pub.dev
- Web ターゲット: https://dart.dev/web / https://pub.dev/packages/web
- ツール: https://dart.dev/tools/dart-analyze / https://dart.dev/tools/dart-format / https://dartpad.dev
