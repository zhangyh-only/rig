---
name: rig
description: 安装、迁移或更新这套"AI coding 分层工作流"（本地 hook 机制 + 项目级规范/spec 内容）。当用户说"安装这套工作流""给这个项目接入工作流""在新设备装好""扫描缺失并整理""onboard 这个项目"等时使用。全程幂等合并、绝不覆盖已有 AGENTS.md/CLAUDE.md/settings.json，并自动整理项目既有规范、补齐缺失的 skills/工具。
---

# AI Coding 工作流安装器

被调用时：把这套分层工作流安装/迁移/更新到**当前机器**和/或**当前项目**。
配套设计文档：`docs/DESIGN.md`（机制原理）。

## 铁律（任何步骤都遵守）
1. **幂等**：可反复运行；已存在的不重复加、不破坏。
2. **合并不覆盖**：`AGENTS.md` / `CLAUDE.md` / `settings.json` 一律「读取→合并→写回」，保留原有内容。**禁止整体覆盖。**
3. **先探测后动手**；联网/破坏性/写敏感区的项按 manifest 的 `requires_consent` 汇总成**一次批量征询**，确认后才动。
4. **整理既有不丢弃**：项目已有的规范/规则 → 归并进 `docs/conventions/` 并按三桶分类，原内容保留（清理需许可）。
5. **缺失才补**：按 manifest 逐项 detect，仅对 absent/incomplete 补救；补后 `verify_after` 复验，失败回滚。
6. **数据驱动**：探测与补齐的清单一律来自 `reference/manifest.md`，SKILL.md **不内嵌任何要素枚举**；遇 manifest 未覆盖的新要素，**先往 manifest 加一条再跑**，而非在流程里写死。这是"覆盖任意缺失"的保证。

## 资产位置（相对本 skill 目录）
- **期望终态清单（唯一数据源）**：`reference/manifest.md` —— 安装器遍历它逐项 `detect→remediate`。新增/调整工作流要素**只改此文件，不改流程**。
- 全局机制：`assets/dotfiles-layer/`（共享 `hooks/` + Claude `settings.json` hooks 片段 + `conventions.md`；Codex 由 `rig init` 写 `~/.codex/hooks.json`）
- 项目内容：`assets/project-layer/`（`AGENTS.md`/`CLAUDE.md` 模板 + `scripts/lint-one.sh` + `docs/conventions/` 模板 + `.claude/`）
- **安装期助手**（skill 自己跑、非被装）：`scripts/detect-env.sh`（机器画像）、`scripts/merge-settings.sh`（幂等合并 settings）、`scripts/install-codex-hooks.sh`（幂等合并 Codex hooks.json）、`scripts/verify.sh`（自检）、`scripts/backup.sh`（覆盖前带时间戳备份）、`scripts/bootstrap.sh`（新机一键装全局机制）。
- **被装资产新增**：`assets/dotfiles-layer/hooks/`（8 个 hook：注入×2/lint/guard/guard-bash/verify-on-stop/session-start/session-end；另有 `hook-emit.sh` 输出辅助脚本）、`assets/dotfiles-layer/agents/`（code-reviewer / spec-author 子 agent）、`assets/dotfiles-layer/claude-dotfiles.gitignore`；`assets/project-layer/.claude/commands/`（new-change / archive-change / adr / feature-spec / review）、`scripts/verify-local.sh`（L0 自验证骨架）、`docs/adr/`、`docs/plans/`、`openspec/changes/_template/`、`.editorconfig`。这些都在 manifest 里有条目，引擎遍历时自动落地。

---

## 流程（manifest 驱动）

安装器**不内嵌任何要素清单**——它遍历 `reference/manifest.md`，对每项 `detect → 缺则按 remediation_type 补救 → verify_after`。下面是这套循环的展开。

### 步骤 0 · 机器画像 + 加载 manifest + 探测现状
1. **机器画像**：先跑 `bash scripts/detect-env.sh <项目根>`，拿到 OS/arch、包管理器、jq 等前置、已装 AI 工具(Claude/Codex/Cursor)、skills 同步方式(cc-switch?)、dotfiles 载体、项目语言矩阵。**`jq` 缺失是阻断级**——先补它，否则整套 hook 机制静默空转。
2. **加载 manifest**：读 `reference/manifest.md`；按 `depends_on` 排序，用 `applies_when` 过滤**机器/语言层面**真正不适用的项（如某语言工具链在本项目无对象、本机无该 AI 工具），标 N/A。**不得按「预研/demo」等项目画像字样自动把可选要素（如 openspec）判 N/A**——这类项是否启用一律进步骤 0.4 批量征询交用户拍板。
3. **逐项 detect（四态）**：对每项跑其 detect，得 present/absent/incomplete/not-applicable。**区分 absent(缺) 与 incomplete(文件在但是占位符/空壳/不完整)**——后者走回填，不能当已存在跳过。
4. **确认意图**：把现状报告给用户，问：装/更新全局机制？给当前项目接入？（默认都做）需联网/破坏/写敏感区的项按 `requires_consent` 汇总成**一次**批量征询。**征询纪律**：对「按工作模式取舍」的项（如 openspec）给倾向性推荐前，**先按 `docs/DESIGN.md` §4.2 入口判据判工作模式**（需求驱动才上、改动驱动不上），不得用 §7 项目规模或「单仓自用」等画像字样代替判据；**工作模式判不出时中立呈现二选一、不预设推荐**。具体某项的取舍判据由 manifest 对应条目承载，本步只负责「先按判据判、不足则中立」这一通用动作。

