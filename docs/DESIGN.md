---
title: AI Coding 辅助开发体系 — 设计文档
status: draft（待用户确认 → 确认后进入真实项目试点）
created: 2026-06-15
updated: 2026-06-15（v4：§16.1 安装器升级为 manifest 驱动——遍历 reference/manifest.md 覆盖"任意缺失"，四态 detect、两类补救、机器画像 detect-env.sh；manifest 由多视角穷举+对抗式查漏工作流生成）
owner: zhangyh
purpose: 把"用什么 skill / 工作流怎么运转 / 新封装什么能力"的决策沉淀下来，防止遗忘；用户确认后再找真实项目验证。
---

# AI Coding 辅助开发体系 — 设计文档

> 本文档是一份**跨项目的方法论设计**，不属于任何单一项目。它记录：为什么这么定（背景与认知）、定成什么样（五层体系）、怎么运转（工作流机制）、用哪些工具（清单）、要新建什么（封装能力）、换工具是否还成立（可移植性），以及如何验证（试点计划）。

---

## 1. 背景与动机

### 1.1 用户的工作构成（决定了"不能一刀切"）
1. 在运行项目的**日常开发**（Java/Spring 微服务，依赖云端中间件）
2. 公司内部业务系统**框架升级**（高风险、影响面大、难回退）
3. **AI 技术预研**（探索性，可丢弃）
4. **demo 课题推进**（可丢弃，但想留经验）
5. **日常运维工具**尝试（多为一次性脚本）

### 1.2 触发这次梳理的现状
- 已自研两个 skill：`memory-bank-manager`、`feature-spec`（个人沉淀、未充分验证）。
- 在用 `superpowers`；了解但未深用 `openspec`、`spec-kit`、`karpathy-skills`。
- 参考项目：`/Users/zhangyh/code/study/welearning-neo`、`/Users/zhangyh/code/study/sparring-upgrade`（两者的 memory-bank 都在真实使用、持续维护）。

### 1.3 暴露的真实问题（来自用户反馈，是本设计的靶子）
- **memory-bank 几乎不被主动调用**：希望 AI 编码时遵守的注释/编码规范很难被触发。根因是**机制错配**——skill 是"拉"（按 description 触发），而规范是"推"（需常驻上下文）。
- **feature-spec 大多手动发起，且 `/feature-spec` 后不知道写什么**：空参数缺少引导（应给"选择题"而非"填空题"）。
- 用户核心关注点：**规范遵守、计划、spec 约束制定、AI 任务执行的完成度/遵守度/偏离度**。
- 关键地基问题（来自参考文章）：**Java 微服务本地跑不起来 → AI 无法自验证 → 完成度/遵守度/偏离度无从客观度量**。

### 1.4 关键参考输入
- 阿里云文章一《Skill Factory：面向 Harness 设计的技能工厂》——核心：**评测驱动、失败优先**；加 skill 前先做**基线诊断**（裸模型能否解决？现有 skill 能否覆盖？）；多路并发生成择优；Trace2Skill（从日志轨迹蒸馏 skill）。
- 阿里云文章二《为什么 Java AI Coding 体验差一个量级——五条方法论构建 Harness 环境》——核心：AI 高效的前提是**本地自验证闭环**；Java 微服务把运行时依赖推到云端导致闭环断裂；三原则（依赖倒置/接口先行、零侵入 Profile 隔离、工具 CLI 化）+ 五方法论（最小可运行子集、替代而非模拟、脚本化一切人工操作、分层逐层验证、让 AI 成为改造参与者）。
- `karpathy-skills`（multica-ai/andrej-karpathy-skills）：四条**always-on 规则**（Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution），交付形态是 CLAUDE.md / 插件，**不是 skill**。
- `code-review-graph`（tirth8205）：**tool-agnostic（MCP）的代码情报层**，Tree-sitter AST 图 + blast-radius 影响分析 + ~82x token 压缩。不是"评审法官"，是"情报源"。
- `superpowers`（obra）：方法论纪律框架（brainstorm/plan/execute + TDD + 子 agent 复核），本身用 hook 强制 skill 被调用。
- `spec-kit`（GitHub）：重量级前向 spec 流（constitution + specify/plan/tasks），单 feature 可达 2000+ 行、~18k token。
- `openspec`：轻量"变更提案"流（proposal→apply→archive，delta 合并进 living spec）。

---

