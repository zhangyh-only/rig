#!/usr/bin/env bash
# workflow-router.sh —— 验证 Workflow Router 契约被模板、doctor、Codex 与 Claude Code 命令层覆盖。
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0
tmp_root="$(mktemp -d)"

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
assert_grep '交付说明约束' "$agents" "AGENTS 模板包含交付说明约束"
assert_grep '新项目' "$agents" "AGENTS 模板要求说明新项目用法"
assert_grep '已接入 rig' "$agents" "AGENTS 模板要求说明已接入项目用法"
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
assert_grep '交付说明约束' "$commands" "COMMANDS 包含交付说明约束"
assert_grep '新项目怎么用' "$commands" "COMMANDS 要求说明新项目怎么用"
assert_grep '已接入 rig 的项目怎么更新' "$commands" "COMMANDS 要求说明已接入项目怎么更新"

echo
echo "== README rollout usage =="
readme="$ROOT/README.md"
assert_grep 'Workflow Router 如何落地到项目' "$readme" "README 说明 Workflow Router 落地方式"
assert_grep '新项目' "$readme" "README 说明新项目使用方式"
assert_grep '已接入 rig 的项目' "$readme" "README 说明已接入项目使用方式"
assert_grep 'rig doctor' "$readme" "README 说明用 doctor 检查"
assert_grep '自动补齐' "$readme" "README 说明已接入项目自动补齐"
forbidden_router_docs="$tmp_root/forbidden-router-docs.txt"
if rg -n '手动合并|如需合并请手动|手工拼模板' "$readme" "$commands" "$ROOT/assets/project-layer/AGENTS.md" "$ROOT/docs/INSTALL.md" "$ROOT/scripts/bootstrap.sh" > "$forbidden_router_docs"; then
  no "Workflow Router 文档/脚本不应要求用户手动合并模板"
  sed 's/^/    /' "$forbidden_router_docs"
else
  ok "Workflow Router 文档/脚本不要求用户手动合并模板"
fi

echo
echo "== rig init upgrades already-onboarded project =="
upgraded_project="$tmp_root/upgraded-project"
mkdir -p "$upgraded_project/.claude/commands/rig"
cat > "$upgraded_project/AGENTS.md" <<'MD'
# Existing Project

## 1. 项目地图
- 保留我已有的项目说明。

## 5. 旧变更流程
- 这里是旧项目已有内容。
MD
cat > "$upgraded_project/.claude/commands/rig/new-change.md" <<'MD'
---
description: 旧版 new-change 描述
argument-hint: <变更简述>
---

旧项目里已有的命令正文。
MD
HOME="$tmp_root/upgrade-home" "$ROOT/bin/rig" init --cursor "$upgraded_project" >/dev/null
assert_grep '保留我已有的项目说明' "$upgraded_project/AGENTS.md" "rig init 保留既有 AGENTS 内容"
assert_grep 'Workflow Router' "$upgraded_project/AGENTS.md" "rig init 自动补齐 Workflow Router"
assert_grep '多工具同步约束' "$upgraded_project/AGENTS.md" "rig init 自动补齐多工具同步约束"
assert_grep '交付说明约束' "$upgraded_project/AGENTS.md" "rig init 自动补齐交付说明约束"
assert_grep '新需求 / 行为契约变化 / 接口数据流程变化' "$upgraded_project/.claude/commands/rig/new-change.md" "rig init 自动更新 Claude command description"
assert_grep '## 路由边界' "$upgraded_project/.claude/commands/rig/new-change.md" "rig init 自动补齐 Claude command 路由边界"
assert_grep '旧项目里已有的命令正文' "$upgraded_project/.claude/commands/rig/new-change.md" "rig init 保留既有 Claude command 正文"

echo
echo "== doctor Workflow Router checker =="
if "$ROOT/scripts/check-workflow-router.sh" "$ROOT/assets/project-layer" >/dev/null 2>&1; then
  ok "check-workflow-router 接受项目模板"
else
  no "check-workflow-router 接受项目模板"
fi

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
