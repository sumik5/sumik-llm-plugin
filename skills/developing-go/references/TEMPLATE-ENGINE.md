# テンプレートエンジン

GoはWebページ生成に `html/template`、プレーンテキスト生成に `text/template` を提供する。XSS防御のため、**Webページには必ず `html/template` を使用する**。

→ HTTPサーバーの設定と組み合わせは [HTTP-SERVER.md](./HTTP-SERVER.md) 参照

---

## 1. html/template（XSS防御）

### text/template との根本的な違い

`html/template` はコンテキスト依存エスケープ（Context-Aware Escaping）を自動で適用する。同じ変数が、出力先のコンテキスト（HTML本文 / 属性値 / JavaScript / CSS / URL）によって異なるエスケープ処理を受ける。

```go
// ❌ text/template: エスケープなし → XSS脆弱性
import "text/template"

tmpl := template.Must(template.New("").Parse(`<p>{{.UserInput}}</p>`))
tmpl.Execute(w, map[string]string{
    "UserInput": `<script>alert('XSS')</script>`,
})
// 出力: <p><script>alert('XSS')</script></p>  ← スクリプト実行される！

// ✅ html/template: コンテキスト依存エスケープが自動適用
import "html/template"

tmpl := template.Must(template.New("").Parse(`<p>{{.UserInput}}</p>`))
tmpl.Execute(w, map[string]string{
    "UserInput": `<script>alert('XSS')</script>`,
})
// 出力: <p>&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;</p>  ← 安全
```

### コンテキスト別の自動エスケープ

```go
const tmplText = `
<p>{{.Name}}</p>                          <!-- HTMLエスケープ -->
<a href="{{.URL}}">link</a>               <!-- URLエスケープ -->
<a onclick="foo('{{.Value}}')">btn</a>    <!-- JSエスケープ -->
<div style="color: {{.Color}}">text</div>  <!-- CSSエスケープ -->
<img src="/img/{{.Path}}">                <!-- URLパスエスケープ -->
`

tmpl := template.Must(template.New("").Parse(tmplText))
tmpl.Execute(w, map[string]string{
    "Name":  `<b>Alice & Bob</b>`,       // → &lt;b&gt;Alice &amp; Bob&lt;/b&gt;
    "URL":   `javascript:alert('XSS')`,  // → #ZgotmplZ（危険URLを無効化）
    "Value": `'; DROP TABLE users; --`,  // → \x27; DROP TABLE users; --
    "Color": `red; background:url(x)`,   // → ZgotmplZ（不正CSS無効化）
    "Path":  `../../../etc/passwd`,      // → ..%2F..%2F..%2Fetc%2Fpasswd
})
```

### template.HTML / template.JS / template.URL（信頼済みコンテンツ）

開発者が**明示的に安全だと確認した**コンテンツのエスケープを回避する。

```go
// ❌ ユーザー入力に template.HTML を使うのは危険
userInput := r.FormValue("content")
data := map[string]interface{}{
    "Body": template.HTML(userInput), // ← XSS脆弱性！
}

// ✅ 信頼済みのサーバーサイドHTML（DBから取得したサニタイズ済みコンテンツ等）
safeHTML := sanitizeHTML(userContent) // ブルーリスト方式でサニタイズ済み
data := map[string]interface{}{
    "Body":      template.HTML(safeHTML),     // HTML: エスケープ回避
    "Script":    template.JS(`alert("ok")`),  // JS: エスケープ回避
    "SafeURL":   template.URL("https://example.com"), // URL: バリデーション済み
}
```

---

## 2. マルチファイルテンプレート

### ディレクトリ構成例

```
templates/
├── layout.html      # ベースレイアウト
├── partials/
│   ├── navbar.html  # 共通ナビゲーション
│   └── footer.html  # 共通フッター
└── pages/
    ├── index.html   # トップページコンテンツ
    └── about.html   # Aboutページコンテンツ
