# UXデザイン総合ガイド

## スキル構成

| セクション | 対象領域 | 主な用途 |
|-----------|---------|---------|
| UIデザインガイドライン | Web UI/UXデザイン原則・実践ルール | コンポーネント設計・マルチデバイスUI・ユーザビリティ評価 |
| グラフィックデザイン基礎 | 造形・色彩・タイポグラフィ・レイアウト | 印刷物・ポスター・エディトリアルデザイン |
| インターフェイス哲学 | デザインの「なぜ」・Fluid Interfaces・進化論 | 設計判断の根拠・モーション理論・exUI・ウェルビーイング |

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

### 9. 設計判断ルール集（抜粋）

1. **If** UIの状態遷移にアニメーションがある **then** 遷移中もユーザー操作を受け付ける設計にする
2. **If** モバイルで縦長ディスプレイに対応する **then** 主要操作UIを画面下部に配置する
3. **If** タッチ操作のフィードバックを設計する **then** 慣性・バウンス等の物理的応答で「直接触れている」感覚を維持する
4. **If** UIモーションを設計する **then** 4分類（身体延長/構造認知/メッセージ/演出）のどれに該当するか明確にする
5. **If** ユーザーに複雑な判断を強いている **then** 選択肢を制限して判断コストを消失させられないか検討する
6. **If** UIデザインだけに注力している **then** 不可制御環境のExperiencabilityも検討する
7. **If** ユーザーの滞在時間を最大化しようとしている **then** Time Well Spentの観点から再評価する
8. **If** IoT製品のUIを設計する **then** UIをハードウェアから分離（外在化）し、スマートフォン等から操作する設計を検討する

→ 全ルール集: [references/PHILOSOPHY-UI-PATTERNS.md](references/PHILOSOPHY-UI-PATTERNS.md)

### 10. 他スキルへの参照

| 参照先スキル | 参照タイミング |
|------------|--------------|
| `designing-frontend` | フロントエンドコード実装（shadcn/ui、コンポーネント設計） |
| `applying-behavior-design` | 行動変容設計（習慣化、CREATE Action Funnel） |
| `designing-ai-experiences` | AI体験のUXフレームワーク |
| `building-design-systems` | デザインシステム構築・ガバナンス |
