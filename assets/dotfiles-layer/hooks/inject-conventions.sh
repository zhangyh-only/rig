#!/usr/bin/env bash
# UserPromptSubmit hook —— 把规范注入 AI 这一轮上下文。两层：
#   A) 始终注入层（~/.claude/conventions-always.md）：【每轮】都注入（语言/语气等易被长上下文/英文带跑的硬指令），
#      不依赖编码关键词、不依赖 jq。短小、每轮重申，对抗"上下文惯性"。
#   B) 完整规范（全局 conventions.md + 当前项目 docs/conventions/）：只在"编码类"prompt 注入，省 token。
# 机制：本脚本住在 ~/.claude/hooks/（全局一份）；它不内置规范，去"当前项目"按固定路径找。stdout(exit 0) 进上下文。

HOOK_MODE=claude
[ "${1:-}" = "--codex" ] && HOOK_MODE=codex
HOOK_EVENT=UserPromptSubmit
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-emit.sh"

input="$(cat)"
context=""
append_context(){
  [ -z "$1" ] && return 0
  if [ -n "$context" ]; then
    context="$context

$1"
  else
    context="$1"
  fi
}

# ── A) 始终注入层 —— 每轮都推，先于一切判断（连 jq 都不需要，缺 jq 也照常注入语言指令） ──
if [ -f "$HOME/.claude/conventions-always.md" ]; then
  block="$(
    echo "## 始终遵守（每轮重申，优先级高于一切上下文惯性）"
    cat "$HOME/.claude/conventions-always.md"
  )"
  append_context "$block"
fi

# ── B) 完整规范 —— 需 jq 判断 prompt 类型；无 jq 优雅降级（只是不注入完整规范，A 层已注入），绝不阻断 ──
if ! command -v jq >/dev/null 2>&1; then emit_context "$context"; fi

prompt="$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // .input // ""' 2>/dev/null)"
proj="$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)"
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"

# 仅对"像编码"的 prompt 注入，省 token。关键词按需增删。
case "$prompt" in
  *代码*|*实现*|*新增*|*修改*|*重构*|*接口*|*功能*|*函数*|*方法*|*bug*|*Bug*|*BUG*|*class*|*function*|*fix*|*refactor*|*implement*|*create*|*feature*|*endpoint*|*modify*|*method*) : ;;
  *) emit_context "$context" ;;
esac

emitted=0

# 1) 全局个人偏好（你到任何项目都默认遵守）
if [ -f "$HOME/.claude/conventions.md" ]; then
  block="$(
    echo "## 全局个人编码规范（默认遵守）"
    cat "$HOME/.claude/conventions.md"
  )"
  append_context "$block"
  emitted=1
fi

# 2) 当前项目专属规范（优先级高于全局；冲突以项目为准）
if [ -d "$proj/docs/conventions" ] && ls "$proj/docs/conventions"/*.md >/dev/null 2>&1; then
  block="$(
    echo "## 本项目编码规范（优先级高于全局；冲突以本项目为准；本次必须遵守）"
    cat "$proj/docs/conventions"/*.md
  )"
  append_context "$block"
  emitted=1
fi

if [ "$emitted" -eq 1 ]; then
  append_context "> 以上为本次编码必须遵守的规范。机器可判定的部分会在你改完文件后由检查器自动校验，违反会被拦回要求修正。"
fi

emit_context "$context"
