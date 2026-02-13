# CI/CDパイプライン設計

CI/CDパイプラインの設計と運用のベストプラクティスをカバーします。テスト戦略の詳細は `testing-code` スキルを、セキュリティの詳細は `securing-code` スキルを、それぞれ参照してください。

---

## 1. バージョン管理戦略

### Trunk-Based Development vs Git Flow

| 観点 | Trunk-Based Development | Git Flow |
|-----|-------------------------|----------|
| **ブランチ戦略** | 1つのトランク（main）にコミット | develop/feature/release/hotfixブランチ |
| **リリース頻度** | 高頻度（日次〜週次） | 低〜中頻度（週次〜月次） |
| **Feature Flags** | 必須（未完成機能の隠蔽） | 任意 |
| **マージ頻度** | 日次複数回 | フィーチャー完成時 |
| **コンフリクト解決** | 小さく頻繁に解決 | 大きなコンフリクトのリスク |
| **CI/CD統合** | 容易（常にmainが最新） | 複雑（複数ブランチの調整） |
| **チーム規模** | 小〜大規模（高速リリース文化） | 中〜大規模（リリース計画重視） |

### ブランチ戦略選定基準

```yaml
AskUserQuestion:
  質問: "リリース頻度とチーム規模から最適なブランチ戦略を選択してください"
  選択肢:
    - label: "Trunk-Based Development"
      条件:
        - リリース頻度が日次〜週次
        - Feature Flagsを導入済み/導入可能
        - チームが小さなコミットを頻繁にマージする文化
      推奨: "CI/CD高速化、コンフリクト削減"
    - label: "Git Flow"
      条件:
        - リリースサイクルが長期（週次〜月次）
        - 複数バージョンの並行サポートが必要
        - 厳格なリリース承認プロセス
      推奨: "計画的リリース管理"
    - label: "GitHub Flow"
      条件:
        - 中間的なリリース頻度
        - mainブランチが常にデプロイ可能
        - Feature Branchはmainから分岐し、PR経由でマージ
      推奨: "Git Flowとの中間的なバランス"
```

---

## 2. ビルドシステムの原則

### ビルドの核心原則

1. **再現性 (Reproducibility)**: 同じコードから常に同じビルド結果
   - バージョン固定: `package-lock.json`, `go.mod`, `requirements.txt`
   - コンテナベースビルド: Docker Multi-stage build
   - 環境変数の分離: ビルド時パラメータ vs ランタイムパラメータ

2. **高速化 (Speed)**: 開発者のフィードバックループ短縮
   - **並列ビルド**: マルチコアCPU活用（例: `make -j$(nproc)`）
   - **増分ビルド**: 変更ファイルのみ再ビルド
   - **キャッシュ**: 依存関係キャッシュ、ビルドアーティファクトキャッシュ

3. **Immutable Artifacts**: ビルド成果物のイミュータビリティ
   - タグ付けルール: `<version>-<commit-sha>-<build-number>`
   - レジストリ保存: Docker Registry, Artifactory, npm registry
   - 環境間で同一アーティファクトを使用（dev → staging → prod）

### 主要ビルドツール比較

| 言語/フレームワーク | ツール | 特徴 |
|----------------|-------|------|
| JavaScript/TypeScript | npm, pnpm, Yarn | パッケージ管理 + スクリプトランナー |
| Java | Maven, Gradle | 依存管理 + ビルドライフサイクル |
| Go | go build, Makefile | シンプルなビルドツールチェーン |
| Python | pip, Poetry, Hatch | 依存管理 + 仮想環境 |
| .NET | MSBuild, dotnet CLI | プロジェクトファイルベース |

---

## 3. テスト戦略

### テストピラミッド

```
        /\
       /E2E\      ← 少数（高コスト、低速、広範囲）
      /______\
     /        \
    /統合テスト \  ← 中程度（中コスト、中速、統合点検証）
   /___________\
  /             \
 /ユニットテスト  \ ← 多数（低コスト、高速、狭範囲）
/_________________\
```

