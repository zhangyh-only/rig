#!/usr/bin/env bash
# SessionEnd hook —— 收尾提醒：任务已全勾选却未归档的 change / 未提交改动。
input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"

cdir="$proj/openspec/changes"
if [ -d "$cdir" ]; then
  for d in "$cdir"/*/; do
    n="$(basename "$d")"; case "$n" in archive|_*) continue ;; esac; [ -d "$d" ] || continue
    t="${d}tasks.md"; [ -f "$t" ] || continue
    if ! grep -q '\- \[ \]' "$t" 2>/dev/null && grep -q '\- \[[xX]\]' "$t" 2>/dev/null; then
      echo "提醒：变更 $n 任务已全勾选，可用 /archive-change 归档。"
    fi
  done
fi

if git -C "$proj" rev-parse >/dev/null 2>&1; then
  c="$(git -C "$proj" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [ -n "$c" ] && [ "$c" != "0" ] && echo "提醒：有 $c 处未提交改动。"
fi
exit 0
