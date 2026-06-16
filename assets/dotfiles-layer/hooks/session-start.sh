#!/usr/bin/env bash
# SessionStart hook —— 会话开始注入项目态地图 + harness 健康自检。stdout 进上下文。
# 健康自检（失败响亮）：对"已接入 harness"的项目，若完成度/遵守度硬闸所依赖的项目脚本缺失，
# 开场就响亮提醒——避免硬闸空转却静默放行（= 把"没验证"当"已通过"）。
input="$(cat)"

# proj：有 jq 用 jq 读 cwd；无 jq 也要能继续——健康自检不该因缺 jq 而消音。
proj=""
if command -v jq >/dev/null 2>&1; then
  proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
fi
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"

lines=""
add(){ lines="${lines}$1
"; }

# 项目态：当前分支
if git -C "$proj" rev-parse >/dev/null 2>&1; then
  br="$(git -C "$proj" branch --show-current 2>/dev/null)"
  [ -n "$br" ] && add "- 当前分支：$br"
fi

# 项目态：进行中的 openspec 变更
cdir="$proj/openspec/changes"
if [ -d "$cdir" ]; then
  for d in "$cdir"/*/; do
    n="$(basename "$d")"; case "$n" in archive|_*) continue ;; esac; [ -d "$d" ] || continue
    [ -f "${d}tasks.md" ] && ! grep -q '\- \[ \]' "${d}tasks.md" 2>/dev/null && continue
    add "- 进行中变更：${n}（实现须落在其范围内）"
  done
fi

# harness 健康自检：仅对"已接入 harness"的项目（有 AGENTS.md 或 docs/conventions/）。
# 未接入的 throwaway 目录 → 不检查、不报警（优雅降级，与低摩擦工作不冲突）。
if [ -f "$proj/AGENTS.md" ] || [ -d "$proj/docs/conventions" ]; then
  [ -x "$proj/scripts/verify-local.sh" ] || add "- ⚠️ 缺 scripts/verify-local.sh：完成度硬闸（Stop）当前空转、会静默放行——“已完成”无法被客观验证，请尽早补上。"
  [ -x "$proj/scripts/lint-one.sh" ] || add "- ⚠️ 缺 scripts/lint-one.sh：遵守度 lint 闸当前空转、改完文件不被检查，请尽早补上。"
fi

[ -n "$lines" ] && printf "## 本会话项目态\n%s" "$lines"
exit 0
