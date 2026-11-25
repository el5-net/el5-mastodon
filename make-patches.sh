#!/usr/bin/env bash
# 从现有 fork 中提取真正的定制，做成 5 个 git 提交补丁
# 原理: 以 v4.7.2 为基线，逐个把 fork HEAD 中对应文件的内容登记进临时索引，
#       用 commit-tree 生成提交，最后 format-patch 导出
set -euo pipefail
FORK="C:/Users/maisui/.local/share/opencode/worktree/6f38e6/nimble-nebula"
cd "$(dirname "$0")"

export GIT_INDEX_FILE="$(mktemp)"
export GIT_AUTHOR_NAME="maisui" GIT_AUTHOR_EMAIL="aibofan95@gmail.com"
export GIT_COMMITTER_NAME="maisui" GIT_COMMITTER_EMAIL="aibofan95@gmail.com"

git -C "$FORK" read-tree v4.7.2

next() {  # next <msg> <parent> <file...>
  local msg="$1" parent="$2"; shift 2
  local p
  for p in "$@"; do
    git -C "$FORK" update-index --add --cacheinfo \
      "100644,$(git -C "$FORK" rev-parse "HEAD:$p"),$p"
  done
  local tree
  tree=$(git -C "$FORK" write-tree)
  git -C "$FORK" commit-tree "$tree" -p "$parent" -m "$msg"
}

C1=$(next "feat: raise max toot chars to 5000" v4.7.2 \
  app/validators/status_length_validator.rb)
C2=$(next "feat: raise poll options to 16" "$C1" \
  app/validators/poll_options_validator.rb)
C3=$(next "feat: tune trending statuses thresholds" "$C2" \
  app/models/trends/statuses.rb)
C4=$(next "feat: show only 5 recent posts to logged-out visitors" "$C3" \
  app/controllers/api/v1/accounts/statuses_controller.rb)
C5=$(next "feat: chinese search analyzers (ik_max_word + stconvert)" "$C4" \
  app/chewy/accounts_index.rb app/chewy/statuses_index.rb app/chewy/tags_index.rb)

echo "$C5" > tip.sha
rm -rf patches
git -C "$FORK" format-patch v4.7.2.."$C5" -o "$PWD/patches" >/dev/null
echo ">> 生成补丁:"
ls patches/
