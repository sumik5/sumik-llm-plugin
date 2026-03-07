---
description: |
  Podman コンテナのセキュリティ強化ガイド：rootless 実行、UID 0 回避、イメージ署名（Sigstore/Cosign）、Linux Capabilities 管理、SELinux 連携の実践手順。
  Use when hardening containers, implementing image trust policies, customizing kernel capabilities, or troubleshooting SELinux denials.
  Supplements SKILL.md with detailed security procedures.
---

# セキュリティリファレンス

## 1. Rootless コンテナ

### 設計上の利点

| 利点 | 説明 |
|------|------|
| **コンテナ脱出の被害限定** | エンジン・カーネルの脆弱性でコンテナ外に出ても、非 root 権限しか得られない |
| **マルチユーザー共存** | 異なる非特権ユーザーが同一ホストで並行して安全にコンテナを実行できる |

### subuid / subgid の仕組み

Podman は `/etc/subuid` と `/etc/subgid` を使い、ユーザー名前空間内の UID/GID をホストの UID にマッピングする:

```bash
$ id
uid=1000(alice) gid=1000(alice)

# コンテナ内の uid_map を確認
$ podman run alpine cat /proc/self/uid_map
         0       1000          1   # コンテナ UID 0 → ホスト UID 1000
         1     100000      65536   # コンテナ UID 1-65536 → ホスト UID 100000-165535
```

**読み方**:
- 列1: コンテナ名前空間内の UID 開始値
- 列2: ホスト名前空間の UID 開始値
- 列3: マッピングするレンジ数

ホスト上では UID/GID がフルレンジ（0-4294967295）でマッピングされるため、変換なしにそのまま動作する。

### 確認と設定

```bash
# subuid 設定確認
cat /etc/subuid  # alice:100000:65536

# usermod で subuid/subgid を追加
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 username

# rootless コンテナが実際に非 root で動いているか確認
podman run --name test -d nginx
podman exec test id  # uid=101(nginx) gid=101(nginx) であることを確認
```

---

## 2. UID 0 を避けたコンテナ実行

### リスク

コンテナ内で root（UID 0）として動作するプロセスは、カーネル脆弱性によってコンテナ外のホスト root と同等の権限を得る可能性がある。

### Containerfile での非 root ユーザー設定

```dockerfile
FROM docker.io/library/nginx:mainline-alpine

# デフォルト設定を削除して独自設定を追加
RUN rm /etc/nginx/conf.d/*
COPY hello.conf /etc/nginx/conf.d/

# nginx が必要とするファイル・ディレクトリのパーミッションを非 root でも書けるよう修正
RUN chmod -R a+w /var/cache/nginx/ \
    && touch /var/run/nginx.pid \
    && chmod a+w /var/run/nginx.pid

# 非特権ポート（1024 以上）を使用（非 root はポート 1-1023 をバインドできない）
EXPOSE 8080

# 非 root ユーザーに切り替え
USER nginx
```

```bash
# ビルドして実行
buildah bud -t nginx-user:latest -f .
podman run --name myapp -p 127.0.0.1::8080 -d nginx-user

# コンテナが非 root で動作していることを確認
podman exec myapp id
# → uid=101(nginx) gid=101(nginx)
```

### AskUserQuestion が必要なケース

- `USER` 指定なしのサードパーティイメージを本番で使う場合（rootful になることを認識しているか確認）
- `--privileged` フラグを追加しようとする場合（全権限が付与される。代替手段を先に検討）

---

## 3. イメージ署名（Sigstore / Cosign）

### 設計概念

**Detached Signature** モデル（Podman 4.x 以前）: 署名をレジストリ外の Web サーバー（sigstore）に別置きする。

**Integrated Signature** モデル（Podman 5.x 推奨）: 署名を OCI artifact としてレジストリに直接格納。sigstore ディレクトリ管理が不要になる。

### Cosign キーペアの生成

```bash
# Cosign でキーペア生成（cosign.key / cosign.pub を出力）
cosign generate-key-pair
# → Private key written to cosign.key
# → Public key written to cosign.pub

# または Skopeo を使って生成
skopeo generate-sigstore-key --output-prefix .skopeo/sig-myapp
# → .skopeo/sig-myapp.private と .skopeo/sig-myapp.pub を生成
```

**cosign.key（秘密鍵）**: CI/CD システムのシークレットとして厳重管理
**cosign.pub（公開鍵）**: プルする全環境に配布

### イメージへの署名と push

```bash
# ビルド
podman build -t custom_httpd .
podman tag custom_httpd localhost:5000/custom_httpd

# push と同時に署名（Podman 5.x）
podman push \
  --tls-verify=false \
  --sign-by-sigstore-private-key ./cosign.key \
  localhost:5000/custom_httpd
# → "Creating signature: Signing image using a sigstore signature"

# ベストプラクティス: digest で署名（タグ差し替え攻撃対策）
cosign sign --key ./cosign.key registry.example.com/myapp@sha256:<digest>
```

