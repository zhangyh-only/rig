#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit) hook —— 对刚改的文件跑项目检查器。
# 机制：全局一份；它调用"当前项目"里的 scripts/lint-one.sh（语言适配器）。
#       不通过则 exit 2，把问题清单（stderr）回灌给 AI，让它当场修——这仍是生成期纠错，不是最终 review。

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')"
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -z "$file" ] && exit 0

adapter="$proj/scripts/lint-one.sh"
# 项目没装适配器 → 跳过，不阻断（机制对未接入的项目无害）
[ -x "$adapter" ] || exit 0

out="$("$adapter" "$file" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  {
    echo "❌ 规范检查未通过：$file"
    echo "请按下列问题修正后再继续："
    echo "$out"
  } >&2
  exit 2   # exit 2 → Claude Code 把 stderr 回灌给 AI 处理
fi
exit 0
