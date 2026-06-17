---
description: 把当前项目接入 rig（检测→装缺的全局机制→铺项目骨架→归并既有规范/推导地图/写 verify-local）。全局命令，在任意项目里跑。
---

把**当前项目**接入 rig。这是入口——它是全局命令，在任何项目里敲 `/rig:init` 都能用。

按 **rig** skill（`~/.claude/skills/rig` 的 `SKILL.md`，manifest 驱动）对当前项目执行：

1. **机械部分**（直接跑 CLI）：`rig init`（或 `~/.claude/skills/rig/bin/rig init`）——机器画像、装/补缺的全局机制（hooks/agents/settings）、铺项目骨架（AGENTS/CLAUDE/docs/conventions/scripts/项目级 `/rig:*` 命令，幂等不覆盖）。
2. **判断部分**（你来做，禁止凭模板伪造）：
   - 把项目既有规范（`.cursorrules`、`.github/copilot-instructions.md`、README 规范段、散落 `docs/` 规范…）**归并**进 `docs/conventions/` 并打 A/B/C 三桶，**原文件保留**（需续用可收敛为指针）。
   - **若存在 `memory-bank/`（用户正退役的个人模式，唯一例外：迁移后整目录删除，不保留）——这是用户已授权的标准动作；memory-bank 受 git 跟踪，故删除会进 diff、commit 前可审、可 `git checkout` 找回**：
     - `conventions/*` → `docs/conventions/`（权威全文，以代码核对纠错、打 A/B/C 桶）；
     - `project/feature-specs/*` → `docs/feature-specs/`（rig 后向真相，1:1 迁、以代码核对）；
     - `project/{architecture,modules,tech-stack,runtime}.md` → **只把关键事实折进 `AGENTS.md` §1 地图**（以代码为准），详细手写文档**不保留**（日后用 `/rig:feature-spec` 从代码重生）；
     - `tasks/**`、`README.md` 及其余残余 → **丢弃**（过程记录，git 历史仍可捞）；
     - 迁完 `rm -rf memory-bank/`，并在汇报里写明「memory-bank 已迁移并删除，删除见 diff、可 git 找回」。
   - 从 `pom.xml`/`package.json`/`Makefile` **推导**回填 `AGENTS.md` 项目地图（build/test/run）；同时**以代码为准核对**既有规范/文档里的过时事实（如"暂无测试"、旧接口路径），过时的就更正，别照抄。别再让 `AGENTS.md` 指向已删除的 `memory-bank/` 路径。
   - 起草 `scripts/verify-local.sh` 的**真实命令**（compile→test→smoke），按项目实际填，**别留 `SKELETON=1` 占位**：
     - 先**探测测试基础设施依赖**：看测试配置（如 `src/test/resources/application.yml`）里 datasource/redis/mq 指向哪——本地？远程共享？
     - **分类用例**：hermetic（纯单测/Mockito，无需外部基础设施）vs 需全上下文（`@SpringBootTest`/需 DB·Redis）；
     - 设计成**「诚实但不被基础设施惩罚」**：compile + hermetic 子集**永远强制**；需基础设施的用例**探活可达才纳入**，不可达则跳过提示（不算失败，避免基础设施没起就卡收工）；真实代价的冒烟（外呼/计费）默认 `opt-in`（env 开关）；
     - 写完**实跑一遍** compile + 该跑的测试子集，证明真能过——别只写不验。
   - **openspec（外部 CLI，缺则跟其它外部件一样进批量征询、由我定）**：**绝不靠 grep "预研"/"demo" 之类字样替我判 N/A、替我跳过——要不要 openspec 是我的决定，不是你的**。openspec 未装 → **纳入下面的批量征询问我装不装**（一句话说明它给"需求驱动的 change/spec 流程"用、不需要可跳过）。我要 → 装（`npm i -g openspec`）后 `npx openspec init` 建 `openspec/`（**root 级是 openspec 固有约定，不是放 `docs/`**）+ 拷 change 模板；我不要 → 跳过、**别预先铺空 `openspec/`**。已装则直接 init + 拷模板。
   - **缺的外部件：先问后装（不静默装、也别甩给我手动）**：openspec / superpowers / feature-spec 等缺失时，汇总成**一次批量征询**——逐个列「缺什么 + 怎么装 + 影响哪个命令」问我装哪些。我同意装的，按机制分两类、别搞混：
     - **命令行可代装的（CLI：openspec=`npm i -g openspec` 等）→ 你直接替我装上并接好**（openspec 装完随即 `npx openspec init` + 拷 change 模板）。
     - **走 Claude Code marketplace/plugin 的 skill（superpowers 等）→ 你装不了，别假装装好**：给我确切 marketplace 名 + 安装步骤，由**我在 UI 装**；装完我会告诉你再继续。（feature-spec 这类已是本地 skill 目录的，能拷就拷、拷不到也照此给步骤。）
     - 我拒绝装的：标缺 + 给命令/步骤 + 说影响、对应产物不铺。联网/装插件务必经我这次确认。
3. **收尾**：跑 `/rig:doctor` 自检，把"建了什么 / 合并了什么 / 待我确认什么 / 缺的外部件"列给我。

铁律：幂等、合并不覆盖、整理既有不丢弃、判断内容以代码 / 我为准不伪造、verify-local 写完必须实跑验证过才报完成。完成后说明哪些需开新会话才生效（hook 变更）。
