# デザインシステム構築ガイド

デザインシステム（DS）の新規構築・再設計・組織導入・パターンライブラリ整備のための実践ガイド。

---

## 1. When to Use

このスキルを使用するタイミング:

| ユースケース | 具体的な状況 |
|-------------|-------------|
| **DS新規構築** | 製品が安定しチームが5名以上に成長した段階でのシステム設計 |
| **既存DS評価・再構築** | デザイン負債の蓄積・不整合の増大・複数プロダクトへの展開時 |
| **組織導入計画** | ステークホルダー説得・ROI試算・導入ロードマップ策定 |
| **パターンライブラリ構築** | インターフェースインベントリ→パターン定義→ライブラリ整備 |
| **DS立ち上げ・浸透** | 小さく始めて組織に浸透させる実践プロセス → [STARTING-GUIDE.md](references/STARTING-GUIDE.md) |
| **コンテンツ策定** | ブランド・UI・コンテンツ・運用ガイドラインの作り方 → [CONTENT-GUIDELINES.md](references/CONTENT-GUIDELINES.md) |
| **他組織の事例参照** | 多組織のDS実践パターンから学ぶ → [CASE-STUDIES.md](references/CASE-STUDIES.md) |
| **合意形成の実践** | 企画書作成後の5チャネル活用・反対意見対処・繰り返しコミュニケーション → [ORGANIZATION-STRATEGY.md](references/ORGANIZATION-STRATEGY.md) |
| **DS更新周知・運用見直し** | 更新周知6ステップ・形骸化防止・運用主体者パターン（横断/単一）→ [IMPLEMENTATION-OPERATIONS.md](references/IMPLEMENTATION-OPERATIONS.md) |

**このスキルを使わないケース（→ 別スキルへ）:**

| 要求 | 代わりに使うスキル |
|------|------------------|
| 個別UIコンポーネントのスタイル調整 | `applying-design-guidelines` |
| FigmaデザインのコードへのHTML/CSS変換 | `implementing-design` |
| shadcn/uiでのコンポーネント実装 | `designing-frontend` |
| Tailwind CSS設定・デザイントークン設定 | `styling-with-tailwind` |

---

## 2. Structure

このスキルの構成ファイル:

```
skills/building-design-systems/
├── SKILL.md                        # エントリポイント
├── INSTRUCTIONS.md                 # このファイル（メインガイド）
└── references/
    ├── FOUNDATIONS.md              # DSの基礎・定義・歴史・6構成要素・導入判断
    ├── DESIGN-PATTERNS.md          # 機能/知覚パターン・原則・共有言語・体系化プロセス
    ├── UI-PATTERNS-CATALOG.md      # 20+具体UIパターン・組み合わせ手法・IA原則
    ├── ANTI-PATTERNS.md            # アンチパターン・Design Smell・ダークパターン
    ├── ORGANIZATION-STRATEGY.md    # 組織戦略・ステークホルダー説得・システムパラメータ
    ├── IMPLEMENTATION-OPERATIONS.md # 実装プロセス・パターンライブラリ構築・測定・維持
    ├── FIGMA-DESIGN-TOKENS.md      # Figmaデザイントークン設計（3層構造・実装手順）
    ├── FIGMA-PATTERN-LIBRARY.md    # Figmaパターンライブラリ構築・ガイドライン3原則
    ├── FIGMA-CODE-INTEGRATION.md   # FigmaとコードのCI/CD連携・エンジニア連携実践
    ├── STARTING-GUIDE.md           # DS立ち上げ・浸透・チーム構成・運用の実践ガイド
    ├── CONTENT-GUIDELINES.md       # DSコンテンツ（ガイドライン）の策定プロセス
    └── CASE-STUDIES.md             # 多組織のDS実践パターン・自己診断フレームワーク
```

### 各リファレンスの役割

