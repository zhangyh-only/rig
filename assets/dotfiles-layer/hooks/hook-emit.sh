#!/usr/bin/env bash
# hook-emit.sh —— rig hook 的公共输出层。被各 hook 脚本 source。
#
# 让同一份脚本同时伺候 Claude 和 Codex 两套 hook 协议:脚本核心逻辑只管算出
# "要注入的文本 / 要拦截的原因",最后调下面的 emit_* 由本库按目标 agent 选输出格式。
#
# 约定（source 前由调用脚本设好）：
#   HOOK_MODE   claude(默认) | codex   —— 脚本开头按 $1=--codex 设
#   HOOK_EVENT  UserPromptSubmit | SessionStart | PreToolUse | PostToolUse | Stop
#
# 输出语义：
#   Claude —— 注入=裸 stdout；拦截=exit 2 + stderr（Claude Code 原生）。
#   Codex  —— 注入=hookSpecificOutput.additionalContext；PreToolUse 拒=permissionDecision:deny；
#             PostToolUse/Stop 拦=decision:block（均 exit 0，语义在 JSON 里）。
#             官方惯用法：结构化 JSON 是标准，exit 2 是 legacy convenience。
#   无 jq 的 Codex 环境 —— 注入降级为纯文本 stdout（Codex 也接受）；拦截降级为 exit 2 + stderr。

_have_jq(){ command -v jq >/dev/null 2>&1; }

# 注入上下文（UserPromptSubmit / SessionStart）。空文本 → 静默放行。调用后即终止脚本。
emit_context(){
  local text="$1"
  [ -z "$text" ] && exit 0
  if [ "${HOOK_MODE:-claude}" = codex ] && _have_jq; then
    jq -n --arg e "${HOOK_EVENT:-UserPromptSubmit}" --arg c "$text" \
      '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
  else
    printf '%s' "$text"
  fi
  exit 0
}

# PreToolUse 拒绝工具调用（红线）。调用后即终止脚本。
emit_deny(){
  local reason="$1"
  if [ "${HOOK_MODE:-claude}" = codex ] && _have_jq; then
    jq -n --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r}}'
    exit 0
  fi
  printf '%s\n' "$reason" >&2
  exit 2
}

# PostToolUse / Stop 拦截（让 agent 当场修 / 别收工继续干）。调用后即终止脚本。
emit_block(){
  local reason="$1"
  if [ "${HOOK_MODE:-claude}" = codex ] && _have_jq; then
    jq -n --arg r "$reason" '{decision:"block", reason:$r}'
    exit 0
  fi
  printf '%s\n' "$reason" >&2
  exit 2
}