- **ユニットテスト（70-80%）**: 関数/クラス単位、高速、モック活用
- **統合テスト（15-25%）**: API/DB統合、実環境に近い
- **E2Eテスト（5-10%）**: ブラウザ操作、クリティカルパスのみ

**詳細は `testing-code` スキル参照。**

### Shift-Left Testing

開発プロセスの早い段階でテストを実施し、バグの早期発見コストを削減する:

1. **開発者ローカル実行**: Pre-commit hooks（lint, unit test）
2. **PR時実行**: 統合テスト、セキュリティスキャン
3. **マージ後実行**: E2Eテスト、パフォーマンステスト

---

## 4. CIパイプライン設計

### 典型的なCIステージ

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌────────────┐   ┌──────────┐
│ Lint &   │ → │ Build    │ → │ Test     │ → │ Security   │ → │ Artifact │
│ Format   │   │          │   │          │   │ Scan       │   │ Publish  │
└──────────┘   └──────────┘   └──────────┘   └────────────┘   └──────────┘
```

| ステージ | 内容 | ツール例 | 失敗時アクション |
|---------|-----|---------|----------------|
| **Lint & Format** | コードスタイルチェック | ESLint, Prettier, Ruff | PR Block |
| **Build** | コンパイル、依存解決 | npm, Gradle, Docker | PR Block |
| **Test** | Unit/Integration テスト | Jest, Vitest, pytest | PR Block |
| **Security Scan** | 脆弱性スキャン | Snyk, Trivy, CodeQL | PR Block（高リスク） |
| **Artifact Publish** | イミュータブルアーティファクト作成 | Docker push, npm publish | アラート |

### 並列化とキャッシュ

- **並列実行**: Lint/Test/Security Scanを独立したジョブとして並列実行
- **依存キャッシュ**: `node_modules`, `.m2`, `venv` をキャッシュ
- **ビルドキャッシュ**: Docker layer cache, npm cache

### 高速フィードバックの原則

1. **失敗の早期検出**: Lintを最初に実行し、即座に失敗通知
2. **並列実行**: 独立したテストスイートを並列化
3. **キャッシュ戦略**: 変更のない依存関係は再取得しない
4. **部分実行**: モノレポでは変更ファイルのみテスト（例: Turborepo, Nx）

---

## 5. CDパイプライン設計

### デプロイ戦略の比較

| 戦略 | 仕組み | ダウンタイム | ロールバック容易性 | リソースコスト | 適用ケース |
|-----|------|------------|----------------|--------------|-----------|
| **Blue-Green** | 2つの環境（Blue/Green）を用意し、新バージョンをGreenにデプロイ後、トラフィックを切替 | なし | 容易（即座にBlueへ戻す） | 高（2倍環境） | 本番環境、ゼロダウンタイム必須 |
| **Canary** | 新バージョンを一部ユーザー（5-10%）に先行公開し、メトリクス監視後に全体展開 | なし | 容易（カナリアトラフィックを0%に） | 中 | リスク低減、段階的検証 |
| **Rolling** | インスタンスを順次更新（例: 10台中2台ずつ） | なし | 中（進行中のロールバックは複雑） | 低（既存環境内） | Kubernetes標準、低リスク |
| **Recreate** | 既存バージョンを停止後、新バージョンをデプロイ | あり | 困難（再デプロイ必要） | 最低 | 開発環境、ダウンタイム許容 |

### デプロイ戦略選定基準

```yaml
AskUserQuestion:
  質問: "デプロイ要件から最適な戦略を選択してください"
  選択肢:
    - label: "Blue-Green Deployment"
      条件:
        - ダウンタイムが許容されない
        - 即座のロールバックが必須
        - リソースコストの2倍が許容可能
      推奨: "本番環境、金融/医療など高可用性要求"
    - label: "Canary Deployment"
      条件:
        - 段階的な検証が重要
        - メトリクス監視体制が整っている
        - 一部ユーザーへの影響を最小化したい
      推奨: "リスク低減、新機能の段階的ロールアウト"
    - label: "Rolling Deployment"
      条件:
        - Kubernetesなどのオーケストレータを使用
        - 順次更新が許容される
        - リソースコストを抑えたい
      推奨: "標準的なクラウドネイティブアプリケーション"
    - label: "Recreate"
      条件:
        - 開発環境またはステージング環境
        - ダウンタイムが許容される
        - シンプルさを優先
      推奨: "非本番環境のみ"