## 2. 核心认知（设计原则）

1. **两条正交轴**：
   - 前向流（一次变更的生命周期：讨论→spec→计划→执行）——易逝。
   - 后向沉淀（跨变更的长期资产：项目事实、约定、域设计）——常驻。
   - `superpowers/openspec/spec-kit` 主攻前向；`feature-spec` 主攻后向。两者互补，非竞品。
2. **地基认知**：**AI 能否本地自验证，决定上层一切**。没有本地 Harness，"完成度"会退化成 AI 自己说的"已完成"。
3. **触发可靠性是软→硬的梯子**：散文 < skill description < slash command < hook < CI gate。**必做项必须上 hook / CI，别指望模型自觉。**（memory-bank 失败正因为押在最软那档。）
4. **可迁移底座 vs 工具专属外壳**：价值放进仓库内工件（脚本、markdown、AGENTS.md、MCP、CI），工具专属的 skill/hook 打包保持薄、可替换。
5. **基线诊断治理**：加任何 skill 前先问——裸模型行不行？现有 skill 能否覆盖？都能就别造。（这是删 memory-bank 的依据，也是防 skill 膨胀的闸门。）
6. **ceremony 匹配风险**：重武器（spec、偏离度复核、Harness）集中在框架升级 + 生产日常开发；预研/demo/运维保持低摩擦。

---

## 3. 目标体系：五层架构

```
┌──────────────────────────────────────────────────────────────┐
│ L4 执行评估    完成度 · 遵守度 · 偏离度                          │  新增（薄封装，复用 /code-review + /verify）
├──────────────────────────────────────────────────────────────┤
│ L3 长期资产    功能域设计 · 跨域决策                             │  feature-spec(保留改造) + ADR(新增)
├──────────────────────────────────────────────────────────────┤
│ L2 变更流程    讨论 · spec · 计划 · 执行(TDD)                    │  superpowers(保留) ; openspec(可选)
├──────────────────────────────────────────────────────────────┤
│ L1 常驻上下文  给 AI 一张地图 + 硬规范（推，不靠触发）           │  AGENTS.md/CLAUDE.md + karpathy 四原则
├══════════════════════════════════════════════════════════════┤
│ L0 本地 Harness  让 AI 能本地自验证（地基·最高杠杆）            │  新建（每项目一次的工程改造）
└──────────────────────────────────────────────────────────────┘
依赖：L0 决定 L4 能否成立——"完成度"只有在 AI 能本地跑验证时才可客观度量。
```

- **L0 本地 Harness**：依赖倒置 + Profile 隔离 + 工具 CLI 化 + `verify-local.sh`/`start-local.sh`/`fetch-config.sh` + 冒烟测试。最小可运行子集、替代而非模拟。
- **L1 常驻上下文**：`AGENTS.md`（canonical，<100 行）= 地图（怎么 build/test/本地启动）+ 你真要每次遵守的硬规范 + karpathy 四原则；`CLAUDE.md` 仅 `@AGENTS.md` 引入（单源、跨工具）。其余规范留 reference，按需拉。
- **L2 变更流程**：`superpowers` 跑大特性；**每份 spec 的验收标准必须落成可执行脚本/测试**（接 L0、喂 L4）。
- **L3 长期资产**：`feature-spec` 沉淀域设计（代码→文档）；`ADR` 记跨域决策（why）。
- **L4 执行评估**：fresh-context 对抗式 review + lint，输出完成度（验收脚本命中率）/遵守度（对照 AGENTS.md+feature-spec）/偏离度（动了计划外的文件/依赖/重构）。高频违规回灌成新规范。

---

## 4. 工作流如何运转

