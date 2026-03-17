# Anki MCP Server 完全ガイド

**Anki MCP Server**（AnkiMCPサーバー）は、Ankiアドオンとして動作するMCPサーバーです。AIアシスタント（Claude Code、Claude Desktop等）から直接Ankiフラッシュカードコレクションを操作可能にし、学習教材の作成・カードレビュー・メディア管理をプログラマティックに実行できます。

**主な機能:**
- デッキ管理（作成・一覧取得）
- ノート操作（検索・追加・更新・削除）
- カードレビュー（復習カード取得・表示・評価）
- メディア管理（画像・音声のアップロード・削除）
- GUI統合（Ankiインターフェース操作）
- ノートタイプ・スタイリング管理

**リポジトリ**: [ankimcp/anki-mcp-server-addon](https://github.com/ankimcp/anki-mcp-server-addon)

---

## セットアップ

### 1. Ankiアドオンインストール

**AnkiWeb コード**: `124672614`

1. Ankiを起動
2. **ツール** → **アドオン** → **アドオンを入手**
3. コード `124672614` を入力してインストール
4. Ankiを再起動

**要件:**
- Anki 25.07 以降（Python 3.13）
- 初回起動時に `pydantic_core` を自動ダウンロード

### 2. サーバー設定

Ankiの **ツール** → **アドオン** → **Anki MCP Server** → **設定** から以下の設定を確認・変更可能:

**デフォルト設定:**
```json
{
  "mode": "http",
  "http_port": 3141,
  "http_host": "127.0.0.1",
  "http_path": "",
  "cors_origins": [],
  "cors_expose_headers": ["mcp-session-id", "mcp-protocol-version"],
  "auto_connect_on_startup": true
}
```

| フィールド | 説明 | デフォルト |
|-----------|------|-----------|
| `mode` | `http` または `stdio` | `http` |
| `http_port` | HTTPサーバーポート | `3141` |
| `http_host` | バインドホスト | `127.0.0.1` |
| `http_path` | URLパス | `""` |
| `auto_connect_on_startup` | 起動時に自動接続 | `true` |

### 3. MCPクライアント設定

#### Claude Code

プロジェクトの `.mcp.json` に以下を追加:

```json
{
  "mcpServers": {
    "anki": {
      "url": "http://127.0.0.1:3141/"
    }
  }
}
```

#### Claude Desktop

`claude_desktop_config.json` に以下を追加:

```json
{
  "mcpServers": {
    "anki": {
      "url": "http://127.0.0.1:3141/"
    }
  }
}
```

**注意**: Ankiアプリケーションが起動している間のみMCPサーバーが動作します。

---

## 基本ワークフロー

### 1. デッキ管理

```typescript
// デッキ一覧取得
const decks = await list_decks();

// 新しいデッキ作成
await create_deck({ deck: "Japanese::Vocabulary" });
```

**ユースケース:**
- 学習トピックごとにデッキを整理
- 階層構造の管理（`::`区切り）

### 2. ノート操作

```typescript
// ノート検索（Anki検索構文使用）
const noteIds = await find_notes({ query: "deck:Japanese tag:N5" });

// ノート詳細取得
const notes = await notes_info({ notes: noteIds });

// フラッシュカード追加
await add_note({
  note: {
    deckName: "Japanese::Vocabulary",
    modelName: "Basic",
    fields: {
      Front: "こんにちは",
      Back: "Hello"
    },
    tags: ["greeting", "basic"]
  }
});

// フィールド更新
await update_note_fields({
  note: {
    id: 1234567890,
    fields: {
      Back: "Hello (Greeting)"
    }
  }
});

// ノート削除
await delete_notes({ notes: [1234567890] });
```

### 3. カードレビュー

```typescript
// 次のレビューカード取得
const cards = await get_due_cards({ deck: "Japanese::Vocabulary" });

// カード表示
const cardInfo = await present_card({ card: cards[0].id });
console.log(cardInfo.question); // 問題面
console.log(cardInfo.answer);   // 解答面

// レビュー評価
await rate_card({
  card: cards[0].id,
  ease: "good"  // "again" | "hard" | "good" | "easy"
});
```

### 4. メディア管理

```typescript
// 画像アップロード（Base64エンコード）
await store_media_file({
  filename: "diagram.png",
  data: "iVBORw0KGgoAAAANS...",  // Base64文字列
  deleteExisting: true
});

// メディアファイル一覧
const mediaFiles = await get_media_files_names({
  pattern: "*.png"
});

// メディア削除
await delete_media_file({ filename: "old_image.png" });
```

---

## 活用パターン

### 1. 学習教材の一括作成

**シナリオ**: PDFやMarkdownから語彙リストを抽出し、フラッシュカードを自動生成

```typescript
const vocabulary = extractVocabulary(text);

await create_deck({ deck: "English::Vocabulary::Unit5" });

for (const word of vocabulary) {
  await add_note({
    note: {
      deckName: "English::Vocabulary::Unit5",
      modelName: "Basic",
      fields: {
        Front: word.term,
        Back: word.definition
      },
      tags: ["unit5", word.difficulty]
    }
  });
}
```

### 2. AIによるレビューセッション

**シナリオ**: `review_session` プロンプトを活用した対話的学習

```typescript
// 対話モード（質問→ヒント→解答）
const session = await review_session({
  mode: "interactive",
  deck: "Japanese::JLPT_N3"
});

// クイックモード（即座に評価）
const quickSession = await review_session({
  mode: "quick",
  deck: "Japanese::JLPT_N3"
});
```

**モード:**
- **interactive**: ヒント提供→ユーザー回答→正解表示の3ステップ
- **quick**: 問題→正解を即座に表示
- **voice**: 音声アシスタント用の簡潔な応答

### 3. GUI統合

```typescript
// 特定タグのカードをブラウザで表示
await gui_browse({ query: "tag:review_needed" });

// カード追加ダイアログを開く
await gui_add_cards({ deckName: "Japanese::Vocabulary" });

// 現在のカードを編集
await gui_edit_note({ noteId: 1234567890 });
```

### 4. ノートタイプのカスタマイズ

```typescript
// ノートタイプ一覧
const models = await model_names();

// 特定ノートタイプのフィールド取得
const fields = await model_field_names({ modelName: "Basic" });

// スタイリング更新
await update_model_styling({
  modelName: "Basic",
  css: `
    .card {
      font-size: 24px;
      text-align: center;
    }
    .front { color: #333; }
    .back { color: #0066cc; }
  `
});
```

---

## ベストプラクティス

### 1. 検索構文の活用

```typescript
// タグとデッキの組み合わせ
find_notes({ query: "deck:Japanese tag:N5 tag:verb" });

// フィールド検索
find_notes({ query: "Front:*こんにち*" });

// 追加日指定
find_notes({ query: "added:7" }); // 過去7日間
```

### 2. バッチ処理

大量のカード追加時は一括処理を推奨:

```typescript
for (const note of notes) {
  await add_note({ note });
}

// 処理後に同期
await sync();
```

### 3. エラーハンドリング

```typescript
try {
  await add_note({ note: { deckName: "NonExistentDeck", ... } });
} catch (error) {
  console.error("Failed to add note:", error);
  // デッキ作成後にリトライ
  await create_deck({ deck: "NonExistentDeck" });
}
```

### 4. メディアファイル命名

メディアファイルは一意の名前を使用:

```typescript
const timestamp = Date.now();
await store_media_file({
  filename: `image_${timestamp}.png`,
  data: base64Data,
  deleteExisting: false
});
```

---

## トラブルシューティング

### サーバーに接続できない

**原因**: Ankiアプリが起動していない、ポート設定が誤っている

**解決策**:
1. Ankiを起動
2. ツール → アドオン → Anki MCP Server → 設定 でポートを確認
3. `.mcp.json` のURLが一致しているか確認
4. `http://127.0.0.1:3141/` にブラウザでアクセスして動作確認

### pydantic_core エラー

**原因**: 初回起動時の依存関係ダウンロードに失敗

**解決策**:
1. Ankiを再起動
2. インターネット接続を確認

### ノート追加時のエラー

**原因**: ノートタイプ（modelName）やフィールド名が存在しない

**解決策**:
1. `model_names()` でノートタイプ一覧を確認
2. `model_field_names()` で正確なフィールド名を取得
3. フィールド名は大文字小文字を区別

---

## 関連リソース

- [Anki MCP Server GitHub](https://github.com/ankimcp/anki-mcp-server-addon)
- [Anki検索構文ドキュメント](https://docs.ankiweb.net/searching.html)
- 詳細なツールリファレンス: `ANKI-MCP-TOOLS.md`
