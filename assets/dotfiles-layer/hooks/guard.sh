#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit) hook —— 红线拦截：禁止修改自动生成 / 受保护文件。
# 机制：全局一份；默认红线 + 可被项目 .claude/protected-paths.txt 覆盖（每行一个 glob）。
#       命中则 exit 2 直接拦住这次编辑。

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')"
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -z "$file" ] && exit 0

# 默认红线；项目可用 .claude/protected-paths.txt 自定义
patterns=$'*/generated/*\n*.g.*\n*/build/*\n*/target/*\n*/node_modules/*\n*/dist/*'
deny_file="$proj/.claude/protected-paths.txt"
[ -f "$deny_file" ] && patterns="$(cat "$deny_file")"

while IFS= read -r pat; do
  [ -z "$pat" ] && continue
  case "$pat" in \#*) continue ;; esac   # 跳过注释行
  # shellcheck disable=SC2254
  case "$file" in
    $pat) echo "🚫 受保护路径，禁止修改：$file（命中红线：$pat）" >&2; exit 2 ;;
  esac
done <<< "$patterns"

exit 0