```

### テンプレートファイル

```html
<!-- templates/layout.html -->
<!DOCTYPE html>
<html>
<head><title>{{block "title" .}}デフォルトタイトル{{end}}</title></head>
<body>
  {{template "navbar" .}}
  <main>
    {{block "content" .}}デフォルトコンテンツ{{end}}
  </main>
  {{template "footer" .}}
</body>
</html>

<!-- templates/partials/navbar.html -->
{{define "navbar"}}
<nav>
  <a href="/">ホーム</a>
  {{if .User}}<a href="/logout">ログアウト ({{.User.Name}})</a>{{end}}
</nav>
{{end}}

<!-- templates/pages/index.html -->
{{define "title"}}トップページ{{end}}
{{define "content"}}
<h1>ようこそ、{{.User.Name}}さん</h1>
<p>登録日: {{.User.CreatedAt | formatDate}}</p>
{{end}}
```

### ParseFilesとExecuteTemplate

```go
// ✅ ParseFiles: 複数ファイルを一度に読み込む
// 注意: ParseFilesは最初のファイル名がテンプレート名になる
tmpl, err := template.New("layout").Funcs(funcMap).ParseFiles(
    "templates/layout.html",
    "templates/partials/navbar.html",
    "templates/partials/footer.html",
    "templates/pages/index.html",
)
if err != nil {
    log.Fatal(err)
}

// ExecuteTemplate: 名前を指定して実行
// ParseFilesで読んだ場合、ファイルのbase名がテンプレート名
err = tmpl.ExecuteTemplate(w, "layout.html", data)
```

### ParseGlob + Must パターン（起動時一括読み込み）

```go
// ✅ アプリ起動時にテンプレートを一括コンパイル（推奨）
var templates *template.Template

func init() {
    funcMap := template.FuncMap{
        "formatDate": func(t time.Time) string {
            return t.Format("2006/01/02")
        },
    }
    // template.Must: エラー時にpanicする（起動時チェックに最適）
    templates = template.Must(
        template.New("").Funcs(funcMap).ParseGlob("templates/**/*.html"),
    )
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
    data := PageData{
        Title: "トップページ",
        User:  getCurrentUser(r),
    }
    if err := templates.ExecuteTemplate(w, "layout.html", data); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
    }
}
```

---

## 3. テンプレート関数（FuncMap）

### カスタム関数の登録

```go
// ✅ FuncMapでカスタム関数を登録
funcMap := template.FuncMap{
    // 日付フォーマット
    "formatDate": func(t time.Time) string {
        return t.Format("2006年01月02日")
    },
    // 数値フォーマット（3桁区切り）
    "formatNumber": func(n int) string {
        return humanize.Comma(int64(n))
    },
    // 文字列切り詰め
    "truncate": func(s string, n int) string {
        runes := []rune(s)
        if len(runes) <= n {
            return s
        }
        return string(runes[:n]) + "..."
    },
    // スライスの結合
    "join": strings.Join,
}

tmpl := template.Must(template.New("").Funcs(funcMap).ParseFiles("template.html"))
```

### パイプラインパターン

```html
<!-- テンプレート内でのパイプライン使用 -->
<p>投稿日: {{.CreatedAt | formatDate}}</p>
<p>ユーザー数: {{.UserCount | formatNumber}}人</p>
<p>概要: {{.Description | truncate 100}}</p>
<p>タグ: {{.Tags | join ", "}}</p>

<!-- 複数パイプ -->
<p>{{.Name | html | truncate 50}}</p>
```

### 組み込み関数

```html
<!-- 論理演算 -->
{{if and .IsLoggedIn .IsAdmin}}管理者メニュー{{end}}
{{if or .IsGuest (not .IsLoggedIn)}}ゲスト向けコンテンツ{{end}}

<!-- 長さ確認 -->
{{if gt (len .Items) 0}}
  {{range .Items}}<li>{{.}}</li>{{end}}
{{else}}
  <li>アイテムなし</li>
{{end}}

