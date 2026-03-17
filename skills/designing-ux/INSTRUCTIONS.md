# UXデザイン総合ガイド

## スキル構成

| セクション | 対象領域 | 主な用途 |
|-----------|---------|---------|
| UIデザインガイドライン | Web UI/UXデザイン原則・実践ルール | コンポーネント設計・マルチデバイスUI・ユーザビリティ評価 |
| グラフィックデザイン基礎 | 造形・色彩・タイポグラフィ・レイアウト | 印刷物・ポスター・エディトリアルデザイン |
| インターフェイス哲学 | デザインの「なぜ」・Fluid Interfaces・進化論 | 設計判断の根拠・モーション理論・exUI・ウェルビーイング |
| UXエレメント（5段階モデル） | Strategy→Scope→Structure→Skeleton→Surface | プロダクトUXの構造分解・段階別設計・要件整理 |
| 認知心理学基盤 | 知覚・視覚・記憶・思考・物理操作の科学的基盤 | UIレイアウト設計根拠・ユーザーエラー分析・定量的判断 |
| UIデザイン実践TIPS | 状態設計・フィードバック・コンポーネント選択・画面構成 | ローディング/空状態/保存パターン/フォーム分割等の実装判断 |

---

## 認知心理学基盤

UIデザイン原則の根拠となる認知心理学の知見。「何をすべきか」（ガイドライン）だけでなく「なぜそうすべきか」を理解するための科学的基盤。

### When to Use

以下の場面で参照:
- UIレイアウト・視覚的階層の設計根拠が必要な時
- ユーザーエラーの原因を認知科学的に分析する時
- インタラクティブ要素のサイズ・配置を定量的に判断する時
- 応答性要件の設定根拠を知りたい時
- ヒューリスティック評価の認知科学的根拠が必要な時

### Structure

| ファイル | 領域 | 主要トピック |
|---------|------|------------|
| [PSYCHOLOGY-PERCEPTION-AND-BIAS.md](references/PSYCHOLOGY-PERCEPTION-AND-BIAS.md) | 知覚とバイアス | 認知バイアス（プライミング・習慣化・注意の瞬き）、ゲシュタルト7原則、視覚的階層化 |
| [PSYCHOLOGY-VISUAL-SYSTEM.md](references/PSYCHOLOGY-VISUAL-SYSTEM.md) | 視覚システム | 色覚の限界と色使いガイドライン、周辺視野の活用、可読性の最適化 |
| [PSYCHOLOGY-MEMORY-AND-ATTENTION.md](references/PSYCHOLOGY-MEMORY-AND-ATTENTION.md) | 記憶と注意力 | 作業記憶の限界、Change Blindness、Information Scent、認識vs想起 |
| [PSYCHOLOGY-THINKING-AND-LEARNING.md](references/PSYCHOLOGY-THINKING-AND-LEARNING.md) | 思考と学習 | デュアルプロセス理論（System 1/2）、学習促進設計、意思決定バイアス |
| [PSYCHOLOGY-PHYSICAL-INTERACTION.md](references/PSYCHOLOGY-PHYSICAL-INTERACTION.md) | 物理的操作 | フィッツの法則、ステアリングの法則、脳の時定数と応答性要件 |

---

## UIデザインガイドライン

This skill provides comprehensive design guidance for creating exceptional frontend interfaces that are both visually distinctive and cognitively intuitive.

### When to Use

Apply these guidelines when:
- Building web components, pages, or applications
- Making UI/UX design decisions
- Designing interaction patterns and information architecture
- Evaluating existing interfaces for improvements
- Ensuring production-grade design quality
- Designing interfaces for multiple devices (PC, smartphone, tablet, TV)
- Making navigation or layout decisions across screen sizes

### Structure

This section consists of five complementary perspectives:

#### GUIDELINES-UI-DESIGN.md
Visual design principles focused on aesthetics and brand:
- Typography and color systems
- Motion and micro-interactions
- Spatial composition and layouts
- Anti-patterns to avoid (generic AI aesthetics)
- Creating memorable, distinctive interfaces

