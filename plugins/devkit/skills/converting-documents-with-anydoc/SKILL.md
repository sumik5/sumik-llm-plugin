---
name: converting-documents-with-anydoc
description: >-
  Converts Word, PowerPoint, Excel, OpenDocument, RTF, and CSV files
  to GitHub Flavored Markdown via anydoc (firecrawl/anydoc, MIT v0.1.6),
  run with `npx -y @firecrawl/anydoc@0.1.6` (Node.js 20+ required; first
  run needs network access to fetch the package), with matching
  npm/PyPI/crates.io libraries for code integration. Use when converting
  office documents or spreadsheets to Markdown, especially legacy formats
  (.doc, .ppt, .xls, .ods) that pandoc/pdf-to-markdown cannot read. anydoc
  does not perform OCR — for scanned study materials, use the Apple
  Vision / local VLM workflow in certificate:creating-flashcards instead.
license: LICENSE.anydoc
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
