# HANDOFF-DESIGN.md

デザインハンドオフに必要なスタイル設計・状態管理・インタラクティブコンポーネントのベストプラクティスガイド。

---

## 目次

1. [カラースタイル設計](#カラースタイル設計)
2. [ダークモード対応](#ダークモード対応)
3. [テキストスタイル設計](#テキストスタイル設計)
4. [画面サイズ対応](#画面サイズ対応)
5. [UIスタック（5状態）](#uiスタック5状態)
6. [インタラクティブコンポーネント](#インタラクティブコンポーネント)
7. [ユーザー確認の原則](#ユーザー確認の原則)

---

## カラースタイル設計

カラーやタイポグラフィなど、デザインを構成する最小単位を「デザイントークン」と呼ぶ。カラースタイルとして管理することで、デザインと実装コードの双方の保守性が向上する。

### 命名規則

カラースタイルの命名は以下の構造に従う。

```
[Mode] / [Element] / [Type] (/ [State])
```

| セグメント | 説明 | 例 |
|-----------|------|-----|
| Mode | Light/Dark のどちらかを指定 | `Light`, `Dark` |
| Element | このカラーを適用するUI要素 | `Label`, `Background`, `Button Label`, `Pagination` |
| Type | バリエーションを番号や単語で表現 | `1`, `2`, `Primary` |
| State | 「通常・選択中」などの状態（省略可） | `Default`, `Active` |

**命名例:**

| スタイル名 | 用途 |
|-----------|------|
| `Light/Label/1` | ライトモードのテキスト・アイコン |
| `Light/Label/2` | ライトモードの控えめなテキスト |
| `Light/Background/1` | ライトモードの背景 |
| `Light/Background/2` | ライトモードの暗めな背景 |
| `Dark/Label/1` | ダークモードのテキスト・アイコン |
| `Dark/Background/1` | ダークモードの背景 |
| `Dark/Button Label/1/Default` | ダークモードのボタンラベル（通常） |
| `Dark/Pagination/1/Active` | ダークモードのアクティブなページ指示 |

> 用途が異なれば同じカラー値でも別スタイルとして登録する。
> 例: `Dark/Label/1`（テキスト）と `Dark/Pagination/1/Active`（ページネーション）は #FFFFFF だが用途が異なるため別々に登録。

### 登録・適用フロー

**登録フロー:**

1. コンポーネントを選択 → 右パネルの Selection colors を確認
2. UI Kitのカラーや内部用カラー（バリアントセット境界線等）は登録対象外
3. アプリUIに使用するカラーをスタイルとして登録
4. スラッシュ（`/`）を使うと右パネルでグループ階層化される

**適用フロー:**

1. コンポーネントを優先してスタイル適用（画面より先に）
2. 次にデザインページ（Design）の各画面にスタイルを適用
3. 同じ用途のカラーを重複登録しないよう注意

### カラーパレットの可視化

スタイル一覧ページ（`Styles` 等）を作成し、ライトモード・ダークモードを並べてカラーパレットを俯瞰できるようにする。

```
Colors
Light                  Dark
─────                  ────
Label                  Label
  Label/1                Label/1
  Label/2                Label/2
Background             Background
  Background/1           Background/1
  Background/2           Background/2
Button Label           Button Label
  Button Label/1/Default Button Label/1/Default
Pagination             Pagination
  Pagination/1/Default   Pagination/1/Default
  Pagination/1/Active    Pagination/1/Active
```

両モードを比較することで、対称性が崩れているカラーを早期に発見できる。

---

## ダークモード対応

ダークモードとは、黒を基調とした配色に切り替える機能。ユーザーのOS設定に応じてアプリが自動対応するためには、デザイン段階からの計画が必要。

### コンポーネント対応手順

1. **バリアントの追加**: 各コンポーネントに `Dark Mode` プロパティを追加
   - プロパティ名: `Dark Mode`
   - 値: `false`（初期値）、`true`
2. **カラースタイルの切り替え**: `Dark Mode: true` バリアントで Light → Dark に入れ替え
3. **対称確認**: カラーパレットで両モードの対応関係を視覚確認

**切り替えパターン:**

| 変更前（Light） | 変更後（Dark） |
|----------------|---------------|
| `Light/Label/1` | `Dark/Label/1` |
| `Light/Label/2` | `Dark/Label/2` |
| `Light/Background/1` | `Dark/Background/1` |
| `Light/Story/1/Active` | `Dark/Story/1/Active` |

### カラースタイルの切り替え戦略

- Selection colors から一括でスタイルを切り替えることで効率化
- 同一コンポーネントの `true/false` バリアントをセットで管理することで、画面適用時に `Dark Mode` プロパティを変更するだけで全体が切り替わる

> **判断ポイント**: ダークモード対応をいつから始めるか → [ユーザー確認の原則](#ユーザー確認の原則)参照

---

## テキストスタイル設計

テキスト設定もデザイントークンとして管理する。フォント・サイズ・ウェイト・行間の組み合わせをスタイルとして登録することで、変更が全体に反映される。

### 命名規則

```
[Mode] / [Element] / [Size]
```

**例:** `Light/Body/M`, `Dark/Heading/S`

### タイプスケール設計

| スタイル名 | Font weight | Font size | Line height | 用途 |
|-----------|------------|-----------|-------------|------|
| Caption | Regular | 12 | 16 | 補足的なテキスト |
| Body/S | Regular | 14 | 16 | 小さめな文章 |
| Body/M | Regular | 16 | 24 | 文章・全般的なUI要素 |
| Heading/S | Medium | 14 | 16 | 小さめな見出し |
| Heading/M | Medium | 18 | 24 | 見出し |
| Button Label | Medium | 18 | 24 | ボタンのラベル |

> **ダークモード固有の調整**: 黒背景ではテキストが太く見えるため、Body/S と Body/M の Font weight を `Light` に下げる。同名のスタイルをモードごとに登録し、コンテキストに応じて使い分ける。

### 適用フロー

1. **コンポーネント先行**: Components ページの各コンポーネントにスタイルを適用
2. **画面へ展開**: Design ページの各画面テキストに適用
3. **ライト/ダーク分類**: 画面背景に応じて `Light/` または `Dark/` プレフィックスを選択

**タイポグラフィ一覧の共有**: スタイルを適用したサンプルコンポーネントで Typography 一覧ページを作成し、エンジニアと共有する。

---

## 画面サイズ対応

異なるデバイス幅に対してレイアウトが破綻しないよう、Constraints と Auto Layout を活用する。

### Constraints 設定パターン

| 要素の種類 | 水平方向 | 垂直方向 |
|-----------|---------|---------|
| 全幅コンテナ（ヘッダー、カード等） | Left and right | Top |
| 右端ボタン（戻るボタン等） | Right | Top |
| 中央タイトル | Center | Top |
| スクロールコンテンツ領域 | Left and right | Top and bottom |

**重要な注意点:**
- `Fix position when scrolling` が有効だと Constraints の一部オプションが選択できない場合がある（バグの可能性）
- 変更時は `Fix position when scrolling` を一時的に無効化 → Constraints 変更 → 再有効化

### Auto Layout での可変レイアウト

Auto Layout を活用すれば、画面幅変更に対してコンポーネント内部が自動調整される。

```
┌─────────────────────────────────┐
│ App Header                       │  ← Left and right
│  [Logo]          [Btn][Btn][Btn] │  ←             Right
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Post                             │  ← Left and right
│  [Avatar] [Text ──────────────] │  ← Left and right (内部要素)
│           [Text ──────────────] │
│  [Btn1] [Btn2] [Btn3]     [Btn4]│  ← Button4 は Right
└─────────────────────────────────┘
```

### デバイス固有の考慮事項

- ノッチ・Dynamic Island の形状による Safe Area の調整
- 正方形維持など Constraints では実現できないリサイズはコメントでエンジニアに相談
- 対応デバイスの優先順位（iOSファースト vs Androidファースト）はプロジェクト開始時に決定

---

## UIスタック（5状態）

UIデザインで考慮すべき5つの状態をまとめた「UIスタック」は、アプリの実装品質を高める普遍的なパターン。すべての画面・コンポーネントでこの5状態を設計する。

### 5状態の定義と判断基準

| 状態 | 定義 | 発生タイミング | デザイン方針 |
|------|------|--------------|-------------|
| **Blank State** | 表示データが存在しない | 初回起動・検索0件・フォロー0人 | ユーザー行動を促すCTAを配置。単なる「見つかりません」は避ける |
| **Loading State** | データ読み込み中 | API応答待ち・初期ロード | コンテンツが想起されるプレースホルダー（スケルトン）を使用 |
| **Partial State** | 部分的に満たされているが不完全 | フォロー人数が少ない・データが少量 | 不完全な理由を示し、完全な状態に誘導するUIを追加 |
| **Error State** | エラーが発生している | ネットワーク断絶・サーバーエラー・入力不備 | シンプルに原因と対処法を伝える。過度な詳細は避ける |
| **Ideal State** | すべてが期待通りに揃っている | 通常使用時 | メインのデザイン。他の状態の設計はここから派生 |

### 各状態の設計指針

**Blank State（空状態）**
```
✅ 良い例:
  - アイコン + 簡潔な説明文 + アクションボタン
  - 「まだ投稿がありません。友達をフォローしよう！」+ [フォローを探す]

❌ 避けるべき:
  - 空白のみ表示
  - 「データなし」「見つかりませんでした」のみ
```

**Loading State（ローディング状態）**
```
✅ 良い例:
  - スケルトンUI（グレーの矩形でコンテンツ形状を示す）
  - コンポーネントのバリアントとして管理（切り替えが容易）

❌ 避けるべき:
  - スピナーのみ（コンテンツ位置が予測できない）
  - 長時間のブロッキングUI
```

**Partial State（部分状態）**
```
✅ 良い例:
  - コンテンツと混在して誘導UIを表示
  - Blank State のUIを再利用してカード等として挿入

❌ 避けるべき:
  - 何も表示しない、または通常と区別がつかない表示
```

**Error State（エラー状態）**
```
✅ 良い例:
  - アイコン + エラー理由の一言説明 + 再試行ボタン
  - 「インターネット接続を確認してください」+ [再試行]

❌ 避けるべき:
  - エラーコードや技術的詳細をそのまま表示
  - ユーザーに何もできない状態
```

**Ideal State（理想状態）**
```
- メインのデザインがこの状態
- 他の4状態の設計はここを起点にする
- コンポーネントのバリアントで各状態を管理すると切り替えが容易
```

### Figmaでの実装パターン

```
コンポーネント設計:
  Post
  ├── Ideal State（デフォルト）
  ├── Loading State（スケルトンバリアント）
  └── Error State（エラー表示バリアント）

画面設計:
  Home
  ├── Home（= Ideal State）
  ├── Home/Blank
  ├── Home/Loading
  ├── Home/Partial
  └── Home/Error
```

---

## インタラクティブコンポーネント

アニメーションをデザイン側で定義し、エンジニアへ動きの指示を伝えるための機能。同一コンポーネントのバリアント間をNoodleで接続することで、プロトタイプ上でインタラクションを再現できる。

### 基本設定

1. コンポーネントのバリアントを作成（例: `Liked: false` / `Liked: true`）
2. Prototype タブでバリアント間をNoodleで接続
3. Trigger・Action・Animation を設定

**インタラクション設定パターン:**

| 設定項目 | 値 | 説明 |
|---------|-----|------|
| Trigger | On tap | タップ/クリックで発火 |
| Trigger | After delay | 指定ミリ秒後に自動遷移 |
| Action | Change to [...] | 指定バリアントに切り替え |
| Transition | Instant | 即時切り替え |
| Transition | Smart animate | 同名レイヤーをモーフィング |

### マイクロインタラクション

状態変化やアクションに対する細かな演出を「マイクロインタラクション」と呼ぶ。ユーザーのフィードバックを視覚的に強化する。

**基本のOn/Offトグル:**

```
[Liked: false] →(On tap)→ [Liked: true]
[Liked: true]  →(On tap)→ [Liked: false]
Transition: Instant
```

### 慣性アニメーション

慣性（物体が運動状態を維持しようとする性質）をアニメーションに取り入れることで、リアルな動きを表現できる。

**慣性アニメーションの考え方:**

```
停止 → 加速 → 行き過ぎ → 戻って停止
```

**Figmaでの実装（Step バリアント）:**

複数の中間バリアントを作成し、`After delay` で連鎖させる。

```
[Step: 1, Liked: false]
  → (On tap, Instant) →
[Step: 2, Liked: false]  ← やや小さいサイズ
  → (After delay 1ms, Smart animate, Ease out, 100ms) →
[Step: 3, Liked: false]  ← 一番大きいサイズ（行き過ぎ）
  → (After delay 1ms, Smart animate, Ease out, 50ms) →
[Step: 4, Liked: true]   ← 通常サイズに戻って停止
  → (On tap, Instant) →
[Step: 1, Liked: false]  ← LIKE解除で最初に戻る
```

**バリアント設計のポイント:**

| Step | Liked | サイズ | 役割 |
|------|-------|--------|------|
| 1 | false | 通常 | 初期状態 |
| 2 | false | 小さめ | 押し込み（勢いがつく） |
| 3 | false | 大きめ | 行き過ぎ（慣性） |
| 4 | true | 通常 | 完了状態 |

> `[Liked: true]` に対応するバリアントが `Step: 4` のみの場合、`Change to [Step: 4]` を設定すると自動的に `Liked: true` に変更される。

### 注意事項

- インタラクティブコンポーネントが動作しない場合: Prototype タブの `Enable interactive components` チェックを確認
- インスタンスのベクターパスは直接編集不可 → `Detach component`（Option + B）でFrame変換してから編集
- 複数の `Step` バリアントと `Liked` プロパティの組み合わせが重複すると警告が出るが、すべてのバリアントにユニークな組み合わせを設定することで解消

---

## ユーザー確認の原則

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

```python
AskUserQuestion(
    questions=[
        {
            "question": "カラースタイルの命名規則をどうしますか？",
            "header": "命名規則の選択",
            "options": [
                {
                    "label": "Mode/Element/Type(/State)（推奨）",
                    "description": "Light/Label/1 のような形式。モード・要素・バリエーションで分類"
                },
                {
                    "label": "セマンティック名のみ",
                    "description": "primary, secondary, surface など意味を表す名前で管理"
                },
                {
                    "label": "プロジェクト固有の命名体系を使用",
                    "description": "既存プロジェクトに合わせてカスタマイズ"
                }
            ],
            "multiSelect": False
        },
        {
            "question": "ダークモード対応のタイミングをどうしますか？",
            "header": "ダークモード対応時期",
            "options": [
                {
                    "label": "デザイン初期から対応",
                    "description": "Light/Dark を最初から並行設計。後からの修正コストが低い"
                },
                {
                    "label": "ライトモード完成後に対応",
                    "description": "まずライトモードを完成させてから追加。速度優先"
                },
                {
                    "label": "ダークモード対応なし",
                    "description": "対応不要な場合。カラースタイルのMode階層を省略できる"
                }
            ],
            "multiSelect": False
        }
    ]
)
```

**その他の確認ポイント:**

| 確認事項 | 理由 |
|---------|------|
| 対象デバイスの優先順位（iOS/Android/両方） | Constraints設計とSafe Areaの基準が変わる |
| UIスタック対応範囲（全画面 or 重要画面のみ） | デザイン工数の見積もりに影響 |
| アニメーション仕様の詳細度 | エンジニアへのハンドオフ情報量が変わる |

### 確認不要な場面

- カラースタイルのスラッシュ階層化（常に推奨）
- コンポーネント先行でのスタイル適用（常に推奨）
- Ideal State から他の4状態への派生設計（UIスタックの基本）
- Constraints の基本パターン（Left and right / Right / Center）

---

## 関連スキル

- `designing-figma-ui` — メインスキル（制作フロー全体）
- `designing-figma-ui/references/PRODUCTION-WORKFLOW.md` — Auto Layout・コンポーネント設計
- `designing-figma-ui/references/ENGINEER-COLLABORATION.md` — Inspect/Design タブ活用・エンジニア協業
- `constructing-figma-design-systems` — Variables を使った本格的なデザインシステム構築
