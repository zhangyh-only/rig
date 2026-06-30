#!/usr/bin/env bash
# 安装后自检 —— 把 smoke 测试固化。用法：verify.sh [project-dir]（默认当前目录）
proj="${1:-$PWD}"
hooks="$HOME/.claude/hooks"
fail=0

# 前置:无 jq 时所有 hook 都 command -v jq||exit 0 静默放行——下面的红线/注入测试必然全"放行",
# 那不代表逻辑坏,而是缺 jq。先点名根因,别把"缺 jq"误报成"红线逻辑失效"。
if ! command -v jq >/dev/null 2>&1; then
  echo "✗ 缺 jq（阻断级）——所有 hook 依赖 jq 解析输入,缺了会【静默放行】,当前装的 hook 实际全空转。"
  echo "  先装 jq(brew/apt install jq)再重跑自检。(无 jq 下红线/注入测试必然全'放行',不代表逻辑正确。)"
  exit 1
fi

echo "=== 1. 注入脚本（编码 prompt 应输出规范）==="
if [ -x "$hooks/inject-conventions.sh" ]; then
  out=$(printf '{"prompt":"改代码","cwd":"%s"}' "$proj" | "$hooks/inject-conventions.sh" 2>/dev/null)
  [ -n "$out" ] && echo "  ✓ 有注入输出" || echo "  ⚠ 无输出（项目还没 docs/conventions/，或非编码语义）"
else
  echo "  ✗ 未找到 $hooks/inject-conventions.sh（全局机制未装？）"; fail=1
fi

echo "=== 2. 红线拦截（generated 文件应 exit 2）==="
if [ -x "$hooks/guard.sh" ]; then
  printf '{"tool_input":{"file_path":"x/generated/A"},"cwd":"%s"}' "$proj" | "$hooks/guard.sh" >/dev/null 2>&1
  rc=$?; [ "$rc" -eq 2 ] && echo "  ✓ 已拦截 (exit 2)" || { echo "  ✗ 未拦截 (exit $rc)"; fail=1; }
else
  echo "  ✗ 未找到 $hooks/guard.sh"; fail=1
fi

echo "=== 3. 红线放行（正常文件应 exit 0）==="
if [ -x "$hooks/guard.sh" ]; then
  printf '{"tool_input":{"file_path":"src/Foo"},"cwd":"%s"}' "$proj" | "$hooks/guard.sh" >/dev/null 2>&1
  rc=$?; [ "$rc" -eq 0 ] && echo "  ✓ 已放行" || { echo "  ✗ 异常 (exit $rc)"; fail=1; }
fi

echo "=== 4. settings.json 已注册 hook ==="
if [ -d "$HOME/.rig/hooks" ]; then
  shared_missing=0
  for h in inject-conventions inject-active-spec lint-changed guard guard-bash verify-on-stop session-start session-end hook-emit; do
    [ -x "$HOME/.rig/hooks/$h.sh" ] || shared_missing=1
  done
  [ "$shared_missing" -eq 0 ] && echo "  ✓ ~/.rig/hooks 共享 hook 源完整" || echo "  ⚠ ~/.rig/hooks 存在但脚本不完整"
else
  echo "  ⚠ 无 ~/.rig/hooks 共享 hook 源（旧安装可用；重跑 bootstrap/rig init 会补）"
fi
if command -v jq >/dev/null 2>&1 && [ -f "$HOME/.claude/settings.json" ]; then
  n=$(jq '[(.hooks // {}) | to_entries[].value[]?.hooks[]?.command] | length' "$HOME/.claude/settings.json" 2>/dev/null || echo 0)
  [ "${n:-0}" -gt 0 ] && echo "  ✓ 注册了 ${n} 个 hook 命令" || { echo "  ✗ settings.json 未注册 hook"; fail=1; }
else
  echo "  ⚠ 无 jq 或无 ~/.claude/settings.json，跳过"
fi
if [ -f "$HOME/.codex/hooks.json" ]; then
  if jq empty "$HOME/.codex/hooks.json" >/dev/null 2>&1; then
    cn=$(jq '[.. | objects | .command? // empty | select(contains(".codex/hooks/"))] | length' "$HOME/.codex/hooks.json" 2>/dev/null || echo 0)
    if [ "${cn:-0}" -ge 2 ]; then
      echo "  ✓ Codex hooks.json 注册了 ${cn} 个 rig hook 命令"
    else
      echo "  ⚠ Codex hooks.json 存在，但未见完整 rig hook 注册（若只装 Claude 可忽略）"
    fi
  else
    echo "  ⚠ Codex hooks.json 不是合法 JSON（若使用 Codex hooks，请先修复）"
  fi
else
  echo "  ⚠ 无 ~/.codex/hooks.json，跳过 Codex hook 检查"
fi
if [ -e "$HOME/.codex/hooks" ]; then
  [ -x "$HOME/.codex/hooks/inject-conventions.sh" ] && echo "  ✓ Codex hook 脚本入口可执行" || echo "  ⚠ Codex hook 脚本入口不可执行"
fi

echo "=== 5. 失败降级（缺前提时 hook 必须 exit 0 不阻断）==="
if [ -x "$hooks/inject-conventions.sh" ]; then
  o=$(printf '{"prompt":"今天天气如何","cwd":"%s"}' "$proj" | "$hooks/inject-conventions.sh" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] && echo "  ✓ 非编码 prompt 不阻断 (exit 0)" || { echo "  ✗ 非编码 prompt 阻断了 (exit $rc)"; fail=1; }
fi
if [ -x "$hooks/lint-changed.sh" ]; then
  printf '{"tool_input":{"file_path":"%s/none.java"},"cwd":"%s"}' "$proj" "$proj" | "$hooks/lint-changed.sh" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && echo "  ✓ 无 lint-one 时放行" || { echo "  ✗ 无 lint-one 未放行 (exit $rc)"; fail=1; }
fi

echo "=== 6. 新增 hook 行为 ==="
if [ -x "$hooks/verify-on-stop.sh" ]; then
  printf '{"cwd":"%s","stop_hook_active":true}' "$proj" | "$hooks/verify-on-stop.sh" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && echo "  ✓ Stop: 防循环放行" || { echo "  ✗ Stop 防循环失效 (exit $rc)"; fail=1; }
else echo "  ⚠ 未装 verify-on-stop.sh"; fi
if [ -x "$hooks/guard-bash.sh" ]; then
  printf '{"tool_input":{"command":"echo x > a/generated/B"},"cwd":"%s"}' "$proj" | "$hooks/guard-bash.sh" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && echo "  ✓ guard-bash: 写 generated 拦截" || { echo "  ✗ guard-bash 未拦 (exit $rc)"; fail=1; }
  printf '{"tool_input":{"command":"cat a/generated/B"},"cwd":"%s"}' "$proj" | "$hooks/guard-bash.sh" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && echo "  ✓ guard-bash: 只读放行" || { echo "  ✗ guard-bash 误拦只读 (exit $rc)"; fail=1; }
else echo "  ⚠ 未装 guard-bash.sh"; fi
for h in session-start session-end inject-active-spec; do
  [ -x "$hooks/$h.sh" ] && echo "  ✓ $h.sh 已装" || echo "  ⚠ 未装 $h.sh"
done

echo
[ "$fail" -eq 0 ] && echo "=== 关键项全部通过 ===" || { echo "=== 有失败项，请检查上面 ✗ ==="; exit 1; }
