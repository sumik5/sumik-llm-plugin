/**
 * PDF → Markdown 変換スクリプト
 *
 * 使用方法: node pdf-to-markdown.mjs <input.pdf> <output.md>
 *
 * pdfjs-dist を使用してPDFからテキストを抽出し、
 * レイアウト解析を行ってMarkdownに変換します。
 */

import fs from "fs/promises";
import path from "path";
import { fileURLToPath, pathToFileURL } from "url";
import { dirname } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * 依存関係の自動インストール
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
 * テキストアイテムを行にグループ化
 */
function groupIntoLines(items) {
  const lines = new Map();
  const tolerance = 2;

  for (const item of items) {
    if (!item.str.trim()) continue;

    const y = Math.round(item.transform[5]);
    let lineY = y;

    // 既存の行を探す
    for (const [existingY] of lines) {
      if (Math.abs(existingY - y) < tolerance) {
        lineY = existingY;
        break;
      }
    }

    if (!lines.has(lineY)) {
      lines.set(lineY, []);
    }
    lines.get(lineY).push(item);
  }

  // Y座標でソート（上から下へ）
  return Array.from(lines.entries())
    .sort((a, b) => b[0] - a[0])
    .map(([y, items]) => ({
      y,
      items: items.sort((a, b) => a.transform[4] - b.transform[4]),
      text: items
        .map((item) => item.str)
        .join(" ")
        .trim(),
    }));
}

/**
 * インデントレベルを検出
 */
function detectIndentation(lines) {
  const values = lines
    .filter((line) => line.items.length > 0 && line.items[0]?.transform?.[4])
    .map((line) => line.items[0].transform[4])
    .filter((x) => x > 0);
  const minX = values.length > 0 ? Math.min(...values) : 0;

  return lines.map((line) => ({
    ...line,
    indent: Math.round(((line.items[0]?.transform?.[4] || 0) - minX) / 10),
  }));
}

/**
 * 見出しを検出
 */
function detectHeadings(lines) {
  return lines.map((line) => {
    const avgFontSize =
      line.items.reduce((sum, item) => sum + (item.height || 0), 0) /
      line.items.length;

    const isBold = line.items.some(
      (item) => item.fontName && item.fontName.toLowerCase().includes("bold"),
    );

    const isAllCaps =
      line.text === line.text.toUpperCase() && /[A-Z]/.test(line.text);

    let headingLevel = 0;
    if (avgFontSize > 20 || (avgFontSize > 16 && isBold)) {
      headingLevel = 1;
    } else if (avgFontSize > 16 || (avgFontSize > 14 && isBold)) {
      headingLevel = 2;
    } else if (avgFontSize > 14 || (avgFontSize > 12 && isBold)) {
      headingLevel = 3;
    } else if (isAllCaps && line.text.length < 50) {
      headingLevel = 3;
    }

    return { ...line, headingLevel };
  });
}

/**
 * リストを検出
 */
function detectLists(lines) {
  const bulletPatterns = [/^[•·▪▫◦‣⁃]\s*/, /^[-–—]\s+/, /^\*\s+/];

  const numberedPatterns = [
    /^\d+[.)]\s*/,
    /^[a-z][.)]\s*/i,
    /^[ivxIVX]+[.)]\s*/,
  ];

  return lines.map((line) => {
    const isBullet = bulletPatterns.some((pattern) => pattern.test(line.text));
    const isNumbered = numberedPatterns.some((pattern) =>
      pattern.test(line.text),
    );

    return { ...line, isBullet, isNumbered };
  });
}

/**
 * ページコンテンツを構築
 */
function buildPageContent(structuredContent) {
  let content = "";

  // 構造化コンテンツをMarkdownに変換
  for (const line of structuredContent) {
    if (line.headingLevel > 0) {
      content += "#".repeat(line.headingLevel) + " " + line.text + "\n\n";
    } else if (line.isBullet) {
      content += "- " + line.text.replace(/^[•·▪▫◦‣⁃\-–—*]\s*/, "") + "\n";
    } else if (line.isNumbered) {
      content += line.text + "\n";
    } else if (line.text) {
      content += line.text + "\n";
    }
  }

  return content.trim();
}

/**
 * メタデータをフォーマット
 */
