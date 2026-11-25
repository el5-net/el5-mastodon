#!/usr/bin/env bash
# 验证装配结果: 5 个补丁的每一处改动都应在 src/ 中
# 可选: 设置 FORK=<旧 fork 路径> 时追加 "与 fork HEAD 逐字节一致" 的对比
set -euo pipefail
FORK="${FORK:-}"
cd "$(dirname "$0")"

echo "== src/ 提交历史 =="
git -C src log --oneline -6

echo
if [ -n "$FORK" ]; then
  echo "== 与 fork HEAD 逐字节对比 (FORK=$FORK) =="
  FILES=(
    app/validators/status_length_validator.rb
    app/validators/poll_options_validator.rb
    app/models/trends/statuses.rb
    app/controllers/api/v1/accounts/statuses_controller.rb
    app/chewy/accounts_index.rb
    app/chewy/statuses_index.rb
    app/chewy/tags_index.rb
  )
  fail=0
  for f in "${FILES[@]}"; do
    if git -C "$FORK" show "HEAD:$f" | cmp -s - "src/$f"; then
      echo "  OK    $f"
    else
      echo "  DIFF  $f"; fail=1
    fi
  done
else
  echo "== 与 fork HEAD 逐字节对比 =="
  echo ">> 跳过字节级比对（未提供 FORK）"
  fail=0
fi

echo
echo "== 热点抽查 =="
grep -o "MAX_CHARS = 5000"  src/app/validators/status_length_validator.rb
grep -o "MAX_OPTIONS *= 16" src/app/validators/poll_options_validator.rb
grep -o "threshold: 2"      src/app/models/trends/statuses.rb
grep -o "ik_max_word"       src/app/chewy/statuses_index.rb | head -1
grep -o "limit(5)"          src/app/controllers/api/v1/accounts/statuses_controller.rb | head -1

echo
[ "$fail" -eq 0 ] && echo ">> 全部通过" || { echo ">> 有差异!"; exit 1; }