| ファイル | 読むべきタイミング |
|---------|-----------------|
| [FOUNDATIONS.md](references/FOUNDATIONS.md) | DSとは何かの基礎を確認したいとき・用語の整理・導入タイミング判断 |
| [DESIGN-PATTERNS.md](references/DESIGN-PATTERNS.md) | パターンの分類・定義プロセス・共有言語の構築・CEV命名パターン |
| [UI-PATTERNS-CATALOG.md](references/UI-PATTERNS-CATALOG.md) | 具体的なUIパターンの選択・組み合わせ・IA設計 |
| [ANTI-PATTERNS.md](references/ANTI-PATTERNS.md) | 問題のあるパターンの識別・デザイン負債の管理 |
| [ORGANIZATION-STRATEGY.md](references/ORGANIZATION-STRATEGY.md) | 組織への導入・ステークホルダー説得・体制設計・企画書テンプレート・合意形成パターン |
| [IMPLEMENTATION-OPERATIONS.md](references/IMPLEMENTATION-OPERATIONS.md) | 実装の進め方・パターンライブラリ構築・更新周知フレームワーク・運用主体者パターン |
| [FIGMA-DESIGN-TOKENS.md](references/FIGMA-DESIGN-TOKENS.md) | Figmaデザイントークン3層設計・カラー/タイポグラフィ実装手順 |
| [FIGMA-PATTERN-LIBRARY.md](references/FIGMA-PATTERN-LIBRARY.md) | Figmaパターンライブラリ構築・ファイル分割・ガイドライン3原則 |
| [FIGMA-CODE-INTEGRATION.md](references/FIGMA-CODE-INTEGRATION.md) | FigmaとコードのCI/CD連携・Storybook統合・エンジニア連携実践 |
| [STARTING-GUIDE.md](references/STARTING-GUIDE.md) | DSを小さく始めて浸透させる実践プロセス・チーム構成・運用ツール |
| [CONTENT-GUIDELINES.md](references/CONTENT-GUIDELINES.md) | ブランド・UI・コンテンツ・運用ガイドラインの策定プロセス |
| [CASE-STUDIES.md](references/CASE-STUDIES.md) | 多組織のDS実践パターン・自己診断フレームワーク |

---

## 3. Design System Overview

### デザインシステムの定義

**デザインシステム = 相互接続されたパターンの集合 + 共有されたプラクティスの集合**

- **パターン**: インターフェースを構成する繰り返し要素（ユーザーフロー・インタラクション・コンポーネント・スタイル等）
- **プラクティス**: パターンをどのように作り・共有し・使うかの方法（特にチーム協働における）

効果的なDSが満たすべき2条件:
1. デザインプロセスのコスト効率（パターンの再発明をしない）
2. プロダクト目的に対するUXの効率と満足度

### DSと関連用語の違い

| 用語 | スコープ | 特徴 |
|------|---------|------|
| スタイルガイド | ビジュアル言語の定義 | 静的ドキュメント。カラー・タイポグラフィ等 |
| コンポーネントライブラリ | UIコンポーネントの集合 | ライブコードを含む場合もある |
| パターンライブラリ | デザインパターンの収集・保存 | DS強化のツール（DSそのものではない） |
| **デザインシステム** | 上記を含む上位概念 | ライブコード例・原則・ルール・ガイドライン |

### 要素の階層構造

```
リージョン（Region）
    └── ナビゲーション・検索エリア等の大きなパラダイム
コンポーネントグループ（Component Group）
    └── 複数コンポーネントが集まった大きな単位
コンポーネント（Component）
    └── フォーム・カード・ドロップダウン等
エレメント（Element）
    └── ラベル・アイコン・テキスト（最小単位）
```

---

## 4. Core Frameworks

### フレームワーク1: 6構成要素モデル

| 構成要素 | 内容 | 例 |
|---------|------|-----|
| **Layout** | スペーシング・グリッドシステム | 8pxグリッド・スペーシングスケール |
| **Styles** | ビジュアル言語のコアアスペクト | カラー・アイコノグラフィ・タイポグラフィ |
| **Components** | インターフェースのコア要素 | ボタン・フォームフィールド |
| **Regions** | 大きなデザインパラダイム | ナビゲーション・検索エリア |
| **Content** | 言語・トーン・用語集 | マイクロコピー・エラーメッセージ |
| **Usability** | アクセシビリティ・国際化 | WCAG基準・i18n対応 |

