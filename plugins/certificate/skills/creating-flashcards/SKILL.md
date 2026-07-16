---
name: creating-flashcards
description: >-
  Creates Anki flashcards in bulk from EPUB/PDF/scanned-book files via Anki MCP Server or AnkiConnect
  API, covering MCP setup, OCR for image-based sources (Apple Vision first choice, local VLM
  fallback), deck/note-type management, and batch import with HTML formatting.
  Use when converting textbooks, question banks, or study materials into spaced repetition flashcards,
  or when managing Anki cards via MCP tools.
  Covers full workflow: MCP setup → file conversion (pandoc / OCR) → content analysis → batch card
  creation. For MCP server/client development, use lang:developing-mcp instead.
  Also supports a fast-path for pre-structured exam JSON collected by collecting-kentei-lab-exams
  (kentei-lab schema: exam_title/slug/questions), importing directly via scripts/kentei_lab_import.py
  and skipping AI structure inference.
  For EPUB image compression/size reduction use studio:compressing-epub-images; for standalone
  image-EPUB→text OCR conversion (no flashcard creation) use converting-content.
argument-hint: "<file-path>"
context: fork
agent: general-purpose
disable-model-invocation: true
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