#### GUIDELINES-UI-DESIGN-WORKFLOW.md
UIデザインのワークフロー・プロセス・組織内役割:
- デザイン＝解像度を高める行為の定義
- UIデザイナーのスキルマップと担当業務
- 情報→UI要素への翻訳プロセス
- 画面設計の忠実度レベル（スケッチ→モックアップ）
- スタイルガイドによる品質管理
- 組織内でのステークホルダー連携

#### GUIDELINES-UX-DESIGN.md
User experience principles based on cognitive psychology and HCI:
- Mental models and task flows
- Interaction patterns and usability
- Cognitive biases and perception
- Accessibility and inclusive design
- Making interfaces feel natural and effortless

#### Interface Design Rules（実践的UIルール集）

具体的なUIコンポーネント別のDo/Don'tルール:

- **[GUIDELINES-TYPOGRAPHY-RULES.md](./references/GUIDELINES-TYPOGRAPHY-RULES.md)**: 書体、フォントサイズ、コントラスト、用語統一のルール（ルール002-013）
- **[GUIDELINES-CONTROLS-RULES.md](./references/GUIDELINES-CONTROLS-RULES.md)**: アイコン、ボタン、ドロップダウン、スライダー、リンクのルール（ルール014-035）
- **[GUIDELINES-FORMS-RULES.md](./references/GUIDELINES-FORMS-RULES.md)**: 検索、バリデーション、パスワード、決済フォームのルール（ルール036-054）
- **[GUIDELINES-NAVIGATION-RULES.md](./references/GUIDELINES-NAVIGATION-RULES.md)**: ナビゲーション、ジャーニー、プログレスバー、通知のルール（ルール055-084）
- **[GUIDELINES-ACCESSIBILITY-UX-RULES.md](./references/GUIDELINES-ACCESSIBILITY-UX-RULES.md)**: アクセシビリティ、デフォルト設定、ダークパターン回避のルール（ルール085-101）

#### デザイン理論基盤（Design Theory Foundation）

- **[GUIDELINES-DESIGN-THEORY.md](./references/GUIDELINES-DESIGN-THEORY.md)**: デザインコンセプト構築、タイポグラフィ理論、情報整理の原則(CRAP/ゲシュタルト)、レイアウト(黄金比/三分割法)、色彩理論(配色・調和論・対比)、ビジュアル選定

#### マルチデバイスUIデザイン（Multi-device UI Design）

- **[GUIDELINES-DEVICE-CONSTRAINTS.md](./references/GUIDELINES-DEVICE-CONSTRAINTS.md)**: デバイス別の物理的制約（PC/スマホ/タブレット/TV）、入力手段（タッチ/マウス/キーボード/リモコン）、画面特性（解像度/密度/アスペクト比）
- **[GUIDELINES-PLATFORM-AND-COGNITION.md](./references/GUIDELINES-PLATFORM-AND-COGNITION.md)**: Web vs ネイティブアプリの判断基準、認知特性、インタラクションコスト、一貫性とシンプルさ
- **[GUIDELINES-NAVIGATION-AND-STRUCTURE.md](./references/GUIDELINES-NAVIGATION-AND-STRUCTURE.md)**: 階層モデル、ナビゲーション配置、カラムレイアウト選択、マルチデバイス戦略

#### ユーザビリティ評価とデザインマインドセット

- **[GUIDELINES-USABILITY-PATTERNS.md](./references/GUIDELINES-USABILITY-PATTERNS.md)**: 「分からない」の3要因モデル（場所・操作・状態）、実例1〜6のケーススタディ、UI評価チェックリスト
- **[GUIDELINES-DESIGN-MINDSET.md](./references/GUIDELINES-DESIGN-MINDSET.md)**: サンクコスト・機能肥大化・売り手都合・プロトタイピング・謙虚さの5テーマ

**IMPORTANT**: Great design requires all five perspectives. Use all documents together for complete design guidance.

### Design Philosophy

- **Intentionality over intensity**: Bold maximalism and refined minimalism both work - the key is executing with precision
- **Invisible interface**: The best UX feels like no UX at all - users accomplish goals without thinking about the tool
- **Context-specific creativity**: Avoid generic solutions - design for the specific problem, audience, and constraints
- **Cognitive respect**: Every element costs mental effort - be ruthless about reducing unnecessary complexity

