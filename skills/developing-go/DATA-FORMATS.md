# データフォーマット処理

## JSON

### 基本的なエンコード・デコード

#### デコード（Unmarshal/Decoder）

```go
type User struct {
    ID   string `json:"id"`
    Name string `json:"name"`
}

// Unmarshal: []byteから変換
data := []byte(`{"id":"001","name":"gopher"}`)
var u User
if err := json.Unmarshal(data, &u); err != nil {
    log.Fatal(err)
}

// NewDecoder: io.Readerから変換（推奨: HTTP/ストリーム）
resp, _ := http.Get("https://api.example.com/user")
defer resp.Body.Close()
var u User
if err := json.NewDecoder(resp.Body).Decode(&u); err != nil {
    log.Fatal(err)
}
```

#### エンコード（Marshal/Encoder）

```go
u := User{ID: "001", Name: "gopher"}

// Marshal: []byteに変換
data, err := json.Marshal(u)
fmt.Println(string(data)) // {"id":"001","name":"gopher"}

// NewEncoder: io.Writerに変換（推奨: HTTP/ファイル）
var buf bytes.Buffer
if err := json.NewEncoder(&buf).Encode(u); err != nil {
    log.Fatal(err)
}
```

### 非公開フィールドの罠

```go
// Bad: 非公開フィールドはマッピングされない
type User struct {
    ID   string `json:"id"`
    name string `json:"name"` // 先頭小文字 → マッピングされない
}

// Good: 先頭大文字で公開
type User struct {
    ID   string `json:"id"`
    Name string `json:"name"`
}
```

### omitemptyとポインター型の使い分け

#### omitemptyの基本

```go
type User struct {
    Name     string `json:"name"`
    Optional string `json:"optional,omitempty"` // ゼロ値なら省略
}

u := User{Name: "gopher"}
data, _ := json.Marshal(u)
fmt.Println(string(data)) // {"name":"gopher"}
```

#### ゼロ値と区別してomitemptyする

数値の0、boolのfalse、空文字列を明示的に設定した場合も出力したいなら**ポインター型**を使う。

```go
type Product struct {
    Name  string `json:"name"`
    Price *int   `json:"price,omitempty"` // ポインター型
}

func Int(v int) *int { return &v }

p := Product{
    Name:  "商品A",
    Price: Int(0), // 0を明示的に設定
}
data, _ := json.Marshal(p)
fmt.Println(string(data)) // {"name":"商品A","price":0}
```

### DisallowUnknownFields

入力JSONに構造体に存在しないフィールドがある場合、エラーにする。

```go
type Input struct {
    Width  int `json:"width"`
    Height int `json:"height"`
}

data := []byte(`{"width":10,"height":20,"radius":5}`) // radiusは未知

dec := json.NewDecoder(bytes.NewReader(data))
dec.DisallowUnknownFields() // 有効化
var in Input
if err := dec.Decode(&in); err != nil {
    log.Fatal(err) // エラー: json: unknown field "radius"
}
```

### json.RawMessage（遅延評価・動的構造）

デコードを遅延させる、または部分的にデコードする。

```go
type Envelope struct {
    Type string          `json:"type"`
    Data json.RawMessage `json:"data"` // 遅延デコード
}

data := []byte(`{"type":"user","data":{"id":"001","name":"gopher"}}`)
var env Envelope
json.Unmarshal(data, &env)

switch env.Type {
case "user":
    var u User
    json.Unmarshal(env.Data, &u)
case "product":
    var p Product
    json.Unmarshal(env.Data, &p)
}
```

### カスタムマーシャラー（MarshalJSON/UnmarshalJSON）

独自のエンコード・デコードロジックを実装。

```go
type Date time.Time

func (d Date) MarshalJSON() ([]byte, error) {
    return []byte(`"` + time.Time(d).Format("2006-01-02") + `"`), nil
}

func (d *Date) UnmarshalJSON(data []byte) error {
    str := strings.Trim(string(data), `"`)
    t, err := time.Parse("2006-01-02", str)
    if err != nil {
        return err
    }
    *d = Date(t)
    return nil
}

type Event struct {
    Name string `json:"name"`
    Date Date   `json:"date"`
}

// 使用例
e := Event{Name: "Go Conference", Date: Date(time.Now())}
data, _ := json.Marshal(e)
fmt.Println(string(data)) // {"name":"Go Conference","date":"2025-01-15"}
```

---

## CSV

### encoding/csv基本

```go
// 読み込み
f, _ := os.Open("data.csv")
defer f.Close()
r := csv.NewReader(f)
records, err := r.ReadAll()
if err != nil {
    log.Fatal(err)
}

// 書き込み
f, _ := os.Create("output.csv")
defer f.Close()
w := csv.NewWriter(f)
w.Write([]string{"ID", "Name"})
w.Write([]string{"001", "Gopher"})
w.Flush()
```

### BOM付きファイル対応（spkg/bom）

```go
import "github.com/saintfish/chardet"
import "github.com/saintfish/chardet/simplifiedchinese"

