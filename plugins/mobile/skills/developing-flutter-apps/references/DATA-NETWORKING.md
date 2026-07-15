# ネットワークとデータ永続化

## 概要

このリファレンスは、Flutterアプリの外部通信（http/dioによるREST API連携、Firebase Auth/Firestore、GraphQL）とローカル永続化（shared_preferences、sqflite、hive、drift、secure_storage）を扱う。developing-flutter-apps のINSTRUCTIONS.mdから「バックエンドと通信したい」「端末にデータを保存したい」タスクでルーティングされる想定であり、状態管理レイヤーでの非同期処理のハンドリングはSTATE-MANAGEMENT.md、アプリ全体のレイヤ分離はARCHITECTURE-PATTERNS.mdが担当する。

## HTTPクライアント: http パッケージ

`http` パッケージはDartチーム公式の軽量HTTPクライアントで、シンプルなCRUD通信であれば追加の依存なしで完結する。

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class Article {
  const Article({required this.id, required this.title});

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String,
        title: json['title'] as String,
      );

  final String id;
  final String title;
}

class ArticleApi {
  ArticleApi(this._client);
  final http.Client _client;

  Future<List<Article>> fetchArticles() async {
    final response = await _client.get(
      Uri.parse('https://api.example.com/articles'),
    );
    if (response.statusCode != 200) {
      throw ArticleApiException('failed to fetch articles: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((json) => Article.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

class ArticleApiException implements Exception {
  ArticleApiException(this.message);
  final String message;

  @override
  String toString() => 'ArticleApiException: $message';
}
```

`http.Client` をコンストラクタで注入することで、テスト時にモッククライアントへ差し替えられる。トップレベル関数として `http.get` を直接呼ぶ実装はテスト困難になるため避ける。

## HTTPクライアント: dio パッケージ

`dio` はインターセプター、リクエストキャンセル、タイムアウト設定、ファイルアップロード/ダウンロードなど、実務でよく必要になる機能を標準搭載したHTTPクライアント。認証トークンの自動付与やログ出力を横断的に行いたい場合、`http` より少ないコードで実現できる。

```dart
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(String baseUrl, {required Future<String?> Function() tokenProvider})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10))) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenProvider();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // 401等の共通エラーハンドリングをここに集約する
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  Future<Response<T>> get<T>(String path) => _dio.get<T>(path);
}
```

**選定基準:**

| 状況 | 推奨 |
|---|---|
| 単純なCRUD呼び出しのみ、依存を最小化したい | `http` |
| 認証トークンの自動付与、リトライ、ログ、キャンセルが必要 | `dio` |
| GraphQLを使う | 専用のGraphQLクライアント（後述） |

## リポジトリ層とエラーハンドリング

通信処理はUI層から直接呼ばず、リポジトリ層に隔離する。HTTPステータスエラー・デコードエラー・通信不可（オフライン）を区別できる例外型を用意し、UI層は「成功/失敗」を分岐するだけでよい状態にする。

```dart
sealed class ArticleResult {
  const ArticleResult();
}

class ArticleSuccess extends ArticleResult {
  const ArticleSuccess(this.articles);
  final List<Article> articles;
}

class ArticleFailure extends ArticleResult {
  const ArticleFailure(this.message);
  final String message;
}

class ArticleRepository {
  ArticleRepository(this._api);
  final ArticleApi _api;

