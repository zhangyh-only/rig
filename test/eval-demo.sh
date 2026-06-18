#!/usr/bin/env bash
# 轻量自评分（golden-fixture）—— 把 demo 的 hook 链固化成"确定性打分 + 3 次跑分一致"的回归闸。
# 跑的是 assets 里的 hook 源（不需先安装到 ~/.claude），可进 CI / pre-commit。零 LLM、纯 bash、可复读。
# 断言四类：① hook 有没触发 ② 违规有没被抓 ③ 闸有没拦 ④ 占位符判没判 incomplete；外加 3 次跑分一致。
# 这是重型 eval 平台（7 维 / headless / A-B）的"轻量版"——只固化 demo，不替被试干活。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$HERE/../assets/dotfiles-layer/hooks"
SBX="$HERE/.eval-sandbox"      # 固定路径 → 输出稳定、3 次跑分可比

# ---------- 断言原语 ----------
PASS=0; FAIL=0; RESULTS=""
_rec(){ RESULTS="${RESULTS}$1
"; }
ok(){ _rec "PASS  $1"; PASS=$((PASS+1)); }
no(){ _rec "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }
exit_is(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "期望 exit $2，实得 $3"; }
has(){ case "$3" in *"$2"*) ok "$1";; *) no "$1" "输出缺『$2』";; esac; }
empty_ok(){ [ -z "$2" ] && ok "$1" || no "$1" "期望空输出"; }
not_has(){ case "$3" in *"$2"*) no "$1" "不该含『$2』";; *) ok "$1";; esac; }

build_sandbox(){   # $1 = with_verify_local (1/0)
  rm -rf "$SBX"
  mkdir -p "$SBX/docs/conventions" "$SBX/scripts" "$SBX/src/generated" \
           "$SBX/openspec/changes/add-exclaim/specs/greeting" "$SBX/.claude/commands/rig"
  ( cd "$SBX" && git -c init.defaultBranch=main init -q && git config user.email e@x && git config user.name e )
  printf '# 编码约定（fixture）\n- [A桶] 禁止用 print() 调试输出。\n- [B桶] 函数命名用动词短语。\n' > "$SBX/docs/conventions/code.md"
  cat > "$SBX/scripts/lint-one.sh" <<'EOF'
#!/usr/bin/env bash
f="$1"; [ -z "$f" ] && exit 0
case "$f" in
  *.py) grep -nE '(^|[^_A-Za-z])print\(' "$f" >/dev/null 2>&1 && { echo "[A桶]违反 print(): $f"; exit 1; }
        python3 -m py_compile "$f" 2>&1 || exit 1 ;;
esac
exit 0
EOF
  chmod +x "$SBX/scripts/lint-one.sh"
  if [ "$1" = "1" ]; then
    cat > "$SBX/scripts/verify-local.sh" <<'EOF'
#!/usr/bin/env bash
set -e
python3 -m py_compile src/greeting.py
out="$(python3 -c "import sys;sys.path.insert(0,'src');import greeting;print(greeting.greet('world'))")"
echo "$out" | grep -q "Hello" || { echo "冒烟失败：缺 Hello"; exit 1; }
EOF
    chmod +x "$SBX/scripts/verify-local.sh"
  fi
  printf 'def greet(name):\n    return f"Hello, {name}"\n' > "$SBX/src/greeting.py"
  echo "# 自动生成，勿改" > "$SBX/src/generated/auto.py"
  echo '*/generated/*' > "$SBX/.claude/protected-paths.txt"
  printf '## 交流语言\n始终用简体中文回复（ALWAYS-FIXTURE）。\n' > "$SBX/.claude/conventions-always.md"  # always 注入层夹具（HOME 隔离用）
  printf '# add-exclaim\n## 目标\n给 greet 加感叹号。\n## 范围\n只改 src/greeting.py。\n' > "$SBX/openspec/changes/add-exclaim/proposal.md"
  printf -- '- [ ] 加感叹号\n- [ ] 自验证通过\n' > "$SBX/openspec/changes/add-exclaim/tasks.md"
  printf '## MODIFIED Requirements\n验收：greet("world") == "Hello, world!"\n' > "$SBX/openspec/changes/add-exclaim/specs/greeting/spec.md"
  ( cd "$SBX" && git add -A && git commit -qm init )
}

