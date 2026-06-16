#!/usr/bin/env bash
# 自包含演示：在一个 sandbox 项目上模拟 Claude Code 在你编码时自动跑的 hook 链。
# 不碰 ~/.claude、不碰你的真实项目。展示"装了这套之后，你编码时背后发生了什么"。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$HERE/../assets/dotfiles-layer/hooks"
P="$HERE/demo-sandbox"
rm -rf "$P"
mkdir -p "$P/docs/conventions" "$P/scripts" "$P/src/generated" "$P/openspec/changes/add-exclaim/specs/greeting" "$P/.claude"
cd "$P"
git init -q 2>/dev/null; git config user.email d@x 2>/dev/null; git config user.name d 2>/dev/null

# ---------- 项目内容（= 安装器接入后的样子）----------
cat > docs/conventions/code.md <<'EOF'
# 编码约定（demo）
- [A桶] 禁止用 print() 做调试输出，改用日志。  ← 机器可判，被 lint 抓
- [B桶] 函数命名用动词短语。
EOF

cat > scripts/lint-one.sh <<'EOF'
#!/usr/bin/env bash
f="$1"; [ -z "$f" ] && exit 0
case "$f" in
  *.py)
    if grep -nE '(^|[^_A-Za-z])print\(' "$f" >/dev/null 2>&1; then
      echo "规范[A桶]违反：$f 用了调试 print()（见 docs/conventions/code.md）"
      grep -nE '(^|[^_A-Za-z])print\(' "$f" | sed 's/^/    /'
      exit 1
    fi
    python3 -m py_compile "$f" 2>&1 || exit 1 ;;
esac
exit 0
EOF
chmod +x scripts/lint-one.sh

cat > scripts/verify-local.sh <<'EOF'
#!/usr/bin/env bash
set -e
python3 -m py_compile src/greeting.py
out="$(python3 -c "import sys;sys.path.insert(0,'src');import greeting;print(greeting.greet('world'))")"
echo "  冒烟输出: $out"
echo "$out" | grep -q "Hello" || { echo "  冒烟失败：问候语必须含 'Hello'"; exit 1; }
EOF
chmod +x scripts/verify-local.sh

printf 'def greet(name):\n    return f"Hello, {name}"\n' > src/greeting.py
echo "# 自动生成，勿改" > src/generated/auto.py
echo '*/generated/*' > .claude/protected-paths.txt

cat > openspec/changes/add-exclaim/proposal.md <<'EOF'
# add-exclaim
## 目标
给 greet 的问候语加一个感叹号。
## 范围
只改 src/greeting.py，不动其它。
EOF
printf -- '- [ ] 给问候语加感叹号\n- [ ] 自验证通过\n' > openspec/changes/add-exclaim/tasks.md
cat > openspec/changes/add-exclaim/specs/greeting/spec.md <<'EOF'
## MODIFIED Requirements
系统应当返回带感叹号的问候语。
验收：greet("world") == "Hello, world!"
EOF
git add -A 2>/dev/null; git commit -qm init 2>/dev/null

bar(){ printf '════════════════════════════════════════════════════════════\n'; }
echo; bar; echo "场景：你在这个项目里说「修改 greeting 功能：问候语加个感叹号」"; bar

echo; echo "▶ [会话开始] SessionStart → 自动注入项目态地图："
printf '{"cwd":"%s"}' "$P" | "$HOOKS/session-start.sh"

echo; echo "▶ [你发话] UserPromptSubmit → 自动把 规范全文 + 进行中 spec 注入上下文（AI 还没动手就手握规则）："
printf '{"prompt":"修改 greeting 功能：问候语加个感叹号","cwd":"%s"}' "$P" | "$HOOKS/inject-conventions.sh"
printf '{"prompt":"修改 greeting 功能：问候语加个感叹号","cwd":"%s"}' "$P" | "$HOOKS/inject-active-spec.sh"

echo; echo "▶ [AI 第一版] 加了感叹号，但顺手塞了调试 print()、还把 Hello 写成 Hi："
printf 'def greet(name):\n    print("debug:", name)\n    return f"Hi, {name}!"\n' > src/greeting.py
echo "  改完 PostToolUse → lint-changed："
printf '{"tool_input":{"file_path":"%s/src/greeting.py"},"cwd":"%s"}' "$P" "$P" | "$HOOKS/lint-changed.sh"
echo "    → exit $?  （2 = 被拦回，AI 必须当场修）"

echo; echo "▶ [AI 修第一处] 去掉 print()，再 lint："
printf 'def greet(name):\n    return f"Hi, {name}!"\n' > src/greeting.py
printf '{"tool_input":{"file_path":"%s/src/greeting.py"},"cwd":"%s"}' "$P" "$P" | "$HOOKS/lint-changed.sh"
echo "    → exit $?  （0 = lint 过了）"

echo; echo "▶ [AI 想顺手改自动生成文件] PreToolUse → guard："
printf '{"tool_input":{"file_path":"%s/src/generated/auto.py"},"cwd":"%s"}' "$P" "$P" | "$HOOKS/guard.sh"
echo "    → exit $?  （2 = 红线拦住）"

echo; echo "▶ [AI 想收工] Stop → verify-on-stop 跑 verify-local（lint 过了，但 Hi≠Hello 是功能回归）："
printf '{"cwd":"%s","stop_hook_active":false}' "$P" | "$HOOKS/verify-on-stop.sh"
echo "    → exit $?  （2 = 验证没过，不让收工）"

echo; echo "▶ [AI 修第二处] 改回 Hello + 保留感叹号，再 verify："
printf 'def greet(name):\n    return f"Hello, {name}!"\n' > src/greeting.py
printf '{"cwd":"%s","stop_hook_active":false}' "$P" | "$HOOKS/verify-on-stop.sh"
echo "    → exit $?  （0 = 通过，可以收工）"

echo; bar
echo "全程没靠 AI 自觉：规范自动注入 → 风格违规被 lint 拦 → 红线被 guard 拦 → 功能回归被 verify 拦。"
echo "这就是「装了这套之后，你编码时背后自动发生的事」。"
bar
