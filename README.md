# rig

给 AI coding 供给**纪律**的分层 harness —— 模型负责聪明，rig 负责让它守规矩、可验证、不偏离。

> 不是更聪明的 prompt，是结构性约束：规范在编码时**注入**（push，不靠触发）、违规被**确定性的闸**当场拦（lint / 红线 / verify）、状态外置、意图×风险决定流程力度。

## 完整顺序（从零到用起来）

终端**只在 A 出现一次**；B、C 全在对应 AI 工具的会话里敲 `/rig:*`。

### A · 装一次（每台机器）
```bash
git clone https://github.com/zhangyh-only/rig.git
bash rig/scripts/bootstrap.sh        # 装 ~/.rig 共享 hooks，并自动接 Claude/Codex 的 hook、skill、/rig:* 入口；幂等、合并不覆盖
bash rig/install.sh                  # 可选：把 rig 加进 PATH（模型 B 基本用不到）
```
- 跑完**开一个新 AI 工具会话**（hooks、skills 与 `/rig:*` 命令通常在新会话才生效）；Codex CLI 如提示 hook 待信任，用 `/hooks` review + trust。Codex Desktop App 当前普通会话没有 `/hooks` 入口，按客户端实际提示处理。
- 克隆目录别移走（skill 软链指向它）。
- 不想碰终端？在任意会话里说「跑 `rig/scripts/bootstrap.sh` 把 rig 接到本机 AI coding 工具」，让 AI 用 Bash 替你跑——效果一样。

### B · 接入一个项目（每个项目一次，在 AI 里）
1. 进项目目录、在**要使用的 AI 工具里**开新会话；建议先 `git switch -c harness-onboard` 把在飞的改动隔开。
2. 敲 **`/rig:init`**（或终端跑 `rig init --codex|--claude <项目路径>`）—— 这是“当前项目 + 当前 AI 工具”的初始化入口。同一个项目从 Claude 换到 Codex，也要在 Codex 里再跑一次 `/rig:init`，因为工具侧 hook/skill/command 信任和项目骨架检查都要以该工具会话为准。
3. `/rig:init` 会自动检测缺啥补啥：本机检测已装 Claude/Codex/Cursor 并补对应工具接线；项目里铺骨架、把既有规范（`.cursorrules`/copilot-instructions…）归并进 `docs/conventions/` 三桶、从 `pom`/`package.json` 推导 `AGENTS.md` 地图、起草 `scripts/verify-local.sh`。
4. 审 diff，确认后 commit。
5. 把 `scripts/verify-local.sh` 填成项目真实命令（compile→test→smoke）。
6. 敲 **`/rig:doctor`** 自检，绿了就接入完成。

### C · 日常干活（每个任务）
背后**自动**跑（不用记）：编码前注入规范 → 改完 `lint` 拦 → 改受保护文件 `guard` 拦 → 收工 `verify` 拦。
按 Workflow Router 用命令：
- 查询、小 bug、小样式、小文案、小字段 → Query / Fast Path，普通查改 + 聚焦验证；
- 新需求、行为契约变化、接口数据流程变化 → `/rig:new-change` 起 OpenSpec；
- 前后端联动 + 数据结构 + 多模块 → OpenSpec + implementation plan；
- 当前实现偏离、完成度、当前 diff 复核 → `/rig:review`，不创建 change；
- 跨域决策 → `/rig:adr`；代码稳定 → `/rig:feature-spec` 沉淀；踩了坑 → `/rig:learn`。

## 它装了什么

**全局机制**（共享源 `~/.rig` + 各工具入口，所有项目共用，装一次）
- `~/.rig/hooks`：8 个 hook + 1 个输出辅助脚本，作为多工具共享源；`hook-emit.sh` 负责 Claude/Codex 输出协议分叉
- Claude Code：`~/.claude/hooks`、`~/.claude/settings.json`、`/rig:init`/`/rig:doctor`、`~/.claude/skills/rig`
- Codex：`~/.codex/hooks -> ~/.rig/hooks`、`~/.codex/hooks.json`、`~/.codex/skills/rig`、`~/.agents/skills/rig`、`~/.codex/skills/rig-*` 操作 skills、`~/.agents/plugins/rig`（本地插件用 `ON_USE`，不触发连接授权）；Codex CLI 用 `/hooks` 管理 hook trust，Desktop App 当前普通会话不支持该 slash command
- 2 个 Claude 子 agent：`code-reviewer`（收尾语义复核 + honesty gap）、`spec-author`

