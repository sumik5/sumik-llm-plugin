#!/usr/bin/env python3
"""LM Studio 画像認識スクリプト

LM Studio のローカル VLM を使って画像からテキストを抽出し Markdown 形式で出力する。
lmstudio Python SDK を使用。
https://lmstudio.ai/docs/python/llm-prediction/image-input
"""

import sys
import re
import argparse
from pathlib import Path

SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
DEFAULT_BLANK_THRESHOLD = 15360  # 15KB

RECOGNITION_PROMPT = (
    "添付の画像を文字に変換し、markdown形式で返信してください。"
    "前後の不要なシステムメッセージは不要であり、画像の内容のみ返信してください"
)


def ensure_lmstudio() -> None:
    """lmstudio パッケージが未インストールの場合、自動インストールする。"""
    try:
        import lmstudio  # noqa: F401
    except ImportError:
        import subprocess

        print("lmstudio パッケージをインストールしています...", file=sys.stderr)
        subprocess.check_call([sys.executable, "-m", "pip", "install", "lmstudio", "-q"])


def strip_think_tags(text: str) -> str:
    """推論モデル（Qwen 3.5等）の思考ブロックを除去する。

    パターン1: <think>...</think> が完全にある場合
    パターン2: <think> なしで </think> だけある場合（暗黙の思考開始）
    """
    # まず完全なタグペアを除去
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL)
    # </think> だけ残っている場合、それより前を全て除去
    if "</think>" in text:
        text = text.split("</think>", 1)[1]
    return text.strip()


def is_blank_image(path: Path, threshold: int = DEFAULT_BLANK_THRESHOLD) -> bool:
    """ファイルサイズが閾値以下なら空白ページ候補と判定する。"""
    return path.stat().st_size <= threshold


def collect_image_files(
    path: Path,
    order_file: Path | None = None,
) -> list[Path]:
    """パスから画像ファイルを収集する。

    order_file が指定された場合、そのファイルの各行をファイル名として
    path ディレクトリ内から順序付きで収集する（EPUB のページ順再現用）。
    """
    if order_file is not None:
        if not path.is_dir():
            print(
                f"エラー: --order-file 使用時は --path にディレクトリを指定してください。",
                file=sys.stderr,
            )
            sys.exit(1)
        lines = order_file.read_text().strip().splitlines()
        files = []
        for name in lines:
            name = name.strip()
            if not name:
                continue
            candidate = path / name
            if candidate.is_file() and candidate.suffix.lower() in SUPPORTED_EXTENSIONS:
                files.append(candidate)
        if not files:
            print(
                f"エラー: order-file に記載されたファイルが '{path}' に見つかりません。",
                file=sys.stderr,
            )
            sys.exit(1)
        return files

    if path.is_file():
        if path.suffix.lower() in SUPPORTED_EXTENSIONS:
            return [path]
        print(
            f"エラー: '{path}' は対応していない画像形式です。"
            f"対応形式: {', '.join(SUPPORTED_EXTENSIONS)}",
            file=sys.stderr,
        )
        sys.exit(1)

    if path.is_dir():
        files = sorted(
            f for f in path.iterdir()
            if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS
        )
        if not files:
            print(
                f"エラー: '{path}' に対応する画像ファイルが見つかりません。",
                file=sys.stderr,
            )
            sys.exit(1)
        return files

    print(f"エラー: '{path}' が見つかりません。", file=sys.stderr)
    sys.exit(1)


def recognize_single_image(model_name: str, image_path: Path) -> str:
    """単一画像を認識してテキストを返す。lmstudio SDK 使用。"""
    import lmstudio as lms

    image_handle = lms.prepare_image(str(image_path))
    model = lms.llm(model_name)
    chat = lms.Chat()
    chat.add_user_message(RECOGNITION_PROMPT, images=[image_handle])
    result = model.respond(chat)
    return strip_think_tags(result.content)


def cmd_recognize(args: argparse.Namespace) -> None:
    """画像を認識してテキストを stdout に出力する。"""
    target_path = Path(args.path).resolve()
    order_file = Path(args.order_file).resolve() if args.order_file else None
    image_files = collect_image_files(target_path, order_file=order_file)
    skip_blank = args.skip_blank

    try:
        if len(image_files) == 1:
            if skip_blank and is_blank_image(image_files[0]):
                print("スキップ（空白ページ候補）: " + image_files[0].name, file=sys.stderr)
                return
            result = recognize_single_image(args.model, image_files[0])
            print(result)
        else:
            total = len(image_files)
            print(f"{total} 件の画像を処理します...", file=sys.stderr)
            results: list[str] = []
            skipped = 0
            for i, image_file in enumerate(image_files, 1):
                if skip_blank and is_blank_image(image_file):
                    print(
                        f"[{i}/{total}] {image_file.name} をスキップ"
                        f"（空白ページ: {image_file.stat().st_size}B）",
                        file=sys.stderr,
                    )
                    skipped += 1
                    continue
                print(
                    f"[{i}/{total}] {image_file.name} を処理中...",
                    file=sys.stderr,
                )
                text = recognize_single_image(args.model, image_file)
                results.append(text)

            print("\n\n---\n\n".join(results))
            if skipped:
                print(f"{skipped} 件の空白ページをスキップしました。", file=sys.stderr)

    except Exception as exc:
        print(
            f"エラー: 画像認識中に LM Studio API がエラーを返しました。\n"
            f"LM Studio が起動しモデルがロードされていることを確認してください。\n"
            f"詳細: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)


def main() -> None:
    ensure_lmstudio()

    parser = argparse.ArgumentParser(
        description="LM Studio のローカル VLM を使って画像からテキストを抽出する"
    )
    parser.add_argument(
        "--model",
        default="qwen/qwen3.5-9b",
        help="使用するモデル名 (デフォルト: qwen/qwen3.5-9b)",
    )
    parser.add_argument(
        "--path",
        required=True,
        help="画像ファイルまたは画像を含むディレクトリのパス",
    )
    parser.add_argument(
        "--order-file",
        default=None,
        help="ページ順序ファイル（1行1ファイル名）。EPUB変換時にpandoc出力から生成",
    )
    parser.add_argument(
        "--skip-blank",
        action="store_true",
        default=False,
        help=f"空白ページ候補（{DEFAULT_BLANK_THRESHOLD}B以下）をスキップ",
    )
    args = parser.parse_args()
    cmd_recognize(args)


if __name__ == "__main__":
    main()
