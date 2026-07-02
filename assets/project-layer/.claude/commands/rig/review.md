---
description: 触发：复核当前实现 / 完成度 / 偏离度 / 当前 diff；边界：不创建 change、不归档、不规划新需求；动作：对照 AGENTS/conventions/OpenSpec/plan/验证要求审查。
argument-hint: [可选：本次变更/计划的范围说明]
---

对当前改动做**收尾语义审查**。前提：lint / CI 已过（机器判得了的应已被拦下），这一步专兜机器判不了的语义。

## 路由边界
- 用于复核当前实现、当前 diff、完成度、偏离度、缺测和执行结果。
- review 不创建 change，不归档 change；如果用户要新需求、行为契约变化或接口数据流程变化，改走 `/rig:new-change`。

调用 **code-reviewer** 子 agent，对 git diff（相对本次变更基线）做 fresh-context 对抗式审查，输出三维清单（**只报不改**，给可执行修复建议）：

- **遵守度**：对照 `docs/conventions/` 全文与 `AGENTS.md`，列违反项（file:line）。
- **偏离度**：对照当前 openspec change 范围 / 计划（`$ARGUMENTS` 可补充范围说明），列"做了但没被要求"的改动——新依赖、顺手重构、越界文件。
- **完成度**：对照验收标准 / tasks.md，列已达成与未达成。

审查完，把高优先问题汇总给我，等我决定怎么改；不要直接改代码。
