#!/usr/bin/env python3
"""LM Studio 翻訳スクリプト

LM Studio のローカル LLM を使って英語テキストを日本語に翻訳する。
OpenAI 互換 API を利用するため、openai パッケージが必要。
"""

import sys
import json
import argparse


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


def cmd_translate(args: argparse.Namespace) -> None:
    """テキストを英語から日本語に翻訳して stdout に出力する。"""
    if args.text:
        source_text = args.text
    else:
        source_text = sys.stdin.read()

    if not source_text.strip():
        print("エラー: 翻訳対象のテキストが空です。", file=sys.stderr)
        sys.exit(1)

    instruction = (
        "Translate the following English text to natural Japanese. "
        "Keep technical terms (service names, product names, command names) in English. "
        "Output only the translated text without any explanation.\n\n"
    )

    try:
        client = make_client(args.base_url)
        response = client.chat.completions.create(
            model=args.model,
            messages=[
                {"role": "user", "content": instruction + source_text},
            ],
            temperature=0.3,
        )
        translated = response.choices[0].message.content
        print(translated)
    except Exception as exc:
        print(
            f"エラー: 翻訳中に LM Studio API がエラーを返しました。\n"
            f"LM Studio が起動しモデルがロードされていることを確認してください ({args.base_url})\n"
            f"詳細: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="LM Studio のローカル LLM を使って英語→日本語翻訳を行う"
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # list-models サブコマンド
    list_parser = sub.add_parser("list-models", help="利用可能なモデル一覧を JSON 配列で出力する")
    list_parser.add_argument(
        "--base-url",
        default="http://localhost:1234",
        help="LM Studio の API ベース URL (デフォルト: http://localhost:1234)",
    )
    list_parser.set_defaults(func=cmd_list_models)

    # translate サブコマンド
    trans_parser = sub.add_parser("translate", help="英語テキストを日本語に翻訳する")
    trans_parser.add_argument("--model", required=True, help="使用するモデル名")
    trans_parser.add_argument(
        "--text",
        default=None,
        help="翻訳対象テキスト（省略時は stdin から読み取る）",
    )
    trans_parser.add_argument(
        "--base-url",
        default="http://localhost:1234",
        help="LM Studio の API ベース URL (デフォルト: http://localhost:1234)",
    )
    trans_parser.set_defaults(func=cmd_translate)

    return parser


def main() -> None:
    ensure_openai()
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
