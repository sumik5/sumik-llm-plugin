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

# Podmanコンテナ管理スキル

このスキルはPodmanを使ったコンテナ管理・DevOpsワークフローの実践ガイドです。

## メインガイド

詳細な手順・コマンド・判断フローは [INSTRUCTIONS.md](INSTRUCTIONS.md) を参照してください。

## リファレンス

| ファイル | 内容 |
|---------|------|
| [references/ARCHITECTURE.md](references/ARCHITECTURE.md) | コンテナ基礎 + Podman vs Docker アーキテクチャ |
| [references/INSTALLATION.md](references/INSTALLATION.md) | OS別インストール・環境構築 |
| [references/CONTAINERS.md](references/CONTAINERS.md) | コンテナライフサイクル管理・Pods |
| [references/STORAGE.md](references/STORAGE.md) | ストレージ（volumes/bind mounts/tmpfs） |
| [references/BUILDAH.md](references/BUILDAH.md) | Buildah + マルチステージビルド + CI統合 |
| [references/IMAGES.md](references/IMAGES.md) | ベースイメージ選択 + レジストリ + Skopeo |
| [references/SECURITY.md](references/SECURITY.md) | rootless, user namespaces, SELinux, capabilities, signing |
| [references/TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) | デバッグ・モニタリング・ヘルスチェック |
| [references/NETWORKING.md](references/NETWORKING.md) | Netavark, DNS, ポート公開, rootless制限 |
| [references/DOCKER-MIGRATION.md](references/DOCKER-MIGRATION.md) | Docker→Podman移行ガイド |
| [references/SYSTEMD-KUBERNETES.md](references/SYSTEMD-KUBERNETES.md) | Quadlet, systemd統合, K8s YAML生成 |
| [references/DESKTOP-AI.md](references/DESKTOP-AI.md) | Podman Desktop, AI Lab |
