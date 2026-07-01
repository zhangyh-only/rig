#!/usr/bin/env bash
# codex-hooks.sh —— 验证 rig hook 的"双模式输出"(Claude / Codex)。
# 本机 codex 二进制可能不可用 → 用"模拟事件 JSON 喂脚本"代替端到端，断言输出格式。
# 用法：bash test/codex-hooks.sh   （退出码 0=全绿）
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/assets/dotfiles-layer/hooks"
pass=0; fail=0
ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }
tmp_root=""
cleanup(){ [ -n "$tmp_root" ] && rm -rf "$tmp_root"; }
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || { echo "需要 jq 跑本测试"; exit 1; }

echo "== hook-emit.sh 双模式 =="

# emit_context —— Codex 模式 → 合法 JSON，additionalContext 带文本
out="$(HOOK_MODE=codex HOOK_EVENT=UserPromptSubmit bash -c ". '$HOOKS/hook-emit.sh'; emit_context '规范文本X'")"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName=="UserPromptSubmit" and .hookSpecificOutput.additionalContext=="规范文本X"' >/dev/null 2>&1; then
  ok "emit_context codex → hookSpecificOutput.additionalContext"
else no "emit_context codex（实得：${out-}）"; fi

# emit_context —— Claude 模式 → 裸文本（非 JSON）
out="$(HOOK_MODE=claude HOOK_EVENT=UserPromptSubmit bash -c ". '$HOOKS/hook-emit.sh'; emit_context '规范文本X'")"
if [ "$out" = "规范文本X" ]; then ok "emit_context claude → 裸 stdout"; else no "emit_context claude（实得：${out-}）"; fi

# emit_context —— 空文本 → 无输出、exit 0
out="$(HOOK_MODE=codex bash -c ". '$HOOKS/hook-emit.sh'; emit_context ''"; echo "rc=$?")"
if [ "$out" = "rc=0" ]; then ok "emit_context 空文本 → 静默 exit 0"; else no "emit_context 空（实得：${out-}）"; fi

# emit_deny —— Codex 模式 → permissionDecision:deny，exit 0
out="$(HOOK_MODE=codex bash -c ". '$HOOKS/hook-emit.sh'; emit_deny '红线R'")"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny" and .hookSpecificOutput.permissionDecisionReason=="红线R"' >/dev/null 2>&1; then
  ok "emit_deny codex → permissionDecision:deny (exit 0)"
else no "emit_deny codex（rc=${rc-} 实得：${out-}）"; fi

# emit_deny —— Claude 模式 → exit 2，stderr 带原因
err="$(HOOK_MODE=claude bash -c ". '$HOOKS/hook-emit.sh'; emit_deny '红线R'" 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && [ "$err" = "红线R" ]; then ok "emit_deny claude → exit 2 + stderr"; else no "emit_deny claude（rc=${rc-} err=${err-}）"; fi

# emit_block —— Codex 模式 → decision:block，exit 0
out="$(HOOK_MODE=codex bash -c ". '$HOOKS/hook-emit.sh'; emit_block '修我M'")"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | jq -e '.decision=="block" and .reason=="修我M"' >/dev/null 2>&1; then
  ok "emit_block codex → decision:block (exit 0)"
else no "emit_block codex（rc=${rc-} 实得：${out-}）"; fi

# emit_block —— Claude 模式 → exit 2，stderr 带原因
err="$(HOOK_MODE=claude bash -c ". '$HOOKS/hook-emit.sh'; emit_block '修我M'" 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && [ "$err" = "修我M" ]; then ok "emit_block claude → exit 2 + stderr"; else no "emit_block claude（rc=${rc-} err=${err-}）"; fi

echo
echo "== real hooks --codex =="
tmp_root="$(mktemp -d)"
proj="$tmp_root/project"
mkdir -p "$proj/docs/conventions" "$proj/scripts" "$tmp_root/home/.claude"
printf '%s\n' '项目规范Y' > "$proj/docs/conventions/code.md"
printf '%s\n' '始终层Z' > "$tmp_root/home/.claude/conventions-always.md"
cat > "$proj/scripts/lint-one.sh" <<'SH'
#!/usr/bin/env bash
echo "lint failed for $1"
exit 7
SH
chmod +x "$proj/scripts/lint-one.sh"

out="$(HOME="$tmp_root/home" printf '{"prompt":"改代码","cwd":"%s"}' "$proj" | HOME="$tmp_root/home" "$HOOKS/inject-conventions.sh" --codex)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName=="UserPromptSubmit" and (.hookSpecificOutput.additionalContext | contains("项目规范Y")) and (.hookSpecificOutput.additionalContext | contains("始终层Z"))' >/dev/null 2>&1; then
  ok "inject-conventions --codex → additionalContext"
else no "inject-conventions --codex（rc=${rc-} 实得：${out-}）"; fi

out="$(printf '{"tool_input":{"file_path":"%s/src/Foo.java"},"cwd":"%s"}' "$proj" "$proj" | "$HOOKS/lint-changed.sh" --codex)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | jq -e '.decision=="block" and (.reason | contains("lint failed"))' >/dev/null 2>&1; then
  ok "lint-changed --codex → decision:block"
else no "lint-changed --codex（rc=${rc-} 实得：${out-}）"; fi

