# アーキテクチャパターン

## 概要

このリファレンスは、Flutterアプリのレイヤ分離とアーキテクチャパターン（Clean Architecture、BLoCパターン、MVVM、素朴なlayered構成）を扱う。developing-flutter-apps のINSTRUCTIONS.mdから「アプリ全体の構造を設計したい」「レイヤをどう分けるか決めたい」タスクでルーティングされる想定である。状態管理ライブラリ自体（setState/Provider/Riverpod/BLoC(Cubit)/Redux/GetX）の選定と実装はSTATE-MANAGEMENT.mdが担当し、本リファレンスはそれらを「どのレイヤに配置するか」というアプリ全体構造の観点を扱う。

## レイヤ分離の基本原則

アプリが小さいうちはWidget内に直接ロジックを書いても問題ないが、画面数やチーム人数が増えるにつれて次の問題が顕在化する。

- UIコードとビジネスロジックが混在し、ロジックだけを単体テストできない
- 同じデータ取得処理を複数の画面で重複して書いてしまう
- データソース（API/DB）を差し替える際にUIコードまで変更が波及する

これらを避けるため、責務ごとにレイヤを分離する。分離の度合いはアプリの規模に応じて選ぶべきで、小規模アプリに大規模向けの層構造を持ち込むと、かえって見通しを悪くする（過剰設計）。

| アプリ規模 | 推奨構成 |
|---|---|
| 小規模（画面数が少ない、個人開発） | 素朴なlayered構成（UI / サービス / データの3層） |
| 中規模（チーム開発、機能追加が続く） | MVVM |
| 大規模（複数チーム、長期保守、複雑な業務ロジック） | Clean Architecture |
| リアルタイム性・イベント駆動が中心 | BLoCパターン |

## Clean Architecture

Clean Architectureは、依存関係を「外側から内側」への一方向に限定する設計思想である。アプリの核となるビジネスロジック（ドメイン層）は、UIフレームワークやデータベースといった外側の実装詳細に依存しない。これにより、UIやデータソースを差し替えてもビジネスロジックへの影響を局所化できる。

### 層構成

| 層 | 責務 | 依存先 |
|---|---|---|
| Entities（エンティティ） | アプリのコアとなる業務モデル（User、Taskなど） | なし |
| Use Cases（ユースケース/インタラクター） | エンティティに対する具体的な操作（GetUser、AddTaskなど） | Entities、Repository抽象 |
| Repositories（リポジトリ抽象） | データソースへのアクセスを抽象化するインターフェース | Entities |
| Data層 | Repository抽象の実装。API呼び出し、DB操作の実体 | Repositories（実装側） |
| UI層（Presentation） | Widgetとその状態管理。Use Caseを呼び出すだけの薄い層 | Use Cases |

依存の方向は常に「UI層 → Use Cases → Repositories(抽象) ← Data層（実装）」であり、Data層はRepository抽象を実装する形でUse Cases側の抽象に依存する（依存性逆転）。

### 実装例

```dart
// Entities
class Task {
  const Task({required this.id, required this.title, this.isDone = false});
  final String id;
  final String title;
  final bool isDone;
}

// Repository抽象（ドメイン層が定義し、データ層が実装する）
abstract interface class TaskRepository {
  Future<List<Task>> fetchTasks();
  Future<void> addTask(String title);
}

// Use Case
class FetchTasksUseCase {
  const FetchTasksUseCase(this._repository);
  final TaskRepository _repository;

  Future<List<Task>> call() => _repository.fetchTasks();
}

// Data層（Repository抽象の実装）
class RemoteTaskRepository implements TaskRepository {
  const RemoteTaskRepository(this._api);
  final TaskApi _api;

  @override
  Future<List<Task>> fetchTasks() async {
    final dtoList = await _api.fetchTasks();
    return dtoList.map((dto) => Task(id: dto.id, title: dto.title)).toList();
  }

  @override
  Future<void> addTask(String title) => _api.createTask(title);
}

// UI層（Use Caseを呼び出すだけの薄いWidget）
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({required this.fetchTasks, super.key});
  final FetchTasksUseCase fetchTasks;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Task>>(
      future: fetchTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return ListView(
          children: snapshot.data!.map((t) => ListTile(title: Text(t.title))).toList(),
        );
      },
    );
  }
}
```

Use CaseやRepository抽象はテスト対象として単体テストしやすく、`TaskRepository` をモック実装に差し替えれば、実際のAPIやDBなしでUse Caseの振る舞いを検証できる。

## BLoCパターン（アーキテクチャとして）

BLoC（Business Logic Component）は、UIとビジネスロジックをStream経由のイベント/状態でやり取りするパターンである。STATE-MANAGEMENT.mdで扱う `flutter_bloc` パッケージのBloc/Cubitは、このパターンを実装する具体的な手段の1つであり、本リファレンスでは「アプリ全体の構造としてBLoCを採用する」という観点に絞る。

BLoCパターンの骨格は次の3要素である。

- Event: ユーザー操作やトリガーを表す入力（ボタン押下、データ取得要求など）
- State: UIに表示すべきデータやUI状態（loading/success/errorなど）
- Bloc: Eventを受け取りStateを出力する変換ロジック。UIから完全に独立してテストできる

