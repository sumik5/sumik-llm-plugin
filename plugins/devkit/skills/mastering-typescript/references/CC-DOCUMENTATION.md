# TypeScript固有のドキュメント生成ツールチェーン（TSDoc + TypeDoc）

> 基本JSDocタグ（`@param`/`@returns`/`@example`/`@throws`）とコメント哲学は writing-clean-code: [CLEAN-CODE-BASICS.md](../../writing-clean-code/references/CLEAN-CODE-BASICS.md) を参照。非推奨APIのマーク（`@deprecated`）は [ET-CH08-TYPE-DECLARATIONS.md](./ET-CH08-TYPE-DECLARATIONS.md) 項目68を参照。本参照は「拡張タグ + 静的ドキュメントサイト生成ツールチェーン」に絞る。

---

## 1. TSDoc と TypeDoc の役割分担

| ツール | 役割 | 成果物 |
|--------|------|--------|
| **TSDoc** | コメント記法の標準。型シグネチャに設計意図（単位・前提）を付与 | ソース内の `/** ... */` ブロック |
| **TypeDoc** | TSDocコメントを解析し静的HTMLサイトを生成 | `docs/` 配下の静的サイト |

TSDocコメントが生成ドキュメントの「基盤」、TypeDocがそれを「公開可能なWebサイト」へ変換する補完関係。

## 2. TSDoc 拡張タグ（`@remarks` / `@link`）

- **`@remarks`**: 実装詳細・設計判断・計算式など、シグネチャだけでは伝わらない文脈を補足する。
- **`@link`**: 関連クラス・仕様へのリンクを `{@link ...}` 形式で埋め込む。

```typescript
/**
 * 合計金額に割引を適用する。
 * @remarks discount はパーセンテージ（例: 10 は 10% 引き）。計算式は total * (1 - discount / 100)。
 *          関連処理は {@link ShoppingCart.checkout} を参照。
 */
applyDiscount(discount: number): number {
  return this.calculateTotalPrice() * (1 - discount / 100);
}
```

> エディタのホバー表示にも反映され、IDE上の自己説明性が向上する。

## 3. TypeDoc セットアップ手順

```bash
npm install --save-dev typedoc   # 1. devDependency として導入
npm run docs                     # 4. ルートに docs/ が生成され index.html が静的サイトの起点になる
```

```jsonc
// 2. プロジェクトルートに typedoc.json（theme=標準レイアウト / exclude=対象外パス）
{ "theme": "default", "exclude": "node_modules/**" }

// 3. package.json にスクリプトを追加（npx でローカル導入済み typedoc を実行、起点は ./index.ts）
{ "scripts": { "docs": "npx typedoc ./index.ts" } }
```

## 4. エントリーポイント（barrel export）とドキュメント網羅性

TypeDocはエントリーポイント（`./index.ts`）から到達可能なシンボルのみ文書化する。公開APIを barrel export に集約すると、生成ドキュメントの網羅性とAPIサーフェスが一致する。

```typescript
// index.ts — 公開APIの barrel export
export { ShoppingCart } from './shopping-cart';
export type { CartItem } from './shopping-cart';
export { UserService } from './user-service';
```

> エントリーポイントに載せ忘れたシンボルはドキュメントに現れない。「公開したいAPI＝起点に集約」を原則とする。

## 5. 採用判断テーブル（いつ TypeDoc を使うか）

| 状況 | 判断 |
|------|------|
| 公開ライブラリ / SDK を配布する | ✅ 採用（型定義に頼れない外部利用者向け） |
| 大規模チーム・オンボーディング負荷が高い | ✅ 採用（探索可能なサイトが学習コストを下げる） |
| API表面が広く横断的な関連を辿りたい | ✅ 採用（`@link` のクロスリファレンスが効く） |
| 小規模・内部限定・短命なコード | ⚠️ 型シグネチャ + 最小限のTSDocで十分（生成サイトは過剰） |

## 6. ドキュメント vs クリーンコードの原則

ドキュメントは**良い命名・単一責任（SRP）の代替ではない**。自己説明的なコードを最優先し、TSDoc/TypeDocは「型シグネチャだけでは伝えきれない設計意図」を補うために使う。「命名で表現できないか」を先に問う哲学は writing-clean-code: [CLEAN-CODE-BASICS.md](../../writing-clean-code/references/CLEAN-CODE-BASICS.md) を参照。
