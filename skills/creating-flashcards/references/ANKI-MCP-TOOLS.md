# Anki MCP Server ツール詳細リファレンス

このドキュメントは、Anki MCP Serverが提供する全ツールの詳細仕様とコード例を提供します。

---

## 1. コレクション管理

### sync

**説明**: AnkiWebとコレクションを同期します。

**パラメータ**: なし

**使用例**:
```typescript
// ローカルの変更をAnkiWebにアップロード
await sync();
```

**ユースケース**:
- バッチ処理後にクラウドへ変更を保存
- 複数デバイス間でのデータ同期

---

### list_decks

**説明**: 全デッキの名前とIDを取得します。

**パラメータ**: なし

**戻り値**:
```typescript
Array<{ name: string; id: number }>
```

**使用例**:
```typescript
const decks = await list_decks();
console.log(decks);
// [
//   { name: "Default", id: 1 },
//   { name: "Japanese::Vocabulary", id: 1234567890 },
//   { name: "Japanese::Grammar", id: 1234567891 }
// ]
```

**ユースケース**:
- デッキ構造の確認
- 特定デッキへのノート追加前の検証

---

### create_deck

**説明**: 新しいデッキを作成します。階層構造は `::` で区切ります。

**パラメータ**:
```typescript
{
  deck: string;  // デッキ名（例: "Japanese::JLPT_N3"）
}
```

**使用例**:
```typescript
// 階層デッキ作成
await create_deck({ deck: "Languages::Japanese::JLPT_N3" });

// シンプルなデッキ
await create_deck({ deck: "Quick Review" });
```

**注意事項**:
- 既存のデッキと同じ名前の場合、何も起こらない（エラーなし）
- 親デッキが存在しない場合、自動的に作成される

---

### find_notes

**説明**: Anki検索構文を使用してノートを検索します。

**パラメータ**:
```typescript
{
  query: string;  // Anki検索構文
}
```

**戻り値**:
```typescript
Array<number>  // ノートID配列
```

**使用例**:
```typescript
// デッキとタグで絞り込み
const noteIds = await find_notes({
  query: "deck:Japanese tag:N5"
});

// フィールド検索（ワイルドカード使用）
const noteIds = await find_notes({
  query: "Front:*こんにち*"
});

// 追加日指定
const recentNotes = await find_notes({
  query: "added:7"  // 過去7日間
});

// 複合条件
const noteIds = await find_notes({
  query: "deck:Japanese tag:verb -tag:mastered"
});
```

**検索構文例**:
| 構文 | 意味 |
|------|------|
| `deck:名前` | 特定デッキ内 |
| `tag:タグ名` | 特定タグ付き |
| `-tag:タグ名` | 特定タグを除外 |
| `Front:テキスト` | フロントフィールド検索 |
| `added:N` | 過去N日間に追加 |
| `is:due` | 復習期限 |
| `is:new` | 新規カード |

