#!/usr/bin/env bash
# workflow-router.sh —— 验证 Workflow Router 契约被模板、doctor、Codex 与 Claude Code 命令层覆盖。
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0
tmp_root=""

ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }
cleanup(){ [ -n "$tmp_root" ] && rm -rf "$tmp_root"; }
trap cleanup EXIT

assert_grep(){
  pattern="$1"
  file="$2"
  label="$3"
  if grep -q "$pattern" "$file"; then
    ok "$label"
  else
    no "$label"
  fi
}

echo "== project AGENTS Workflow Router template =="
agents="$ROOT/assets/project-layer/AGENTS.md"
assert_grep 'Workflow Router' "$agents" "AGENTS 模板包含 Workflow Router 标题"
assert_grep 'rig:workflow-router:start' "$agents" "AGENTS 模板包含稳定起始锚点"
assert_grep '小需求快路径' "$agents" "AGENTS 模板说明小需求快路径"
assert_grep 'OpenSpec：需求合同、行为契约、验收清单' "$agents" "AGENTS 模板固定 OpenSpec 职责"
assert_grep 'superpowers plan / implementation plan：复杂需求的施工图' "$agents" "AGENTS 模板固定 implementation plan 职责"
assert_grep 'review 不创建 change' "$agents" "AGENTS 模板说明 review 不创建 change"
assert_grep '多工具同步约束' "$agents" "AGENTS 模板包含多工具同步约束"
assert_grep 'Claude Code' "$agents" "AGENTS 模板点名 Claude Code 层"
assert_grep 'Codex' "$agents" "AGENTS 模板点名 Codex 层"
assert_grep '不适用 / 待补' "$agents" "AGENTS 模板要求显式标注未同步工具"
assert_grep '改按钮文案' "$agents" "AGENTS 模板包含快路径正例"
assert_grep '新增场景配置工作台' "$agents" "AGENTS 模板包含 OpenSpec 正例"
assert_grep 'Graph 编排边界' "$agents" "AGENTS 模板包含 ADR 正例"

echo
echo "== docs command contract multi-tool policy =="
commands="$ROOT/docs/COMMANDS.md"
assert_grep '多工具同步约束' "$commands" "COMMANDS 包含多工具同步约束"
assert_grep 'Claude Code' "$commands" "COMMANDS 点名 Claude Code 层"
assert_grep 'Codex action skills' "$commands" "COMMANDS 点名 Codex action skills"
assert_grep 'Codex plugin command surface' "$commands" "COMMANDS 点名 Codex plugin command surface"
assert_grep '不适用 / 待补' "$commands" "COMMANDS 要求显式标注未同步工具"

echo
echo "== doctor Workflow Router checker =="
if "$ROOT/scripts/check-workflow-router.sh" "$ROOT/assets/project-layer" >/dev/null 2>&1; then
  ok "check-workflow-router 接受项目模板"
else
  no "check-workflow-router 接受项目模板"
fi

tmp_root="$(mktemp -d)"
bad_project="$tmp_root/bad-project"
mkdir -p "$bad_project"
cat > "$bad_project/AGENTS.md" <<'MD'
# Demo

## 5. 变更流程

只有泛泛说明，没有 Workflow Router 契约。
MD
bad_out="$("$ROOT/scripts/check-workflow-router.sh" "$bad_project" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$bad_out" | grep -q 'Workflow Router'; then
  ok "check-workflow-router 拒绝缺少契约的 AGENTS.md"
else
  no "check-workflow-router 未拒绝缺少契约的 AGENTS.md（rc=${rc-} out=${bad_out-}）"
fi

echo
echo "== Codex action skill routing descriptions =="
home="$tmp_root/home"
proj="$tmp_root/project"
mkdir -p "$home/.codex" "$proj"
HOME="$home" "$ROOT/bin/rig" init --codex "$proj" >/dev/null
assert_grep '新需求 / 行为契约变化 / 接口数据流程变化' "$home/.codex/skills/rig-new-change/SKILL.md" "rig-new-change 描述聚焦新需求和契约变化"
assert_grep '不用于 review' "$home/.codex/skills/rig-new-change/SKILL.md" "rig-new-change 描述排除 review"
assert_grep '复核当前实现 / 完成度 / 偏离度 / 当前 diff' "$home/.codex/skills/rig-review/SKILL.md" "rig-review 描述聚焦当前实现复核"
assert_grep '不创建 change' "$home/.codex/skills/rig-review/SKILL.md" "rig-review 描述排除新建 change"
assert_grep '长期架构决策原因' "$home/.codex/skills/rig-adr/SKILL.md" "rig-adr 描述聚焦长期决策原因"
assert_grep '代码现状反扫' "$home/.codex/skills/rig-feature-spec/SKILL.md" "rig-feature-spec 描述聚焦代码现状反扫"

echo
echo "== Claude command template routing descriptions =="
assert_grep '新需求 / 行为契约变化 / 接口数据流程变化' "$ROOT/assets/project-layer/.claude/commands/rig/new-change.md" "new-change 命令描述聚焦新需求和契约变化"
assert_grep '不用于 review' "$ROOT/assets/project-layer/.claude/commands/rig/new-change.md" "new-change 命令描述排除 review"
assert_grep '复核当前实现 / 完成度 / 偏离度 / 当前 diff' "$ROOT/assets/project-layer/.claude/commands/rig/review.md" "review 命令描述聚焦当前实现复核"
assert_grep '不创建 change' "$ROOT/assets/project-layer/.claude/commands/rig/review.md" "review 命令描述排除新建 change"
assert_grep '长期架构决策原因' "$ROOT/assets/project-layer/.claude/commands/rig/adr.md" "adr 命令描述聚焦长期决策原因"
assert_grep '代码现状反扫' "$ROOT/assets/project-layer/.claude/commands/rig/feature-spec.md" "feature-spec 命令描述聚焦代码现状反扫"

echo
echo "workflow-router: $pass 过 / $fail 失败"
[ "$fail" -eq 0 ]