f, _ := os.Open("data_with_bom.csv")
defer f.Close()

// BOM検出・除去
reader := bom.NewReader(f)
r := csv.NewReader(reader)
records, _ := r.ReadAll()
```

### Shift-JIS対応（golang.org/x/text）

```go
import (
    "golang.org/x/text/encoding/japanese"
    "golang.org/x/text/transform"
)

f, _ := os.Open("shift_jis.csv")
defer f.Close()

// Shift-JIS → UTF-8 変換
reader := transform.NewReader(f, japanese.ShiftJIS.NewDecoder())
r := csv.NewReader(reader)
records, _ := r.ReadAll()
```

### gocsvによる構造体マッピング

```go
import "github.com/gocarina/gocsv"

type User struct {
    ID   string `csv:"id"`
    Name string `csv:"name"`
}

// CSVファイル → 構造体スライス
f, _ := os.Open("users.csv")
defer f.Close()

var users []*User
if err := gocsv.UnmarshalFile(f, &users); err != nil {
    log.Fatal(err)
}

// 構造体スライス → CSVファイル
f, _ := os.Create("output.csv")
defer f.Close()
gocsv.MarshalFile(users, f)
```

### チャネルを使った巨大CSV逐次処理

```go
func processLargeCSV(path string) error {
    f, _ := os.Open(path)
    defer f.Close()

    r := csv.NewReader(f)
    records := make(chan []string, 100)

    // 読み込みゴルーチン
    go func() {
        defer close(records)
        for {
            record, err := r.Read()
            if err == io.EOF {
                break
            }
            if err != nil {
                log.Println(err)
                continue
            }
            records <- record
        }
    }()

    // 処理ゴルーチン
    for record := range records {
        // 1レコードずつ処理
        processRecord(record)
    }
    return nil
}
```

---

## Excel

### xuri/excelize

```go
import "github.com/xuri/excelize/v2"

// 読み込み
f, err := excelize.OpenFile("Book1.xlsx")
if err != nil {
    log.Fatal(err)
}
defer f.Close()

// セル読み込み
cell, _ := f.GetCellValue("Sheet1", "A1")
fmt.Println(cell)

// 書き込み
f := excelize.NewFile()
f.SetCellValue("Sheet1", "A1", "Hello")
f.SetCellValue("Sheet1", "B1", 100)
if err := f.SaveAs("output.xlsx"); err != nil {
    log.Fatal(err)
}
```

### ストリーム書き込み（StreamWriter）

大量データを効率的に書き込む。

```go
f := excelize.NewFile()
sw, err := f.NewStreamWriter("Sheet1")
if err != nil {
    log.Fatal(err)
}

// ヘッダー
sw.SetRow("A1", []interface{}{"ID", "Name", "Score"})

// データ
for i := 1; i <= 10000; i++ {
    row := []interface{}{i, fmt.Sprintf("User%d", i), rand.Intn(100)}
    cell, _ := excelize.CoordinatesToCellName(1, i+1)
    sw.SetRow(cell, row)
}

sw.Flush()
f.SaveAs("large.xlsx")
```

---

## 固定長データ

### 文字数 vs バイト数

日本語は1文字が複数バイト（UTF-8で3バイト）。固定長は**バイト数**で定義されることが多い。

```go
// Bad: 文字数でカウント
s := "こんにちは"
fmt.Println(len(s)) // 15（バイト数）

// Good: rune数でカウント
fmt.Println(utf8.RuneCountInString(s)) // 5（文字数）
```

### ianlopshire/go-fixedwidth

```go
import "github.com/ianlopshire/go-fixedwidth"

type Record struct {
    ID   string `fixed:"1,5"`   // 1-5バイト目
    Name string `fixed:"6,20"`  // 6-20バイト目
    Age  int    `fixed:"21,23"` // 21-23バイト目
}

// 読み込み
data := "00001Gopher             025"
var r Record
fixedwidth.Unmarshal([]byte(data), &r)
fmt.Printf("%+v\n", r) // {ID:00001 Name:Gopher Age:25}

// 書き込み
r := Record{ID: "00001", Name: "Gopher", Age: 25}
data, _ := fixedwidth.Marshal(r)
fmt.Println(string(data)) // 00001Gopher             025
```

---

## まとめ

データフォーマット処理のベストプラクティス：

- **JSON**: NewEncoder/NewDecoderを推奨（ストリーム対応）、omitemptyはポインター型と組み合わせ
- **CSV**: BOM/Shift-JIS対応、gocsv推奨、巨大CSVはチャネル処理
- **Excel**: excelize推奨、大量データはStreamWriter
- **固定長**: ianlopshire/go-fixedwidth推奨、文字数とバイト数の違いに注意