```dart
sealed class TaskEvent {}
class TaskRequested extends TaskEvent {}

sealed class TaskState {}
class TaskLoading extends TaskState {}
class TaskLoaded extends TaskState {
  TaskLoaded(this.tasks);
  final List<Task> tasks;
}
class TaskLoadError extends TaskState {
  TaskLoadError(this.message);
  final String message;
}

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  TaskBloc(this._repository) : super(TaskLoading()) {
    on<TaskRequested>((event, emit) async {
      emit(TaskLoading());
      try {
        final tasks = await _repository.fetchTasks();
        emit(TaskLoaded(tasks));
      } catch (e) {
        emit(TaskLoadError(e.toString()));
      }
    });
  }

  final TaskRepository _repository;
}
```

アプリ全体をBLoCパターンで構成する場合、画面ごとにBlocを持ち、BlocがRepository層（Clean Architectureで言うData層相当）を呼び出す。BLoCパターン単体はレイヤ分離の粒度を規定しないため、大規模アプリではBLoCパターンとClean Architectureの層構成（Repository抽象の導入等）を併用することが多い。

## MVVM（Model-View-ViewModel）

MVVMは、View（UI）とModel（データ）の間にViewModelを挟み、ViewModelがModelのデータをView向けに整形する責務を持つパターンである。ViewはViewModelの状態を購読して描画するだけで、ロジックを持たない。

| 要素 | 責務 |
|---|---|
| Model | データと業務ロジック |
| View | UIの描画とユーザー入力の送出 |
| ViewModel | Modelのデータを整形し、Viewの状態として公開する |

```dart
// Model
class Task {
  const Task({required this.id, required this.title, this.isDone = false});
  final String id;
  final String title;
  final bool isDone;
}

// ViewModel
class TaskListViewModel extends ChangeNotifier {
  TaskListViewModel(this._repository);
  final TaskRepository _repository;

  List<Task> _tasks = [];
  List<Task> get tasks => List.unmodifiable(_tasks);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _tasks = await _repository.fetchTasks();
    _isLoading = false;
    notifyListeners();
  }
}

// View
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({required this.viewModel, super.key});
  final TaskListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) return const CircularProgressIndicator();
        return ListView(
          children: viewModel.tasks.map((t) => ListTile(title: Text(t.title))).toList(),
        );
      },
    );
  }
}
```

MVVMは中規模アプリでよく採用される。Clean ArchitectureのようにUse Case/Repository抽象まで層を分けず、ViewModelが直接Repositoryを呼ぶ分、記述量が少ない。業務ロジックが複雑化してViewModelが肥大化してきたら、Use Case層を追加してClean Architectureへ寄せる移行がしやすい設計にしておく。

## 素朴なlayered構成

画面数が少ない小規模アプリや個人開発では、Clean ArchitectureやMVVMの層構造がオーバーヘッドになることがある。その場合は「UI / サービス / データ」程度の3層に留め、必要になった時点で層を追加する方が合理的である。

```dart
// データ層: APIやDBを直接叩く
class TaskApi {
  Future<List<Task>> fetchTasks() async { /* ... */ }
}

// サービス層: 複数のデータソースをまたぐ処理や簡単な変換のみ
class TaskService {
  const TaskService(this._api);
  final TaskApi _api;

  Future<List<Task>> loadTasks() => _api.fetchTasks();
}

// UI層: サービスを直接呼ぶ
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({required this.service, super.key});
  final TaskService service;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}
```

素朴な構成であっても、通信処理をWidget内に直接書かずサービス層に隔離する原則は守る。これにより、後からMVVMやClean Architectureへ段階的に移行する際の変更範囲を小さくできる。

## アーキテクチャの選び方

特定のアーキテクチャ名を採用すること自体を目的化しない。最も単純な構成から始め、次の兆候が出た時点でより厳密な層分離を導入する。

- 同じロジックがWidget間で重複し始めた
- ロジックの単体テストが書きにくい（Widgetを介さないとテストできない）
- データソースの差し替え（モック化、API変更）がUIコードの変更を伴う
- チームメンバーが増え、担当領域の境界を明確にする必要が生じた

| 兆候 | 対応 |
|---|---|
| ロジックの重複 | サービス層/ViewModelへの抽出 |
| テスト困難 | Repository抽象の導入（依存性逆転） |
| データソース差し替えの波及 | Clean Architectureへの移行 |
| リアルタイム/イベント駆動が中心 | BLoCパターンの採用 |

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- アーキテクチャパターンの選択(Clean Architecture / BLoCパターン / MVVM / 素朴なlayered構成)。アプリの規模、チーム人数、既存コードベースの構成、状態管理ライブラリの選定(STATE-MANAGEMENT.md)と密接に関わるため、推測で選ばない。
- 既存プロジェクトに複数のアーキテクチャパターンが混在している場合、統一するか各機能ごとに許容するか。
- 小規模構成から本格的な層分離への移行タイミング。

確認不要な場面:
- 通信処理・永続化処理をUI層(Widget)から分離しサービス層/リポジトリ層に隔離すること(規模を問わず一義的に決める)。
- 既にプロジェクトでアーキテクチャパターンが決まっている場合は、その方式を踏襲する。

## チェックリスト

- [ ] アプリ規模・チーム構成からアーキテクチャパターンを選定した(不明な場合はAskUserQuestionで確認した)
- [ ] UIコードとビジネスロジックが分離されており、ロジックをWidgetなしで単体テストできる
- [ ] データソース(API/DB)へのアクセスがRepository抽象等を介しており、UI層から直接呼ばれていない
- [ ] 採用したパターンとSTATE-MANAGEMENT.mdで選定した状態管理ライブラリの役割分担が明確である
- [ ] 小規模構成で開始した場合、将来の層追加を妨げない依存注入の形にしている
- [ ] 特定のアーキテクチャ名の採用を目的化せず、現在の複雑度に見合った層分離になっている