<!-- インデックスアクセス -->
最初の要素: {{index .Items 0}}
マップの値: {{index .Config "key"}}
```

---

## 4. 使い分けガイド

| 用途 | パッケージ | 理由 |
|------|----------|------|
| Webページ（HTML出力） | `html/template` | XSS防御が必須 |
| APIレスポンス（JSON） | `encoding/json` | テンプレート不要 |
| メール本文（テキスト） | `text/template` | エスケープ不要 |
| メール本文（HTML） | `html/template` | XSS防御（重要） |
| CLI出力 / ログメッセージ | `text/template` | エスケープ不要 |
| コード生成（Go/SQL等） | `text/template` | エスケープが邪魔になる |
| 設定ファイル生成 | `text/template` | エスケープ不要 |
| Kubernetes manifest | `text/template` | YAML生成 |

```go
// ✅ コード生成はtext/templateを使う
import "text/template"

const goTemplate = `
package {{.Package}}

// {{.TypeName}} は自動生成されたコードです。
type {{.TypeName}} struct {
    {{range .Fields}}{{.Name}} {{.Type}}
    {{end}}
}
`

tmpl := template.Must(template.New("").Parse(goTemplate))
tmpl.Execute(os.Stdout, struct {
    Package  string
    TypeName string
    Fields   []struct{ Name, Type string }
}{
    Package:  "main",
    TypeName: "User",
    Fields: []struct{ Name, Type string }{
        {"ID", "int64"},
        {"Name", "string"},
    },
})
```

---

## 5. テンプレートの再利用パターン

### ページデータ構造

```go
// ✅ 全ページ共通データとページ固有データを分離
type BaseData struct {
    Title       string
    User        *User
    CSRFToken   string
    FlashMessage string
}

type IndexPageData struct {
    BaseData
    Posts    []Post
    HasMore  bool
    NextPage int
}

// ハンドラーでの使用
func indexHandler(w http.ResponseWriter, r *http.Request) {
    data := IndexPageData{
        BaseData: BaseData{
            Title:     "トップページ",
            User:      getUser(r),
            CSRFToken: generateCSRF(),
        },
        Posts:    getPosts(r.Context()),
        HasMore:  true,
        NextPage: 2,
    }
    templates.ExecuteTemplate(w, "layout.html", data)
}
```

### エラーページのテンプレート

```go
// ✅ エラーレスポンス専用ヘルパー
func renderError(w http.ResponseWriter, status int, message string) {
    w.WriteHeader(status)
    templates.ExecuteTemplate(w, "error.html", map[string]interface{}{
        "Status":  status,
        "Message": message,
    })
}
```

---

## 6. セキュリティ注意事項

```go
// ❌ ユーザー入力でテンプレート文字列を構築してはいけない
userInput := r.FormValue("template")
tmpl, _ := template.New("").Parse(userInput) // RCE脆弱性！

// ✅ テンプレートは必ず静的なソースコードから読み込む
tmpl := template.Must(template.ParseFiles("templates/safe.html"))

// ✅ Content-Type ヘッダーを明示的に設定
func renderHTML(w http.ResponseWriter, tmplName string, data interface{}) {
    w.Header().Set("Content-Type", "text/html; charset=utf-8")
    if err := templates.ExecuteTemplate(w, tmplName, data); err != nil {
        // エラー詳細をユーザーに露出しない
        log.Printf("template execution error: %v", err)
        http.Error(w, "Internal Server Error", http.StatusInternalServerError)
    }
}
```

---

## チェックリスト

- [ ] Webページ出力に `html/template` を使っているか（`text/template` ではないか）
- [ ] `template.HTML` / `template.JS` を使う箇所は信頼済みコンテンツのみか
- [ ] テンプレートはアプリ起動時に一括コンパイルしているか（リクエストごとのParseは避ける）
- [ ] ユーザー入力をテンプレート文字列として使っていないか
- [ ] ExecuteTemplateのエラーを適切にハンドリングしているか
- [ ] Content-Typeヘッダーを設定しているか