### registries.d の設定

```yaml
# /etc/containers/registries.d/default.yaml（Podman 5.x: OCI artifact として保存）
default-docker:
  sigstore-staging: file:///var/lib/containers/sigstore
  use-sigstore-attachments: true

# ローカルレジストリ向けに署名 attachment を有効化
docker:
  localhost:5000:
    use-sigstore-attachments: true

# Red Hat レジストリ（従来型外部 sigstore）
docker:
  registry.access.redhat.com:
    sigstore: https://access.redhat.com/webassets/docker/content/sigstore
```

### policy.json による署名検証の強制

```json
// /etc/containers/policy.json
{
    "default": [
        { "type": "insecureAcceptAnything" }   // 他レジストリはチェックなし（デフォルト）
    ],
    "transports": {
        "docker": {
            "localhost:5000": [
                {
                    "type": "sigstoreSigned",
                    "keyPath": "/etc/pki/containers/cosign.pub",
                    "signedIdentity": { "type": "matchRepository" }
                }
            ],
            "registry.access.redhat.com/ubi9": [
                {
                    "type": "signedBy",
                    "keyType": "GPGKeys",
                    "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat"
                }
            ]
        },
        "docker-daemon": {
            "": [{ "type": "insecureAcceptAnything" }]
        }
    }
}
```

### podman image trust コマンド

```bash
# 現在のトラスト設定を確認
podman image trust show

# Red Hat の公開 GPG キーで UBI9 の署名を検証するよう設定
sudo podman image trust set \
  -f /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat \
  registry.access.redhat.com/ubi9
```

### Skopeo での署名検証

```bash
# Skopeo copy も policy.json を参照して自動検証
skopeo copy --src-tls-verify=false \
  docker://localhost:5000/custom_httpd \
  containers-storage:localhost:5000/custom_httpd

# Skopeo で署名して push
skopeo copy \
  --dest-tls-verify=false \
  --sign-by-sigstore-private-key ./cosign.key \
  containers-storage:localhost:5000/custom_httpd \
  docker://localhost:5000/custom_httpd
```

### 署名検証エラーの確認

```bash
# 未署名イメージを署名が必要なレジストリに push → pull を試みる
podman pull localhost:5000/custom_httpd:unsigned
# → Error: Source image rejected: A signature was required, but no signature exists

# 誤ったキーで検証しようとした場合
# → Error: Source image rejected: Invalid signature: key mismatch
```

### Rekor による透明性ログ

```bash
# Rekor パブリックサーバーに署名ログを記録
cosign sign --key ./cosign.key registry.example.com/myapp@sha256:<digest>
# → tlog entry created with index: 165166231

# ログ確認
./rekor-cli get --log-index 165166231

# 署名の検証
cosign verify --key ./cosign.pub registry.example.com/myapp@sha256:<digest>
```

---

## 4. Linux Capabilities の管理

### Capabilities とは

Linux カーネル 2.2 で導入された、root 権限を細分化する仕組み。全権限の付与（UID 0）の代わりに、必要な権限のみを付与できる。

### 主要な Capabilities

| Capability | 機能 | リスク |
|-----------|------|--------|
| `CAP_CHOWN` | ファイルの UID/GID を変更 | 低 |
| `CAP_KILL` | 任意プロセスへシグナル送信 | 中 |
| `CAP_NET_BIND_SERVICE` | 1024 以下ポートをバインド | 低 |
| `CAP_NET_ADMIN` | ネットワーク設定変更、ルーティング | 高 |
| `CAP_NET_RAW` | RAW/PACKET ソケット（ping 等） | 中 |
| `CAP_SYS_ADMIN` | mount、名前空間操作等（ほぼ全権限）| **危険** |
| `CAP_SYS_CHROOT` | chroot、mount 名前空間変更 | 中 |
| `CAP_DAC_OVERRIDE` | DAC パーミッションチェックをバイパス | 高 |
| `CAP_BPF` | 特権 BPF 操作（Linux 5.8+） | 中 |

### Podman のデフォルト Capabilities

```
# /usr/share/containers/containers.conf の default_capabilities
CHOWN, DAC_OVERRIDE, FOWNER, FSETID, KILL,
NET_BIND_SERVICE, SETFCAP, SETGID, SETPCAP, SETUID, SYS_CHROOT
```

```bash
# 実際に適用された capability を確認
podman run -d --name cap_test nginx
podman exec cap_test sh -c 'grep Cap /proc/1/status'
# CapPrm: 00000000800405fb

# bitmap をデコード
capsh --decode=00000000800405fb
# → cap_chown,cap_dac_override,...
```