**詳細**: [Anki検索構文ドキュメント](https://docs.ankiweb.net/searching.html)

---

### notes_info

**説明**: ノートIDからノートの詳細情報を取得します。

**パラメータ**:
```typescript
{
  notes: Array<number>;  // ノートID配列
}
```

**戻り値**:
```typescript
Array<{
  noteId: number;
  modelName: string;
  tags: Array<string>;
  fields: Record<string, { value: string; order: number }>;
  cards: Array<number>;
}>
```

**使用例**:
```typescript
const noteIds = await find_notes({ query: "deck:Japanese" });
const notes = await notes_info({ notes: noteIds.slice(0, 10) });

for (const note of notes) {
  console.log(`Note ${note.noteId}:`);
  console.log(`  Model: ${note.modelName}`);
  console.log(`  Tags: ${note.tags.join(", ")}`);
  console.log(`  Fields:`, note.fields);
}
```

**ユースケース**:
- 既存ノートの内容確認
- バルク更新前のデータ検証

---

### add_note

**説明**: 新しいフラッシュカードを作成します。

**パラメータ**:
```typescript
{
  note: {
    deckName: string;
    modelName: string;
    fields: Record<string, string>;
    tags?: Array<string>;
    audio?: Array<{
      url: string;
      filename: string;
      fields: Array<string>;
    }>;
    video?: Array<{
      url: string;
      filename: string;
      fields: Array<string>;
    }>;
    picture?: Array<{
      url: string;
      filename: string;
      fields: Array<string>;
    }>;
  };
}
```

**戻り値**:
```typescript
number  // 新しいノートID
```

**使用例**:
```typescript
// シンプルな単語カード
const noteId = await add_note({
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

// 画像付きカード
await add_note({
  note: {
    deckName: "Biology",
    modelName: "Basic",
    fields: {
      Front: "Cell Structure",
      Back: "See diagram"
    },
    tags: ["biology", "cell"],
    picture: [{
      url: "https://example.com/cell.png",
      filename: "cell_diagram.png",
      fields: ["Back"]
    }]
  }
});
```

**注意事項**:
- `deckName` と `modelName` は事前に存在している必要がある
- フィールド名は大文字小文字を区別
- メディアURL指定時、Ankiが自動ダウンロード

---

### update_note_fields

**説明**: 既存ノートのフィールドを更新します。

**パラメータ**:
```typescript
{
  note: {
    id: number;
    fields: Record<string, string>;
    audio?: Array<{ url: string; filename: string; fields: Array<string>; }>;
    video?: Array<{ url: string; filename: string; fields: Array<string>; }>;
    picture?: Array<{ url: string; filename: string; fields: Array<string>; }>;
  };
}
```

**使用例**:
```typescript
// フィールド更新
await update_note_fields({
  note: {
    id: 1234567890,
    fields: {
      Back: "Hello (Greeting - Formal)"
    }
  }
});
```

**注意事項**:
- 指定したフィールドのみ更新（他のフィールドは変更されない）
- 存在しないフィールド名を指定するとエラー

---

### delete_notes

**説明**: ノートとそれに関連する全カードを削除します。

**パラメータ**:
```typescript
{
  notes: Array<number>;  // 削除するノートID配列
}
```

**使用例**:
```typescript
// 単一ノート削除
await delete_notes({ notes: [1234567890] });

// 複数ノート削除
const oldNotes = await find_notes({ query: "tag:deprecated" });
await delete_notes({ notes: oldNotes });
```

**注意事項**:
- 削除は不可逆的（Undo可能期間を除く）
- ノートを削除すると、関連する全カードも削除される

---

## 2. カード操作

### card_management

**説明**: カードの位置変更、デッキ間移動、bury/unburyを実行します。

**パラメータ**:
```typescript
{
  cards: Array<number>;        // カードID配列
  deck?: string;               // 移動先デッキ名
  position?: "top" | "bottom"; // キュー内の位置
  bury?: boolean;              // bury状態にする
  unbury?: boolean;            // unbury状態にする
}
```

**使用例**:
```typescript
// カードを別デッキに移動
await card_management({
  cards: [9876543210],
  deck: "Japanese::Review"
});

// カードをbury（一時的に非表示）
await card_management({
  cards: [9876543210],
  bury: true
});
```

---

### get_due_cards

**説明**: 指定したデッキの復習期限カードを取得します。

**パラメータ**:
```typescript
{
  deck?: string;  // デッキ名（省略時は全デッキ）
}
```

**使用例**:
```typescript
const cards = await get_due_cards({ deck: "Japanese::JLPT_N3" });
console.log(`${cards.length} cards due for review`);
```

---

### present_card

**説明**: カードの問題面と解答面を取得します。

**パラメータ**:
```typescript
{
  card: number;  // カードID
}
```

**戻り値**:
```typescript
{
  question: string;  // 問題面（HTML）
  answer: string;    // 解答面（HTML）
}
```

---

### rate_card

**説明**: カードのレビューを記録し、次の復習スケジュールを設定します。

**パラメータ**:
```typescript
{
  card: number;
  ease: "again" | "hard" | "good" | "easy";
}
```

**easeの意味**:
| 値 | 意味 | 次回復習間隔 |
|----|------|-------------|
| `again` | 忘れた | 短縮 |
| `hard` | 難しかった | やや短縮 |
| `good` | 思い出せた | 通常 |
| `easy` | 簡単 | 延長 |

---

## 3. ノートタイプ・スタイリング

### model_names

**説明**: 利用可能なノートタイプの一覧を取得します。

**使用例**:
```typescript
const models = await model_names();
// ["Basic", "Basic (and reversed card)", "Cloze", ...]
```

---

### model_field_names

**説明**: 特定のノートタイプのフィールド名を取得します。

**使用例**:
```typescript
const fields = await model_field_names({ modelName: "Basic" });
// ["Front", "Back"]
```

---

### model_styling / update_model_styling

**説明**: ノートタイプのCSSスタイリングを取得・更新します。

```typescript
const styling = await model_styling({ modelName: "Basic" });
await update_model_styling({ modelName: "Basic", css: "..." });
```

---

### create_model

**説明**: 新しいノートタイプを作成します。

```typescript
await create_model({
  modelName: "Vocabulary Extended",
  inOrderFields: ["Word", "Reading", "Meaning", "Example", "Notes"],
  cardTemplates: [{
    Name: "Card 1",
    Front: "<div class='word'>{{Word}}</div>",
    Back: "{{FrontSide}}<hr>Reading: {{Reading}}<br>Meaning: {{Meaning}}"
  }]
});
```

---

## 4. メディア管理

### store_media_file

**説明**: 画像・音声ファイルをAnkiのメディアフォルダに保存します。

```typescript
await store_media_file({
  filename: "cell_diagram.png",
  data: base64ImageData,
  deleteExisting: true
});
```

---

### get_media_files_names / delete_media_file

```typescript
const pngFiles = await get_media_files_names({ pattern: "*.png" });
await delete_media_file({ filename: "old_image.png" });
```

---

## 5. GUI統合

| ツール | 説明 |
|--------|------|
| `gui_browse` | Ankiブラウザを検索付きで開く |
| `gui_add_cards` | カード追加ダイアログを開く |
| `gui_edit_note` | ノート編集ダイアログを開く |
| `gui_current_card` | 現在レビュー中のカード情報を取得 |
| `gui_show_question` | カードの問題面を表示 |
| `gui_show_answer` | カードの解答面を表示 |
| `gui_select_card` | 特定のカードをアクティブにする |
| `gui_deck_browser` | デッキビューに移動 |
| `gui_undo` | 最後の操作を取り消す |

---

## 6. リソース・プロンプト

### system_info

AnkiのバージョンとプラットフォームをGET。

### review_session

**モード:**
| モード | ワークフロー |
|-------|------------|
| `interactive` | 問題表示 → ヒント → ユーザー回答 → 正解表示 → 評価 |
| `quick` | 問題表示 → 正解表示 → 評価 |
| `voice` | 音声アシスタント向けの簡潔な応答 |
