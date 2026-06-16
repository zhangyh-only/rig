#!/usr/bin/env bash
# Stop hook —— 收工前跑项目 verify-local.sh，没过 exit 2 不让收工（守"完成度"）。
# 没有 verify-local.sh 的项目 → 静默放行。防循环：stop_hook_active=true 时直接放行。
input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"
[ "$active" = "true" ] && exit 0
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"
v="$proj/scripts/verify-local.sh"
[ -x "$v" ] || exit 0
out="$(cd "$proj" && bash "$v" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  { echo "❌ 本地验证未通过，请修复后再收工（scripts/verify-local.sh）："; echo "$out" | tail -25; } >&2
  exit 2
fi
exit 0
