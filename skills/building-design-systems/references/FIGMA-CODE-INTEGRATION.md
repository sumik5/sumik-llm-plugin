# コード連携 リファレンス

FigmaデザインシステムとコードベースをつなぐJSON出力・Style Dictionary・Storybookの実装詳細。

---

## 1. FigmaからのJSONエクスポート

FigmaのバリアブルはJSON形式でエクスポートできる。エクスポートしたJSONをStyle Dictionaryで各プラットフォームのトークンファイルに変換するパイプラインを構築する。

**エクスポートされるJSONの例**

```json
{
  "color": {
    "text": {
      "default": { "$value": "#1A1A1A", "$type": "color" },
      "subtle": { "$value": "#6B6B6B", "$type": "color" }
    },
    "background": {
      "default": { "$value": "#FFFFFF", "$type": "color" }
    }
  },
  "spacing": {
    "4": { "$value": "16px", "$type": "dimension" }
  }
}
```

---

## 2. Style Dictionary

Style Dictionaryはデザイントークン（JSON）を複数のプラットフォーム向けファイルに変換するビルドツール。

**変換フロー**

```
Figma バリアブル
    ↓（JSONエクスポート）
tokens.json
    ↓（Style Dictionary）
├── CSS カスタムプロパティ（Web）
├── Swift / Objective-C 定数（iOS）
└── XML / Kotlin 定数（Android）
```

**CSS変換例（ライトモード）**

```css
:root {
  --color-text-default: #1A1A1A;
  --color-text-subtle: #6B6B6B;
  --color-background-default: #FFFFFF;
  --color-background-primary-action-enabled: #2563EB;
  --spacing-4: 16px;
  --border-radius-md: 8px;
}
```

**ダークモードの切り替え**

```css
:root {
  --color-text-default: #1A1A1A;
  --color-background-default: #FFFFFF;
}

[data-theme="dark"] {
  --color-text-default: #F5F5F5;
  --color-background-default: #1A1A1A;
}
```

セマンティックカラートークンのみをCSS変数として公開することで、ダークモード切替を1箇所のdata属性変更で実現できる。

---

## 3. Storybook連携

StorybookはコンポーネントのUIカタログであり、デザインシステムのドキュメントサイトとして機能する。

**主な役割**

| 機能 | 内容 |
|------|------|
| UIカタログ | コンポーネントを独立した環境で確認 |
| ドキュメント | PropTypes / TypeScriptの型から自動生成 |
| バリアント確認 | Controls機能でプロパティをリアルタイム変更 |
| 視覚的回帰テスト | スナップショット比較による変更検知 |

**Storybookとデザイントークンの連携**

1. CSS変数をStorybookのグローバルスタイルに注入
2. ダークモードはStorybookのthemeアドオンでdata属性を切替
3. デザイントークンのリファレンスページをドキュメントとして追加

**コンポーネントストーリーの例**

```tsx
// Button.stories.tsx
export default {
  title: 'Components/Button',
  component: Button,
};

export const Primary = {
  args: {
    variant: 'primary',
    size: 'md',
    children: 'ボタン',
  },
};

export const AllVariants = () => (
  <div style={{ display: 'flex', gap: 'var(--spacing-2)' }}>
    <Button variant="primary">Primary</Button>
    <Button variant="secondary">Secondary</Button>
    <Button variant="ghost">Ghost</Button>
    <Button variant="danger">Danger</Button>
  </div>
);
```

---

## 4. トークン更新のワークフロー

```
1. Figmaでバリアブルを変更
2. JSONをエクスポート（手動 or Figma Plugin自動化）
3. Style DictionaryでCSS/コード生成
4. プルリクエスト作成
5. Storybookで視覚的差分を確認
6. デザイナー・エンジニアの承認後マージ
```

Figmaバリアブルをトークンのsource of truthとし、コードは常にFigmaから生成されたトークンを参照する運用が理想形。この一方向の流れにより、デザインとコードの乖離を防ぐ。