### 4.1 一个典型 Java 特性（改动驱动 + 需求驱动通用）
| 步骤 | 做什么 | 用什么（层） | 谁触发 / 怎么强制 |
|---|---|---|---|
| 0 背景常驻 | 地图+硬规范+karpathy 原则始终在上下文 | AGENTS.md（L1） | 常驻加载（推） |
| 1 起活/澄清需求 | 引导式 Q&A 把需求问清 → 出计划 | superpowers brainstorm/plan（L2） | 用户起意 + slash 把关 |
| 2 定验收 | 计划的验收标准写成**可执行脚本/测试** | verify 脚本（L0/L2） | 计划阶段产出 |
| 3 执行 | AI 在本地 Harness 自迭代（compile→test→smoke）直到收敛 | L0 + superpowers execute | 自动循环（省掉推预发等待） |
| 4 遵守度守门 | 每次 Edit/Write 后跑 lint/规范检查 | hook（L4） | **PostToolUse hook 强制** |
| 5 完成度守门 | verify 没过不让"收工" | hook（L4） | **Stop hook 强制** |
| 6 偏离度复核 | 收尾调 code-reviewer 子 agent 做语义复核（遵守度/偏离度/完成度，可喂 blast-radius） | /review → code-reviewer 子 agent（L4） | 人触发的收尾复核（**非硬 hook**；机器可判的已被 lint/verify 拦） |
| 7 沉淀 | 设计稳定→域文档；跨域决策→ADR | feature-spec + ADR（L3） | feature-spec 主动 propose |

### 4.2 两种入口
- **改动驱动**（日常开发为主）：从第 1 步进，superpowers plan + git 历史 + ADR 足够，**不需要 openspec**。
- **需求驱动**（收到正式需求文档、要跨特性追溯 需求→delta→归档）：**这是 openspec 唯一该上的场景**；否则不上。
  - **init 据此判 openspec 取舍**：/rig:init 在批量征询给 openspec 推荐前必走本入口判据（需求驱动才上），不得用 §7 项目规模或「单仓自用」等画像字样代替；工作模式判不出则中立呈现二选一（规则见 §8.2、根因见 §9）。

### 4.3 "完整调用"的保证机制（关键）
触发可靠性从软到硬：
| 机制 | 可靠性 | 谁触发 | 放什么 |
|---|---|---|---|
| AGENTS.md 散文 | 软 | 模型自觉 | 偏好、风格、地图 |
| skill description | 中 | 模型按需 | 显式意图（沉淀、review） |
| slash command | 高 | 人手动 | 判断节点（批准 plan/spec） |
| **hook** | 很高 | 自动 | **机械硬步骤（lint、verify、gate）** |
| CI / 外部 gate | 最高 | 自动 | 最终兜底（PR 检查） |

**原则**：hook 管机械（遵守度 lint / 完成度 verify），人管判断（slash 批准方案、收尾触发 code-reviewer 做偏离度/语义复核）。跨工具的强制力优先押 **CI/git hook**（活在仓库里，不随工具走）。

---

## 5. 工具清单（装 / 留 / 复用 / 自建 / 不装）

| 工具/能力 | 层 | 动作 | 说明 |
|---|---|---|---|
| memory-bank-manager | — | ✅ 已删 | 未过基线诊断；职责拆到 L0/L1/L3。已于 2026-06-15 删除 `~/.cc-switch/skills/memory-bank-manager`（存量项目内 `memory-bank/` 数据已按映射迁移并整目录删除，退役完成） |
| superpowers | L2 | 保留（已装） | 变更流程：brainstorm/plan/execute/TDD（执行层，spec 之下） |
| openspec | L2 | **采用（工具）** | 前向 spec 契约层；较大/跨模块/难回退的改动先起 change，详见 §15 |
| feature-spec | L3 | 保留（不改触发） | 单一能力，手动发起；后向设计沉淀。触发改造后续再迭代 |
| karpathy-skills | L1 | 安装（唯一新装现成件） | 当 always-on 行为基线，进 AGENTS.md |
| /code-review、/verify | L4 | 复用（内置） | 评估的现成零件 |
| code-review-graph | L0/L4 | 候选（按信号引入） | MCP 情报层；当内置 review 对跨模块影响判不准时引入 |
| spec-kit | L2 | 不装 | 兼容成本（双 constitution+双 plan+双 tasks）> 边际价值 |

### 5.1 需要新封装的能力（多数不是 skill，是仓库工件/薄封装）
1. **L0 本地 Harness 脚手架**：接口抽象 + `@Profile("local")` 隔离 + `verify-local.sh`/`start-local.sh`/`fetch-config.sh` + 冒烟测试（每个 Java 项目一次，AI 可参与改造）。
2. **L1 AGENTS.md(canonical) + CLAUDE.md(@import) 单源结构**（每项目一份 <100 行）。
3. **L3 ADR 轻量模板 + 习惯**（一个 md 模板，极小）。
4. **L4 遵守度/偏离度评分**（在 /code-review 之上的薄 prompt/skill；偏离度可喂 blast-radius）。
5. **两个强制 gate（hook）+ 一个收尾复核**：PostToolUse 规范 lint（遵守度）、Stop verify-on-stop（完成度）是硬 hook；偏离度/语义复核由收尾调 code-reviewer 子 agent（`/review`，人触发，非硬 hook）。
6. **feature-spec 两处改造**（见上）。

