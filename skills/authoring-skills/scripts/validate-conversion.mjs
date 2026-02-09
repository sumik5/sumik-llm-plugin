/**
 * Markdown変換結果の検証スクリプト
 *
 * 使用方法:
 *   node validate-conversion.mjs <output.md> --type pdf --pages N
 *   node validate-conversion.mjs <output.md> --type epub --chapters N
 *
 * 検証ロジック:
 *   PDF: ページ数 × 500文字（最小期待値）
 *   EPUB: チャプター数 × 1000文字（最小期待値）
 *
 * 出力形式: JSON (stdout)
 */

import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * コマンドライン引数をパース
 */
function parseArgs(args) {
  const result = {
    filePath: null,
    type: null,
    count: null,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--type" && i + 1 < args.length) {
      result.type = args[i + 1];
      i++;
    } else if (arg === "--pages" && i + 1 < args.length) {
      result.count = parseInt(args[i + 1], 10);
      i++;
    } else if (arg === "--chapters" && i + 1 < args.length) {
      result.count = parseInt(args[i + 1], 10);
      i++;
    } else if (!result.filePath) {
      result.filePath = arg;
    }
  }

  return result;
}

/**
 * Markdown変換結果を検証
 */
async function validateConversion(filePath, type, count) {
  // Markdownファイルを読み込み
  const content = await fs.readFile(filePath, "utf-8");
  const characterCount = content.length;

  // 検証基準を計算
  let expectedMinimum = 0;
  if (type === "pdf") {
    expectedMinimum = count * 500;
  } else if (type === "epub") {
    expectedMinimum = count * 1000;
  } else {
    throw new Error(`Unknown type: ${type}`);
  }

  // 検証結果を判定
  const result = {
    status: characterCount >= expectedMinimum ? "ok" : "warning",
    characterCount,
    expectedMinimum,
    message: "",
  };

  if (result.status === "ok") {
    result.message = "変換結果は期待値を満たしています";
  } else {
    result.message = `警告: 変換結果が期待値を下回っています（期待: ${expectedMinimum}文字以上、実際: ${characterCount}文字）`;
  }

  return result;
}

/**
 * メイン処理
 */
async function main() {
  const args = process.argv.slice(2);

  if (args.length < 4) {
    console.error("使用方法:");
    console.error(
      "  node validate-conversion.mjs <output.md> --type pdf --pages N",
    );
    console.error(
      "  node validate-conversion.mjs <output.md> --type epub --chapters N",
    );
    process.exit(1);
  }

  const parsedArgs = parseArgs(args);

  if (!parsedArgs.filePath || !parsedArgs.type || !parsedArgs.count) {
    console.error("エラー: 必須の引数が不足しています");
    console.error("  --type (pdf または epub)");
    console.error("  --pages または --chapters (数値)");
    process.exit(1);
  }

  try {
    const result = await validateConversion(
      parsedArgs.filePath,
      parsedArgs.type,
      parsedArgs.count,
    );

    // 結果をJSONで出力
    console.log(JSON.stringify(result, null, 2));

    // 警告の場合はexit code 0（スクリプトとしては正常終了）
    process.exit(0);
  } catch (error) {
    console.error("検証エラー:", error.message);
    process.exit(1);
  }
}

main();
