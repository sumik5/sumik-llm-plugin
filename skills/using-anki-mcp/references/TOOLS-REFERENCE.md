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

// 音声付きカード
await add_note({
  note: {
    deckName: "Japanese::Vocabulary",
    modelName: "Basic",
    fields: {
      Front: "ありがとう",
      Back: "Thank you"
    },
    audio: [{
      url: "https://example.com/arigatou.mp3",
      filename: "arigatou.mp3",
      fields: ["Front"]
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

// 複数フィールド同時更新
await update_note_fields({
  note: {
    id: 1234567890,
    fields: {
      Front: "こんにちは（正式な挨拶）",
      Back: "Hello (Formal greeting)",
      Extra: "Used in business settings"
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

// カードをキューの先頭に移動
await card_management({
  cards: [9876543210],
  position: "top"
});

// カードをbury（一時的に非表示）
await card_management({
  cards: [9876543210],
  bury: true
});

// カードをunbury
await card_management({
  cards: [9876543210],
  unbury: true
});
```

**ユースケース**:
- 優先的に復習したいカードを先頭に移動
- 類似カードを一時的に非表示（bury）

---

### get_due_cards

**説明**: 指定したデッキの復習期限カードを取得します。

**パラメータ**:
```typescript
{
  deck?: string;  // デッキ名（省略時は全デッキ）
}
```

**戻り値**:
```typescript
Array<{
  id: number;
  due: number;
  interval: number;
  ease: number;
}>
```

**使用例**:
```typescript
// 特定デッキの復習カード取得
const cards = await get_due_cards({ deck: "Japanese::JLPT_N3" });
console.log(`${cards.length} cards due for review`);

// 全デッキの復習カード
const allDueCards = await get_due_cards();
```

**ユースケース**:
- レビューセッション開始前のカード数確認
- 学習進捗の分析

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

**使用例**:
```typescript
const cards = await get_due_cards({ deck: "Japanese::Vocabulary" });

if (cards.length > 0) {
  const cardInfo = await present_card({ card: cards[0].id });
  console.log("Question:", cardInfo.question);
  console.log("Answer:", cardInfo.answer);
}
```

**注意事項**:
- HTMLタグが含まれる場合があるため、レンダリング時は注意
- メディアファイルへの参照はAnkiのメディアフォルダパス

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

**使用例**:
```typescript
const cards = await get_due_cards({ deck: "Japanese::Vocabulary" });

if (cards.length > 0) {
  const card = cards[0];
  const cardInfo = await present_card({ card: card.id });

  // ユーザーの回答を評価
  const userAnswer = getUserInput();
  const ease = evaluateAnswer(userAnswer, cardInfo.answer)
    ? "good"
    : "again";

  await rate_card({ card: card.id, ease });
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

**パラメータ**: なし

**戻り値**:
```typescript
Array<string>  // ノートタイプ名配列
```

**使用例**:
```typescript
const models = await model_names();
console.log("Available note types:", models);
// ["Basic", "Basic (and reversed card)", "Cloze", ...]
```

---

### model_field_names

**説明**: 特定のノートタイプのフィールド名を取得します。

**パラメータ**:
```typescript
{
  modelName: string;
}
```

**戻り値**:
```typescript
Array<string>  // フィールド名配列
```

**使用例**:
```typescript
const fields = await model_field_names({ modelName: "Basic" });
console.log("Fields:", fields);
// ["Front", "Back"]

const clozeFields = await model_field_names({ modelName: "Cloze" });
console.log("Cloze fields:", clozeFields);
// ["Text", "Extra"]
```

---

### model_styling

**説明**: ノートタイプのCSSスタイリングを取得します。

**パラメータ**:
```typescript
{
  modelName: string;
}
```

**戻り値**:
```typescript
{
  css: string;
}
```

**使用例**:
```typescript
const styling = await model_styling({ modelName: "Basic" });
console.log(styling.css);
```

---

### update_model_styling

**説明**: ノートタイプのCSSスタイリングを更新します。

**パラメータ**:
```typescript
{
  modelName: string;
  css: string;
}
```

**使用例**:
```typescript
await update_model_styling({
  modelName: "Basic",
  css: `
    .card {
      font-family: "Noto Sans JP", sans-serif;
      font-size: 24px;
      text-align: center;
      color: #333;
      background-color: #f9f9f9;
    }

    .front {
      font-size: 28px;
      font-weight: bold;
      color: #0066cc;
    }

    .back {
      font-size: 20px;
      color: #555;
    }

    .night_mode .card {
      background-color: #1e1e1e;
      color: #e0e0e0;
    }
  `
});
```

**ユースケース**:
- ダークモード対応
- フォントサイズ・色のカスタマイズ
- レスポンシブデザイン

---

### create_model

**説明**: 新しいノートタイプを作成します。

**パラメータ**:
```typescript
{
  modelName: string;
  inOrderFields: Array<string>;
  css?: string;
  isCloze?: boolean;
  cardTemplates?: Array<{
    Name: string;
    Front: string;
    Back: string;
  }>;
}
```

**使用例**:
```typescript
// 単語カード用のカスタムノートタイプ
await create_model({
  modelName: "Vocabulary Extended",
  inOrderFields: ["Word", "Reading", "Meaning", "Example", "Notes"],
  css: `
    .card { font-family: arial; font-size: 20px; }
    .word { font-size: 32px; color: #0066cc; }
  `,
  cardTemplates: [{
    Name: "Card 1",
    Front: "<div class='word'>{{Word}}</div>",
    Back: "{{FrontSide}}<hr>Reading: {{Reading}}<br>Meaning: {{Meaning}}"
  }]
});

// Cloze形式のカスタムノートタイプ
await create_model({
  modelName: "Custom Cloze",
  inOrderFields: ["Text", "Context", "Extra"],
  isCloze: true,
  css: `
    .cloze { font-weight: bold; color: blue; }
  `
});
```

---

## 4. メディア管理

### store_media_file

**説明**: 画像・音声ファイルをAnkiのメディアフォルダに保存します。

**パラメータ**:
```typescript
{
  filename: string;
  data: string;           // Base64エンコード文字列
  deleteExisting?: boolean;
}
```

**使用例**:
```typescript
// 画像アップロード
const imageData = fs.readFileSync("diagram.png").toString("base64");
await store_media_file({
  filename: "cell_diagram.png",
  data: imageData,
  deleteExisting: true
});

// 音声アップロード
const audioData = fs.readFileSync("pronunciation.mp3").toString("base64");
await store_media_file({
  filename: "word_pronunciation.mp3",
  data: audioData,
  deleteExisting: false
});
```

**注意事項**:
- `deleteExisting: true` で既存の同名ファイルを上書き
- ファイル名は一意にすることを推奨（タイムスタンプ付与等）

---

### get_media_files_names

**説明**: パターンに一致するメディアファイル名を取得します。

**パラメータ**:
```typescript
{
  pattern?: string;  // ワイルドカード使用可能（例: "*.png"）
}
```

**戻り値**:
```typescript
Array<string>  // ファイル名配列
```

**使用例**:
```typescript
// PNG画像一覧
const pngFiles = await get_media_files_names({ pattern: "*.png" });

// 特定プレフィックスのファイル
const userFiles = await get_media_files_names({ pattern: "user_*" });

// 全メディアファイル
const allMedia = await get_media_files_names();
```

---

### delete_media_file

**説明**: メディアファイルを削除します。

**パラメータ**:
```typescript
{
  filename: string;
}
```

**使用例**:
```typescript
// 単一ファイル削除
await delete_media_file({ filename: "old_image.png" });

// 未使用メディアの一括削除
const allMedia = await get_media_files_names();
const usedMedia = getUsedMediaFromNotes(); // カスタム関数

const unusedMedia = allMedia.filter(f => !usedMedia.includes(f));
for (const file of unusedMedia) {
  await delete_media_file({ filename: file });
}
```

---

## 5. GUI統合

### gui_browse

**説明**: Ankiブラウザを検索付きで開きます。

**パラメータ**:
```typescript
{
  query?: string;  // Anki検索構文
}
```

**使用例**:
```typescript
// 特定タグのカードをブラウザで表示
await gui_browse({ query: "tag:review_needed" });

// デッキ全体を表示
await gui_browse({ query: "deck:Japanese::JLPT_N3" });
```

---

### gui_add_cards

**説明**: カード追加ダイアログを開きます。

**パラメータ**:
```typescript
{
  deckName?: string;  // 初期選択デッキ
}
```

**使用例**:
```typescript
await gui_add_cards({ deckName: "Japanese::Vocabulary" });
```

---

### gui_edit_note

**説明**: ノート編集ダイアログを開きます。

**パラメータ**:
```typescript
{
  noteId: number;
}
```

**使用例**:
```typescript
const notes = await find_notes({ query: "tag:needs_review" });
if (notes.length > 0) {
  await gui_edit_note({ noteId: notes[0] });
}
```

---

### gui_current_card

**説明**: 現在レビュー中のカード情報を取得します。

**パラメータ**: なし

**戻り値**:
```typescript
{
  noteId: number;
  cardId: number;
}
```

**使用例**:
```typescript
const current = await gui_current_card();
if (current) {
  console.log(`Current card: ${current.cardId}`);
  const noteInfo = await notes_info({ notes: [current.noteId] });
}
```

---

### gui_show_question

**説明**: カードの問題面を表示します（レビュー画面）。

**パラメータ**: なし

**使用例**:
```typescript
await gui_show_question();
```

---

### gui_show_answer

**説明**: カードの解答面を表示します（レビュー画面）。

**パラメータ**: なし

**使用例**:
```typescript
await gui_show_answer();
```

---

### gui_select_card

**説明**: 特定のカードをアクティブにします。

**パラメータ**:
```typescript
{
  cardId: number;
}
```

**使用例**:
```typescript
const cards = await get_due_cards({ deck: "Japanese::Vocabulary" });
if (cards.length > 0) {
  await gui_select_card({ cardId: cards[0].id });
}
```

---

### gui_deck_browser

**説明**: デッキビューに移動します。

**パラメータ**: なし

**使用例**:
```typescript
await gui_deck_browser();
```

---

### gui_undo

**説明**: 最後の操作を取り消します。

**パラメータ**: なし

**使用例**:
```typescript
await gui_undo();
```

---

## 6. リソース・プロンプト

### system_info

**説明**: Ankiのバージョン情報とプラットフォーム情報を取得します。

**パラメータ**: なし

**戻り値**:
```typescript
{
  version: string;
  platform: string;
}
```

**使用例**:
```typescript
const info = await system_info();
console.log(`Anki version: ${info.version}`);
console.log(`Platform: ${info.platform}`);
```

---

### review_session

**説明**: ガイド付きレビューワークフローを提供するプロンプトリソース。

**パラメータ**:
```typescript
{
  mode: "interactive" | "quick" | "voice";
  deck?: string;
}
```

**モード説明**:
| モード | 説明 | ワークフロー |
|-------|------|------------|
| `interactive` | 対話的レビュー | 問題表示 → ヒント提供 → ユーザー回答 → 正解表示 → 評価 |
| `quick` | クイックレビュー | 問題表示 → 正解表示 → 評価 |
| `voice` | 音声アシスタント向け | 簡潔な応答、音声読み上げに最適化 |

**使用例**:
```typescript
// 対話的レビューセッション
const session = await review_session({
  mode: "interactive",
  deck: "Japanese::JLPT_N3"
});

// クイックレビュー
const quickSession = await review_session({
  mode: "quick",
  deck: "English::Vocabulary"
});

// 音声モード（音声アシスタント用）
const voiceSession = await review_session({
  mode: "voice",
  deck: "Spanish::Verbs"
});
```

**ユースケース**:
- AIアシスタントによる学習サポート
- 音声インターフェースでの復習
- カスタム学習ワークフローの実装

---

## まとめ

このリファレンスは、Anki MCP Serverの全ツールを網羅しています。各ツールを組み合わせることで、以下のような高度なワークフローを実現できます:

1. **自動フラッシュカード生成**: テキスト解析 → `create_deck` + `add_note`
2. **学習進捗分析**: `get_due_cards` + `notes_info` → データ可視化
3. **カスタムレビューシステム**: `present_card` + `rate_card` + AIによる評価
4. **メディア統合学習**: `store_media_file` + `add_note` で画像・音声付きカード
5. **GUI自動化**: `gui_*` ツール群でAnki UIの操作自動化

詳細な実装例は `SKILL.md` の「活用パターン」セクションを参照してください。
