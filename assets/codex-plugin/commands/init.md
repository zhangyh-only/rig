# /rig:init

为当前 Codex 会话初始化当前项目的 rig 接入。

## 触发条件

- 用户要求 `/rig:init`、`rig init`、初始化 rig、onboard 当前项目、把当前项目接入工作流。
- 当前项目第一次在 Codex 中使用 rig。
- 同一个仓库已在 Claude Code 初始化过，但现在切到 Codex 使用。

## 边界

- 这是 **Codex 侧项目级初始化**，不是当前 diff 的 review。
- 项目专属内容不能凭模板伪造；`AGENTS.md` 地图、`scripts/verify-local.sh`、conventions 都要来自项目文件或用户确认。
- 任何联网安装、外部 plugin/skill 安装前都要先询问用户。

## 必须动作

1. 运行 `rig init --codex "$PWD"`；如果 `rig` 不在 `PATH` 中，确认文件存在后尝试 `~/.codex/skills/rig/bin/rig init --codex "$PWD"` 或 `~/.agents/skills/rig/bin/rig init --codex "$PWD"`。
2. 机械安装完成后，读取 `rig` skill 说明并完成需要判断的工作：
   - 把既有规则文件整理进 `docs/conventions/`，不删除原文件；
   - 从项目文件推导 build/test/run 命令并更新 `AGENTS.md`；
   - 把占位的 `scripts/verify-local.sh` 替换成真实项目命令；
   - 检查 openspec、superpowers、feature-spec 等支撑组件是否缺失。
3. 运行 `rig doctor "$PWD"`。
4. 报告改了什么、还缺什么、哪些需要用户决定，以及是否需要打开新的 Codex 会话。

如果 Codex 不能直接安装外部 marketplace skills，不要假装已经安装；应请用户安装后再继续。
