---
description: 把当前项目接入 rig（检测→装缺的全局机制→铺项目骨架→归并既有规范/推导地图/写 verify-local）。全局命令，在任意项目里跑。
---

把**当前项目**接入 rig。这是入口——它是全局命令，在任何项目里敲 `/rig:init` 都能用。

按 **rig** skill（`~/.claude/skills/rig` 的 `SKILL.md`，manifest 驱动）对当前项目执行：

1. **机械部分**（直接跑 CLI）：`rig init`（或 `~/.claude/skills/rig/bin/rig init`）——机器画像、装/补缺的全局机制（hooks/agents/settings）、铺项目骨架（AGENTS/CLAUDE/docs/conventions/scripts/项目级 `/rig:*` 命令，幂等不覆盖）。
2. **判断部分**（你来做，禁止凭模板伪造）：
   - 把项目既有规范（`memory-bank/`、`.cursorrules`、README 规范段…）**归并**进 `docs/conventions/` 并打 A/B/C 三桶；
   - 从 `pom.xml`/`package.json`/`Makefile` **推导**回填 `AGENTS.md` 项目地图（build/test/run）；
   - 起草 `scripts/verify-local.sh` 的真实命令（compile→test→smoke），按项目实际填。
3. **收尾**：跑 `/rig:doctor` 自检，把"建了什么 / 合并了什么 / 待我确认什么"列给我。

铁律：幂等、合并不覆盖、整理既有不丢弃、判断内容以代码 / 我为准不伪造。完成后说明哪些需开新会话才生效（hook 变更）。