### フレームワーク2: 機能パターン vs 知覚パターン

| | 機能パターン | 知覚パターン |
|--|------------|------------|
| **目的** | ユーザー行動を可能にし促進する | ブランドの感覚・美的品質を定義する |
| **定義基準** | 促進する行動によって定義（見た目ではない） | 表現する感情・美的品質によって定義 |
| **安定性** | スタイル変化後も行動の本質は変わらない | プロダクトのビジョン・ブランドに紐づく |
| **例** | カートに追加・サインアップ・検索 | 信頼性・活発さ・温かみ・洗練 |
| **体系化手法** | 目的指向インベントリ・パターンマップ | ムードボード・スタイルタイル・エレメントコラージュ |
| **詳細** | [DESIGN-PATTERNS.md](references/DESIGN-PATTERNS.md) | [DESIGN-PATTERNS.md](references/DESIGN-PATTERNS.md) |

### フレームワーク3: システムパラメータ3軸

| 軸 | Strict（厳格） | Loose（緩やか） |
|----|--------------|---------------|
| **規則の厳密性** | 逸脱に承認プロセスが必要・一貫性最優先 | ガイドラインとして機能・実験を歓迎 |
| **向いている組織** | 大規模・ブランド統一が重要 | 少数精鋭・創造性重視 |

| 軸 | Modular | Integrated |
|----|---------|------------|
| **モジュール性** | UIを独立した再利用可能なパーツに分解 | コンポーネントが密に連携・全体として機能 |
| **トレードオフ** | 高い初期設計コスト・断片化リスク | 全体最適化が困難・変更コスト高 |

| 軸 | Centralized | Distributed |
|----|------------|-------------|
| **組織分散度** | 専任チームが管理・品質管理容易 | 複数チームが貢献・スケーラブル |
| **リスク** | ボトルネックになりやすい | ガバナンスが複雑 |

**ケーススタディ詳細**: [ORGANIZATION-STRATEGY.md](references/ORGANIZATION-STRATEGY.md)

### フレームワーク4: 3次元の価値フレームワーク

| 次元 | 主なステークホルダー | 訴求ポイント |
|------|-------------------|------------|
| **従業員レベル** | デザイナー・エンジニア・PM | 繰り返し作業削減・創造的余白・認知負荷軽減 |
| **組織レベル** | 経営層・プロダクト責任者 | コスト削減（設計→開発→リリース後の費用逓増防止）・アジリティ向上 |
| **ユーザーレベル** | プロダクトチーム全体 | 体験一貫性・改善速度・従業員幸福→複雑フロー集中 |

**説得戦略詳細**: [ORGANIZATION-STRATEGY.md](references/ORGANIZATION-STRATEGY.md)

---

## 5. Decision Guide

### ステップ1: DSが今必要かを判断する

```
【組織の年齢】
早期スタートアップ（全てが流動的） → まだ待つ
製品が安定・ピボット頻度が低下 → 進む ↓

【チームサイズ】
デザイナー・エンジニア数名以下 → まだ待つ
5名以上または成長見込み → 進む ↓

【作業パターン】
複数プロダクト・複数チーム・高頻度の繰り返し作業がある → 今すぐ始める
単一プロダクト・少人数・頻繁な会話で解決可能 → 軽量な共有ドキュメントで十分
```

### ステップ2: 何から始めるかを決める

| 組織タイプ | 推奨する開始点 |
|----------|--------------|
| 単一プロダクト | レイアウト + スタイルを先に定義（全コンポーネントの基盤） |
| 複数クライアント（エージェンシー） | 中核コンポーネント特定 → テーマ対応レイアウトシステム |
| ステークホルダーの支持がない | インベントリ作成から着手し、データ蓄積でビジネスケースを構築 |

### ステップ3: 既存DSを評価・再構築する場合

