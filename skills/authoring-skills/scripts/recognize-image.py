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


def collect_image_files(path: Path) -> list[Path]:
    """パスから画像ファイルを収集する。"""
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
    image_files = collect_image_files(target_path)

    try:
        if len(image_files) == 1:
            result = recognize_single_image(args.model, image_files[0])
            print(result)
        else:
            print(f"{len(image_files)} 件の画像を処理します...", file=sys.stderr)
            results: list[str] = []
            for i, image_file in enumerate(image_files, 1):
                print(
                    f"[{i}/{len(image_files)}] {image_file.name} を処理中...",
                    file=sys.stderr,
                )
                text = recognize_single_image(args.model, image_file)
                results.append(f"## {image_file.name}\n\n{text}")

            print("\n\n---\n\n".join(results))

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
    args = parser.parse_args()
    cmd_recognize(args)


if __name__ == "__main__":
    main()
