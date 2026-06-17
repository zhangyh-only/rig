#!/usr/bin/env bash
# 回归测试:guard-bash.sh 只拦【写受保护路径】,不误伤读取/字符串提及/2>&1。
# 复现 2026-06-17 审计 guard-bash-1/2:旧版对整条命令做剥星号子串匹配,大面积误拦正常命令。
# 需要 jq。无副作用(只喂 JSON 给 hook 看退出码)。
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/assets/dotfiles-layer/hooks/guard-bash.sh"
command -v jq >/dev/null 2>&1 || { echo "需要 jq,跳过"; exit 0; }
TMP="$(cd -P "$(mktemp -d)" && pwd)"   # 无 protected-paths.txt → 用默认红线
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

run(){ printf '{"tool_input":{"command":%s},"cwd":%s}' "$(jq -Rn --arg c "$1" '$c')" "$(jq -Rn --arg p "$TMP" '$p')" | bash "$HOOK" >/dev/null 2>&1; echo $?; }
allow(){ rc="$(run "$1")"; if [ "$rc" = "0" ]; then echo "  ✓ 放行: $1"; pass=$((pass+1)); else echo "  ✗ 误拦(rc=$rc): $1"; fail=$((fail+1)); fi; }
block(){ rc="$(run "$1")"; if [ "$rc" = "2" ]; then echo "  ✓ 拦截: $1"; pass=$((pass+1)); else echo "  ✗ 漏拦(rc=$rc): $1"; fail=$((fail+1)); fi; }

echo "== 应放行(读取 / 仅提及 / 2>&1 / 写到非红线) =="
allow 'grep HOST .env.example > /tmp/out.txt'
allow 'cat .env >> combined.txt'
allow 'echo see /target/overview > notes.md'
allow 'pytest 2>&1 | tee log.txt'
allow 'echo done > result.txt && cat .env.sample'
allow 'grep -r generated src/ > report.txt'
allow 'ls node_modules > /tmp/list'
allow 'cp src/target/x.txt ./local.txt'

echo "== 应拦截(真的写到受保护路径) =="
block 'echo x > src/generated/foo.py'
block "sed -i 's/a/b/' src/target/x.txt"
block 'echo data > out.g.py'
block 'cp build.sh src/dist/build.sh'
block 'dd if=/dev/zero of=src/build/big.bin'
block 'cat x | tee src/generated/y.txt'

echo; echo "guard-bash: $pass 过 / $fail 失败"
[ "$fail" -eq 0 ]