### 実行時に Capabilities を追加・削除

```bash
# 特定の capability を削除（最小権限原則）
podman run -d --name myapp \
  --cap-drop=DAC_OVERRIDE \
  --cap-drop=KILL \
  nginx

# 必要な capability を追加
podman run -d --name netapp \
  --cap-add=NET_RAW \
  --cap-add=NET_ADMIN \
  myimage

# 全 capabilities を削除してから必要なものだけ追加（最もセキュア）
podman run -d --name strictapp \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  myimage
```

### Rootless コンテナでの Capabilities

rootless コンテナの capabilities は **名前空間化**されており、ホストシステムに影響を与えられない:

```bash
# rootless では CAP_MKNOD を付与しても特殊ファイル作成は拒否される
podman run -it --cap-add=MKNOD busybox sh
/ # mknod /tmp/urandom c 1 8
# → mknod: /tmp/urandom: Operation not permitted

# rootful（root で実行）なら可能
sudo podman run -it --cap-add=MKNOD busybox sh
```

### ベストプラクティス

- デフォルト capabilities を維持し、**不要なものだけ drop** する
- `CAP_SYS_ADMIN` は**絶対に追加しない**（コンテナ分離が実質無効になる）
- `--privileged` は最終手段（全 capabilities 付与 + SELinux 無効化）

---

## 5. SELinux とコンテナの連携

### SELinux の動作モード

| モード | 動作 |
|-------|------|
| **Enforcing** | ポリシー違反をブロック + 監査ログ記録（デフォルト・推奨） |
| **Permissive** | 違反を監査ログに記録するが、ブロックしない（デバッグ用） |
| **Disabled** | SELinux を完全無効化（**セキュリティ上のリスク、非推奨**） |

### SELinux アクセス制御の種類

| 種類 | 略称 | 概要 |
|------|------|------|
| Type Enforcement | **TE** | プロセス（domain）とファイル（type）のアクセス制御（メイン） |
| Role-Based Access Control | **RBAC** | SELinux ユーザーとロールによるアクセス制御 |
| Multi-Level Security | **MLS** | 同一感度レベルのリソースへのアクセス制御 |
| Multi-Category Security | **MCS** | カテゴリラベルによるコンテナ間の分離（TE + カテゴリ） |

### コンテナの SELinux ラベル

```bash
# コンテナプロセスの SELinux コンテキスト確認
podman run -d --name webserver nginx
podman exec webserver ps -Z
# → system_u:system_r:container_t:s0:c123,c456

# ボリュームに SELinux ラベルを付与（:z / :Z オプション）
# :z → 共有ラベル（他コンテナもアクセス可能）
# :Z → プライベートラベル（このコンテナのみアクセス可能、推奨）
podman run -d -v /data/myapp:/app:Z nginx
```

### SELinux 拒否ログの確認

```bash
# SELinux 拒否ログを確認
sudo ausearch -m AVC -ts recent

# コンテナが SELinux でブロックされている場合
# Permissive モードで何が拒否されるかを確認（本番では使わない）
sudo setenforce 0

# 問題が解決した場合は Enforcing に戻す
sudo setenforce 1
```

### Udica による SELinux カスタムポリシー生成

```bash
# コンテナの JSON インスペクト情報から自動生成
podman inspect mycontainer > mycontainer.json
udica -j mycontainer.json mycontainer_policy

# 生成されたポリシーをインストール
sudo semodule -i mycontainer_policy.cil /usr/share/udica/templates/*.cil

# カスタムポリシーを使ってコンテナを起動
podman run --security-opt label=type:mycontainer_policy.process myimage
```

---

## 6. セキュリティレイヤーの全体像

```
[ホストの保護レイヤー]
┌────────────────────────────────────┐
│ SELinux (Type Enforcement / MCS)   │  カーネルレベルの強制アクセス制御
│ Linux Capabilities（最小権限）     │  root 権限の細分化・制限
│ Rootless（User Namespace）         │  UID マッピングでホスト root 保護
│ 非 root ユーザー（USER 指定）      │  コンテナ内プロセスの権限最小化
│ イメージ署名（Sigstore/Cosign）    │  MITM攻撃・改ざんイメージの防止
└────────────────────────────────────┘
```

### セキュリティチェックリスト

- [ ] rootless モードで実行（root 不要なら必須）
- [ ] Containerfile に `USER <non-root>` を明記
- [ ] `--cap-drop=ALL` + 必要な capability のみ `--cap-add`
- [ ] `--privileged` を使っていない
- [ ] ボリュームマウントに `:Z` を付与
- [ ] SELinux が Enforcing モード（`getenforce` で確認）
- [ ] イメージが署名済みで `policy.json` で検証設定済み
- [ ] ダイジスト指定でイメージを pin（`@sha256:`）
