#!/usr/bin/env bash
# 检查项目 AGENTS.md 是否带有 rig Workflow Router 契约。
set -u

proj="${1:-$PWD}"
agents="$proj/AGENTS.md"
fail=0

check(){
  pattern="$1"
  label="$2"
  if grep -qF "$pattern" "$agents" 2>/dev/null; then
    echo "  ✓ $label"
  else
    echo "  ✗ 缺少 ${label}：${pattern}"
    fail=1
  fi
}

echo "Workflow Router contract: $agents"

if [ ! -f "$agents" ]; then
  echo "  ✗ 缺少 AGENTS.md，无法检查 Workflow Router"
  exit 1
fi

check "Workflow Router" "Workflow Router 标题"
check "rig:workflow-router:start" "稳定起始锚点"
check "rig:workflow-router:end" "稳定结束锚点"
check "小需求快路径" "小需求快路径说明"
check "多工具同步约束" "多工具同步约束"
check "Claude Code" "Claude Code 同步层说明"
check "Codex" "Codex 同步层说明"
check "不适用 / 待补" "未同步工具显式标注要求"
check "OpenSpec：需求合同、行为契约、验收清单" "OpenSpec 职责定义"
check "交付/验收视角任务" "openspec/tasks.md 职责定义"
check "superpowers plan / implementation plan：复杂需求的施工图" "implementation plan 职责定义"
check "ADR：长期架构决策原因" "ADR 职责定义"
check "feature-spec：代码现状反扫" "feature-spec 职责定义"
check "review 不创建 change" "review 边界"
check "改按钮文案" "快路径正例"
check "修局部 bug" "快路径 bug 正例"
check "新增场景配置工作台" "OpenSpec 正例"
check "前后端联动 + 数据结构 + 多模块" "OpenSpec + implementation plan 正例"
check "Graph 编排边界" "ADR 正例"

if [ "$fail" -eq 0 ]; then
  echo "  ✓ Workflow Router 契约完整"
else
  echo "  ✗ Workflow Router 契约不完整，请补齐项目 AGENTS.md 的路由规则"
fi

exit "$fail"