インターフェースインベントリの実施 → 目的指向分類 → 重複・不整合の特定 → 段階的再構築

**詳細手順**: [IMPLEMENTATION-OPERATIONS.md](references/IMPLEMENTATION-OPERATIONS.md)

### ステップ4: システムパラメータを決定する

```
ブランドの統一性が収益・信頼に直結する → Strict寄り
イノベーション・実験が重要 → Loose寄り

UIが独立した再利用可能な部品に分解できる → Modular
コンポーネント間の密連携が本質的に重要 → Integrated

専任チームが確保できる・標準化が最優先 → Centralized
エンジニアリング文化が強い・スケーラビリティ優先 → Distributed
```

### ステップ5: 合意形成を進める

企画書完成後、ステークホルダーの合意を取り付けるための5チャネル:

| チャネル | 推奨タイミング |
|---------|--------------|
| **ミーティング（全体説明会）** | 企画書完成後・全関係者への一斉説明 |
| **1on1（個別コミュニケーション）** | 懸念を持つ関係者の早期特定・解消 |
| **ワークショップ** | DS設計方針を協働で決定したいとき |
| **定期的な進捗共有** | 長期プロジェクトのモメンタム維持 |
| **ユーザーインタビュー** | UX改善が目的に含まれるとき |

> 合意形成は一度で完結しない。繰り返しのコミュニケーションで徐々に詳細を詰め、意見を柔軟に取り入れながら企画書を最適化し続ける。

**詳細**: [ORGANIZATION-STRATEGY.md](references/ORGANIZATION-STRATEGY.md)

### ステップ6: パターンを定義・体系化する

**機能パターンの体系化フロー:**
1. **準備**: プロダクトのコア画面10〜12を選択・多職種チーム編成
2. **行動特定**: 各画面でユーザーが達成しようとしていることを洗い出す
3. **グループ化**: 同じ行動を支える要素を全画面から収集してグループ化
4. **パターン定義**: グループを「統合」か「分離」かを特異性スケールで判断
5. **命名**: 行動・目的を反映した名前（見た目・コンテンツタイプではない）

**知覚パターンの体系化フロー:**
1. **シグネチャパターン**: ブランドを最もよく表現するユニークな知覚パターンから始める
2. **カラー体系化**: アクセシビリティ基準を満たす組み合わせのみ採用
3. **アニメーション**: ブランドの感情表現と機能的フィードバックを分離して定義
4. **ボイス&トーン**: ブランド個性・価値観・禁止用語・文章ルールを定義

---

## 6. Quick Reference

### 他スキルとの使い分けガイド

| ユーザーの要求 | 選択すべきスキル | 選択しないスキル |
|------------|---------------|---------------|
| 「デザインシステムを新規構築したい」 | `building-design-systems` | — |
| 「DSを小さく立ち上げたい」 | `building-design-systems` → [STARTING-GUIDE.md](references/STARTING-GUIDE.md) | — |
| 「DSコンテンツを何からどう作るか知りたい」 | `building-design-systems` → [CONTENT-GUIDELINES.md](references/CONTENT-GUIDELINES.md) | — |
| 「他組織のDS事例を参考にしたい」 | `building-design-systems` → [CASE-STUDIES.md](references/CASE-STUDIES.md) | — |
| 「パターンライブラリを整備したい」 | `building-design-systems` | — |
| 「組織にDS導入を提案したい」 | `building-design-systems` | — |
| 「DS導入の合意を取り付けたい」 | `building-design-systems` → [ORGANIZATION-STRATEGY.md](references/ORGANIZATION-STRATEGY.md) | — |
| 「DS更新を周知したい」 | `building-design-systems` → [IMPLEMENTATION-OPERATIONS.md](references/IMPLEMENTATION-OPERATIONS.md) | — |
| 「DS運用の形骸化を防ぎたい」 | `building-design-systems` → [IMPLEMENTATION-OPERATIONS.md](references/IMPLEMENTATION-OPERATIONS.md) | — |
| 「DS運用を専任担当者と兼任どちらにすべきか」 | `building-design-systems` → [IMPLEMENTATION-OPERATIONS.md](references/IMPLEMENTATION-OPERATIONS.md) | — |
| 「ボタンの色やスペーシングを調整したい」 | `applying-design-guidelines` | `building-design-systems` |
| 「Figmaデザインをコードに変換したい」 | `implementing-design` | `building-design-systems` |
| 「shadcn/uiでコンポーネントを作りたい」 | `designing-frontend` | `building-design-systems` |
| 「Tailwindのデザイントークンを設定したい」 | `styling-with-tailwind` | `building-design-systems` |

