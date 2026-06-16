# rig

给 AI coding 供给**纪律**的分层 harness —— 模型负责聪明，rig 负责让它守规矩、可验证、不偏离。

> 不是更聪明的 prompt，是结构性约束：规范在编码时**注入**（push，不靠触发）、违规被**确定性的闸**当场拦（lint / 红线 / verify）、状态外置、意图×风险决定流程力度。

## 怎么用（两步，第一步只此一次）

**① 装一次 / 每台机器** —— 把机制装进 `~/.claude`（hooks + 子 agent + 全局 `/rig:*` 命令 + 注册 skill）：

```bash
git clone https://github.com/zhangyh-only/rig.git
bash rig/scripts/bootstrap.sh        # 幂等；settings 合并不覆盖
```

> - 不想自己敲终端？在任意 AI 会话里说「跑 `rig/scripts/bootstrap.sh` 把 rig 装到我的 ~/.claude」，让 AI 用 Bash 替你跑——效果一样。
> - 装完**开个新会话**（hooks 与 `/rig:*` 命令在新会话才生效）；克隆目录别移走（skill 软链指向它）。
> - 可选 `bash rig/install.sh`：把 `rig` 加进 PATH，方便在终端直接敲 `rig`（模型 B 下基本用不到）。

**② 之后都在 AI 里敲 `/rig:*`，不再碰终端：**

- **`/rig:init`** —— 接入当前项目：检测 → 装缺的机制 → 铺骨架 → 归并既有规范、从 `pom`/`package.json` 推导 `AGENTS.md` 地图、起草 `verify-local`（判断活由 AI 读 [`SKILL.md`](SKILL.md) 完成；幂等，重复跑只补缺的）。
- **`/rig:doctor`** —— 自检（注入 / 红线 / 闸 / 降级 绿不绿）。
- 接入后该项目就有工作流命令：`/rig:new-change` `/rig:archive-change` `/rig:adr` `/rig:feature-spec` `/rig:review` `/rig:learn`。

## 它装了什么

**全局机制**（`~/.claude`，所有项目共用，装一次）
- 8 个 hook：编码时注入规范 + 进行中 spec、改完即 `lint`、红线 `guard`、收工 `verify`、会话态自检（缺闸响亮告警）
- 2 个子 agent：`code-reviewer`（收尾语义复核 + honesty gap）、`spec-author`
- 全局命令 `/rig:init`、`/rig:doctor`；注册 skill `~/.claude/skills/rig`

**项目内容**（`/rig:init` 时落地，每个项目一份）
- `AGENTS.md`（地图 + 基线 + 指针）· `docs/conventions/`（规范三桶 A/B/C）· `scripts/lint-one.sh`（语言适配器）· `scripts/verify-local.sh`（L0 自验证）· `/rig:*` 工作流命令 · openspec / ADR 模板

## 三道闸 + 兜底

1. **生成时注入全文**（主动）：编码一开始 hook 把规范 + 进行中 spec 注入，AI 带着规则一次写对。
2. **改完即时 lint**（硬）：违规 `exit 2` 当场回灌让 AI 修。
3. **CI 必过**（硬，不可绕）：lint + 架构测试进 `mvn verify` / required check。
4. **收尾 `code-reviewer`**（兜底）：只兜机器判不了的语义（遵守度 / 偏离度 / 完成度 + 自报 vs 实测的诚实度核对）。

## 验证自身

```bash
bash test/eval-demo.sh    # 把整条 hook 链固化成确定性打分(13/13、3 次一致)，可进 CI
bash test/demo-run.sh     # 带旁白地演示整条链跑一遍
```

## 文档

- 设计与机制原理：[docs/DESIGN.md](docs/DESIGN.md)
- 安装细节（AI 辅助 / 人工两条路径）：[docs/INSTALL.md](docs/INSTALL.md)
- 期望终态清单（安装器唯一数据源）：[reference/manifest.md](reference/manifest.md)

## 现状

机制与内容齐备、脚本过 bash 3.2 + 功能测试；全链路已在隔离环境验过（`eval-demo` 13/13、3 次一致；`rig init` → 8 hooks + 2 agents + 全局/项目 `/rig:*` + skill 软链；`doctor` 关键项全过）。全局机制对 **Claude** 完整，**Codex / Cursor 仅 canonical + CI 兜底**（`--codex` 暂为占位）。**尚未在真实项目上长期跑过**——首个试点见 [docs/DESIGN.md](docs/DESIGN.md) §8。
