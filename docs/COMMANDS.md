# rig 命令与 AI 调用契约

本文是 rig 项目内的命令语义索引。它不是给人背命令的速查表，而是给 AI 工具做入口选择时使用的调用契约：什么时候触发、什么时候不要触发、触发后必须做什么。

## 入口层级

| 层级 | 位置 | 作用 |
|---|---|---|
| 主 skill | `SKILL.md`、`~/.codex/skills/rig`、`~/.agents/skills/rig`、`~/.claude/skills/rig` | 安装、迁移、更新整套 rig 工作流。 |
| 全局项目命令 | `assets/dotfiles-layer/commands/rig/init.md`、`doctor.md` | Claude Code 的全局 `/rig:init`、`/rig:doctor`。 |
| 项目命令模板 | `assets/project-layer/.claude/commands/rig/*.md` | `/rig:init` 后落到项目里的变更、归档、ADR、review、learn 等命令。 |
| Codex action skills | `scripts/install-codex-surface.sh` 生成到 `~/.codex/skills/rig-*` | Codex 候选列表里的 `Rig Init`、`Rig Review` 等操作入口。 |
| Codex plugin command surface | `assets/codex-plugin/commands/*.md` | Codex 本地 plugin 暴露的 `/rig:init`、`/rig:doctor`。 |

## 总体路由原则

- 查询、解释、排查但不改代码：不要启动 change；直接普通分析，必要时用 `Rig Review` 做复核。
- 当前项目第一次接入某个 AI 工具：用 `Rig Init`。
- 怀疑 rig 接线或项目验证坏了：用 `Rig Doctor`。
- 当前已有改动，需要审查质量、完成度、是否偏离：用 `Rig Review`。
- 明确要开始一个新需求、新 spec、新 change：用 `Rig New Change`。
- 已完成 change，要合并 spec-delta 并收口：用 `Rig Archive Change`。
- 有跨域架构取舍需要记录为什么：用 `Rig ADR`。
- 代码已稳定，要反扫现状设计：用 `Rig Feature Spec`。
- 踩坑或经验要沉淀，避免下次重复犯：用 `Rig Learn`。

## 命令契约

| 入口 | 触发条件 | 不要触发 / 边界 | 必须动作 |
|---|---|---|---|
| `Rig` | 用户要求安装、迁移、更新 rig；扫描缺失；新机器接入；给项目 onboard。 | 不替代日常代码 review；不要把项目专属内容凭模板伪造出来。 | 按 `reference/manifest.md` 探测、补缺、合并不覆盖，最后验证并报告。 |
| `Rig Init` / `/rig:init` | 当前项目要在当前 AI 工具中接入 rig；用户说初始化、onboard、接入工作流。 | 同仓库在 Claude 跑过，不代表 Codex 已完成；换 AI 工具仍要跑一次。不是代码质量审查入口。 | 运行工具侧初始化，如 Codex 中 `rig init --codex "$PWD"`；补项目骨架；归并既有规范；推导项目命令；最后跑 `rig doctor "$PWD"`。 |
| `Rig Doctor` / `/rig:doctor` | 用户要求检查 rig 是否健康；hook、skill、plugin、verify-local、jq、会话生效有疑问。 | 先诊断，不要一上来重装或改文件；联网安装、破坏性修改前必须确认。 | 运行 `rig doctor "$PWD"`；报告通过/失败；失败项先定位根因，再给最小修复动作。 |
| `Rig Review` / `/rig:review` | 当前已有 diff、执行情况、未完成事项，需要按 rig 规范复核。 | 不创建新 change；不归档；不把普通状态分析误路由到 `new-change`。 | 对照 `AGENTS.md`、`docs/conventions/`、活跃 spec 和验证要求审查；优先报 bug、偏离、缺测、完成度缺口。 |
| `Rig New Change` / `/rig:new-change` | 用户明确要启动新需求、新 change、新 spec，或说“为这个需求起一个 change”。 | 不用于“分析当前状态”“看看执行情况”“review 当前改动”。如果没有明确创建意图，立即分流。 | 先确认 openspec 是否启用；有边界地检查目录和 CLI；再创建 proposal/tasks/spec-delta 骨架。 |
| `Rig Archive Change` / `/rig:archive-change` | 用户明确要归档、关闭、完成某个 openspec change。 | tasks 未完成、验证未过、change id 不明确时不归档。 | 定位 change；检查 tasks 和 validate；执行 archive；提醒 ADR/feature-spec 后续沉淀。 |
| `Rig ADR` / `/rig:adr` | 有架构决策、技术选型、跨域边界、难回退取舍需要记录。 | 不用于普通实现说明；不要替用户编造决策理由。 | 基于模板创建 `docs/adr/NNNN-*.md`，记录 context/decision/consequences/alternatives，并更新索引。 |
| `Rig Feature Spec` / `/rig:feature-spec` | 用户要反扫某个稳定业务域，把现状设计沉淀成长期文档。 | 不规划新需求；不写未来方案；不编造业务规则。 | 以代码、测试、文档和用户确认事实为准，生成或更新 as-built feature spec，不确定点标问题。 |
| `Rig Learn` / `/rig:learn` | 用户要沉淀一次坑、经验、反复问题，或把规则固化。 | 不把一次性猜测直接升级成硬规则；晋升 convention/lint/ADR 前必须确认。 | 写 lesson；同源多次时归纳 pattern；经确认后晋升到 `docs/conventions/`、`scripts/lint-one.sh` 或 ADR。 |

## 描述文案的写法

AI 工具里的 `description` 不应只写“这个命令是什么”，而要写成可路由的短契约：

```text
触发：用户表达了什么意图；边界：哪些相似请求不要选它；动作：选中后第一步做什么。
```

标题和 `name` 可以保持英文稳定，如 `rig-new-change`；正文和描述可以用中文，只要能明确表达触发、边界和动作。对这个项目而言，中文契约比泛泛英文说明更适合当前使用者和常见 prompt，但必须保留 slash command、文件名、CLI 命令等原始 token，方便工具和模型匹配。