### DS失敗パターン（要注意）

| 失敗パターン | 対策 |
|------------|------|
| 初期の賛同不足 | ロール別のメリットを具体的に提示し、問題解決の視点から会話を始める |
| 過度・過速な取り組み | ペースを守り、本当に必要なものを理解してからコミットする |
| 完璧主義 | 「完成する」ことは決してない前提でイテレーションを続ける |
| メンテナンス不足 | 自己文書化の仕組みを最初から設計する |
| 他社DSへの羨望 | 自組織のニーズに集中し、他社DSはインスピレーションとして活用する |

---

## 7. AskUserQuestion Pattern

DS構築・支援の際にユーザーに確認すべき判断ポイント:

### 初期状況の把握

```
1. 新規構築ですか、それとも既存DSの評価・改善ですか？
2. チームの規模（デザイナー・エンジニア数）と組織の成熟度は？
3. 単一プロダクトですか、複数プロダクト（エージェンシー型）ですか？
4. ステークホルダー（経営層・PM等）の支持は既に得られていますか？
```

### システム設計の判断

```
5. ブランドの統一性とチームの柔軟性、どちらを優先しますか？
   （Strict vs Loose）
6. UIコンポーネントを独立したパーツとして管理しますか、
   それとも密連携した統合体験として設計しますか？
   （Modular vs Integrated）
7. DSを専任チームが管理しますか、
   それとも全チームがコントリビューターになる分散モデルですか？
   （Centralized vs Distributed）
```

### パターン定義の判断

```
8. どの画面・機能がプロダクトの根幹ですか？
   （インベントリ対象の優先順位付け）
9. ユーザーにとって最も重要な「行動」は何ですか？
   （機能パターン定義の起点）
10. ブランドを最もよく表現する「シグネチャ瞬間」はどこですか？
    （知覚パターン定義の起点）
```

### 組織戦略の判断

```
11. どのステークホルダーへの説得が最も重要ですか？
    （コミュニケーション戦略の選択: 外交・教育・営業・広報）
12. DS構築の成功をどのようなメトリクスで測定しますか？
    （OKR設定の起点）
13. 合意形成のメインチャネルはどれですか？
    （ミーティング全体説明 / 1on1個別対応 / ワークショップ協働）
14. DS運用は専任担当者を置く横断運用ですか、
    それともデザイナー全員で回す単一運用ですか？
    （複数プロダクト横断 → 担当者あり推奨 / 1プロダクト → 担当者なしも可）
```

---

## リファレンス早見表

| テーマ | 参照先 |
|-------|-------|
| DSの定義・歴史・用語整理 | [FOUNDATIONS.md](references/FOUNDATIONS.md) |
| 機能/知覚パターン・原則・命名・CEV命名パターン | [DESIGN-PATTERNS.md](references/DESIGN-PATTERNS.md) |
| 具体UIパターン20+のカタログ | [UI-PATTERNS-CATALOG.md](references/UI-PATTERNS-CATALOG.md) |
| アンチパターン・Design Smell識別 | [ANTI-PATTERNS.md](references/ANTI-PATTERNS.md) |
| 組織導入・ステークホルダー説得・企画書テンプレート・合意形成パターン | [ORGANIZATION-STRATEGY.md](references/ORGANIZATION-STRATEGY.md) |
| 実装・パターンライブラリ・更新周知フレームワーク・運用主体者パターン | [IMPLEMENTATION-OPERATIONS.md](references/IMPLEMENTATION-OPERATIONS.md) |
| Figmaデザイントークン詳細設計 | [FIGMA-DESIGN-TOKENS.md](references/FIGMA-DESIGN-TOKENS.md) |
| Figmaパターンライブラリ構築・ガイドライン3原則 | [FIGMA-PATTERN-LIBRARY.md](references/FIGMA-PATTERN-LIBRARY.md) |
| FigmaとコードのCI/CD連携・エンジニア連携実践 | [FIGMA-CODE-INTEGRATION.md](references/FIGMA-CODE-INTEGRATION.md) |
| DS立ち上げ・浸透の実践プロセス | [STARTING-GUIDE.md](references/STARTING-GUIDE.md) |
| コンテンツ（ガイドライン）策定プロセス | [CONTENT-GUIDELINES.md](references/CONTENT-GUIDELINES.md) |
| 多組織のDS実践パターン・自己診断 | [CASE-STUDIES.md](references/CASE-STUDIES.md) |