---

## 6. 可移植性（换 Codex / 阿里云工具是否还适用）

| | 内容 | 换工具时 |
|---|---|---|
| **可迁移底座**（价值放这） | L0 Harness 脚本、L1 规范/地图内容、L3 feature-spec+ADR（markdown）、L4 验收脚本/测试、MCP 工具（code-review-graph） | 直接带走，几乎零改 |
| **工具专属外壳**（保持薄） | skill 本体、hook、slash command | 每换一次重新打包 |

- **canonical 用 `AGENTS.md`**（Codex 原生标准、多工具可读）；`CLAUDE.md` 只写 `@AGENTS.md`。
- 换 Codex：原生读 AGENTS.md、能跑 verify 脚本、能用 code-review-graph 的 MCP，底座平移，仅把 CC 的 skill/hook 换成其等价物或靠 CI 兜底。
- 换通义灵码/Qoder：有各自规则文件，把 canonical 同步过去即可；Harness 脚本 + MCP 仍可用。
- 结论：**"为可移植而设计" = "多投 L0 + 仓库工件 + MCP + CI"**，与本体系方向一致。

---

## 7. 工作模式匹配（哪类工作上哪些层）

| 工作类型 | 风险/可逆性 | 该上 | 不该上 |
|---|---|---|---|
| 公司业务系统框架升级 | 高 | 全栈，重点 L0 + L4 偏离度复核 | — |
| 在运行项目日常开发 | 中（碰线上） | L0 + L1 + 轻 L2 + 遵守度抽查 | 重 spec |
| AI 技术预研 | 低（可丢弃） | 仅 L1（轻）；事后 ADR 沉淀 | 前置 spec、规范负担、L0 重改造 |
| demo 课题 | 低（可丢弃） | L1 + 轻计划 + 决策记录 | 规范强制、偏离度复核 |
| 日常运维工具 | 低（可能碰生产） | 仅护栏（surgical changes、别动生产数据） | 几乎所有流程 |

> 轻依赖项目（预研/demo/运维）本来就本地可跑，L0 几乎免费，跳过重改造。

---

## 8. 待办与验证计划

### 8.1 待自建清单（确认后启动）
- [ ] L0：选一个真实项目盘云端依赖，产出 `AGENTS.md` + `verify-local.sh` 骨架
- [ ] L1：AGENTS.md(canonical) + CLAUDE.md(@import) 结构；接入 karpathy 四原则
- [ ] L4：配两个 hook gate（遵守度 lint / 完成度 verify-on-stop）+ 收尾 code-reviewer（偏离度/语义，`/review` 触发）
- [ ] L3：ADR 模板；feature-spec 两处小改
- [x] 迁移：把项目内 `memory-bank/project/feature-specs/` 迁到 `docs/feature-specs/`（存量已全部迁移并删除，memory-bank 退役完成）

### 8.2 待决策/触发条件（防止过早引入）
- **openspec**：✅ 已决定直接采用（工具）。`npx openspec init`；与 feature-spec 分工见 §15。
- **init 征询的倾向性约束（试点新增）**：/rig:init 对 openspec 给推荐方向前，**必须按 §4.2 入口判据判工作模式**——"需求驱动"（收正式需求文档、要追溯 需求→delta→归档）才是 openspec 唯一该上的场景，"改动驱动"的日常开发不上；判 openspec 取舍**不得用 §7 项目规模/风险，也不得凭"单仓自用""业务系统"等项目画像字样**（§7 只管分层轻重）。**工作模式判不出时不给倾向、中立呈现二选一**交用户拍板（承接 git 9e9920d/16b3aee）。同类"按工作模式取舍"的征询项同此纪律。
- **code-review-graph**：仅当内置 /code-review（high/ultra）对跨模块影响判不准时引入。
- **多路并发生成 / Trace2Skill**：作为后续"维护体系本身"的高级手段，不急。
- **feature-spec 触发改造**（空参数菜单 / 主动 propose）：后续再迭代，当前保持单一手动能力。