Reference the specific documents (GUIDELINES-UI-DESIGN.md or GUIDELINES-UX-DESIGN.md) as needed for detailed guidance.

### ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

| 確認項目 | 例 |
|---|---|
| デザインシステムの有無 | 既存のデザインシステムに従うか、新規作成か |
| ブランドカラー | プロジェクト固有の配色指定 |
| アクセシビリティ基準 | WCAG 2.1 AA, AAA |
| モーション設定 | アニメーション有無、reduced motion対応 |
| タイポグラフィ | フォントファミリー、スケール |

**確認不要な場面**: 認知心理学の原則適用・コントラスト比の確保・レスポンシブデザインの考慮（常に必須）

---

## グラフィックデザイン基礎

造形・色彩・タイポグラフィ・レイアウトの基礎理論を体系的に扱う。印刷物・エディトリアルデザインにおける「考え方」と「手の動かし方」を接続する実践的な知識体系。

### 使用タイミング

- 印刷物・ポスター・チラシ・パンフレット・冊子のデザイン制作時
- デザインの造形的・色彩的な判断（形の選択、配色スキームの決定）を行う時
- 書体選択・文字組みの方針を決定する時
- レイアウトの構図・視線誘導・グリッドシステムを設計する時

### デザインの4要素

#### 形（造形）

形はデザインの最も基本的な要素。**ゲシュタルト心理学**（近接・類同・閉合・よい連続）を応用して情報のまとまりをつくる。**図と地**の関係を意識し、「地の形」の美しさが洗練されたデザインの条件になる。幾何学形態の特性（正方形=安定、三角形=動き・緊張感）と錯視補正もデザイン判断の基礎。

→ 詳細: [references/GRAPHICS-FORM-AND-SHAPE.md](references/GRAPHICS-FORM-AND-SHAPE.md)

#### 色（色彩）

色は形よりも記憶に残りやすく、印象形成への影響が最も大きい要素。**色の三属性**（色相・明度・彩度）の理解を土台に、**加法混色（RGB）** と **減法混色（CMYK）** の違いをモニター・印刷の文脈で使い分ける。配色セオリー（コンプリメンタリー、アナロガス、トライアド等）と**トーン概念**を組み合わせて一貫した配色を設計する。

→ 詳細: [references/GRAPHICS-COLOR-THEORY.md](references/GRAPHICS-COLOR-THEORY.md)

#### 文字（タイポグラフィ）

文字デザインは「書体選択」と「組み方」の二本柱。日本語書体（明朝体・ゴシック体）と欧文書体（セリフ4系統・サンセリフ4系統）の分類とイメージを理解し、媒体・目的に応じて選択する。**仮想ボディ・字面・字送り・行送り**の概念を押さえ、禁則処理・文字組みアキ量設定で可読性を担保する。

→ 詳細: [references/GRAPHICS-TYPOGRAPHY-AND-TYPESETTING.md](references/GRAPHICS-TYPOGRAPHY-AND-TYPESETTING.md)

#### レイアウト（構成）

レイアウトは情報の視覚的組織化。**構図**（二等分割・三等分割・対角線）、**コントラスト**（ジャンプ率：大小・明暗・粗密・色・形）、**マージンとホワイトスペース**、**視線誘導**（Z型・N型、アイキャッチャー）の4軸で設計する。**グリッドシステム**は情報量・媒体サイズに応じて選定する。

→ 詳細: [references/GRAPHICS-LAYOUT-AND-COMPOSITION.md](references/GRAPHICS-LAYOUT-AND-COMPOSITION.md)

### クイックリファレンス

| 目的 | 使用する要素 | 参照先 |
|------|------------|--------|
| 安定感・信頼性を表現したい | 正方形・水平線・シンメトリー | GRAPHICS-FORM-AND-SHAPE.md |
| 動き・緊張感・スピード感を表現したい | 三角形・対角線・アシンメトリー | GRAPHICS-FORM-AND-SHAPE.md |
| 統一感のある配色にしたい | トーン・イン・トーン配色 | GRAPHICS-COLOR-THEORY.md |
| メリハリのある配色にしたい | コンプリメンタリー（補色）配色 | GRAPHICS-COLOR-THEORY.md |
| 可読性重視の本文テキスト | ゴシック体 / サンセリフ体 | GRAPHICS-TYPOGRAPHY-AND-TYPESETTING.md |
| 視線を効果的に誘導したい | Z型・N型レイアウト、アイキャッチャー | GRAPHICS-LAYOUT-AND-COMPOSITION.md |