```

---

## 6. Progressive Delivery

### Feature Flags

- **定義**: 機能のオン/オフをコードデプロイと分離
- **ユースケース**:
  - 未完成機能の隠蔽（Trunk-Based Developmentの前提）
  - A/Bテスト
  - 段階的ロールアウト（ユーザーセグメント別）
  - 緊急時の機能無効化

- **ツール**: LaunchDarkly, Unleash, Split.io, AWS AppConfig

### Canary Analysis

- **自動カナリア分析**: メトリクスベースのロールアウト判定
- **Golden Signals監視**:
  - Latency: レイテンシ悪化 → ロールバック
  - Traffic: 予期しないトラフィック増減
  - Errors: エラー率上昇
  - Saturation: リソース使用率

- **ツール**: Flagger（Kubernetes）, AWS CodeDeploy, Argo Rollouts

### A/B Testing

- **目的**: 機能の効果測定（ビジネスメトリクス）
- **手法**: ユーザーをランダムに2グループに分割し、異なるバージョンを提供
- **指標**: コンバージョン率、滞在時間、クリック率

---

## 7. パイプラインのベストプラクティス

### Pipeline as Code

- **宣言的定義**: YAML/JSON/HCLでパイプラインを管理
- **バージョン管理**: `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` をGit管理
- **再利用性**: 共有ワークフロー、テンプレート化

**例**: GitHub Actions Reusable Workflow

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    uses: org/shared-workflows/.github/workflows/test.yml@v1
```

### Immutable Artifacts

- **原則**: ビルド成果物は変更不可（タグ付け、SHA256ハッシュ）
- **環境間共通**: dev/staging/prodで同一アーティファクトを使用
- **トレーサビリティ**: アーティファクトからソースコードのコミットを追跡可能

### Environment Parity

- **Dev/Prod Parity**: 開発環境と本番環境の差異を最小化
- **IaCによる環境再現**: 全環境をコードで管理
- **コンテナ化**: 環境依存性を排除

---

## 8. 関連スキルとの差別化

| トピック | このスキル（practicing-devops） | 詳細スキル |
|---------|-------------------------------|-----------|
| **テスト戦略** | テストピラミッド概要、Shift-Left Testingの原則 | `testing-code`: テストコード実装、Vitest/Playwright詳細 |
| **セキュリティスキャン** | CI/CDパイプラインへの統合方法、ツール選定 | `securing-code`: 脆弱性対策、コードレビュー詳細 |
| **デプロイ戦略** | Blue-Green/Canary/Rolling比較、選定基準 | `developing-terraform`, `managing-docker`: IaC実装、コンテナオーケストレーション |

---

## 9. CI/CD成熟度モデル

| レベル | 特徴 | 実現内容 |
|-------|-----|---------|
| **1. 手動** | 手動ビルド、手動デプロイ | なし |
| **2. 自動ビルド** | CIサーバーでビルド自動化 | Jenkins, GitHub Actions |
| **3. 自動テスト** | ユニット/統合テストの自動実行 | テストピラミッド適用 |
| **4. 自動デプロイ** | ステージング環境への自動デプロイ | Blue-Green, Canary |
| **5. Continuous Deployment** | 本番環境への自動デプロイ（承認なし） | Feature Flags, 自動ロールバック |

---

**次のセクション**:
- [PLATFORM-ENGINEERING.md](./PLATFORM-ENGINEERING.md): ネットワーク・セキュリティ・マルチ環境管理
- [DATA-OBSERVABILITY.md](./DATA-OBSERVABILITY.md): データストア・監視設計