### 8.3 试点计划（用户确认本文档后执行）
1. 选 **sparring-upgrade**（云端依赖重、L0 收益最大）做第一个试点。
2. 先做 **L0 + L1**（其它层的前提）：本地能一条命令启动 + verify 脚本能跑通 + AGENTS.md 立起来。
3. 验收标准：AI 能在本地自迭代收敛一个小改动（compile→test→smoke 全绿），无需推预发。
4. 跑顺后再叠 L4 三个 gate，最后补 L3。

---

## 9. 决策记录（关键 why）
- **删 memory-bank**：未过基线诊断；规范该"推"却放进"拉"的 skill；tasks 层与 superpowers/openspec 重叠。
- **不装 spec-kit**：太重（2000+ 行/~18k token），与 feature-spec + AGENTS.md 全重叠。
- **openspec 直接采用**（修正早前"暂缓"）：harness 建好后，spec 不与 superpowers 冲突——spec=契约（持久前向），plan=执行（易逝）；且 spec 给 L4 偏离度补上硬基准。与 feature-spec 方向相反（前向 intent vs 后向 as-built），分工而非重叠，见 §15。
- **karpathy 放 AGENTS.md 而非做 skill**：行为基线必须常驻（推），不能等触发。
- **code-review-graph 视为情报源而非法官**：走 MCP（可移植）、提供 blast-radius（喂偏离度）、省 token（合 RTK 习惯）。
- **init 给 openspec 推荐必须走 §4.2 判据、不凭项目画像**：试点中 init 在 welearning-neo（auth-token 分支）上把"暂不启用"标"(推荐)"，理由"单仓自用、多走 feature-spec"。"单仓自用"是误判（welearning-neo 是多模块业务系统），但**结论对错取决于它是不是"需求驱动"工作（§4.2），init 根本没按 §4.2 判、是凭画像拍的**——故根因不是"推荐反了"，而是绕过 §4.2 入口判据、拿项目画像/规模代替判据。规则：openspec 取舍唯一按 §4.2（需求驱动才上、改动驱动不上），§7 只判分层轻重不作此用；工作模式判不出时中立呈现二选一（呼应 9e9920d/16b3aee）。

---

---

## 10. 规范如何落地与强制（核心机制 · 取代早前"L1 缩成 100 行"的粗略说法）

**规范一行都不缩；改的是"交付时机"——从 always-on 摆摘要，改为编码时注入全文。**

### 10.1 三桶分流（每条规则按"靠什么强制"归类）
| 桶 | 规则特征 | 强制方式 |
|---|---|---|
| A 机器可判定 | 命名、目录归属、依赖方向、必须有注释、禁用 import、禁魔法值 | 编译成检查器（行级 lint + 架构测试），由 hook + CI 自动拦 |
| B 需判断、每次都相关 | "注释要有信息量""按职责选后缀""归属看调用面" | 写进 `docs/conventions/` 全文，**生成时注入** AI |
| C 详细参照/决策背景 | 完整表格、示例、为什么这么定 | 全文参照 + L4 review 对照基准 |

### 10.2 三道闸 + 兜底（主次顺序）
1. **生成时注入（主力·主动）**：编码任务一开始，hook 把"全局个人规范 + 当前项目规范"全文注入上下文 → AI 带着规则一次写对，不进返工循环。
2. **改完即时检查（硬·快反馈）**：PostToolUse 跑项目检查器，违规 exit 2 当场回灌让 AI 修（仍是生成期纠错）。
3. **CI 必过（硬·不可绕过）**：lint + 架构测试绑进 `mvn verify` / CI required check，不通过不许合并——与 AI 工具无关。
4. **L4 review（兜底·只兜语义）**：注释信息量、归属判断等机器判不了的，收尾兜底。

> 为什么不 always-on 摆全文：(a) 每轮非编码对话也背着它，浪费；(b) 超长常驻上下文会让模型"读不进/忘中段"，埋在长文里的规则反而更不被遵守。按编码时机注入既更省又更有效。

## 11. 双层架构：机制全局 + 内容随项目

| | 机制（通用机器） | 内容（项目专属） |
|---|---|---|
| 是什么 | 注入/检查/拦截的逻辑 | 规范文本、linter 规则、模块地图 |
| 每个项目 | 完全一样 | 各不相同 |
| 放哪 | **`~/.claude/`（全局共享）** | **项目 repo（`docs/conventions/` 等）** |
| 跨机器迁移 | 个人 dotfiles 仓库 | 项目自己的 git |