### ユーザー確認の原則（AskUserQuestion）

**デザイン判断は媒体・目的・ブランド要件に強く依存する。以下の場面では必ず確認する:**

- **媒体と目的の確認**: ポスター/チラシ・冊子・名刺・Webバナーで最適解が異なる
- **書体の選択**: デザインのトーン（クラシカル/モダン/カジュアル）とターゲット層に依存
- **配色スキームの決定**: ブランドガイドライン・使用色数・コントラスト要件に依存

**確認不要な場面**: ゲシュタルト法則の適用・文字色のコントラスト確保・禁則処理・図と地の分離（客観的基準あり）

---

## インターフェイス哲学

「なぜそうデザインすべきか」というWHYを提供するインターフェイス哲学の参照書。
UIデザインガイドライン（WHAT/HOW実践ルール）と補完関係にある。

### 1. インターフェイス進化の3フェーズ

#### フェーズ1: スキューモーフィズム
現実世界のメタファーをUIに適用。フォルダ・ごみ箱・革製ノートなど、物理世界への「見立て」でタッチインターフェイスの直感性を補完した。**消えた理由**: タッチパネルの普及でユーザーがメタファーなしで操作を習得。

#### フェーズ2: フラットデザイン
スキューモーフィズムからの転換。メタファー脱却＝**コンピュータ起点のGUI**への移行。
→ 詳細: [references/PHILOSOPHY-PIXEL-AESTHETICS.md](references/PHILOSOPHY-PIXEL-AESTHETICS.md)

#### フェーズ3: Fluid Interfaces
静的な画面遷移を超え、ユーザーの「意識の流れ」に追随する連続的なインタラクション体験。アニメーション中もインプットを受け付け、中断可能で、自己帰属感を損なわない設計。
→ 詳細: [references/PHILOSOPHY-FLUID-INTERFACES.md](references/PHILOSOPHY-FLUID-INTERFACES.md)

### 2. 自己帰属感とFluid Interfaces

**道具の透明性**: 優れた道具はその存在を意識させない。**自己帰属感**: 「自分がシステムを操作している」という感覚。インプットに対するダイレクトかつ物理的なフィードバックで醸成される。

#### Fluid Interfaces の7原則

1. **応答性**: UIの状態遷移中もユーザー操作を受け付ける
2. **中断可能性**: アニメーション完了を待たせない
3. **連続性**: 画面遷移で認知的断絶を生まない
4. **到達可能性**: 主要操作を画面下部に集中させる
5. **統合性**: ビジュアルとモーションを同時にデザインする
6. **低遅延**: レイテンシを最優先事項として実装する
7. **一貫性**: マルチプラットフォームでブランドの一貫性を保つ

→ 詳細: [references/PHILOSOPHY-FLUID-INTERFACES.md](references/PHILOSOPHY-FLUID-INTERFACES.md)

### 3. モーションデザイン理論

#### モーション4分類（鹿野護）

| 分類 | 役割 | 例 |
|------|------|-----|
| **身体延長** | タッチへの直接フィードバック | バウンス・慣性スクロール |
| **構造認知** | 画面の空間的構造を示す | スライドイン・ズームイン |
| **メッセージ** | 感情・状態を非言語で伝える | エラー時の首振り |
| **演出** | コンテンツの世界観を表現する | ブランド固有のモーション |

→ 詳細: [references/PHILOSOPHY-MOTION-THEORY.md](references/PHILOSOPHY-MOTION-THEORY.md)

### 4. 制約のデザイン

**「制約が自由な行動を促す」**: 選択肢を意図的に制限することで判断コストを消失させ、ユーザーを能動的にする。**精神的相互作用と引力設計**: コンテンツへの「引力」をUIデザインで設計する発想。