run_suite(){
  PASS=0; FAIL=0; RESULTS=""
  build_sandbox 1

  # ① hook 有没触发
  o="$(printf '{"cwd":"%s"}' "$SBX" | "$HOOKS/session-start.sh" 2>/dev/null)"
  has "① session-start 注入进行中变更" "进行中变更：add-exclaim" "$o"
  o="$(printf '{"prompt":"修改 greeting 功能","cwd":"%s"}' "$SBX" | HOME="$SBX" "$HOOKS/inject-conventions.sh" 2>/dev/null)"
  has "① inject-conventions 编码:注入项目规范全文" "禁止用 print()" "$o"
  has "① inject-conventions 编码:也注入 always 层（语言）" "ALWAYS-FIXTURE" "$o"
  o="$(printf '{"prompt":"修改 greeting 功能","cwd":"%s"}' "$SBX" | "$HOOKS/inject-active-spec.sh" 2>/dev/null)"
  has "① inject-active-spec 注入变更规格" "add-exclaim" "$o"
  o="$(printf '{"prompt":"今天天气如何","cwd":"%s"}' "$SBX" | HOME="$SBX" "$HOOKS/inject-conventions.sh" 2>/dev/null)"
  not_has "① inject-conventions 非编码:完整规范静默（失败降级）" "禁止用 print()" "$o"
  has "① inject-conventions 非编码:always 层仍每轮注入（语言不漏）" "ALWAYS-FIXTURE" "$o"

  # ② 违规有没被抓
  printf 'def greet(name):\n    print("dbg", name)\n    return f"Hi, {name}!"\n' > "$SBX/src/greeting.py"
  out="$(printf '{"tool_input":{"file_path":"%s/src/greeting.py"},"cwd":"%s"}' "$SBX" "$SBX" | "$HOOKS/lint-changed.sh" 2>&1)"; rc=$?
  exit_is "② lint-changed 抓到 print()（exit 2）" 2 "$rc"
  has "② lint-changed 报告 print 违规" "print" "$out"
  printf 'def greet(name):\n    return f"Hi, {name}!"\n' > "$SBX/src/greeting.py"
  printf '{"tool_input":{"file_path":"%s/src/greeting.py"},"cwd":"%s"}' "$SBX" "$SBX" | "$HOOKS/lint-changed.sh" >/dev/null 2>&1; rc=$?
  exit_is "② lint-changed 放行干净文件（exit 0）" 0 "$rc"

  # ③ 闸有没拦
  printf '{"tool_input":{"file_path":"%s/src/generated/auto.py"},"cwd":"%s"}' "$SBX" "$SBX" | "$HOOKS/guard.sh" >/dev/null 2>&1; rc=$?
  exit_is "③ guard 拦住受保护路径（exit 2）" 2 "$rc"
  printf '{"cwd":"%s","stop_hook_active":false}' "$SBX" | "$HOOKS/verify-on-stop.sh" >/dev/null 2>&1; rc=$?
  exit_is "③ verify-on-stop 抓住功能回归 Hi≠Hello（exit 2）" 2 "$rc"
  printf 'def greet(name):\n    return f"Hello, {name}!"\n' > "$SBX/src/greeting.py"
  printf '{"cwd":"%s","stop_hook_active":false}' "$SBX" | "$HOOKS/verify-on-stop.sh" >/dev/null 2>&1; rc=$?
  exit_is "③ verify-on-stop 修好后放行（exit 0）" 0 "$rc"

  # ③b A3 回归：缺 verify-local 时 session-start 必须"响亮"告警（不静默）
  rm -f "$SBX/scripts/verify-local.sh"
  o="$(printf '{"cwd":"%s"}' "$SBX" | "$HOOKS/session-start.sh" 2>/dev/null)"
  has "③b A3：缺 verify-local 时 session-start 响亮告警" "缺 scripts/verify-local.sh" "$o"

  # ④ 占位符判 incomplete（manifest 四态：空壳 ≠ present）
  printf '# 约定\n- 命名：<按本项目实际填写>\n' > "$SBX/docs/conventions/_placeholder.md"
  if grep -nE '<[^>]+>' "$SBX/docs/conventions/_placeholder.md" >/dev/null 2>&1; then ok "④ 占位符文件判为 incomplete"; else no "④ 占位符文件判为 incomplete" "未检出占位符"; fi
  if grep -nE '<[^>]+>' "$SBX/docs/conventions/code.md" >/dev/null 2>&1; then no "④ 已填文件判为 present" "误检出占位符"; else ok "④ 已填文件判为 present"; fi

  printf '%s' "$RESULTS"
  echo "SCORE ${PASS}/$((PASS+FAIL))"
}

# ---------- 跑 3 次验确定性 ----------
r1="$(run_suite)"
r2="$(run_suite)"
r3="$(run_suite)"
rm -rf "$SBX"

echo "$r1"
echo
fails="$(printf '%s\n' "$r1" | grep -c '^FAIL ')"
s1="$(printf '%s' "$r1" | cksum)"; s2="$(printf '%s' "$r2" | cksum)"; s3="$(printf '%s' "$r3" | cksum)"
if [ "$s1" = "$s2" ] && [ "$s2" = "$s3" ]; then
  echo "DETERMINISM ✓ 3 次跑分完全一致 [$s1]"
  det_ok=1
else
  echo "DETERMINISM ✗ 三次不一致：[$s1] [$s2] [$s3]"
  det_ok=0
fi

echo
if [ "$fails" -eq 0 ] && [ "$det_ok" -eq 1 ]; then
  echo "=== GOLDEN-FIXTURE PASS ==="; exit 0
else
  echo "=== GOLDEN-FIXTURE FAIL（见上 FAIL 行 / 确定性）==="; exit 1
fi
