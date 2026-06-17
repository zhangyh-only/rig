---
description: 把当前项目接入 rig（检测→装缺的全局机制→铺项目骨架→归并既有规范/推导地图/写 verify-local）。全局命令，在任意项目里跑。
---

把**当前项目**接入 rig。这是入口——它是全局命令，在任何项目里敲 `/rig:init` 都能用。

按 **rig** skill（`~/.claude/skills/rig` 的 `SKILL.md`，manifest 驱动）对当前项目执行：

1. **机械部分**（直接跑 CLI）：`rig init`（或 `~/.claude/skills/rig/bin/rig init`）——机器画像、装/补缺的全局机制（hooks/agents/settings）、铺项目骨架（AGENTS/CLAUDE/docs/conventions/scripts/项目级 `/rig:*` 命令，幂等不覆盖）。
2. **判断部分**（你来做，禁止凭模板伪造）：
   - 把项目既有规范（`memory-bank/`、`.cursorrules`、README 规范段…）**归并**进 `docs/conventions/` 并打 A/B/C 三桶；
   - 从 `pom.xml`/`package.json`/`Makefile` **推导**回填 `AGENTS.md` 项目地图（build/test/run）；同时**以代码为准核对**既有规范/文档里的过时事实（如"暂无测试"、旧接口路径），过时的就更正，别照抄。
   - 起草 `scripts/verify-local.sh` 的**真实命令**（compile→test→smoke），按项目实际填，**别留 `SKELETON=1` 占位**：
     - 先**探测测试基础设施依赖**：看测试配置（如 `src/test/resources/application.yml`）里 datasource/redis/mq 指向哪——本地？远程共享？
     - **分类用例**：hermetic（纯单测/Mockito，无需外部基础设施）vs 需全上下文（`@SpringBootTest`/需 DB·Redis）；
     - 设计成**「诚实但不被基础设施惩罚」**：compile + hermetic 子集**永远强制**；需基础设施的用例**探活可达才纳入**，不可达则跳过提示（不算失败，避免基础设施没起就卡收工）；真实代价的冒烟（外呼/计费）默认 `opt-in`（env 开关）；
     - 写完**实跑一遍** compile + 该跑的测试子集，证明真能过——别只写不验。
3. **收尾**：跑 `/rig:doctor` 自检，把"建了什么 / 合并了什么 / 待我确认什么"列给我。

铁律：幂等、合并不覆盖、整理既有不丢弃、判断内容以代码 / 我为准不伪造、verify-local 写完必须实跑验证过才报完成。完成后说明哪些需开新会话才生效（hook 变更）。
