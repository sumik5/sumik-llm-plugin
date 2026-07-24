---
name: creating-flashcards
description: >-
  Creates Anki flashcards in bulk from EPUB/PDF/scanned-book files, certificate-exam URLs
  (kentei-lab.com, studying/member.studying.jp, Whizlabs, shikaku-drill.com), or pre-structured
  exam JSON, via Anki MCP Server or AnkiConnect API, covering MCP setup, OCR for image-based
  sources (Apple Vision first choice, local VLM fallback), deck/note-type management, and batch
  import with HTML formatting.
  Use when converting textbooks, question banks, or study materials into spaced repetition
  flashcards, collecting all questions from a supported certificate-exam site by URL, or managing
  Anki cards via MCP tools. For MCP server/client development, use lang:developing-mcp instead.
  URL input is auto-detected by hostname and routed to a dedicated collector, skipping AI
  structure inference.
  For EPUB image compression/size reduction use studio:compressing-epub-images; for standalone
  image-EPUB→text OCR conversion (no flashcard creation) use converting-content.
argument-hint: "<file-path-or-url>"
context: fork
agent: general-purpose
disable-model-invocation: true
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
