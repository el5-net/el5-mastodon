#!/usr/bin/env bash
# el5-mastodon 装配脚本: 上游指定版本 + 补丁 + overlay -> src/
# 无状态: src/ 用完即扔, 出错就删掉重跑, 不污染任何东西
set -euo pipefail
cd "$(dirname "$0")"

# ── 升级时只改这两行 (可被环境变量覆盖) ─────────────
MASTODON_REF="${MASTODON_REF:-v4.7.6}"   # 要构建的上游版本
PATCH_BASE="${PATCH_BASE:-v4.7.2}"       # 补丁生成时的基线 (三方合并参照, 勿随手改)
# ───────────────────────────────────────────────────
UPSTREAM="https://github.com/mastodon/mastodon.git"

echo ">> Assembling Mastodon $MASTODON_REF + $(ls patches/*.patch | wc -l) patches (base $PATCH_BASE)"
rm -rf src
git init -q src
git -C src remote add origin "$UPSTREAM"
git -C src fetch -q --depth 1 origin \
  "refs/tags/$MASTODON_REF:refs/tags/$MASTODON_REF" \
  "refs/tags/$PATCH_BASE:refs/tags/$PATCH_BASE"
git -C src checkout -q "refs/tags/$MASTODON_REF"

echo ">> Applying patches (3-way)..."
# 若 am 失败，按下面三条依次处理（详见 README「升级 SOP / 补丁撞上了怎么办」）:
#   1) git -C src am --show-current-patch=diff  看撞在哪个补丁/hunk
#   2) git -C src am --abort && rm -rf src && bash build.sh  放弃本次装配、重跑
#   3) 补丁本身坏了就改 patches/ 对应文件再来（可在 src/ 手工改好后 git format-patch 回写）
if ! ( cd src && git -c user.name=el5 -c user.email=build@el5.net am --3way ../patches/*.patch ); then
  echo ">> am 失败：补丁与 $MASTODON_REF 冲突（上游哪个补丁撞了会具名报错）。" >&2
  echo "   git -C src am --show-current-patch=diff   # 看撞在哪" >&2
  echo "   git -C src am --abort && rm -rf src && bash build.sh   # 清理后重跑" >&2
  echo "   补丁本身坏了就改 patches/ 再来（详见 README 升级 SOP）。" >&2
  exit 1
fi

if compgen -G "overlay/*" > /dev/null; then
  echo ">> Copying overlay files..."
  cp -a overlay/. src/
fi

echo ">> OK: src/ = Mastodon $MASTODON_REF + el5 定制, 构建镜像即可:"
echo "   docker build -f src/Dockerfile -t maisuier/mastodon:v${MASTODON_REF#v} src"
echo "   docker build -f src/streaming/Dockerfile -t maisuier/mastodon-streaming:v${MASTODON_REF#v} src/streaming"
