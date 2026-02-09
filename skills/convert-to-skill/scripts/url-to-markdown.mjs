/**
 * URL → Markdown 変換スクリプト
 *
 * 使用方法: node url-to-markdown.mjs <url> <output.md>
 *
 * @mozilla/readability + turndown を使用してWebページをMarkdownに変換します。
 * 本文抽出にはFirefoxリーダーモードの技術を利用します。
 */

import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * 依存関係の自動確認
 */
async function ensureDependencies() {
  const nodeModulesPath = path.join(__dirname, "node_modules");
  try {
    await fs.access(nodeModulesPath);
  } catch {
    console.error("依存関係がインストールされていません。");
    console.error("以下のコマンドを実行してください:");
    console.error(`  cd ${__dirname} && npm install`);
    process.exit(1);
  }
}

/**
 * HTMLがコードかどうかを判定
 */
function isHtmlContentCode(text) {
  let score = 0;

  // プログラミング言語の特徴をカウント
  if (/\b(function|const|let|var|class|import|export|return)\b/.test(text))
    score += 3;
  if (/[{}[\]();]/.test(text)) score += 1;
  if (/=>|===|!==|&&|\|\|/.test(text)) score += 2;
  if (/<[^>]+>/.test(text) && /<\/[^>]+>/.test(text)) score += 2;

  return score >= 4;
}

/**
 * Markdownをクリーンアップ
 */
function cleanupMarkdown(content) {
  // 孤立したアスタリスク（箇条書きではないもの）を除去
  content = content.replace(/^\s*\*\s*$/gm, "");

  // 空のリンク構造を除去
  content = content.replace(/\[\s*\]\([^)]*\)/g, "");

  // 連続する空行を2行までに制限
  content = content.replace(/\n{3,}/g, "\n\n");

  // 行頭の孤立したアスタリスク（箇条書きの誤検出）を除去
  content = content.replace(/^\*\s*\n(?!\*)/gm, "");

  // 意味のない強調記号のパターンを除去
  content = content.replace(/^\[\s*\*\s*$/gm, "");
  content = content.replace(/^\s*\*\s*\]$/gm, "");

  return content;
}

/**
 * テーブルを解析
 */
function parseTable(tableElement) {
  const rows = [];
  const tableRows = Array.from(tableElement.querySelectorAll("tr"));

  tableRows.forEach((row) => {
    const cells = [];
    const cellElements = Array.from(row.querySelectorAll("td, th"));

    cellElements.forEach((cell) => {
      cells.push(cell.textContent?.trim() || "");
    });

    if (cells.length > 0) {
      rows.push(cells);
    }
  });

  return rows;
}

/**
 * Markdownテーブルをフォーマット
 */
function formatMarkdownTable(table) {
  if (table.length === 0) return "";

  const maxCols = Math.max(...table.map((row) => row.length));
  const normalizedTable = table.map((row) => {
    const normalizedRow = [...row];
    while (normalizedRow.length < maxCols) {
      normalizedRow.push("");
    }
    return normalizedRow;
  });

  let markdown = "";

  // ヘッダー行
  if (normalizedTable.length > 0) {
    const headerRow = normalizedTable[0];
    if (headerRow) {
      markdown += "| " + headerRow.join(" | ") + " |\n";
      markdown += "|" + " --- |".repeat(maxCols) + "\n";
    }
  }

  // データ行
  for (let i = 1; i < normalizedTable.length; i++) {
    const row = normalizedTable[i];
    if (row) {
      markdown += "| " + row.join(" | ") + " |\n";
    }
  }

  return markdown;
}

/**
 * カスタムTurndownルールを追加
 */
