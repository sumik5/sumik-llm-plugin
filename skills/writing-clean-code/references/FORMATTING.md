# コードフォーマットの原則

Robert C. Martin「Clean Code」第5章の知見に基づいたフォーマット原則。

## 📋 目次
1. [フォーマットの目的](#フォーマットの目的)
2. [新聞記事メタファ](#新聞記事メタファ)
3. [垂直フォーマット](#垂直フォーマット)
4. [水平フォーマット](#水平フォーマット)
5. [インデント](#インデント)
6. [チームルール](#チームルール)

---

## フォーマットの目的

**フォーマットはコミュニケーションである。**

> "Code formatting is about communication, and communication is the professional developer's first order of business."
> — Robert C. Martin, Clean Code

「動くコード」よりも「読めるコード」を優先すること。今日実装した機能は次のリリースで変わるかもしれないが、コードの可読性はすべての変更に長く影響し続ける。コーディングスタイルと規律は、元のコードが跡形もなく変わっても生き残る。

### コードスメル検出チェックリスト

- [ ] 空行なしで異なる概念が連続している
- [ ] 関連する行が離れた場所に分散している
- [ ] 呼び出し先の関数が呼び出し元より上に定義されている
- [ ] インスタンス変数がクラスの途中に埋もれている
- [ ] 1行が120文字を超えている
- [ ] タブとスペースが混在している
- [ ] チームメンバーごとにフォーマットスタイルが異なる

---

## 新聞記事メタファ

**ソースファイルは新聞記事のように構成すべき。**

| 新聞記事 | ソースファイル |
|---------|--------------|
| 見出し | ファイル名・クラス名（概要を伝える） |
| 最初の段落 | 冒頭の数行（高レベルの概念・アルゴリズム） |
| 詳細な記述 | 下に向かうほど低レベルな実装詳細 |

良い新聞は多くの短い記事で構成され、読みやすい。**同様に、ソースファイルも短く、読み下せるように設計する。**

### 推奨ファイルサイズ

FitNesse（約50,000行のシステム）の分析結果:
- **平均**: 約200行
- **上限**: 500行
- **ルール**: ほとんどのファイルを200行以内に収めることが望ましい

小さなファイルは大きなファイルより理解しやすい。

---

## 垂直フォーマット

### 垂直の開放性（Vertical Openness）

**概念と概念の区切りには空行を入れる。**

```java
// ✅ 良い例: 空行で概念を分離
package fitnesse.wikitext.widgets;

import java.util.regex.*;

public class BoldWidget extends ParentWidget {
    public static final String REGEXP = "'''.+?'''";
    private static final Pattern pattern =
        Pattern.compile("'''(.+?)'''",
            Pattern.MULTILINE + Pattern.DOTALL
        );

    public BoldWidget(ParentWidget parent, String text) throws Exception {
        super(parent);
        Matcher match = pattern.matcher(text);
        match.find();
        addChildWidgets(match.group(1));
    }

    public String render() throws Exception {
        StringBuffer html = new StringBuffer("<b>");
        html.append(childHtml()).append("</b>");
        return html.toString();
    }
}
```

```java
// ❌ 悪い例: 空行なし（概念の境界が見えない）
package fitnesse.wikitext.widgets;
import java.util.regex.*;
public class BoldWidget extends ParentWidget {
    public static final String REGEXP = "'''.+?'''";
    private static final Pattern pattern = Pattern.compile("'''(.+?)'''", Pattern.MULTILINE + Pattern.DOTALL);
    public BoldWidget(ParentWidget parent, String text) throws Exception {
        super(parent);
        Matcher match = pattern.matcher(text);
        match.find();
        addChildWidgets(match.group(1));}
    public String render() throws Exception {
        StringBuffer html = new StringBuffer("<b>");
        html.append(childHtml()).append("</b>");
        return html.toString();}
}
```

### 垂直の密度（Vertical Density）

**関連する行は密集させる。不要なコメントで密度を下げない。**

```java
// ✅ 良い例: 関連する変数が視覚的にグループ化されている
public class ReporterConfig {
    private String m_className;
    private List<Property> m_properties = new ArrayList<Property>();

    public void addProperty(Property property) {
        m_properties.add(property);
    }
}

// ❌ 悪い例: 自明なコメントが関連する変数を引き裂いている
public class ReporterConfig {
    /**
     * The class name of the reporter listener
     */
    private String m_className;

    /**
     * The properties of the reporter listener
     */
    private List<Property> m_properties = new ArrayList<Property>();

    public void addProperty(Property property) {
        m_properties.add(property);
    }
}
```

### 垂直距離（Vertical Distance）

**密接に関連する概念は垂直的に近くに配置する。**

#### 変数宣言

- **ローカル変数**: 使用箇所の直上に宣言
- **ループ制御変数**: ループ文内で宣言
- **インスタンス変数**: クラスの先頭に一箇所に集める

```java
// ✅ 良い例: 変数を使用直前に宣言
private static void readPreferences() {
    InputStream is = null;
    try {
        is = new FileInputStream(getPreferencesFile());
        setPreferences(new Properties(getPreferences()));
        getPreferences().load(is);
    } catch (IOException e) {
        // ...
    }
}

// ✅ ループ制御変数はループ内に
public int countTestCases() {
    int count = 0;
    for (Test each : tests)
        count += each.countTestCases();
    return count;
}
```

#### 依存関数（Stepdown Rule）

**呼び出す関数（caller）は呼び出される関数（callee）の上に配置する。**

```java
// ✅ 良い例: 高レベルな関数が上、低レベルな実装が下
public class WikiPageResponder {
    public Response makeResponse(FitNesseContext context, Request request) throws Exception {
        String pageName = getPageNameOrDefault(request, "FrontPage");
        loadPage(pageName, context);
        if (page == null)
            return notFoundResponse(context, request);
        else
            return makePageResponse(context);
    }

    private String getPageNameOrDefault(Request request, String defaultPageName) {
        String pageName = request.getResource();
        if (StringUtil.isBlank(pageName))
            pageName = defaultPageName;
        return pageName;
    }

    protected void loadPage(String resource, FitNesseContext context) throws Exception {
        // ...
    }

    private Response notFoundResponse(FitNesseContext context, Request request) throws Exception {
        return new NotFoundResponder().makeResponse(context, request);
    }
}
```

プログラムは高レベルから低レベルへと**自然な流れ**を持つ。読者はスクロールせずに上から読み下せる。

#### 概念的類似性（Conceptual Affinity）

**似た名前や共通の目的を持つ関数は近くに配置する。**

```java
// ✅ 良い例: assertTrue/assertFalse は近くに配置
public class Assert {
    static public void assertTrue(String message, boolean condition) {
        if (!condition)
            fail(message);
    }

    static public void assertTrue(boolean condition) {
        assertTrue(null, condition);
    }

    static public void assertFalse(String message, boolean condition) {
        assertTrue(message, !condition);
    }

    static public void assertFalse(boolean condition) {
        assertFalse(null, condition);
    }
}
```

互いを呼び出すことがなくても、概念的な親近性があれば近くに置くべき。

### 垂直の順序（Vertical Ordering）

高レベルな概念を先に示し、詳細は後で。

| 位置 | 内容 |
|-----|------|
| 上位 | public関数・高レベルアルゴリズム |
| 下位 | private関数・低レベル実装詳細 |

---

## 水平フォーマット

### 行の長さ

7プロジェクトの実際の計測結果:
- 20〜60文字: 全行の約40%
- 80文字以下: 大多数のプログラマーが好む
- **推奨上限: 80〜120文字**（著者は120を個人的な上限に設定）

```
// ❌ 悪い例（120文字超）
private void someFunction(String veryLongParameterNameOne, String veryLongParameterNameTwo, String veryLongParameterNameThree) {
```

### 水平の開放性と密度（Horizontal Openness and Density）

**スペースで結合強度を表現する。**

```java
// ✅ 良い例: 演算子の強度をスペースで表現
private void measureLine(String line) {
    lineCount++;
    int lineSize = line.length();        // = の両側にスペース（低強度）
    totalChars += lineSize;
    lineWidthHistogram.addLine(lineSize, lineCount);  // 関数名と ( は密着
    recordWidestLine(lineSize);
}

// ✅ 演算子の優先順位をスペースで可視化
public static double root1(double a, double b, double c) {
    double determinant = determinant(a, b, c);
    return (-b + Math.sqrt(determinant)) / (2*a);  // 2*a は高優先度なのでスペースなし
}
```

| 対象 | スペース | 理由 |
|------|---------|------|
| 代入演算子 `=` 両側 | あり | 左辺と右辺の明確な分離 |
| 関数名と `(` の間 | なし | 関数と引数は密接に関連 |
| 引数間の `,` 後 | あり | 別の引数であることを強調 |
| 高優先度演算子 `*` | なし | 優先順位の高さを視覚化 |
| 低優先度演算子 `+`/`-` | あり | 項の分離を表現 |

### 水平の整列（Horizontal Alignment）は避ける

```java
// ❌ 悪い例: 過度な整列（変数名より型が目立たなくなる）
private   Socket           socket;
private   InputStream      input;
private   OutputStream     output;
private   FitNesseContext  context;
protected long             requestParsingTimeLimit;

// ✅ 良い例: 整列なし（リストが長すぎる場合はクラス分割を検討する）
private Socket socket;
private InputStream input;
private OutputStream output;
private FitNesseContext context;
protected long requestParsingTimeLimit;
```

長い宣言リストが必要なら、**整列で誤魔化さずクラスを分割する**ことを検討する。

---

## インデント

**インデントはスコープの階層を可視化する。**

```java
// ❌ 悪い例: インデントなし（構造が全く見えない）
public class FitNesseServer implements SocketServer { private FitNesseContext context; public FitNesseServer(FitNesseContext context) { this.context = context; } public void serve(Socket s) { serve(s, 10000); } }

// ✅ 良い例: 階層に応じたインデント
public class FitNesseServer implements SocketServer {
    private FitNesseContext context;

    public FitNesseServer(FitNesseContext context) {
        this.context = context;
    }

    public void serve(Socket s) {
        serve(s, 10000);
    }
}
```

### インデント崩しの誘惑に負けない

短い関数でも一行にまとめてはいけない:

```java
// ❌ 悪い例: 一行にまとめる誘惑
public CommentWidget(ParentWidget parent, String text){super(parent, text);}
public String render() throws Exception {return ""; }

// ✅ 良い例: 適切にインデント
public CommentWidget(ParentWidget parent, String text) {
    super(parent, text);
}

public String render() throws Exception {
    return "";
}
```

### ダミースコープ

`while`/`for` のボディがダミーの場合、セミコロンを独立した行に置く:

```java
// ❌ 悪い例: セミコロンが見えにくい
while (dis.read(buf, 0, readBufferSize) != -1);

// ✅ 良い例: セミコロンを独立した行に
while (dis.read(buf, 0, readBufferSize) != -1)
    ;
```

---

## チームルール

**チームで合意したフォーマットを全員が守る。**

> "Every programmer has his own favorite formatting rules, but if he works in a team, then the team rules."
> — Robert C. Martin, Clean Code

- 個人の好みよりチームの一貫性を優先する
- フォーマットスタイルはIDEのコードフォーマッターに設定して自動適用
- ブレースの位置・インデントサイズ・命名スタイルを文書化

良いソフトウェアシステムは**一貫したスタイルを持つドキュメントの集合**である。あるソースファイルで見たフォーマット上の意図が、別のファイルでも同じ意味を持つと読者が信頼できることが重要。

### 自動フォーマッターの活用

| ツール | 用途 |
|--------|------|
| Prettier | JavaScript/TypeScript/CSS |
| black / ruff | Python |
| gofmt | Go |
| rustfmt | Rust |
| google-java-format | Java |

フォーマットをCIで強制することで、レビューでスタイルの議論をなくせる。

---

## 相互参照

- 本リファレンス: Clean Code（Robert C. Martin）第5章 Formatting
- 命名規則: [CODE-READABILITY.md](CODE-READABILITY.md) Ch.7 命名
- コメント: [CODE-READABILITY.md](CODE-READABILITY.md) Ch.8 コメント
- コーディング規約: [CODE-READABILITY.md](CODE-READABILITY.md) Ch.9