echo
echo "== rig init --codex registration =="
home="$tmp_root/codex-home"
target="$tmp_root/codex-project"
mkdir -p "$home" "$target"
HOME="$home" "$ROOT/bin/rig" init --codex "$target" >/dev/null
if [ -f "$home/.codex/hooks.json" ] && jq empty "$home/.codex/hooks.json" >/dev/null 2>&1; then
  ok "rig init --codex → valid ~/.codex/hooks.json"
else no "rig init --codex 未生成合法 hooks.json"; fi
if [ -L "$home/.codex/hooks" ] && [ "$(readlink "$home/.codex/hooks")" = "$home/.rig/hooks" ] && [ -x "$home/.codex/hooks/inject-conventions.sh" ]; then
  ok "rig init --codex → ~/.codex/hooks 关联中立 ~/.rig/hooks"
else no "rig init --codex 未关联 ~/.codex/hooks 到 ~/.rig/hooks"; fi
before="$(jq '[.. | objects | .command? // empty] | length' "$home/.codex/hooks.json" 2>/dev/null || echo 0)"
HOME="$home" "$ROOT/bin/rig" init --codex "$target" >/dev/null
after="$(jq '[.. | objects | .command? // empty] | length' "$home/.codex/hooks.json" 2>/dev/null || echo 0)"
if [ "$before" = "$after" ] && jq -e '.hooks.UserPromptSubmit[0].hooks[0].command | contains("--codex")' "$home/.codex/hooks.json" >/dev/null 2>&1 && jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("lint-changed.sh")' "$home/.codex/hooks.json" >/dev/null 2>&1; then
  ok "rig init --codex → registration idempotent"
else no "rig init --codex registration 非幂等或命令缺失"; fi
bad_home="$tmp_root/bad-codex-home"
bad_proj="$tmp_root/bad-codex-project"
mkdir -p "$bad_home/.codex" "$bad_proj"
printf '%s\n' '{bad json' > "$bad_home/.codex/hooks.json"
HOME="$bad_home" "$ROOT/bin/rig" init --codex "$bad_proj" >/dev/null 2>&1
if grep -q '{bad json' "$bad_home/.codex/hooks.json"; then
  ok "rig init --codex → invalid existing hooks.json not overwritten"
else no "rig init --codex 覆盖了非法 hooks.json"; fi

echo
echo "== rig init auto multi-tool =="
auto_home="$tmp_root/auto-home"
auto_proj="$tmp_root/auto-project"
mkdir -p "$auto_home/.claude" "$auto_home/.codex" "$auto_proj"
HOME="$auto_home" "$ROOT/bin/rig" init "$auto_proj" >/dev/null
if [ -f "$auto_home/.claude/settings.json" ] && [ -f "$auto_home/.codex/hooks.json" ]; then
  ok "rig init(auto) → 同时补 Claude + Codex"
else no "rig init(auto) 未同时补 Claude + Codex"; fi
if [ -x "$auto_home/.rig/hooks/hook-emit.sh" ] && [ -x "$auto_home/.claude/hooks/hook-emit.sh" ] && [ -x "$auto_home/.codex/hooks/hook-emit.sh" ]; then
  ok "rig init(auto) → 共享 hook 与两侧入口都可执行"
else no "rig init(auto) hook 共享/入口不完整"; fi

codex_only_home="$tmp_root/codex-only-home"
codex_only_proj="$tmp_root/codex-only-project"
mkdir -p "$codex_only_home/.codex" "$codex_only_proj"
HOME="$codex_only_home" "$ROOT/bin/rig" init "$codex_only_proj" >/dev/null
if [ -f "$codex_only_home/.codex/hooks.json" ] && [ -L "$codex_only_home/.codex/hooks" ] && [ "$(readlink "$codex_only_home/.codex/hooks")" = "$codex_only_home/.rig/hooks" ]; then
  ok "rig init(auto) → Codex-only 机器不依赖 ~/.claude/hooks"
else no "rig init(auto) Codex-only 仍依赖 Claude 路径"; fi

echo
echo "== bootstrap auto multi-tool =="
boot_home="$tmp_root/bootstrap-home"
mkdir -p "$boot_home/.claude" "$boot_home/.codex"
boot_out="$(HOME="$boot_home" bash "$ROOT/scripts/bootstrap.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -x "$boot_home/.rig/hooks/hook-emit.sh" ] && [ -x "$boot_home/.claude/hooks/hook-emit.sh" ]; then
  ok "bootstrap → 共享 hook 与 Claude 入口"
else no "bootstrap 未补齐共享 hook/Claude 入口（rc=${rc-} out=${boot_out-}）"; fi
if [ "$rc" -eq 0 ] && [ -L "$boot_home/.codex/hooks" ] && [ "$(readlink "$boot_home/.codex/hooks")" = "$boot_home/.rig/hooks" ] && jq empty "$boot_home/.codex/hooks.json" >/dev/null 2>&1; then
  ok "bootstrap → 自动补 Codex hooks.json 与入口"
else no "bootstrap 未自动补 Codex（rc=${rc-} out=${boot_out-}）"; fi
if printf '%s' "$boot_out" | grep -q 'Codex hook 注册已写入'; then
  ok "bootstrap → 输出明确包含 Codex 接线结果"
else no "bootstrap 输出没有 Codex 接线结果"; fi

echo
echo "codex-hooks: $pass 过 / $fail 失败"
[ "$fail" -eq 0 ]