function addCustomTurndownRules(turndownService, { document }) {
  // CODE要素の処理ルール
  turndownService.addRule("codeBlocks", {
    filter: (node) => {
      return node.nodeName === "CODE" && node.parentElement?.nodeName === "PRE";
    },
    replacement: (_content, node) => {
      let textContent = node.textContent || "";

      const className = node.getAttribute("class") || "";
      const langMatch = className.match(/language-(\w+)/);
      const lang = langMatch ? langMatch[1] : "";

      if (textContent && !textContent.endsWith("\n")) {
        textContent += "\n";
      }

      return "\n\n```" + lang + "\n" + textContent + "```\n\n";
    },
  });

  // 画像の処理ルール（altテキストのみ保持）
  turndownService.addRule("images", {
    filter: "img",
    replacement: (_content, node) => {
      const alt = node.getAttribute("alt") || "";
      const src = node.getAttribute("src") || "";
      return `![${alt}](${src})`;
    },
  });

  // PRE要素のコード判定ルール
  turndownService.addRule("smartPre", {
    filter: "pre",
    replacement: (_content, node) => {
      const textContent = node.textContent || "";

      const hasJapanese =
        /[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uff9f\u4e00-\u9faf\u3400-\u4dbf]/.test(
          textContent,
        );
      const hasLongSentence =
        textContent.length > 100 &&
        (textContent.match(/[.。!！?？]/g) || []).length > 2;

      const className = node.getAttribute("class") || "";
      const langMatch = className.match(/language-(\w+)/);
      const lang = langMatch ? langMatch[1] : "";

      let processedContent = textContent;
      if (processedContent && !processedContent.endsWith("\n")) {
        processedContent += "\n";
      }

      if (!hasJapanese && !hasLongSentence) {
        return "\n\n```" + lang + "\n" + processedContent + "```\n\n";
      } else if (isHtmlContentCode(textContent)) {
        return "\n\n```" + lang + "\n" + processedContent + "```\n\n";
      } else {
        return "\n\n" + textContent + "\n\n";
      }
    },
  });

  // テーブル強化ルール
  turndownService.addRule("tables", {
    filter: "table",
    replacement: (_content, node) => {
      const table = parseTable(node);
      return formatMarkdownTable(table);
    },
  });

  // 不要な要素を除去するルール
  turndownService.addRule("removeScriptStyle", {
    filter: ["script", "style", "noscript"],
    replacement: () => {
      return "";
    },
  });
}

/**
 * URLからHTMLを取得し、Markdownに変換
 */
async function convertUrlToMarkdown(url, outputPath) {
  // URLからHTMLを取得
  let html;
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    html = await response.text();
  } catch (error) {
    if (error.cause?.code === "ENOTFOUND") {
      throw new Error(`ネットワークエラー: ホスト名を解決できません (${url})`);
    } else if (error.cause?.code === "ECONNREFUSED") {
      throw new Error(`接続エラー: 接続が拒否されました (${url})`);
    } else if (error.message.startsWith("HTTP")) {
      throw error;
    } else {
      throw new Error(`URLの取得に失敗しました: ${error.message}`);
    }
  }

  // linkedomでHTMLをパース
  const { parseHTML } = await import("linkedom");
  const { document } = parseHTML(html);

  // @mozilla/readabilityで本文抽出
  const { Readability } = await import("@mozilla/readability");
  const reader = new Readability(document);
  const article = reader.parse();

  // 本文が抽出できない場合はHTML全体をfallback
  let content;
  let title;
  if (article && article.content) {
    content = article.content;
    title = article.title || "";
  } else {
    // Readability抽出失敗時はbody全体を使用
    content = document.body.innerHTML || html;
    title = document.title || "";
  }

  // TurndownでMarkdownに変換
  const TurndownModule = await import("turndown");
  const TurndownService = TurndownModule.default;

  const turndownService = new TurndownService({
    headingStyle: "atx",
    hr: "---",
    bulletListMarker: "-",
    codeBlockStyle: "fenced",
    fence: "```",
    emDelimiter: "*",
    strongDelimiter: "**",
    linkStyle: "inlined",
  });

  // カスタムルールを追加
  addCustomTurndownRules(turndownService, { document });

  // HTMLをMarkdownに変換
  let markdown = turndownService.turndown(content);

  // タイトルを追加
  if (title) {
    markdown = `# ${title}\n\n${markdown}`;
  }

  // クリーンアップ
  markdown = cleanupMarkdown(markdown);

  // Markdownファイルに書き込み
  await fs.writeFile(outputPath, markdown, "utf-8");

  // 変換情報を stderr に JSON で出力（検証用）
  const info = {
    characterCount: markdown.length,
    title: title,
    url: url,
  };
  console.error(JSON.stringify(info));
}

/**
 * メイン処理
 */
async function main() {
  // 依存関係の確認
  await ensureDependencies();

  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error("使用方法: node url-to-markdown.mjs <url> <output.md>");
    process.exit(1);
  }

  const [url, outputPath] = args;

  // URL形式の簡易チェック
  if (!url.startsWith("http://") && !url.startsWith("https://")) {
    console.error(
      "エラー: URLは http:// または https:// で始まる必要があります",
    );
    process.exit(1);
  }

  try {
    await convertUrlToMarkdown(url, outputPath);
    console.log(`変換完了: ${outputPath}`);
  } catch (error) {
    console.error("変換エラー:", error.message);
    if (error.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();