---

## Figmaデザインシステム構築

FigmaのVariables・デザイントークン・コンポーネントを使ったデザインシステム実装ガイド。

> **理論・ガバナンス・組織戦略は上記の各セクションを参照。本セクションはFigma実装の実践手順。**

### ファイル分割の段階

```
Stage 1: モノリシック（1ファイルにすべて・小規模・スタート時）
Stage 2: ライブラリ分離（Library + Design ファイル）
Stage 3: モジュール化（Foundation / Components / Patterns / Design Files）
```

チーム規模（デザイナー人数・プロジェクト数）に応じてStageを選択する。

### デザイントークン3層構造

```
Primitive（プリミティブ）: 生の値。例: blue-500 = #3B82F6
    ↓ 参照
Theme/Alias（テーマ）: ブランド・テーマ別エイリアス
    ↓ 参照
Semantic（セマンティック）: 用途ベース。例: color/background/default
```

- **2層（Primitive + Semantic）**: シンプルで小規模向け
- **3層（Primitive + Theme/Alias + Semantic）**: テーマ切替・ブランド複数対応向け

詳細は [FIGMA-DESIGN-TOKENS.md](references/FIGMA-DESIGN-TOKENS.md) 参照。

### カラーシステム実装手順

1. `_PrimitiveColor` コレクション作成 → 全カラー値を登録
2. `_ThemeColor` コレクション作成 → プリミティブを参照するエイリアスを登録
3. `SemanticColor` コレクション作成（Light / Darkモードあり）→ テーマカラーを参照
4. コレクション名先頭の `_` で非公開設定（内部実装の隠蔽）

**アクセシビリティ**: セマンティックカラーのテキスト/背景の組み合わせで WCAG 2.1 AA（4.5:1以上）を確認。

**ダークモード**: 後から追加する場合でも最初から用途ベースの名前にしておくこと（例: `color/background/default`）。

### タイポグラフィシステム

- フォントサイズは9段階（`font-size/10`〜`font-size/90`）を基本
- コンポジットタイポグラフィトークン（`typography/{context}/{size}/{weight}`）をFigmaのテキストスタイルとして登録
- スタイル名をコード側のトークン名と一致させる

### コンポーネント優先順位

1. **アトム**: ボタン・入力・テキスト・アイコン（最頻出）
2. **モレキュール**: フォームグループ・カード・ナビゲーションアイテム
3. **オーガニズム**: ヘッダー・サイドバー・モーダル・テーブル
4. **テンプレート**: ページレイアウトの雛形

### コード連携

| 方法 | 規模 |
|------|------|
| 手動エクスポート | 小規模・シンプル |
| Figmaプラグイン自動同期（Tokens Studio等） | 中規模 |
| Figma REST APIを使ったCI/CD連携 | 大規模 |

- **Storybook統合**: デザイントークンのリファレンスページをStorybookのDocsとして追加
- **変更管理**: デザイン変更（Figma）とコード変更（PR）は対になることを明示

詳細は [FIGMA-CODE-INTEGRATION.md](references/FIGMA-CODE-INTEGRATION.md) 参照。
