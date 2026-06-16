#!/usr/bin/env bash
# PreToolUse(Bash) hook —— best-effort：拦截试图写"受保护路径"的 Bash 命令（堵 sed -i / 重定向 绕过 Edit/Write 红线的洞）。
# 非穷尽：仅在命令含写迹象(> >> tee sed -i cp mv dd)且命中红线片段时拦。误报可在 .claude/protected-paths.txt 收窄。
input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$cmd" ] && exit 0
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"

# 只在命令疑似"写"时才检查
echo "$cmd" | grep -qE '>>?|tee |sed -i|[[:space:]]cp |[[:space:]]mv |dd ' || exit 0

patterns=$'*/generated/*\n*.g.*\n*/target/*\n*/build/*\n*/node_modules/*\n*/dist/*\n*.env*'
deny="$proj/.claude/protected-paths.txt"
[ -f "$deny" ] && patterns="$(cat "$deny")"

while IFS= read -r pat; do
  [ -z "$pat" ] && continue
  case "$pat" in \#*) continue ;; esac
  frag="$(echo "$pat" | sed 's/\*//g')"
  [ -z "$frag" ] && continue
  if echo "$cmd" | grep -qF "$frag"; then
    echo "🚫 Bash 命令疑似写受保护路径（含 '$frag'）：$cmd" >&2
    echo "如确需，请改用受控方式或在 .claude/protected-paths.txt 调整红线。" >&2
    exit 2
  fi
done <<< "$patterns"
exit 0
