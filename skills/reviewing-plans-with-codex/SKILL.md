---
name: reviewing-plans-with-codex
description: >-
  Codex CLI (gpt-5.3-codex) でMarkdownプランファイルの致命的問題をレビュー（初回レビュー＋resume再レビュー）。
  Use when reviewing implementation plans with Codex, or re-reviewing updated plans.
  For general Codex usage (code review, bug investigation), use using-codex instead.
argument-hint: "<plan_file_path> [--resume]"
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, AskUserQuestion
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