→ 詳細: [references/PHILOSOPHY-CONSTRAINT-DESIGN.md](references/PHILOSOPHY-CONSTRAINT-DESIGN.md)

### 5. ピクセルの美学

フラットデザインは単なる「シンプルなビジュアル」ではなく、**コンピュータを起点とした設計思想の転換**。マテリアルデザイン = 厚みのあるピクセル: 重なりに応じた影、質量のある加減速モーション。

→ 詳細: [references/PHILOSOPHY-PIXEL-AESTHETICS.md](references/PHILOSOPHY-PIXEL-AESTHETICS.md)

### 6. Experiencability（体験可能性）

| 環境 | 定義 | デザイン手法 |
|------|------|------------|
| **可制御環境** | ユーザーがUIに接触している時間 | UIデザイン・UXデザイン |
| **不可制御環境** | ユーザーがUIに触れていない時間 | 世界観設計・イネブラ設計 |

**5つのイネブラ**: 流入・送流・還流・定着・ロイヤル

→ 詳細: [references/PHILOSOPHY-EXPERIENCABILITY.md](references/PHILOSOPHY-EXPERIENCABILITY.md)

### 7. exUIとUIの未来

**exUI（外在化UI）**: UIをハードウェアから切り離し、スマートフォン等の汎用デバイスで操作する設計パターン。**メタハードウェア**: UIを変えることで製品の定義自体を変える発想。

→ 詳細: [references/PHILOSOPHY-EXUI-PATTERNS.md](references/PHILOSOPHY-EXUI-PATTERNS.md)

### 8. ウェルビーイングデザイン

ユーザーの滞在時間最大化ではなく、**サービス外での良質な時間**を考慮する設計思想（Time Well Spent）。

→ 詳細: [references/PHILOSOPHY-WELLBEING-DESIGN.md](references/PHILOSOPHY-WELLBEING-DESIGN.md)

### 9. タンジブルインターフェイス哲学

フィジカルとデジタルの融合、触れることの設計哲学、「意のまま感」を生むインタラクション原則。入出力の物理的近接、レイテンシ基準、ビット×アトムの海岸線メタファー、不完全さのデザイン。

→ 詳細: [references/PHILOSOPHY-TANGIBLE-INTERFACE.md](references/PHILOSOPHY-TANGIBLE-INTERFACE.md)

### 10. レスポンシブ・タイポグラフィ哲学

デバイス間の「視覚的に均等な」タイポグラフィ設計。読む距離とフォントサイズの関係、セリフ/サンセリフ選択基準、行高140%基準、妥協点設計の優先順位。

→ 詳細: [references/PHILOSOPHY-RESPONSIVE-TYPOGRAPHY.md](references/PHILOSOPHY-RESPONSIVE-TYPOGRAPHY.md)

### 11. GUI変遷史とインターフェイスの「質感」

ライトペン→マウス→デスクトップメタファー→iPhone→フラットデザインの歴史的変遷。「質感は動きの中で設計する」原則、情報の圧力、スクリーンの未来。

→ 詳細: [references/PHILOSOPHY-GUI-HISTORY.md](references/PHILOSOPHY-GUI-HISTORY.md)

### 12. 設計判断ルール集（抜粋）

1. **If** UIの状態遷移にアニメーションがある **then** 遷移中もユーザー操作を受け付ける設計にする
2. **If** モバイルで縦長ディスプレイに対応する **then** 主要操作UIを画面下部に配置する
3. **If** タッチ操作のフィードバックを設計する **then** 慣性・バウンス等の物理的応答で「直接触れている」感覚を維持する
4. **If** UIモーションを設計する **then** 4分類（身体延長/構造認知/メッセージ/演出）のどれに該当するか明確にする
5. **If** ユーザーに複雑な判断を強いている **then** 選択肢を制限して判断コストを消失させられないか検討する
6. **If** UIデザインだけに注力している **then** 不可制御環境のExperiencabilityも検討する
7. **If** ユーザーの滞在時間を最大化しようとしている **then** Time Well Spentの観点から再評価する
8. **If** IoT製品のUIを設計する **then** UIをハードウェアから分離（外在化）し、スマートフォン等から操作する設計を検討する

