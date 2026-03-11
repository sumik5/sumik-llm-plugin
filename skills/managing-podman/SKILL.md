---
name: managing-podman
description: >-
  Podman container management and DevOps guide covering daemonless architecture, rootless containers,
  Buildah image building, Skopeo image operations, Pods, storage, networking (Netavark),
  security (user namespaces, SELinux, capabilities, image signing), systemd Quadlet integration,
  Kubernetes YAML generation, Docker migration, and Podman Desktop/AI Lab.
  MUST load when Containerfile is detected, or when podman/buildah/skopeo CLI usage is identified.
  Also load when Dockerfile is detected alongside Podman-specific signals (podman-compose.yml, .containers/, podman commands).
  Covers container lifecycle, multi-stage builds, CI/CD integration, troubleshooting, and monitoring.
  For Docker-specific workflows (Docker Engine, Docker Compose, Docker Swarm), use managing-docker instead.
  For Terraform IaC, use developing-terraform instead.
  For broader DevOps methodology, use practicing-devops instead.
  For container security auditing, use securing-code instead.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
