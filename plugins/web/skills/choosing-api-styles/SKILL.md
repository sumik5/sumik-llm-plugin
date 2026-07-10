---
name: choosing-api-styles
description: >-
  Decision guide for choosing among API styles — REST, GraphQL (query-based),
  gRPC (RPC), webhooks (callback), WebSocket (bidirectional), messaging
  (broker-based), and web feeds — based on trade-offs in communication type,
  transmission mode, responsiveness, binary-data support, and development effort.
  Covers API concepts (message, transmission modes, lifecycle, API-as-a-product),
  protocol foundations (HTTP/1.1 vs HTTP/2 vs HTTP/3 QUIC, TCP head-of-line
  blocking), cross-style patterns (pagination, rate limiting, caching, retries,
  versioning, OWASP), and per-style trade-offs with a when-to-use decision matrix.
  Use when selecting or comparing API styles — REST vs GraphQL vs gRPC vs
  realtime/event-driven — or justifying an architecture decision. For REST API
  design, testing, or gRPC .proto specs, use developing-web-apis. For
  Express/NestJS implementation, use developing-fullstack-javascript. For MCP
  protocol, use lang:developing-mcp. For microservice/infrastructure trade-offs,
  use cloud:architecting-infrastructure.
disable-model-invocation: false
when_to_use: >-
  For Fastify service implementation (routing, plugins, schema validation), use web:building-nodejs-services.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
