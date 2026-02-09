/**
 * EPUB → Markdown 変換スクリプト
 *
 * 使用方法: node epub-to-markdown.mjs <input.epub> <output.md>
 *
 * @lingo-reader/epub-parser + turndown を使用してEPUBをMarkdownに変換します。
 */

import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";
import os from "os";

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

  // EPUBリンクの残骸を除去（念のため）
  content = content.replace(/\(epub:EPUB\/[^)]+\)/g, "");

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
function addCustomTurndownRules(turndownService, pendingImages, { document }) {
  // EPUB内部リンクを除去するルール
  turndownService.addRule("epubInternalLinks", {
    filter: (node) => {
      if (node.nodeName !== "A") return false;
      const href = node.getAttribute("href") || "";
      return href.startsWith("epub:") || href.match(/^#cb\d+-\d+$/);
    },
    replacement: (content) => {
      if (!content.trim() || content === "\n") {
        return "";
      }
      return content;
    },
  });

  // コードブロック内のリンクを適切に処理するルール
  turndownService.addRule("codeBlockLinks", {
    filter: (node) => {
      return (
        node.nodeName === "A" &&
        (node.closest("pre") !== null || node.closest("code") !== null)
      );
    },
    replacement: (content) => {
      return content;
    },
  });

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

  // 画像の処理ルール
  turndownService.addRule("images", {
    filter: "img",
    replacement: (_content, node) => {
      const src = node.getAttribute("src") || "";
      const alt = node.getAttribute("alt") || "";
      const tempPlaceholder = `[[TEMP_IMG_${pendingImages.length}]]`;
      pendingImages.push({ placeholder: tempPlaceholder, src, alt });
      return tempPlaceholder;
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
}

/**
 * EPUBをMarkdownに変換
 */
async function convertEpubToMarkdown(inputPath, outputPath) {
  // EPUBファイルを読み込み
  const data = await fs.readFile(inputPath);
  const arrayBuffer = data.buffer.slice(
    data.byteOffset,
    data.byteOffset + data.byteLength,
  );

  // ライブラリをインポート
  const { initEpubFile } = await import("@lingo-reader/epub-parser");
  const TurndownModule = await import("turndown");
  const TurndownService = TurndownModule.default;

  // linkedomを使ってDOM環境を作成（Node.js環境向け）
  const { parseHTML } = await import("linkedom");

  // EPUBをパース
  const tmpImageDir = path.join(os.tmpdir(), `epub-images-${Date.now()}`);
  const epub = await initEpubFile(arrayBuffer, tmpImageDir);

  // メタデータを取得
  const rawMetadata = epub.getMetadata();
  const metadata = {
    title: rawMetadata.title,
    author: rawMetadata.creators?.[0]?.name,
    publisher: rawMetadata.publisher,
    language: rawMetadata.language,
  };

  // Spine取得
  const spine = epub.getSpine();
  const processedSections = [];

  for (let i = 0; i < spine.length; i++) {
    const spineItem = spine[i];
    if (!spineItem) continue;

    try {
      // チャプターを読み込み
      let chapterData = epub.loadChapter(spineItem.id);
      if (chapterData && typeof chapterData.then === "function") {
        chapterData = await chapterData;
      }
      if (!chapterData || !chapterData.html) continue;

      // linkedomでHTMLをパース（Turndown用のDOM環境を提供）
      const { document } = parseHTML(chapterData.html);

      // Turndownサービスを設定
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

      // 保留中の画像を保存
      const pendingImages = [];

      // カスタムルールを追加
      addCustomTurndownRules(turndownService, pendingImages, { document });

      // HTMLをMarkdownに変換
      const markdown = turndownService.turndown(chapterData.html);

      // チャプター区切りを追加
      const separator = `\n\n## Chapter ${i + 1}\n\n`;
      processedSections.push(separator + markdown);
    } catch (chapterError) {
      console.warn(
        `チャプター ${spineItem.id} の処理に失敗しました:`,
        chapterError,
      );
      continue;
    }
  }

  let content = processedSections.join("\n\n");

  // メタデータセクションを追加
  if (metadata && Object.keys(metadata).filter((k) => metadata[k]).length > 0) {
    let metadataSection = "## Metadata\n\n";
    if (metadata.title) metadataSection += `**Title:** ${metadata.title}\n`;
    if (metadata.author) metadataSection += `**Author:** ${metadata.author}\n`;
    if (metadata.publisher)
      metadataSection += `**Publisher:** ${metadata.publisher}\n`;
    if (metadata.language)
      metadataSection += `**Language:** ${metadata.language}\n`;
    content = metadataSection + "\n\n" + content;
  }

  // クリーンアップ
  content = cleanupMarkdown(content);

  // Markdownファイルに書き込み
  await fs.writeFile(outputPath, content, "utf-8");

  // 一時画像ディレクトリをクリーンアップ
  try {
    await fs.rm(tmpImageDir, { recursive: true, force: true });
  } catch {}

  // 変換情報を stderr に JSON で出力（検証用）
  const info = {
    characterCount: content.length,
    chapterCount: spine.length,
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
    console.error(
      "使用方法: node epub-to-markdown.mjs <input.epub> <output.md>",
    );
    process.exit(1);
  }

  const [inputPath, outputPath] = args;

  try {
    await convertEpubToMarkdown(inputPath, outputPath);
    console.log(`変換完了: ${outputPath}`);
  } catch (error) {
    console.error("変換エラー:", error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