- **约定优于配置**：全局脚本只认固定路径（`docs/conventions/`、`scripts/lint-one.sh`），项目放好内容就自动生效；没放则优雅降级、无害。
- **项目独立配置两种**：① 内容级（常态，换 `docs/conventions/` + linter 配置，无需额外动作）；② 流程级（按需，项目 `.claude/settings.json` 追加/覆盖 hook，与全局**叠加执行**）。
- **运行时听谁的**：全局机制 hook + 项目额外 hook 都跑；注入文本里写死"项目规范 > 全局个人偏好，冲突以项目为准"；CI 始终用项目规则兜底。

## 12. hook 机制与脚手架

- **固定时刻**：AI 交互生命周期节点——发消息(`UserPromptSubmit`)、改文件前(`PreToolUse`)、改文件后(`PostToolUse`)、收工(`Stop`)。
- **自动跑**：Claude Code 在节点自动执行你登记的脚本，事件 JSON 从 stdin 传入。
- **脚本怎么影响 AI**：`UserPromptSubmit` 的 **stdout 追加进上下文**（用于注入）；**exit 2 拦截**并把 stderr 回灌 AI（用于守门）。
- **三个 hook**：注入规范(`inject-conventions.sh`/UserPromptSubmit)、改完检查(`lint-changed.sh`/PostToolUse)、红线拦截(`guard.sh`/PreToolUse)。
- **脚手架已重构为安装器 skill**：`rig/`（`SKILL.md` + `assets/`），脚本已本地自测通过（注入双层规范、非编码静默、红线拦/放正确、openspec 变更注入）。安装方式见 §16 与该目录 `INSTALL.md`。

## 13. 名词表
- **linter / 检查器**（Checkstyle=Java / ESLint=JS / ruff=Python / golangci-lint=Go）：自动对照规则清单给源码挑错，输出 file:line。
- **架构测试**（ArchUnit=Java / dependency-cruiser=JS / import-linter=Python）：检查结构/依赖/归属规则（如"gateway 不许依赖 common-data"）。
- **CI / required check**：服务器（GitHub Actions 等）每次推码自动跑构建+测试+检查；required = 不通过不许合并，平台强制、不靠人记得。
- **hook（钩子）**：工具在固定生命周期节点自动跑的脚本。`UserPromptSubmit`=发消息时（注入）；`PreToolUse`=动工具前（拦截）；`PostToolUse`=动工具后（检查回灌）；`Stop`=收工时（没过验证不放行）。

## 14. 工作流与语言无关
五层体系与 hook 注入机制都和语言无关；唯一按语言分叉的是 `scripts/lint-one.sh`（适配器）+ 该语言的检查器配置。换前端/Python/Go 项目只改这一处。

---

## 15. openspec 与 feature-spec 的分工与协作（已采用 openspec）

**结论**：openspec 直接采用（工具）；feature-spec 保持单一手动能力。两者方向相反、天然不抢活。

### 15.1 分工
| | openspec | feature-spec |
|---|---|---|
| 方向 | 前向（intent，要建什么） | 后向（as-built，已建成什么） |
| 内容 | 需求/行为规格 + 变更 delta | 代码实现设计（类/流/file:line） |
| 来源 | 人写意图 | 扫代码生成 |
| 时机 | 改动前写、改完归档 | 代码稳定后沉淀 |
| 粒度 | 能力/变更 | 业务域 |
| 目录 / 层 | `openspec/` · L2 契约 | `docs/feature-specs/` · L3 资产 |

一句话：openspec 答"该做什么/这次改什么"，feature-spec 答"代码里现在怎么搭的"。

### 15.2 接力链路
1. 起变更 → `openspec` 写 change（intent + spec delta + tasks）
2. 实现 → superpowers plan/execute + harness 注入"规范 + 本变更 spec"
3. 归档 → `openspec archive` 把 delta 合并进 `openspec/specs/`（需求真相落账）
4. 代码稳定 → `feature-spec` 重扫受影响域，刷新设计文档（实现真相落账）

### 15.3 唯一重叠「为什么」的消解规则
变更进行中 → why 在 **openspec 提案**；归档时跨域长期决策 → 毕业到 **ADR**；feature-spec §10 **只链接 ADR，不复制**。why 唯一权威。

