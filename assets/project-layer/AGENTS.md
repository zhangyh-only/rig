# <项目名> — AI 协作说明（canonical）

> 本文件是跨工具的单一来源（Codex / 多数工具原生读 AGENTS.md）。
> Claude Code 侧 `CLAUDE.md` 仅 `@AGENTS.md` 引入本文件，避免双份维护。
> 详细规范全文在 `docs/conventions/`，由全局 hook 在编码时自动注入，这里只放"地图 + 基线 + 指针"。

## 1. 项目地图（让 AI 快速定位）
- 一句话定位：<这是什么系统>
- 技术栈：<语言/框架/中间件>
- 关键模块：<模块 → 职责，3-6 行>（模块多时可另见 `docs/architecture.md`，没有就别引这句）
- 构建：`<build 命令>`
- 测试：`<test 命令>`
- 本地启动：`<run 命令>`（重云端依赖项目见 L0 Harness 的 `scripts/verify-local.sh`）

## 2. 行为基线
1. 先想后写：歧义先澄清，不擅自假设。
2. 简洁优先、不过度设计。
3. 外科手术式改动，风格随周围代码。
4. 目标驱动：成功标准可验证，能本地验证就验证到通过。

> 源自 Karpathy 四原则，与全局 `~/.claude/conventions.md` 同源；冲突以本项目为准。

## 3. 规范遵守（重要）
- 本项目的编码/结构/命名等**完整规范在 `docs/conventions/`**，会在你开始编码时被注入上下文，**必须遵守**。
- 优先级：**本项目规范 > 全局个人偏好**，冲突以本项目为准。
- 机器可判定的规则由检查器在你改完文件后自动校验（不通过会被拦回），并在 CI 必过；机器判不了的语义规则在收尾 review 兜底。
- **多工具同步约束**：凡调整工作流入口、命令描述、hook、doctor、manifest、项目模板或安装文档，必须同步覆盖已声明支持的 AI 工具层；至少核对 Claude Code（`.claude/commands`、`~/.claude` hooks/settings/agents/skills）和 Codex（action skills、plugin command surface、hooks.json）。暂不支持的工具必须标明“不适用 / 待补”，不要只改单一工具入口。
- **交付说明约束**：凡完成有一定规模的 rig 调整，最终回复必须说明这次改动在**新项目**中怎么使用、在**已接入 rig** 的项目中怎么更新/检查；若需要重新运行 `/rig:init`、`rig doctor`、重启 AI 会话或手动合并 `AGENTS.md`，要明确写出来。

## 4. 本地自验证（L0 Harness）
- 验证命令：`bash scripts/verify-local.sh`（编译 → 单测 → 本地启动 → 冒烟）。**此脚本按项目填写**（重云端依赖项目尤其需要：DIP + Profile 隔离让本地能跑）。
- 改完代码自行跑一次验证，不要只说"已完成"。
- 注意：若本项目尚无 `scripts/verify-local.sh`，收工时的"完成度"硬闸（Stop hook）会空转（静默放行）——SessionStart 会在会话开场响亮提醒补这个洞，请尽早补上。

## 5. 变更流程：Workflow Router（先判任务，再选工作流）
<!-- rig:workflow-router:start -->
先按任务复杂度和产物选择入口，别把小改过度流程化，也别把契约变化直接写代码。

| 路由 | 触发条件 | 边界 | 动作 |
|---|---|---|---|
| **Query** | 纯查询、解释、排查，不改代码。 | 排查确认是真 bug 后，再转 Fast Path 或 OpenSpec。 | 直接查证并回答；必要时给证据路径。 |
| **Fast Path（小需求快路径）** | 小 bug、小样式、小文案、小字段，影响局部且不改变行为契约。 | 不强制 OpenSpec / superpowers；如果碰接口、数据流或验收口径，升级。 | 直接最小修改 → 聚焦测试 / lint → `verify-local`（能跑则跑）。 |
| **OpenSpec Change** | 新需求、行为契约变化、接口/数据流程变化、验收标准变化。 | 不用于 review 当前实现；不用于只问“做完了吗/偏了吗”。 | 用 `/rig:new-change` 建 proposal / spec-delta / `openspec/tasks.md`。 |
| **OpenSpec + Implementation Plan** | 前后端联动、数据结构变化、多模块协作、步骤多且需要施工顺序。 | OpenSpec 只管“做什么/验收什么”，不替代施工计划。 | 先 OpenSpec，再写 superpowers plan / implementation plan，按计划 TDD 执行。 |
| **ADR** | Graph 编排边界、跨域技术选型、难回退架构选择。 | 不记录普通实现说明；不要把一次性代码细节写成 ADR。 | 用 `/rig:adr` 记录长期架构决策原因，并让其它文档只链接它。 |
| **Review** | 复核当前实现、当前 diff、完成度、偏离度、缺测或执行结果。 | review 不创建 change，不归档 change。 | 用 `/rig:review` 对照 AGENTS / conventions / OpenSpec / plan / 验证结果审查。 |

职责固定口径：
- OpenSpec：需求合同、行为契约、验收清单。
- `openspec/tasks.md`：交付/验收视角任务。
- superpowers plan / implementation plan：复杂需求的施工图。
- ADR：长期架构决策原因。
- feature-spec：代码现状反扫。

正反例：
- 改按钮文案：Fast Path，不起 OpenSpec。
- 修局部 bug：Fast Path；若发现会改接口契约，再升级 OpenSpec。
- review 当前实现偏离：`/rig:review`，不要 `/rig:new-change`。
- 新增场景配置工作台：OpenSpec。
- 前后端联动 + 数据结构 + 多模块：OpenSpec + implementation plan。
- Graph 编排边界 / 难回退架构选择：ADR。
<!-- rig:workflow-router:end -->

**硬规则「改完必验证」**：凡动了真实业务代码，`verify-local`（完成度硬闸）必过才算收工；纯 Query 除外。

**可用命令（入口）**：`/rig:new-change` 起变更 · `/rig:archive-change` 归档（合并 spec-delta 进 `openspec/specs/`）· `/rig:adr` 记跨域决策 · `/rig:feature-spec` 后向沉淀域设计 · `/rig:review` 复核当前实现 · `/rig:learn` 沉淀踩坑、晋升规则。

## 6. 收尾与沉淀
- **收尾评估**：改动完成、lint/CI 都过后，调 **`code-reviewer`** 子 agent 做一次 fresh-context 对抗式语义审查，输出 **遵守度 / 偏离度 / 完成度** 三维清单（只报不改）。机器判得了的已被 lint/verify 拦，这一步专兜机器判不了的语义。
- **前向真相**：openspec 答"该做什么/这次改什么"；change 做完 `/rig:archive-change` 把 spec-delta 合并进 `openspec/specs/`。
- **后向真相**：feature-spec 答"代码里现在怎么搭的"；代码稳定后 `/rig:feature-spec` 刷新 `docs/feature-specs/<domain>.md`。
- **「为什么」唯一权威**：跨域长期决策毕业到 `docs/adr/`（用 `/rig:adr`）；feature-spec 等其它文档只链接 ADR、不复制。
- **越用越聪明（经验进化）**：踩了坑、或发现 AI 反复犯的错 → `/rig:learn` 沉淀成 lesson（落 `docs/lessons.md`，不注入）；复现多了归纳成 pattern，验证后**经你确认**晋升为硬约束——机器可判的进 `scripts/lint-one.sh`（A 桶，改完即拦）、需判断的进 `docs/conventions/`（B 桶，编码时注入）。坑只踩一次。