→ 全ルール集: [references/PHILOSOPHY-UI-PATTERNS.md](references/PHILOSOPHY-UI-PATTERNS.md)

### 13. 他スキルへの参照

| 参照先スキル | 参照タイミング |
|------------|--------------|
| `designing-frontend` | フロントエンドコード実装（shadcn/ui、コンポーネント設計） |
| `applying-behavior-design` | 行動変容設計（習慣化、CREATE Action Funnel） |
| `designing-ai-experiences` | AI体験のUXフレームワーク |
| `building-design-systems` | デザインシステム構築・ガバナンス |

---

## UXエレメント（5段階モデル）

プロダクトのユーザーエクスペリエンスを構造的に分解するための概念フレームワーク。
抽象的な戦略から具体的な視覚表現まで、5つの段階を下から上へと積み上げて設計する。

### 5段階フレームワーク概説

| 段階 | 英語 | 抽象度 | 主な問い |
|------|------|--------|---------|
| 1. 戦略 | Strategy | 最も抽象的 | 誰のために何を達成するか |
| 2. 要件 | Scope | ↑ | 何を作るか・作らないか |
| 3. 構造 | Structure | ↕ | どのように機能させるか |
| 4. 骨格 | Skeleton | ↓ | どこに何を配置するか |
| 5. 表層 | Surface | 最も具体的 | 見た目・感触はどうあるべきか |

各段階の詳細:
- → **[references/ELEMENTS-STRATEGY.md](./references/ELEMENTS-STRATEGY.md)**: ユーザーニーズ・製品目標・ブランドアイデンティティ・成功測定基準
- → **[references/ELEMENTS-SCOPE.md](./references/ELEMENTS-SCOPE.md)**: 機能仕様・コンテンツ要求・要件の優先順位付け
- → **[references/ELEMENTS-STRUCTURE.md](./references/ELEMENTS-STRUCTURE.md)**: インタラクションデザイン・情報アーキテクチャ・概念モデル
- → **[references/ELEMENTS-SKELETON.md](./references/ELEMENTS-SKELETON.md)**: 情報デザイン・インターフェースデザイン・ナビゲーションデザイン
- → **[references/ELEMENTS-SURFACE.md](./references/ELEMENTS-SURFACE.md)**: ビジュアルデザイン・感覚エクスペリエンス・ブランド表現

### 段階間の依存関係ルール

```
Surface（表層）      ← 骨格の配置に依存
  ↑
Skeleton（骨格）     ← 構造のパターンに依存
  ↑
Structure（構造）    ← 要件の内容に依存
  ↑
Scope（要件）        ← 戦略の方向に依存
  ↑
Strategy（戦略）     ← すべての基盤
```

**核心ルール**: 下の段階での決定が、上の段階で使える選択肢を制約する。
これを「波及効果」と呼ぶ。戦略段階での決定は連鎖のずっと上まで影響する。

**プロジェクト計画の原則**:
- ❌ 各段階を完全に終えてから次に進む（ウォーターフォール的な誤解）
- ✅ 下の段階の作業が **終わる前に** 上の段階の作業が **終わらない** よう計画する
- 依存性は両方向: 上の段階の決定により下の段階の再評価を迫られることもある

### ウェブの二重性

ウェブは本質的に2つの異なる性質を持つプラットフォームである。5段階の各段階でこの二重性が専門用語の分岐として現れる。

| 段階 | 機能性プラットフォーム側 | 情報メディア側 |
|------|----------------------|-------------|
| 戦略 | ユーザーニーズ・製品目標 | ユーザーニーズ・製品目標（共通） |
| 要件 | **機能仕様**（feature set） | **コンテンツ要求** |
| 構造 | **インタラクションデザイン** | **情報アーキテクチャ** |
| 骨格 | **インターフェースデザイン** | **ナビゲーションデザイン** |
| 表層 | 感覚エクスペリエンス | 感覚エクスペリエンス（共通） |

**重要**: 現実のほとんどのサイト・アプリは両側の要素を持つハイブリッドであり、
各段階で機能性と情報の両面から検討が必要になる。

### どの段階から着手すべきか（適用フローチャート）

