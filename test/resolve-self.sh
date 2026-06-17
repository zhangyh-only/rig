#!/usr/bin/env bash
# 回归测试:bin/rig / bootstrap.sh 经软链调用时,必须把"包根"解析到真实克隆,
# 而不是软链所在目录(否则找不到 scripts/assets),且不得造成软链自环。
#
# 复现真机 2026-06-17 的 /rig:init 事故:
#   - 裸 rig(~/.local/bin/rig 软链)→ SELF 误解析成 ~/.local → 找不到 scripts/assets,init 当场失败;
#   - 改走 skill 软链 → bootstrap 的 ln -sfn 把 ~/.claude/skills/rig 指向自身成环。
# 本测试只验证"路径解析"这一根因(确定性、无副作用、不写 ~/.claude)。
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(cd -P "$(mktemp -d)" && pwd)"   # 规范成物理路径(macOS /var→/private/var),与 cd -P 解析口径一致
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check(){ if [ "$2" = "$3" ]; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1: 期望[$3] 实得[$2]"; fail=$((fail+1)); fi; }
selfof(){ "$1" help 2>/dev/null | sed -n 's/^包根:[[:space:]]*//p'; }

echo "== bin/rig 软链解析回归(REPO=$REPO) =="

# 1) 经 PATH shim 软链调用(模拟 ~/.local/bin/rig -> REPO/bin/rig)
mkdir -p "$TMP/bin"; ln -sf "$REPO/bin/rig" "$TMP/bin/rig"
check "PATH 软链调用 → 真实包根" "$(selfof "$TMP/bin/rig")" "$REPO"

# 2) 经 skill 软链目录调用(模拟 ~/.claude/skills/rig -> REPO,再 .../bin/rig)
ln -sfn "$REPO" "$TMP/skill"
check "skill 软链目录调用 → 真实包根" "$(selfof "$TMP/skill/bin/rig")" "$REPO"

# 3) 多级软链(shim -> shim -> 真实)
ln -sf "$TMP/bin/rig" "$TMP/bin/rig2"
check "多级软链调用 → 真实包根" "$(selfof "$TMP/bin/rig2")" "$REPO"

# 4) bootstrap 同款解析器:经 skill 软链目录调用时,here 必须=真实包根(非软链自身,否则 ln 自环)
mkdir -p "$TMP/clone/scripts"
cat > "$TMP/clone/scripts/probe.sh" <<'PROBE'
__src="${BASH_SOURCE[0]:-$0}"
while [ -h "$__src" ]; do
  __dir="$(cd -P "$(dirname "$__src")" && pwd)"
  __src="$(readlink "$__src")"
  case "$__src" in /*) ;; *) __src="$__dir/$__src" ;; esac
done
here="$(cd -P "$(dirname "$__src")/.." && pwd)"
echo "$here"
PROBE
ln -sfn "$TMP/clone" "$TMP/sklink"
check "bootstrap 解析器经 skill 软链 → 真实包根(非软链自身)" "$(bash "$TMP/sklink/scripts/probe.sh")" "$TMP/clone"

echo; echo "resolve-self: $pass 过 / $fail 失败"
[ "$fail" -eq 0 ]