### 步骤 1 · 补救 global 项（遍历 manifest 中 scope=global）
按各自 `remediation_type` 分发，代表性动作：
- `template-copy`：拷 `assets/dotfiles-layer/hooks/*.sh` → `~/.rig/hooks/` 作为多工具共享源；同步到 `~/.claude/hooks/` 作为 Claude Code 入口；拷 `conventions.md`（已存在则展示差异问合并，不覆盖个人内容）。
- `merge`：`bash scripts/merge-settings.sh ~/.claude/settings.json assets/dotfiles-layer/settings.json`（幂等去重、留 .bak、不丢既有 permissions）。
- `codex merge`：若机器画像检测到 Codex，`bootstrap.sh` 与 `rig init` 都会自动调用 `scripts/install-codex-hooks.sh`，确保 `~/.codex/hooks -> ~/.rig/hooks`，并幂等合并 `~/.codex/hooks.json`；不改 `~/.codex/config.toml`，末尾提示 `/hooks` trust。
- `install-command`：按机器画像选包管理器（**别假定 brew**）；装/补 skill 默认直接进工具自带 skills 目录(Claude=~/.claude/skills)；仅当该机用 cc-switch 等同步器才写同步源(detect-env 报告)。
- 末尾固定提示：**hook 变更需开新会话生效**。

### 步骤 2 · 补救 project 项（遍历 manifest 中 scope=project）
同样遍历 detect 为 absent/incomplete 的项。代表性：AGENTS.md(建或只补缺章)、CLAUDE.md(@AGENTS.md)、docs/conventions、lint-one.sh(按语言矩阵补分支)、openspec init、protected-paths、gitignore 一致性等。
**探测既有规则文件走 manifest 类别 R 的 rule-sources 数组**（AGENTS/CLAUDE/.cursorrules/.cursor/rules/copilot-instructions/GEMINI.md/…，新工具只往数组加一行）；凡发现→归并进 docs/conventions 并按三桶分类，原文件保留。

### 步骤 3 · 两类缺失的补救分发（核心）
步骤 3 不是独立清单——它就是步骤 0 探测为 absent/incomplete 的项的补救，按 `templatable` 分两条路：
- **3.A 可模板**（templatable=true，template-copy/merge/install-command）→ 引擎可自动落地（联网/破坏除外需同意），内容固定与项目无关。
- **3.B 项目专属·不可模板**（templatable=false，organize-existing/derive-from-code/author-with-user）→ **禁止凭模板伪造**，按阶梯：① `organize-existing` 把散落既有归并进权威单源（旧 .cursorrules/copilot-instructions → docs/conventions）→ ② 无则 `derive-from-code` 扫码推导草稿（从 pom/package.json 推 build/test/run、从模块结构推 architecture.md、从实体推术语表）→ ③ `author-with-user` 以**选择/确认题**而非填空题访谈定稿（回填 AGENTS 地图占位、补写 ADR、写 verify-local 命令、列项目红线）。安装器只负责"检测+识别候选+建骨架+发起"，内容以代码/用户为准。

### 步骤 3.1 · 补后复验与回滚
每项 remediate 后**重跑该项 detect（verify_after）**确认达成；merge 类额外 `jq empty` 校验且 permissions 不减，失败则从带时间戳备份回滚并标红。支持 `--dry-run` 只报不改。

### 步骤 4 · 验证 + 报告
- 跑 `bash scripts/verify.sh <项目根>`（hook 闭环自检）；并**遍历 manifest 逐项复跑 detect** 汇总最终状态。
- **报告清单**（逐项：期望→detect→动作→复验→待决）：新建了什么 / 合并了什么 / 跳过了什么 / 待用户决定（缺失 skill、linter 接入、占位符待回填、悬空软链等）。末尾固定提示"hook 变更需开新会话生效"。

---

## 禁忌
- 禁止整体覆盖已有 `AGENTS.md` / `CLAUDE.md` / `~/.claude/settings.json` / 项目 `.claude/settings.json`。
- 禁止删除既有规范内容（"整理"= 迁移 + 保留；清理须许可）。
- 禁止未经确认就联网安装或执行破坏性命令。
- **禁止在 SKILL.md 里硬编码要素清单**——任何新要素先进 `reference/manifest.md`。
- **禁止用模板伪造项目专属内容**（规范条目/域设计/ADR 决策/验收命令/红线）——templatable=false 的项必须 organize/derive/author。
- **install-command 禁止假定 brew**——按 detect-env 的包管理器选命令，未知平台降级输出手动指引。
- 路径可移植：全局脚本用 `$HOME`、项目脚本用 `$CLAUDE_PROJECT_DIR`，二进制用 `$(command -v …)`，**禁止写死 `/opt/homebrew` 等机器路径**。