```
プロジェクト開始
      ↓
[戦略は明確か？]
  ├─ NO → Strategy段階から開始（ユーザーニーズ調査・製品目標の定義）
  └─ YES
       ↓
[要件は定義されているか？]
  ├─ NO → Scope段階から開始（機能仕様・コンテンツ要求の作成）
  └─ YES
       ↓
[構造・フローは設計されているか？]
  ├─ NO → Structure段階から開始（IA・インタラクション設計）
  └─ YES
       ↓
[コンポーネント配置・ナビゲーションは決まっているか？]
  ├─ NO → Skeleton段階から開始（ワイヤーフレーム・ナビゲーション設計）
  └─ YES → Surface段階（ビジュアルデザイン・最終仕上げ）
```

**注意**: 上の段階から着手しても、必ず下の段階に戻って整合性を確認すること。
「屋根の形がわからないうちに土台を作らない」—逆も同様。

### UXのビジネス価値

UXへの投資がビジネスに与える効果は定量化できる。

**コンバージョンレートによるROI測定**:
- コンバージョンレート（訪問者が次のステップに進む割合）がわずか0.1%上がっただけで収益が10%以上増えることもある
- 「エクスペリエンスがひどければ、ユーザーは戻ってこない」—競合サイトがより良いUXを提供していれば、ユーザーは移行する
- フィーチャーや機能は重要だが、**ユーザーエクスペリエンスは顧客ロイヤルティにはるかに大きな影響**を及ぼす

**コスト削減効果**:
- 効率的なツールは作業速度を上げ、ミスを減らす → 直接的なコスト削減
- 使いやすいツールは従業員の仕事満足度を高め、離職率を下げる → 採用・教育コストの削減
- 社内イントラネット・業務ツールでも同様の効果が得られる

**If/Then ルール（ビジネス文脈）**:
- **If** ROIの根拠を求められたとき **then** コンバージョンレートの数値変化とその収益への波及を示す
- **If** UXへの投資を削減しようとしているとき **then** 「後で修正するコスト > 最初から正しく作るコスト」を示す
- **If** 戦略・要件段階のタスクがカットされそうなとき **then** これらは後続成果物の「必要不可欠な準備」であることを説明する

### マラソンと短距離走（プロセス管理の原則）

UXデザインプロセスはマラソンである。短距離走のアプローチを取ると失敗する。

**短距離走型（アンチパターン）**:
- 全力で最初から最後まで突っ走る
- 常に緊急事態として各プロジェクトに対応
- 戦略・要件・構造の段階を省略して表層へ直行
- → 結果: 誰の期待も満たさない製品。次のプロジェクトは前プロジェクトの欠点修正に費やされる悪循環

**マラソン型（推奨パターン）**:
- スピードを上げるタイミングと落とすタイミングを知る
- プロトタイプ・アイデア出し（前進）とテスト・パーツ確認（後退）を交互に繰り返す
- 目に見えにくい下層の段階（戦略・要件・構造）こそ、UX全体の成否において最も重要
- 考え抜いた上でのデザイン判断は「短期的に時間がかかるが、長い目で見ればはるかに時間の節約」

**If/Then ルール（プロセス管理）**:
- **If** スケジュールが押しているとき **then** 戦略・要件・構造タスクを真っ先にカットしない（これらがなければ後続成果物が孤立する）
- **If** タスクごとに異なるアプローチが必要 **then** それを見極めてペース配分する（マラソン戦略）
- **If** 製品が「誰の期待も満たさない」結果になったとき **then** 下層の段階の欠如を疑う

---

## UIデザイン実践TIPS

UIの状態設計・フィードバック・コンポーネント選択・画面構成における実装レベルの判断基準。
理論や原則（上記セクション群）を「具体的にどう実装するか」に落とし込んだ実践パターン集。

### 使用タイミング

- ローディング・空状態・エラーの表示方法を決めるとき
- 保存パターン（自動/手動/一括）を選択するとき
- ボタン・入力UI・カードUIの使い分けを判断するとき
- フォーム分割や「もっと見る」の設計を検討するとき
- 未読/既読・通知・いいね等のフィードバック設計時

### Structure