function formatMetadata(metadata) {
  let formatted = "## Document Metadata\n\n";

  if (metadata.Title) formatted += `**Title:** ${metadata.Title}\n`;
  if (metadata.Author) formatted += `**Author:** ${metadata.Author}\n`;
  if (metadata.Subject) formatted += `**Subject:** ${metadata.Subject}\n`;
  if (metadata.Keywords) formatted += `**Keywords:** ${metadata.Keywords}\n`;
  if (metadata.Creator) formatted += `**Creator:** ${metadata.Creator}\n`;
  if (metadata.Producer) formatted += `**Producer:** ${metadata.Producer}\n`;
  if (metadata.CreationDate)
    formatted += `**Created:** ${metadata.CreationDate}\n`;
  if (metadata.ModDate) formatted += `**Modified:** ${metadata.ModDate}\n`;

  return formatted.trim();
}

/**
 * アウトラインをフォーマット
 */
function formatOutline(outline) {
  let formatted = "## Table of Contents\n\n";

  const formatItem = (item, level = 0) => {
    let result = "  ".repeat(level) + "- " + (item.title || "Untitled") + "\n";
    if (item.items && item.items.length > 0) {
      for (const child of item.items) {
        result += formatItem(child, level + 1);
      }
    }
    return result;
  };

  for (const item of outline) {
    formatted += formatItem(item);
  }

  return formatted.trim();
}

/**
 * PDFをMarkdownに変換
 */
async function convertPdfToMarkdown(inputPath, outputPath) {
  // PDFファイルを読み込み
  const data = await fs.readFile(inputPath);
  const arrayBuffer = data.buffer.slice(
    data.byteOffset,
    data.byteOffset + data.byteLength,
  );

  // pdfjs-distをインポート（Node.js環境）
  const pdfjsLib = await import("pdfjs-dist/legacy/build/pdf.mjs");

  // CMapと標準フォントのパスを解決
  const pdfjsDistPath = path.dirname(
    fileURLToPath(import.meta.resolve("pdfjs-dist/package.json")),
  );
  const cMapUrl = pathToFileURL(path.join(pdfjsDistPath, "cmaps/")).href;
  const standardFontDataUrl = pathToFileURL(
    path.join(pdfjsDistPath, "standard_fonts/"),
  ).href;

  // Node.js環境向けの設定
  const loadingTask = pdfjsLib.getDocument({
    data: arrayBuffer,
    disableWorker: true,
    cMapUrl,
    cMapPacked: true,
    standardFontDataUrl,
    useSystemFonts: true,
  });

  const pdf = await loadingTask.promise;

  // メタデータ抽出
  let metadata = {};
  try {
    const meta = await pdf.getMetadata();
    metadata = meta?.info || {};
  } catch {
    // メタデータ取得失敗は無視
  }

  // アウトライン抽出
  let outline = [];
  try {
    outline = (await pdf.getOutline()) || [];
  } catch {
    // アウトライン取得失敗は無視
  }

  const pages = [];

  // 各ページを処理
  for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
    const page = await pdf.getPage(pageNum);

    // テキストコンテンツ取得
    const textContent = await page.getTextContent();

    // テキストアイテムをレイアウト解析
    const lines = groupIntoLines(textContent.items);
    const structuredLines = detectIndentation(lines);
    const withHeadings = detectHeadings(structuredLines);
    const withLists = detectLists(withHeadings);

    // ページコンテンツを構築
    const pageContent = buildPageContent(withLists);

    if (pageContent.trim()) {
      pages.push(pageContent);
    }
  }

  // 最終的なMarkdown構築
  let finalContent = "";

  // メタデータを先頭に追加
  if (metadata && Object.keys(metadata).length > 0) {
    finalContent += formatMetadata(metadata) + "\n\n";
  }

  // アウトラインを追加
  if (outline && outline.length > 0) {
    finalContent += formatOutline(outline) + "\n\n";
  }

  // ページコンテンツを追加
  finalContent += pages.join("\n\n---\n\n");

  // Markdownファイルに書き込み
  await fs.writeFile(outputPath, finalContent, "utf-8");

  // 変換情報を stderr に JSON で出力（検証用）
  const info = {
    characterCount: finalContent.length,
    pageCount: pdf.numPages,
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
    console.error("使用方法: node pdf-to-markdown.mjs <input.pdf> <output.md>");
    process.exit(1);
  }

  const [inputPath, outputPath] = args;

  try {
    await convertPdfToMarkdown(inputPath, outputPath);
    console.log(`変換完了: ${outputPath}`);
  } catch (error) {
    console.error("変換エラー:", error.message);
    process.exit(1);
  }
}

main();
