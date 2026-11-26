#!/usr/bin/env bash
# tools/new-patch.sh —— 新增一个补丁的全流程封装
# 用法: bash tools/new-patch.sh "feat: <描述>"
# 流程: src/ 改动 -> 提交 -> format-patch 导出为 patches/NNNN-<slug>.patch -> 从零重装验证
# 约定: src/ 是一次性工作台；本脚本不 push、不打 tag。
set -euo pipefail
cd "$(dirname "$0")/.."

MSG="${1:-}"
[ -d patches ] || { echo "错误: patches/ 不存在，请在仓库根运行本脚本" >&2; exit 1; }
[ -n "$MSG" ] || { echo '用法: bash tools/new-patch.sh "feat: <描述>"' >&2; exit 1; }

# 文件名 slug: 小写 -> 非字母数字折叠为单个 '-' -> 截 50 字符 -> 去首尾 '-'
slug=$(printf '%s' "$MSG" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-50 | sed -E 's/-+$//')
[ -n "$slug" ] || { echo "错误: 提交消息无法生成有效文件名" >&2; exit 1; }

# 下一个序号 = patches/ 中最大 NNNN + 1
last=$(ls patches/*.patch 2>/dev/null | sed -E 's|.*/([0-9]{4})-.*|\1|' | sort -n | tail -1 || true)
last=$((10#${last:-0}))
seq=$(printf '%04d' $((last + 1)))
target="patches/${seq}-${slug}.patch"
[ ! -e "$target" ] || { echo "错误: $target 已存在，请勿重复导出" >&2; exit 1; }

patch_count=$(ls patches/*.patch 2>/dev/null | wc -l)
patch_count=$((10#$patch_count))

if [ ! -d src/.git ]; then
  echo ">> src/ 不存在，先装配（首次需几分钟）..."
  bash build.sh
fi

if [ -n "$(git -C src status --porcelain)" ]; then
  echo ">> 提交 src/ 中的改动: $MSG"
  git -C src -c user.name=el5 -c user.email=build@el5.net add -A
  git -C src -c user.name=el5 -c user.email=build@el5.net commit -q -m "$MSG"
else
  # 干净时只接受用户已自行提交的新 commit（数量 > 补丁数 + 基线那一个提交）
  commits=$(git -C src rev-list --count HEAD)
  if [ "$commits" -le $((patch_count + 1)) ]; then
    echo "错误: src/ 里没有新改动/新提交，先改文件再运行" >&2
    exit 1
  fi
  echo ">> 使用 src/ 中已有的新提交继续导出"
fi

if git -C src diff --quiet HEAD~1 HEAD --; then
  echo "错误: HEAD 是空提交，没有可导出的 diff" >&2
  exit 1
fi

tmp=$(mktemp)
if ! git -C src format-patch -1 --stdout > "$tmp"; then
  echo "错误: format-patch 执行失败，未生成补丁" >&2
  rm -f "$tmp"
  exit 1
fi
if [ ! -s "$tmp" ]; then
  echo "错误: format-patch 结果为空，未生成补丁" >&2
  rm -f "$tmp"
  exit 1
fi
cp "$tmp" "$target"
rm -f "$tmp"
echo ">> 已生成 $target，开始从零重装验证…"
rm -rf src
bash build.sh
new_count=$((patch_count + 1))
echo ">> ${new_count}/${new_count} 补丁全绿。热点自查建议："
echo "   bash verify.sh（FORK 字节比对只覆盖最初 7 个文件，新改动请自行核对关键行）"
echo "   确认无误后 git add patches/ && git commit（push 由 lead 负责）"
