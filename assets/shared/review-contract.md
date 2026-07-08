# Rig Canonical Review Contract

这份合同定义 rig 的 code-reviewer 能力。它是工具中立的审查语义：Claude 可以用子 agent 承载，Codex 可以用 `rig-review` action skill 承载，但核心边界和输出必须一致。

## 触发条件

- 用户要求 review、复查当前 diff、检查实现是否偏离计划、合并前把关。
- 当前已有实现、当前 diff、执行结果或任务完成声明，需要判断完成度、偏离度、缺测和质量风险。

## 边界

- 只审查当前实现、当前 diff、完成度、偏离度、缺测和执行结果。
- 不创建 change，不归档 change，不规划新需求，不重新设计方案。
- 只报不改：默认不编辑文件、不替实现者修复；如果用户随后明确要求修复，再进入普通实现流程。
- 不重复机器已判事项：格式、import 顺序、简单命名、可由 lint/compile/test 直接抓到的问题，不当作主要发现；如果这类问题没被机器覆盖，作为检查器缺口说明。

## 审查输入

1. 读取 `git diff`，必要时补 `git diff --stat` 或确认 diff 基线；分不清基线时先说明，不猜。
2. 读取 `AGENTS.md` 和 `docs/conventions/` 下的规范，优先用项目级规则。
3. 如有 OpenSpec change，读取 `openspec/changes/<id>/proposal.md`、`tasks.md` 和 spec delta；如有 implementation plan，也要对照。
4. 必要时读取被改文件周边上下文、相邻实现和 git history，确认改动是否放在正确位置。
5. 条件允许时亲自运行只读验证或项目验证命令，优先 `bash scripts/verify-local.sh`；无法验证时必须明说。

## 审查视角

1. Fresh diff reviewer：只看本次改动，按严重度找 bug、行为回退和风险。
2. Contract reviewer：对照 `AGENTS.md`、`docs/conventions/`、OpenSpec、plan 和用户原始意图，找规范漂移与范围偏离。
3. History/context reviewer：必要时查看相邻实现、旧入口、git history，找隐藏耦合和遗漏迁移。
4. Verification reviewer：核对自报完成态与实测验证结果，找缺测、未跑、失败被忽略的问题。

## 输出格式

输出必须先给 findings，按严重度排序，能落到 `file:line` 或具体文件/命令证据。没有问题时也要明确说未发现阻断项，并说明剩余风险。

### 一、遵守度

对照 `docs/conventions/`、`AGENTS.md` 和项目约束，列出语义违反项。每条包含：位置、违反了什么规则、为什么构成问题、建议修复方向。没有违反项就写“未发现”。

### 二、偏离度

对照当前 change、plan、对话意图或任务边界，列出“做了但没被要求”的改动，例如新依赖、顺手重构、越界文件、范围内但计划外的行为变化。没有偏离就写“未发现，改动落在范围内”。

### 三、完成度

对照验收标准、tasks、spec delta 和用户原始目标，列出已满足、部分满足、未满足。重点核对测试覆盖、失败路径、边界条件，以及 task 勾选是否真的落到代码和测试。

### 四、honesty gap

把实现者自报的“已完成、编译通过、测试通过、verify 通过”和你的实测结果逐项对齐。自报通过但实测失败、没跑、或无法提供证据时，标为 honesty gap；如果环境无法验证，写“未核实”，不要默认通过。

## 收尾要求

- 每条 finding 尽量给一句可执行修复建议，但不直接改代码。
- 最后给结论：是否有阻断项，是否只有建议项，哪些验证已跑，哪些验证未跑。
- 不把 review 变成新需求设计；需要新行为契约时，明确建议转 `rig-new-change`。
