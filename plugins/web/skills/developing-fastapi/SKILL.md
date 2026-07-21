---
name: developing-fastapi
description: >-
  FastAPI (Python) web API development guide covering fundamentals (routing, path/query params,
  Pydantic models, request/response, error handling), data persistence (SQLAlchemy, SQLModel, async DB,
  MongoDB, CRUD, Alembic migrations), dependency injection (Depends, dependency_overrides, scopes/lifespan),
  auth & security (OAuth2, JWT, CORS), async & concurrency (async/await, Starlette, BackgroundTasks,
  WebSocket, SSE/streaming), testing (TestClient, pytest, httpx, mocking), production
  deployment & scaling (uvicorn/gunicorn, Docker, optimization), generative-AI services (model serving,
  streaming, concurrency), and microservice/GraphQL/OpenAPI patterns.
  MUST load when fastapi is in pyproject.toml/requirements.txt or .py files import fastapi.
  For Python language/tooling fundamentals (uv/ruff/mypy, packaging, non-FastAPI patterns), use
  lang:developing-python. For REST/HTTP-spec design, versioning, and API test strategy, use
  developing-web-apis. For Node.js/Fastify backend services, use building-nodejs-services.
disable-model-invocation: false
when_to_use: >-
  For API security hardening (OWASP API Security Top 10, authn/authz, FAPI), use securing-web-apis.
  For choosing among API styles (REST/GraphQL/gRPC/WebSocket/messaging), use choosing-api-styles.
  For JavaScript/Vercel AI SDK/LangChain.js web AI integration, use ai:integrating-ai-web-apps.
  For framework-agnostic GenAI design patterns (RAG, guardrails, LLMOps), use ai:designing-genai-patterns.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