**项目内容**（`/rig:init` 时落地，每个项目一份）
- `AGENTS.md`（地图 + 基线 + 指针）· `docs/conventions/`（规范三桶 A/B/C）· `scripts/lint-one.sh`（语言适配器）· `scripts/verify-local.sh`（L0 自验证）· `/rig:*` 工作流命令 · openspec / ADR 模板

## 依赖：接线 vs 自带

rig 把下面这些**接好了线**（命令 / hook / `AGENTS.md` 流程都知道何时用哪个），但**外部件本体不随包交付**——`/rig:init`、`/rig:doctor` 会检测，缺了给你安装命令，不替你装：

| 件 | 角色 | rig 怎么用它 | 来源 |
|---|---|---|---|
| **Karpathy 四原则** | L1 行为基线 | 写进 `conventions.md` + `AGENTS.md` §2，编码时注入 | **rig 自带**（内化成内容，装 rig 即有） |
| **superpowers** | L2 设计前段（brainstorm/plan/execute） | `AGENTS.md` §5 流程里调用 · `docs/plans/_template.md` | **外部 skill**，需单独装（marketplace） |
| **openspec** | L2 前向 spec | `/rig:new-change`·`/rig:archive-change` · `inject-active-spec` hook · change 模板 · session hooks | **外部 CLI** `@fission-ai/openspec`（裸 `openspec` 是 2019 空壳；`/rig:init` 经你同意代装 + `openspec init`） |
| **feature-spec** | L3 后向域设计沉淀 | `/rig:feature-spec` 命令 + `spec-author` 子 agent | **外部 skill**，需单独装 |

> 一句话：**装 rig ≠ 自动有 superpowers / openspec / feature-spec**。它们只有 Karpathy 四原则是内化自带的；其余三个 rig 只接线 + 检测，没装时 `/rig:doctor`、`/rig:init` 会标「缺 + 安装命令」。完整取舍见 [docs/DESIGN.md](docs/DESIGN.md) §5、§15。

## 三道闸 + 兜底

1. **生成时注入全文**（主动）：编码一开始 hook 把规范 + 进行中 spec 注入，AI 带着规则一次写对。
2. **改完即时 lint**（硬）：违规 `exit 2` 当场回灌让 AI 修。
3. **CI 必过**（硬，不可绕）：lint + 架构测试进 `mvn verify` / required check。
4. **收尾 `code-reviewer`**（兜底）：只兜机器判不了的语义（遵守度 / 偏离度 / 完成度 + 自报 vs 实测的诚实度核对）。

## 验证自身

```bash
bash test/eval-demo.sh    # 把整条 hook 链固化成确定性打分(15/15、3 次一致)，可进 CI
bash test/codex-hooks.sh  # 验证 Codex hook JSON 输出、skill/command surface、rig init auto 多工具接线与幂等注册
bash test/workflow-router.sh # 验证 Workflow Router、doctor、Codex 与 Claude Code 命令层同步契约
bash test/demo-run.sh     # 带旁白地演示整条链跑一遍
```

## 文档

- 设计与机制原理：[docs/DESIGN.md](docs/DESIGN.md)
- 安装细节（AI 辅助 / 人工两条路径）：[docs/INSTALL.md](docs/INSTALL.md)
- 命令语义与 AI 调用契约：[docs/COMMANDS.md](docs/COMMANDS.md)
- 期望终态清单（安装器唯一数据源）：[reference/manifest.md](reference/manifest.md)

## 现状

机制与内容齐备、脚本过 bash 3.2 + 功能测试；全链路已在隔离环境验过（`eval-demo` 15/15、3 次一致；`rig init` → 8 hooks + 输出辅助脚本 + 2 agents + 全局/项目 `/rig:*` + skill 软链；`doctor` 关键项全过）。

`bootstrap.sh` 和 `rig init` 都会 **auto 检测本机已装工具** 并补齐适配：Claude Code 走完整 hook/命令/skill 机制；Codex 会写 `~/.codex/hooks.json`，注册 `~/.codex/skills/rig` / `~/.agents/skills/rig`，生成 `rig-init`、`rig-doctor` 等操作 skills，并安装 `ON_USE` 本地 plugin surface（`~/.agents/plugins/rig`）。`--claude` / `--codex` / `--cursor` 仅用于限定 `rig init` 本次只处理某个工具。Codex CLI 如提示 hook 待信任，用 `/hooks` review + trust；Codex Desktop App 当前普通会话不支持 `/hooks`。**Cursor** 仍仅 canonical + CI 兜底。
