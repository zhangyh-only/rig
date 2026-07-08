#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

ok() { echo "✓ $1"; }
no() { echo "✗ $1"; [ $# -gt 1 ] && echo "  $2"; fail=1; }

required="
assets/project-layer/docs/conventions/templates/README.md
assets/project-layer/docs/conventions/templates/project-types/coding-full.md
assets/project-layer/docs/conventions/templates/project-types/coding-light.md
assets/project-layer/docs/conventions/templates/project-types/non-coding.md
assets/project-layer/docs/conventions/templates/project-types/mixed.md
assets/project-layer/docs/conventions/templates/languages/java.md
assets/project-layer/docs/conventions/templates/languages/typescript.md
assets/project-layer/docs/conventions/templates/languages/python.md
assets/project-layer/docs/conventions/templates/languages/go.md
assets/project-layer/docs/conventions/templates/languages/markdown-docs.md
"

for f in $required; do
  [ -f "$ROOT/$f" ] && ok "存在模板 $f" || no "缺少模板 $f"
done

if rg -n "Codex-only|Codex 专用|只为 Codex" "$ROOT/assets/project-layer/docs/conventions/templates" >/tmp/rig-convention-template-forbidden.$$ 2>/dev/null; then
  no "模板不能写成 Codex 专用" "$(cat /tmp/rig-convention-template-forbidden.$$)"
else
  ok "模板未收窄为 Codex 专用"
fi
rm -f /tmp/rig-convention-template-forbidden.$$

tmp="$(mktemp -d)"
mkdir -p "$tmp/home/.claude"
printf '始终层\n' > "$tmp/home/.claude/conventions-always.md"
out="$(printf '{"prompt":"改代码","cwd":"%s"}' "$ROOT/assets/project-layer" | HOME="$tmp/home" "$ROOT/assets/dotfiles-layer/hooks/inject-conventions.sh" 2>/dev/null)"

case "$out" in
  *"编码约定（模板"*) ok "顶层 conventions 会被注入" ;;
  *) no "顶层 conventions 未被注入" "$out" ;;
esac

case "$out" in
  *"语言模板：Java / Spring"*) no "模板库被误注入到编码上下文" ;;
  *) ok "模板库保持参考态，不被 hook 直接注入" ;;
esac

rm -rf "$tmp"
exit "$fail"
