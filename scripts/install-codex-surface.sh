#!/usr/bin/env bash
# 安装 Codex 可发现入口：skill 目录 + 本地 plugin command surface。
# hook 本身由 install-codex-hooks.sh 负责；这里补齐用户在 Codex UI 里能发现/调用的层。
set -u

__src="${BASH_SOURCE[0]:-$0}"
while [ -h "$__src" ]; do
  __dir="$(cd -P "$(dirname "$__src")" && pwd)"
  __src="$(readlink "$__src")"
  case "$__src" in /*) ;; *) __src="$__dir/$__src" ;; esac
done
here="$(cd -P "$(dirname "$__src")/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "✗ 缺 jq（阻断级）——Codex marketplace.json 合并依赖 jq。" >&2
  echo "  先安装 jq 后重跑。" >&2
  exit 1
fi

link_dir(){
  target="$1"
  mkdir -p "$(dirname "$target")"
  if [ "$here" = "$target" ]; then
    echo "  ⚠ 包根解析成 $target 自身，跳过以防自环" >&2
  else
    ln -sfn "$here" "$target"
  fi
}

write_skill(){
  dir="$1"
  name="$2"
  description="$3"
  body="$4"
  desc_escaped="${description//\\/\\\\}"
  desc_escaped="${desc_escaped//\"/\\\"}"
  mkdir -p "$dir"
  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$name"
    printf 'description: "%s"\n' "$desc_escaped"
    printf '%s\n' '---'
    printf '\n%s\n' "$body"
  } > "$dir/SKILL.md"
}

install_action_skills(){
  base="$1"
  write_skill "$base/rig-init" "rig-init" "触发：用户要求 /rig:init、初始化、onboard 或接入当前项目；边界：这是当前项目+当前 AI 工具的接入，不是代码审查；动作：运行 rig init --codex 后 doctor。" "# Rig Init

## 触发条件
- 用户要求 \`/rig:init\`、\`rig init\`、初始化 rig、onboard 当前项目、把当前项目接入工作流。
- 同一个仓库换到 Codex 使用时，即使 Claude Code 已经初始化过，也应触发一次。

## 边界
- 这是当前项目 + 当前 AI 工具的初始化，不是当前 diff 的质量审查。
- 不要凭模板伪造项目专属内容；项目地图、验证命令、规范条目必须来自代码或用户确认。

## 执行动作
1. 当 \`rig\` 在 PATH 中时，运行 \`rig init --codex \"\$PWD\"\`。否则先确认文件存在，再运行 \`~/.codex/skills/rig/bin/rig init --codex \"\$PWD\"\` 或 \`~/.agents/skills/rig/bin/rig init --codex \"\$PWD\"\`。
2. 按主 \`rig\` skill 完成判断性工作：归并既有规则到 \`docs/conventions/\`，从项目文件推导 build/test/run 并补进 \`AGENTS.md\`，把占位的 \`scripts/verify-local.sh\` 替换成真实命令。
3. 涉及联网安装或外部 plugin/skill 时先征求用户确认。
4. 最后运行 \`rig doctor \"\$PWD\"\`，报告已改、待决和是否需要新会话。"
  write_skill "$base/rig-doctor" "rig-doctor" "触发：用户要求 /rig:doctor、诊断 rig、排查 hook/skill/plugin/verify 接线；边界：先只读定位，不直接重装；动作：运行 rig doctor 并给根因。" "# Rig Doctor

## 触发条件
- 用户要求 \`/rig:doctor\`、\`rig doctor\`、诊断 rig 安装、排查 hook/skill/plugin/command surface/verify-local。
- 用户反馈“装了但没生效”“命令找不到”“重复显示”“hook 没拦住”等机制健康问题。

## 边界
- 先诊断，不要一上来重跑 bootstrap、改配置或安装依赖。
- 联网安装、破坏性修改、覆盖配置前必须确认。

## 执行动作
1. 运行 \`rig doctor \"\$PWD\"\`。如果 \`rig\` 不在 PATH 中，使用 \`~/.codex/skills/rig/bin/rig doctor \"\$PWD\"\` 或 \`~/.agents/skills/rig/bin/rig doctor \"\$PWD\"\`。
2. 报告 hook 注册、Codex skill/action skill 状态、command surface 状态和项目验证结果。
3. 对失败项先定位根因，再提出最小修复动作。"
  write_skill "$base/rig-review" "rig-review" "触发：复核当前实现 / 完成度 / 偏离度 / 当前 diff；边界：不创建 change、不归档、不规划新需求；动作：对照 AGENTS/conventions/OpenSpec/plan/验证要求审查。" "# Rig Review

## 触发条件
- 用户要求 \`/rig:review\`、\`rig review\`、审查当前变更、分析执行情况、检查未完成事项、复核质量风险。
- 已经有当前实现、当前 diff 或任务执行结果，需要判断完成度、偏离度、缺测和是否符合 rig 规范。

## 边界
- 不创建 change；用户明确要新建需求、行为契约变化或接口数据流程变化时才转 \`rig-new-change\`。
- 不归档 change；用户明确要关闭/归档时才转 \`rig-archive-change\`。
- 不规划新需求；review 只复核当前状态。

## 执行动作
1. 对照 \`AGENTS.md\`、\`docs/conventions/\`、OpenSpec/change、implementation plan 和本地验证要求复查。
2. 优先报告 bug、规范漂移、范围偏离、缺失测试、完成度缺口和自报/实测不一致。
3. 条件允许时运行聚焦验证；只读审查可直接做，写入修复需按用户意图确认。"
  write_skill "$base/rig-new-change" "rig-new-change" "触发：新需求 / 行为契约变化 / 接口数据流程变化；边界：不用于 review、当前 diff 复核或执行情况分析；动作：确认 openspec 后创建 proposal/tasks/spec-delta。" "# Rig New Change

## 触发条件
- 用户明确要求 \`/rig:new-change\`、创建/启动 change、为新需求起 spec、脚手架 openspec change。
- 用户表达的是新需求、行为契约变化、接口数据流程变化或验收标准变化。

## 边界
- 如果用户只是要求“分析当前状态/执行情况/没做完什么/review 当前 diff”，立即说明这不是 \`rig-new-change\`，改走 \`rig-review\` 或普通项目分析；不要先扫描仓库。
- 不要在 openspec 未启用时擅自安装或创建骨架。

## 执行动作
1. 先说明会检查 openspec 是否启用。
2. 只运行有边界的检查：\`pwd\`、\`test -d openspec\`、\`test -f openspec/config.yaml\`、\`command -v openspec\`，以及目录存在时的 \`find openspec/changes -maxdepth 2 -type f\`。
3. 确认 openspec 已启用后，再创建或准备 proposal/tasks/spec-delta。
4. 如果 CLI 缺失，安装 \`@fission-ai/openspec\` 前必须询问用户。"
  write_skill "$base/rig-archive-change" "rig-archive-change" "触发：用户明确要归档/关闭/完成某个 change；边界：未完成、未验证、change id 不明确时不归档；动作：validate+verify 后 archive。" "# Rig Archive Change

## 触发条件
- 用户要求 \`/rig:archive-change\`、归档 change、关闭 change、完成 openspec change。

## 边界
- tasks 未完成、验证未通过、change id 不明确或有多个候选时不要归档。
- 不要替用户把未勾选 task 直接改成完成。

## 执行动作
1. 定位 change，确认 id 和状态。
2. 检查 tasks、运行 validate 和项目验证。
3. 执行 archive。
4. 归档后提醒是否需要 ADR 或 feature-spec 做长期沉淀。"
  write_skill "$base/rig-adr" "rig-adr" "触发：Graph 编排边界、跨域技术选型或难回退取舍，需要记录长期架构决策原因；边界：不是普通实现说明；动作：基于模板写 docs/adr 并更新索引。" "# Rig ADR

## 触发条件
- 用户要求 \`/rig:adr\`、记录架构决策、沉淀技术取舍、解释为什么这样设计。
- 任务涉及 Graph 编排边界、跨域技术选型、难回退架构选择，需要沉淀长期架构决策原因。

## 边界
- 不用于普通实现说明或临时任务记录。
- 不要替用户编造背景、理由或备选方案；不确定就标问题。

## 执行动作
1. 使用项目模板在 \`docs/adr/\` 中创建或更新 ADR。
2. 记录 context、decision、consequences、alternatives 和验证链接。
3. 更新 ADR 索引；其它文档只链接 ADR，不复制 why。"
  write_skill "$base/rig-feature-spec" "rig-feature-spec" "触发：稳定业务域需要代码现状反扫、沉淀现状设计或更新 as-built spec；边界：不规划新需求、不替代 OpenSpec；动作：从代码/文档/测试写 feature spec。" "# Rig Feature Spec

## 触发条件
- 用户要求 \`/rig:feature-spec\`、反扫某个业务域、沉淀现状功能设计、刷新 as-built 文档。
- 代码已稳定，需要代码现状反扫，把当前实现沉淀成长期 as-built 文档。

## 边界
- 这是后向现状文档，不规划新需求，不替代 openspec。
- 不编造业务规则；不确定点必须标成问题。

## 执行动作
1. 从当前代码、文档、测试和用户确认过的行为中提取事实。
2. 创建或更新 \`docs/feature-specs/<domain>.md\`。
3. 架构决策只链接 ADR，不复制 why。"
  write_skill "$base/rig-learn" "rig-learn" "触发：用户要记录经验、踩坑、反复问题或固化规则；边界：不把一次性猜测直接升级硬规则；动作：lesson→pattern→确认后晋升。" "# Rig Learn

## 触发条件
- 用户要求 \`/rig:learn\`、记录经验、沉淀坑、固化规则、避免下次再犯。

## 边界
- 不把一次性猜测直接升级成 convention、lint 或 ADR。
- 任何硬规则晋升前都要先给 diff/方案并等用户确认。

## 执行动作
1. 把确认过的坑写成 lesson。
2. 同源多次出现时归纳成 pattern。
3. 经用户确认后，晋升到 \`docs/conventions/\`、\`scripts/lint-one.sh\` 或 ADR。"
}

cleanup_legacy_action_skills(){
  base="$1"
  for s in rig-init rig-doctor rig-review rig-new-change rig-archive-change rig-adr rig-feature-spec rig-learn; do
    dir="$base/$s"
    if [ -f "$dir/SKILL.md" ] && grep -q "^name: $s$" "$dir/SKILL.md" 2>/dev/null; then
      rm -rf "$dir"
    fi
  done
}

write_marketplace(){
  target="$1"
  mkdir -p "$(dirname "$target")"
  base="$target.base.$$"
  tmp="$target.tmp.$$"
  if [ -f "$target" ]; then
    if jq empty "$target" >/dev/null 2>&1; then
      cp "$target" "$base"
    else
      echo "✗ $target 不是合法 JSON；为避免覆盖你的既有插件市场配置，已停止写入。" >&2
      echo "  请先修复该文件后重跑。" >&2
      return 1
    fi
  else
    printf '%s\n' '{"name":"local","interface":{"displayName":"local plugins"},"plugins":[]}' > "$base"
  fi

  if jq '
    .name = (.name // "local") |
    .interface = (.interface // {"displayName":"local plugins"}) |
    .plugins = (.plugins // []) |
    if ([.plugins[]?.name] | index("rig")) then
      .plugins = (.plugins | map(if .name=="rig" then
        .source = {source:"local", path:"./plugins/rig"} |
        .policy = {installation:"AVAILABLE", authentication:"ON_USE"} |
        .category = "Coding"
      else . end))
    else
      .plugins += [{
        name:"rig",
        source:{source:"local", path:"./plugins/rig"},
        policy:{installation:"AVAILABLE", authentication:"ON_USE"},
        category:"Coding"
      }]
    end
  ' "$base" > "$tmp"; then
    mv "$tmp" "$target"
    rm -f "$base"
  else
    rm -f "$base" "$tmp"
    return 1
  fi
}

plugin_root="$HOME/.agents/plugins/rig"

link_dir "$HOME/.codex/skills/rig"
link_dir "$HOME/.agents/skills/rig"
install_action_skills "$HOME/.codex/skills"
cleanup_legacy_action_skills "$HOME/.agents/skills"

mkdir -p "$plugin_root/.codex-plugin" "$plugin_root/commands" "$plugin_root/skills" "$plugin_root/agents"
cp "$here/assets/codex-plugin/.codex-plugin/plugin.json" "$plugin_root/.codex-plugin/plugin.json"
cp "$here/assets/codex-plugin/commands/"*.md "$plugin_root/commands/"
cp "$here/assets/codex-plugin/agents/openai.yaml" "$plugin_root/agents/openai.yaml"
ln -sfn "$here" "$plugin_root/skills/rig"

write_marketplace "$HOME/.agents/plugins/marketplace.json"

echo "  ✓ Codex skill 已注册: ~/.codex/skills/rig -> $here"
echo "  ✓ Codex skill 已注册: ~/.agents/skills/rig -> $here"
echo "  ✓ Codex action skills 已安装: rig-init / rig-doctor / rig-review / ..."
echo "  ✓ 已清理 ~/.agents/skills/rig-* 旧副本，避免 Codex App 重复显示"
echo "  ✓ Codex /rig:init command surface 已安装: ~/.agents/plugins/rig"
echo "  ✓ Codex plugin marketplace 已登记: ~/.agents/plugins/marketplace.json"