  Future<ArticleResult> loadArticles() async {
    try {
      final articles = await _api.fetchArticles();
      return ArticleSuccess(articles);
    } on ArticleApiException catch (e) {
      return ArticleFailure(e.message);
    } on http.ClientException {
      return const ArticleFailure('ネットワークに接続できません');
    }
  }
}
```

## Firebase連携（Auth・Firestore）

Firebaseは認証・NoSQLデータベース（Firestore）・クラウド関数をまとめて提供するプラットフォームで、自前のバックエンドを持たずにアプリを立ち上げたい場合に選ばれる。`firebase_core` を各アプリで最初に初期化し、必要な機能ごとに `firebase_auth` / `cloud_firestore` 等を追加する。

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

### Firebase Authentication

```dart
class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<void> signOut() => _auth.signOut();
}
```

### Cloud Firestore

```dart
class TaskRepository {
  TaskRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<Task>> watchTasks(String userId) {
    return _db
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Task.fromFirestore).toList());
  }

  Future<void> addTask(String userId, String title) {
    return _db.collection('tasks').add({
      'userId': userId,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
```

Firestoreの `snapshots()` はStreamを返すため、`StreamBuilder` またはSTATE-MANAGEMENT.mdで扱う状態管理ライブラリのStream購読機構と組み合わせる。

> Firestoreセキュリティルール、Cloud Functions、Firebase Hostingなど、Firebaseプラットフォーム自体の深掘りは `cloud:developing-firebase` を参照する。本リファレンスはFlutterアプリ側からの連携方法に限定する。

## GraphQL

GraphQLはクライアントが必要なフィールドだけを指定してクエリできるAPIスタイルで、REST APIの多段リクエスト（N+1問題）を避けたい場合に選ばれる。Flutterでは専用のGraphQLクライアントパッケージでクエリ・ミューテーション・キャッシュを扱う。

```dart
final result = await graphQLClient.query(
  QueryOptions(
    document: gql(r'''
      query GetArticle($id: ID!) {
        article(id: $id) { id title body }
      }
    '''),
    variables: {'id': articleId},
  ),
);

if (result.hasException) {
  throw ArticleApiException(result.exception.toString());
}
final article = result.data!['article'] as Map<String, dynamic>;
```

REST/GraphQL/gRPC/WebSocketなど、APIスタイル自体の比較・選定基準は `web:choosing-api-styles` を参照する。

## ローカル永続化

| 手段 | 特性 | 適する用途 |
|---|---|---|
| `shared_preferences` | プラットフォームネイティブのキーバリューストア | 設定値、フラグ、軽量な文字列/数値 |
| `sqflite` | SQLiteを直接操作するプラグイン | SQLをそのまま書きたい、既存SQLite資産がある |
| `drift`（旧moor） | sqfliteの上に型安全なクエリビルダとコード生成を載せたORM | 複雑なクエリ・リレーション・マイグレーションを型安全に扱いたい |
| `hive` | 純Dart実装のNoSQLキーバリューストア | スキーマレスで高速な端末内保存、オフラインファースト |
| `flutter_secure_storage` | OSのKeychain(iOS)/Keystore(Android)を使う暗号化ストレージ | トークン・パスワード等の機密情報 |

### shared_preferences

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('locale', 'ja');
final locale = prefs.getString('locale');
```

### sqflite

```dart
final db = await openDatabase(
  join(await getDatabasesPath(), 'app.db'),
  version: 1,
  onCreate: (db, version) => db.execute(
    'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL)',
  ),
);

await db.insert('tasks', {'title': 'Buy milk'});
final rows = await db.query('tasks');
```

### drift（型安全なクエリビルダ）

```dart
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
}

@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<Task>> allTasks() => select(tasks).get();
  Future<int> addTask(String title) => into(tasks).insert(TasksCompanion.insert(title: title));
}
```

drift はテーブル定義からコード生成（build_runner）で型安全なクエリメソッドを作るため、生SQLの文字列ミスがコンパイル時に検出できる。マイグレーションも `MigrationStrategy` として型付きで記述できる。

### hive

```dart
await Hive.initFlutter();
final box = await Hive.openBox<String>('settings');
await box.put('theme', 'dark');
final theme = box.get('theme');
```

### flutter_secure_storage（機密情報専用）

```dart
const storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);
final token = await storage.read(key: 'auth_token');
await storage.delete(key: 'auth_token');
```

**機密情報（認証トークン、パスワード、APIキー等）は必ず `flutter_secure_storage` または環境変数（ビルド時の `--dart-define` 等）へ格納する。これはAskUserQuestionの対象ではなく、一義的に決まるセキュリティ必須事項である。** `shared_preferences` は平文でディスクに保存されるため、機密情報の保存先として使わない。

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- ローカル永続化手段の選択（shared_preferences / sqflite / hive / drift / secure_storage）。保存するデータの構造（単純なキーバリューか、リレーショナルなクエリが必要か）、機密性、既存プロジェクトでの採用実績によって最適解が変わるため、推測で選ばない。
- バックエンドの選択（Firebase / 自前REST API / GraphQL）。既にプロジェクトで決まっている場合は再確認不要。
- `http` と `dio` のどちらを使うか、認証トークンの自動付与やインターセプターが必要になった時点で確認する。

確認不要な場面:
- 機密情報の保存先を `flutter_secure_storage` または環境変数にすること（セキュリティ必須事項として一義的に決める）。
- 通信処理をUI層から分離しリポジトリ層に隔離すること（クリーンコードの原則として一義的に決める）。
- 既にプロジェクトで永続化/通信手段が導入済みの場合は、その方式を踏襲する。

## チェックリスト

- [ ] 通信処理をリポジトリ層に隔離し、UI層から直接HTTPクライアントを呼んでいない
- [ ] HTTPステータスエラー・デコードエラー・オフラインを区別して扱っている
- [ ] `http.Client` / `Dio` インスタンスを注入可能にし、テスト時にモック差し替えができる
- [ ] ローカル永続化手段をデータ構造・機密性から選定した（不明な場合はAskUserQuestionで確認した）
- [ ] 機密情報を `flutter_secure_storage` または環境変数に格納している（`shared_preferences` に平文保存していない）
- [ ] Firebaseを使う場合、`firebase_core` の初期化を `main()` の最初で行っている
- [ ] Firebaseプラットフォーム自体の深掘り（Rules/Functions）が必要な場合は `cloud:developing-firebase` を参照した
