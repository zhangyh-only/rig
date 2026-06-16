# rig

给 AI coding 供给**纪律**的分层 harness —— 模型负责聪明，rig 负责让它守规矩、可验证、不偏离。

> 不是更聪明的 prompt，是结构性约束：规范在编码时**注入**（push，不靠触发）、违规被**确定性的闸**当场拦（lint / 红线 / verify）、状态外置、意图×风险决定流程力度。

## 安装（一次 / 机器）

```bash
git clone https://github.com/zhangyh-only/rig.git
cd rig && bash install.sh          # 把 rig 软链上 PATH
```

## 接入项目（一次 / 项目）

进入项目，在 AI 会话里说「用 rig 初始化」，或直接：

```bash
rig init          # 检测 → 装全局机制(缺才装) → 铺项目骨架；判断性内容由 AI 补
rig doctor        # 装好后自检
```

`rig init` 做机械 / 确定性的部分；归并既有规范、从 `pom`/`package.json` 推导项目地图、写本地自验证脚本这些**判断活**，由 AI 读 [`SKILL.md`](SKILL.md) 完成。幂等：重复跑只补缺的，已存在的不动。

## 它装了什么

**全局机制**（`~/.claude`，所有项目共用，装一次）
- 8 个 hook：编码时注入规范 + 进行中 spec、改完即 `lint`、红线 `guard`、收工 `verify`、会话态自检（缺闸响亮告警）
- 2 个子 agent：`code-reviewer`（收尾语义复核 + honesty gap）、`spec-author`

**项目内容**（每个项目一份）
- `AGENTS.md`（地图 + 基线 + 指针）· `docs/conventions/`（规范三桶 A/B/C）· `scripts/lint-one.sh`（语言适配器）· `scripts/verify-local.sh`（L0 自验证）· 项目命令 `/rig:new-change` `/rig:archive-change` `/rig:adr` `/rig:feature-spec` `/rig:review` `/rig:learn`（全局 `/rig:init` `/rig:doctor` 装一次即全项目可用）· openspec / ADR 模板

## 三道闸 + 兜底

1. **生成时注入全文**（主动）：编码一开始 hook 把规范 + 进行中 spec 注入，AI 带着规则一次写对。
2. **改完即时 lint**（硬）：违规 `exit 2` 当场回灌让 AI 修。
3. **CI 必过**（硬，不可绕）：lint + 架构测试进 `mvn verify` / required check。
4. **收尾 `code-reviewer`**（兜底）：只兜机器判不了的语义（遵守度 / 偏离度 / 完成度 + 自报 vs 实测的诚实度核对）。

## 验证自身

```bash
bash test/eval-demo.sh    # 把整条 hook 链固化成确定性打分(13/13、3 次一致)，CI 可用
bash test/demo-run.sh     # 带旁白地演示整条链跑一遍
```

## 文档

- 设计与机制原理：[docs/DESIGN.md](docs/DESIGN.md)
- 安装细节（AI 辅助 / 人工两条路径）：[docs/INSTALL.md](docs/INSTALL.md)
- 期望终态清单（安装器唯一数据源）：[reference/manifest.md](reference/manifest.md)

## 现状

机制与内容齐备、脚本过 bash 3.2 + 功能测试；`rig init`/`doctor` 的全局机制部分对 **Claude** 完整，Codex/Cursor 目前只落 canonical + CI 兜底。**尚未在真实项目上长期跑过**——首个试点见 `docs/DESIGN.md` §8。
