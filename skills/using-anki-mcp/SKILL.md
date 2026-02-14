---
name: using-anki-mcp
description: >-
  Anki MCP Server integration for AI-assisted flashcard management covering deck operations, card review, note types, and media management.
  Use when interacting with Anki flashcards via MCP, creating study materials, or automating spaced repetition workflows.
  For bulk flashcard creation from EPUB/PDF files, use creating-flashcards instead. For MCP server/client development, use developing-mcp instead.
---

# using-anki-mcp

## 概要

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
| `cors_origins` | CORS許可オリジン | `[]` |
| `cors_expose_headers` | CORSで公開するヘッダー | `["mcp-session-id", "mcp-protocol-version"]` |
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

**ユースケース:**
- CSVやJSON等の外部データから一括カード作成
- 既存カードの修正・タグ付け
- 学習進捗に基づく自動削除

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

**ユースケース:**
- AIによる対話的レビューセッション
- 学習進捗の自動記録

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

**ユースケース:**
- 画像付きフラッシュカード作成
- 音声発音教材の追加

---

## 活用パターン

### 1. 学習教材の一括作成

**シナリオ**: PDFやMarkdownから語彙リストを抽出し、フラッシュカードを自動生成

```typescript
// テキストから語彙抽出（AIによる解析）
const vocabulary = extractVocabulary(text);

// Ankiデッキ作成
await create_deck({ deck: "English::Vocabulary::Unit5" });

// 各単語をカード化
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

// 音声モード（音声読み上げ想定）
const voiceSession = await review_session({
  mode: "voice",
  deck: "Japanese::JLPT_N3"
});
```

**モード:**
- **interactive**: ヒント提供→ユーザー回答→正解表示の3ステップ
- **quick**: 問題→正解を即座に表示
- **voice**: 音声アシスタント用の簡潔な応答

### 3. GUI統合

Ankiのインターフェースを直接操作:

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

// CSSスタイリング取得
const styling = await model_styling({ modelName: "Basic" });

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

## ツール一覧

詳細なツールリファレンスは `references/TOOLS-REFERENCE.md` を参照してください。

### コレクション管理
- `sync` — AnkiWebと同期
- `list_decks` — 全デッキ取得
- `create_deck` — デッキ作成
- `find_notes` — Anki検索構文でノート検索
- `notes_info` — ノート詳細取得
- `add_note` — フラッシュカード作成
- `update_note_fields` — ノートフィールド更新
- `delete_notes` — ノート削除

### カード操作
- `card_management` — カードの位置変更、デッキ間移動、bury/unbury
- `get_due_cards` — 次のレビューカード取得
- `present_card` — カード表示
- `rate_card` — レビュー評価（Again/Hard/Good/Easy）

### ノートタイプ・スタイリング
- `model_names` — ノートタイプ一覧
- `model_field_names` — ノートタイプのフィールド取得
- `model_styling` — CSSスタイリング取得
- `update_model_styling` — CSSスタイリング更新
- `create_model` — 新しいノートタイプ作成

### メディア管理
- `store_media_file` — 画像/音声アップロード
- `get_media_files_names` — パターンに一致するファイル一覧
- `delete_media_file` — メディア削除

### GUI統合
- `gui_browse` — ブラウザを検索付きで開く
- `gui_add_cards` — カード追加ダイアログ
- `gui_edit_note` — ノートエディタ
- `gui_current_card` — 現在のカード情報
- `gui_show_question` / `gui_show_answer` — カードの表/裏を表示
- `gui_select_card` — 特定カードをアクティブ化
- `gui_deck_browser` — デッキビューに移動
- `gui_undo` — 最後の操作を取り消し

### リソース・プロンプト
- `system_info` — Ankiバージョン・プラットフォーム情報
- `review_session` — ガイド付きレビューワークフロー（interactive/quick/voiceモード）

---

## ベストプラクティス

### 1. 検索構文の活用

Anki検索構文を使って効率的にノートを絞り込む:

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
const notes = [...]; // 大量のノートデータ

for (const note of notes) {
  await add_note({ note });
}

// 処理後に同期
await sync();
```

### 3. エラーハンドリング

ノートタイプやデッキが存在しない場合のエラーに対処:

```typescript
try {
  await add_note({
    note: {
      deckName: "NonExistentDeck",
      modelName: "Basic",
      fields: { Front: "Test", Back: "Test" }
    }
  });
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
2. 手動でパッケージをインストール（Ankiのアドオンフォルダ内）
3. インターネット接続を確認

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
- [MCP開発ガイド](../developing-mcp/SKILL.md)
