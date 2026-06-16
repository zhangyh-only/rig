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

## 4. 本地自验证（L0 Harness）
- 验证命令：`bash scripts/verify-local.sh`（编译 → 单测 → 本地启动 → 冒烟）。**此脚本按项目填写**（重云端依赖项目尤其需要：DIP + Profile 隔离让本地能跑）。
- 改完代码自行跑一次验证，不要只说"已完成"。
- 注意：若本项目尚无 `scripts/verify-local.sh`，收工时的"完成度"硬闸（Stop hook）会空转（静默放行）——SessionStart 会在会话开场响亮提醒补这个洞，请尽早补上。

## 5. 变更流程：先判 意图×风险，再走对应路径
先给任务分类——**意图**（纯查询 / 修 bug / 加特性）×**风险**（可逆性、影响面、是否碰线上）——决定走多重的流程。别一刀切，也别小题大做：

| 意图 × 风险 | 走的路径（节点集） |
|---|---|
| **QUERY**（纯查询 / 排查，不改业务代码） | **0 流程**——直接查、答；识别对了就不要启动变更流程。排查中若确认是真 bug，再转入下面对应行。 |
| **BUG · 低**（局部修复、可逆、不碰线上契约） | 快路径：注入规范 → 编码 → lint → `verify-local`。照常 git，不强制设计前段。 |
| **特性 · 中**（跨文件特性、改接口/数据但影响可控） | 快路径 **＋ 设计前段**：`superpowers` brainstorm（澄清边界、不擅自假设）→ write-plan（验收写成可执行，套 `docs/plans/_template.md`）→ **你审批** → execute-plan（TDD）。需求驱动则 `/new-change` 起 openspec change（intent + spec-delta + tasks），进行中的 change 会被 hook 自动注入。 |
| **特性 · 高**（框架升级、跨模块、难回退、碰线上） | 中档全部 **＋ `/adr` 记跨域决策 ＋ 收尾必跑 `code-reviewer` 偏离度复核**。越界代价高，动手前先把边界 / 回滚方案 / 失败模式想清楚（高风险才值这个前置成本）。 |

**硬规则「改完必验证」**：凡动了真实业务代码，`verify-local`（完成度硬闸）必过才算收工；纯 QUERY 除外。

**可用命令（入口）**：`/new-change` 起变更 · `/archive-change` 归档（合并 spec-delta 进 `openspec/specs/`）· `/adr` 记跨域决策 · `/feature-spec` 后向沉淀域设计 · `/learn` 沉淀踩坑、晋升规则。

## 6. 收尾与沉淀
- **收尾评估**：改动完成、lint/CI 都过后，调 **`code-reviewer`** 子 agent 做一次 fresh-context 对抗式语义审查，输出 **遵守度 / 偏离度 / 完成度** 三维清单（只报不改）。机器判得了的已被 lint/verify 拦，这一步专兜机器判不了的语义。
- **前向真相**：openspec 答"该做什么/这次改什么"；change 做完 `/archive-change` 把 spec-delta 合并进 `openspec/specs/`。
- **后向真相**：feature-spec 答"代码里现在怎么搭的"；代码稳定后 `/feature-spec` 刷新 `docs/feature-specs/<domain>.md`。
- **「为什么」唯一权威**：跨域长期决策毕业到 `docs/adr/`（用 `/adr`）；feature-spec 等其它文档只链接 ADR、不复制。
- **越用越聪明（经验进化）**：踩了坑、或发现 AI 反复犯的错 → `/learn` 沉淀成 lesson（落 `docs/lessons.md`，不注入）；复现多了归纳成 pattern，验证后**经你确认**晋升为硬约束——机器可判的进 `scripts/lint-one.sh`（A 桶，改完即拦）、需判断的进 `docs/conventions/`（B 桶，编码时注入）。坑只踩一次。
