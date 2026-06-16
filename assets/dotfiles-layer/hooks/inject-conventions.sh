#!/usr/bin/env bash
# UserPromptSubmit hook —— 编码任务开始时，把"全局个人规范 + 当前项目规范"注入 AI 上下文。
# 机制：本脚本住在 ~/.claude/hooks/（全局一份，所有项目共享）；它不内置规范，
#       而是去"当前项目"里按固定路径找规范。stdout(exit 0) 会被追加进 AI 这一轮上下文。
# 语言无关：它只 cat markdown，不关心项目是 Java / TS / Python / Go。

input="$(cat)"

# 无 jq 时优雅降级：不注入，但绝不阻断（始终 exit 0）
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"

# 仅对"像编码"的 prompt 注入，省 token。关键词按需增删。
case "$prompt" in
  *代码*|*实现*|*新增*|*修改*|*重构*|*接口*|*功能*|*函数*|*方法*|*bug*|*Bug*|*BUG*|*class*|*function*|*fix*|*refactor*|*implement*|*create*|*feature*|*endpoint*|*modify*|*method*) : ;;
  *) exit 0 ;;
esac

emitted=0

# 1) 全局个人偏好（你到任何项目都默认遵守）
if [ -f "$HOME/.claude/conventions.md" ]; then
  echo "## 全局个人编码规范（默认遵守）"
  cat "$HOME/.claude/conventions.md"
  echo
  emitted=1
fi

# 2) 当前项目专属规范（优先级高于全局；冲突以项目为准）
if [ -d "$proj/docs/conventions" ] && ls "$proj/docs/conventions"/*.md >/dev/null 2>&1; then
  echo "## 本项目编码规范（优先级高于全局；冲突以本项目为准；本次必须遵守）"
  cat "$proj/docs/conventions"/*.md
  echo
  emitted=1
fi

if [ "$emitted" -eq 1 ]; then
  echo "> 以上为本次编码必须遵守的规范。机器可判定的部分会在你改完文件后由检查器自动校验，违反会被拦回要求修正。"
fi

exit 0
