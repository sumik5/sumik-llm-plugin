#!/usr/bin/env python3
"""LM Studio 画像認識スクリプト

LM Studio のローカル VLM を使って画像からテキストを抽出し Markdown 形式で出力する。
OpenAI 互換 API の Vision 機能を利用するため、openai パッケージが必要。
"""

import sys
import json
import re
import argparse
import base64
from pathlib import Path

SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}

RECOGNITION_PROMPT = (
    "添付の画像を文字に変換し、markdown形式で返信してください。"
    "前後の不要なシステムメッセージは不要であり、画像の内容のみ返信してください"
)


def ensure_openai() -> None:
    """openai パッケージが未インストールの場合、自動インストールする。"""
    try:
        import openai  # noqa: F401
    except ImportError:
        import subprocess

        print("openai パッケージをインストールしています...", file=sys.stderr)
        subprocess.check_call([sys.executable, "-m", "pip", "install", "openai", "-q"])


def make_client(base_url: str):
    """LM Studio 用の OpenAI クライアントを生成する。"""
    from openai import OpenAI

    return OpenAI(base_url=f"{base_url.rstrip('/')}/v1", api_key="lm-studio")


def encode_image(image_path: Path) -> str:
    """画像ファイルを base64 エンコードする。"""
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def get_mime_type(image_path: Path) -> str:
    """ファイル拡張子から MIME タイプを判定する。"""
    ext = image_path.suffix.lower()
    mime_map = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
    }
    return mime_map.get(ext, "image/png")


def collect_image_files(path: Path) -> list[Path]:
    """パスからの画像ファイルを収集する。ファイルなら単一、ディレクトリなら再帰検索。"""
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


def recognize_single_image(client, model: str, image_path: Path) -> str:
    """単一画像を認識してテキストを返す。"""
    base64_image = encode_image(image_path)
    mime_type = get_mime_type(image_path)

    response = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": RECOGNITION_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{mime_type};base64,{base64_image}",
                        },
                    },
                ],
            }
        ],
        temperature=0.1,
    )
    content = response.choices[0].message.content or ""
    # 推論モデル（Qwen 3.5等）の <think>...</think> タグを除去
    content = re.sub(r"<think>.*?</think>", "", content, flags=re.DOTALL)
    return content.strip()


def cmd_list_models(args: argparse.Namespace) -> None:
    """利用可能なモデル一覧を JSON 配列として stdout に出力する。"""
    try:
        client = make_client(args.base_url)
        models = client.models.list()
        model_ids = [m.id for m in models.data]
        print(json.dumps(model_ids))
    except Exception as exc:
        print(
            f"エラー: LM Studio API に接続できませんでした。\n"
            f"LM Studio が起動していることを確認してください ({args.base_url})\n"
            f"詳細: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)


def cmd_recognize(args: argparse.Namespace) -> None:
    """画像を認識してテキストを stdout に出力する。"""
    target_path = Path(args.path).resolve()
    image_files = collect_image_files(target_path)

    try:
        client = make_client(args.base_url)

        if len(image_files) == 1:
            result = recognize_single_image(client, args.model, image_files[0])
            print(result)
        else:
            print(f"{len(image_files)} 件の画像を処理します...", file=sys.stderr)
            results: list[str] = []
            for i, image_file in enumerate(image_files, 1):
                print(
                    f"[{i}/{len(image_files)}] {image_file.name} を処理中...",
                    file=sys.stderr,
                )
                text = recognize_single_image(client, args.model, image_file)
                results.append(f"## {image_file.name}\n\n{text}")

            print("\n\n---\n\n".join(results))

    except Exception as exc:
        print(
            f"エラー: 画像認識中に LM Studio API がエラーを返しました。\n"
            f"LM Studio が起動しモデルがロードされていることを確認してください ({args.base_url})\n"
            f"詳細: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="LM Studio のローカル VLM を使って画像からテキストを抽出する"
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # list-models サブコマンド
    list_parser = sub.add_parser(
        "list-models", help="利用可能なモデル一覧を JSON 配列で出力する"
    )
    list_parser.add_argument(
        "--base-url",
        default="http://localhost:1234",
        help="LM Studio の API ベース URL (デフォルト: http://localhost:1234)",
    )
    list_parser.set_defaults(func=cmd_list_models)

    # recognize サブコマンド
    rec_parser = sub.add_parser(
        "recognize", help="画像からテキストを抽出する"
    )
    rec_parser.add_argument(
        "--model",
        default="qwen/qwen3.5-9b",
        help="使用するモデル名 (デフォルト: qwen/qwen3.5-9b)",
    )
    rec_parser.add_argument(
        "--path",
        required=True,
        help="画像ファイルまたは画像を含むディレクトリのパス",
    )
    rec_parser.add_argument(
        "--base-url",
        default="http://localhost:1234",
        help="LM Studio の API ベース URL (デフォルト: http://localhost:1234)",
    )
    rec_parser.set_defaults(func=cmd_recognize)

    return parser


def main() -> None:
    ensure_openai()
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