| ファイル | 対象領域 | 主要トピック |
|---------|---------|------------|
| [TIPS-VISUAL-DESIGN.md](references/TIPS-VISUAL-DESIGN.md) | 色・文字・動き | 赤の使い方判断、配色の実装テクニック、説明UI 3パターン、アニメーション判断基準 |
| [TIPS-COMPONENT-PATTERNS.md](references/TIPS-COMPONENT-PATTERNS.md) | 機能表現・UIコンポーネント | いいね/保存/未読/更新の設計パターン、ボタン/入力/カード/メッセンジャーUI |
| [TIPS-USER-BEHAVIOR.md](references/TIPS-USER-BEHAVIOR.md) | ユーザー行動への配慮 | エラー表示、受動的体験、ユーザー層対応、待ち時間、空状態 |
| [TIPS-SCREEN-NAVIGATION.md](references/TIPS-SCREEN-NAVIGATION.md) | 画面設計・遷移・実践知 | 画像配置、コンテンツ整理、メニュー、フォーム分割、画面遷移、業務UI |

### クイックリファレンス（実践判断）

| 判断が必要な場面 | 推奨パターン | 詳細 |
|----------------|------------|------|
| ローディング表示 | 処理時間で選択: <1秒→なし、1-3秒→スピナー、3秒超→プログレスバー、不定→スケルトン | TIPS-USER-BEHAVIOR.md |
| 空状態の表示 | 全体空→行動喚起CTA、一部空→説明+代替コンテンツ | TIPS-USER-BEHAVIOR.md |
| 保存パターン | データ喪失リスク高→自動保存、入力量多→一括保存、即時反映→行ごと保存 | TIPS-COMPONENT-PATTERNS.md |
| ボタン種類 | 主要アクション→塗りつぶし、補助→アウトライン、破壊的→赤系 | TIPS-COMPONENT-PATTERNS.md |
| フォーム分割 | 入力項目7つ以上 or 論理グループ明確→分割を検討 | TIPS-SCREEN-NAVIGATION.md |
| 赤の使用 | エラー・削除→赤OK、数値増減→文脈依存（赤字=マイナスとは限らない） | TIPS-VISUAL-DESIGN.md |

---

## UX実践原則（100 Principles）

UXデザインの全工程をカバーする100の実践原則。
各フェーズに分類されており、プロジェクトの現在フェーズに応じて参照する。

### フェーズ別インデックス

| フェーズ | 原則番号 | テーマ | ファイル |
|---------|---------|--------|---------|
| **Consider** | 01–17 | UXの本質・哲学・認知効果・倫理・時間軸 | `references/PRINCIPLES-CONSIDER.md` |
| **Empathize** | 18–37 | アクセシビリティ・多様性・認知・タッチ・文脈 | `references/PRINCIPLES-EMPATHIZE.md` |
| **Define** | 38–51 | 要件定義・MVP・ユーザーフロー・情報設計 | `references/PRINCIPLES-DEFINE.md` |
| **Research** | 52–63 | リサーチ手法・ペルソナ・競合分析・IA検証 | `references/PRINCIPLES-RESEARCH.md` |
| **Design** | 64–87 | IA・ナビゲーション・タイポグラフィ・アニメーション | `references/PRINCIPLES-DESIGN.md` |
| **Validate** | 88–100 | テスト・メトリクス・ローンチ後改善・期待値管理 | `references/PRINCIPLES-VALIDATE.md` |

### 各原則の構造

```
### XX. タイトル

**核心**: 1行で核心メッセージ

- 要点1
- 要点2
- 要点3（あれば）

**If/Then**: If [状況] then [アクション]
```

### 使い方

- **プロジェクト開始前**: Consider（01–17）で哲学的準備を行う
- **ユーザー理解段階**: Empathize（18–37）でユーザー多様性を把握する
- **問題定義段階**: Define（38–51）でスコープと要件を確定する
- **リサーチ計画時**: Research（52–63）で適切な手法を選択する
- **設計段階**: Design（64–87）で具体的なUI設計の判断基準にする
- **テスト・リリース段階**: Validate（88–100）で品質検証と改善計画を立てる
- **特定の問いに答えたいとき**: If/Then 形式で該当する状況の原則を検索する