### 15.4 接进 harness
- 新增 hook `inject-active-spec.sh`（UserPromptSubmit）：编码时把"进行中的 openspec 变更"注入上下文，AI 在 spec 范围内实现。已加入脚手架并自测通过。
- 偏离度（L4）以"是否超出变更 spec 范围"为基准——openspec 给了偏离度第一个硬基准。
- 日常小改动不必起 change，照常 plan + git。

---

## 16. 一键安装：封装为安装器 skill（`rig/`）

**为什么是 skill 而非 cp 脚本**：安装需要判断——合并而非覆盖既有 `AGENTS.md`/`settings.json`、整理项目已有规范、补齐缺失 skills。这些是判断活，cp 做不到，skill 能做到。

- **包即 skill**：`rig/` 自包含 = `SKILL.md`（大脑）+ `assets/`（dotfiles-layer 机制 + project-layer 内容）。复制进 skills 目录即可用。
- **一句话安装**：在目标项目说"安装这套工作流"→ skill 按 SKILL.md 流程：探测 → 确认意图（装全局/接入项目）→ **幂等合并**安装 → **整理**项目既有规范（归并进 `docs/conventions/` 并三桶分类）→ 补齐缺失 skills/工具 → 跑验证并报告。
- **铁律**：幂等、合并不覆盖、先探测后动手、整理不丢弃、缺失才补。其中最易出错的 settings.json 合并由测过的 `scripts/merge-settings.sh` 保证（确定性脚本，不靠模型现写 jq）；`scripts/verify.sh` 固化安装后自检。
- **覆盖全场景**：本地已装→新项目接入；换新设备→全局装一次 + 逐项目接入；项目已有规范/缺 skill→自动整理/安装。
- **两条路径**：AI 辅助（推荐，一句话）/ 人工（`INSTALL.md` 合并式命令）。

> 与第 11 节双层一致：skill 的 `assets/dotfiles-layer` 装到 `~/.claude`（全局机制，dotfiles 仓库迁移），`assets/project-layer` 接入各 repo（内容随项目 git）。

### 16.1 manifest 驱动 —— 覆盖"任意缺失"（v4）

安装器不再硬编码"探测/补缺清单"，而是遍历声明式 `reference/manifest.md`：对每项 `detect(四态)→缺则按 remediation_type 补→verify_after 复验回滚`。**新增任何要素 = 往 manifest 加一行，流程零改动**——这是"无论缺 skill / 脚本 / agent / 规范 / 项目约束，都能探测并补救"的结构性保证。

- **两类缺失**：可模板（template-copy/merge/install-command，自动落地）vs 项目专属不可模板（organize-existing/derive-from-code/author-with-user，禁止伪造，只检测+识别候选+建骨架+发起，内容以代码/用户为准）。
- **四态 detect**：present/absent/**incomplete(占位符空壳)**/not-applicable，避免把"文件在但没填"当已达成。
- **机器画像** `scripts/detect-env.sh`：OS/包管理器(不假定 brew)/jq(阻断级前置)/已装工具(Claude/Codex/Cursor 适配)/cc-switch 软链(写同步源不直写)/语言矩阵——已在真机验证，并实测发现 1 个悬空软链。
- manifest 由一次多视角穷举 + 对抗式查漏工作流生成（153→171 项，10 个遗漏类别 + 15 条非通用假设全部回填），含 15 个类别 M/P/T/H/S/A/C/K/R/V/L/G/SP/PC/MCP。条目标 `[ready]`(有 asset)/`[declared]`(已声明待补)。
- **declared 补建（v5）**：已把 18 个 declared 补成 ready（当前 46 ready / 7 declared）。新增 asset：4 个 slash 命令（new-change/archive-change/adr/feature-spec）、ADR 模板+索引、plan 模板、openspec change 三件套模板、.editorconfig、2 个子 agent（code-reviewer/spec-author）、4 个新 hook（Stop verify 闸 / SessionStart 地图 / SessionEnd 提醒 / PreToolUse Bash 绕过拦截）、dotfiles `.gitignore`+`bootstrap.sh`+`backup.sh`，并修 inject-active-spec 输出无上界。内容类经并行工作流起草、脚本类本人写+测（全过 bash 3.2 + 功能测试）。仍 declared（延后）：run-report、version-migration、golden-fixture-test、windows-wsl、statusline、drift-check、active-change-wellformed。

---

_本文档为决策快照，确认后进入试点；试点中的新发现回写本文件的第 8、9 节。_
