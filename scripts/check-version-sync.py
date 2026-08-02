#!/usr/bin/env python3
"""13プラグイン各々の3ファイル（.claude-plugin/plugin.json・.codex-plugin/plugin.json・
.agents/plugins/marketplace.json）でversionが一致しているかだけを確認する。

絶対値の期待値は持たない。3ファイル間の不一致だけを検出するため、バージョンbump時に
このスクリプト自体やCLAUDE.mdを書き換える必要がない。
"""

import json
import sys

PLUGIN_FILES = {
    "devkit": ("plugins/devkit/.claude-plugin/plugin.json", ".codex-plugin/plugin.json"),
}
SUBDIR_PLUGINS = [
    "studio", "lang", "web", "cloud", "ai", "design", "product",
    "exam", "university", "google", "mobile", "certificate",
]
for name in SUBDIR_PLUGINS:
    PLUGIN_FILES[name] = (
        f"plugins/{name}/.claude-plugin/plugin.json",
        f"plugins/{name}/.codex-plugin/plugin.json",
    )


def main() -> int:
    marketplace = json.load(open(".agents/plugins/marketplace.json"))
    marketplace_versions = {p["name"]: p["version"] for p in marketplace["plugins"]}

    all_ok = True
    for name, (claude_path, codex_path) in PLUGIN_FILES.items():
        v_claude = json.load(open(claude_path))["version"]
        v_codex = json.load(open(codex_path))["version"]
        v_marketplace = marketplace_versions[name]
        versions = {v_claude, v_codex, v_marketplace}
        ok = len(versions) == 1
        all_ok &= ok
        status = "OK  " if ok else "MISMATCH"
        print(f"{name:12} {status} {[v_claude, v_codex, v_marketplace]}")

    print("ALL OK" if all_ok else "FAILED")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
