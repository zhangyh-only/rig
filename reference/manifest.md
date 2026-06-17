# reference/manifest.md — 声明式期望终态清单（Manifest）

> 本文件是安装器 `rig` 的**唯一数据源**。SKILL.md 的步骤 0（探测）与步骤 3（补齐）**不再硬编码任何清单**，而是遍历本文件逐项执行。新增/调整工作流要素时，**只改本文件，不改流程**——这就是"覆盖任意缺失"的结构性保证。
>
> **引擎是谁**：安装器 skill 被调用时，AI 按本清单逐项 `detect → 缺则 remediate → verify_after`。确定性子步骤（如 settings 合并）交给 `scripts/` 助手；判断性子步骤（整理、推导、访谈）由 AI 执行。
>
> **条目状态**：标 `[ready]` 的项今天就有对应 assets/脚本可直接落地；标 `[declared]` 的项是已声明的期望终态、但 asset/脚本待补（本清单是活的目录——任何"可能缺失"的东西都应在这里有一行，哪怕暂时只是 declared）。未标注的默认 ready。

## 安装器通用循环（引擎契约）

```
0. 加载 machine-profile（OS/arch、包管理器、已装工具 Claude/Codex/Cursor、skills 同步方式、dotfiles 是否 git 化、语言矩阵）—— 跑 scripts/detect-env.sh
1. 按 depends_on 拓扑排序；用 applies_when 过滤不适用项（标 N/A）
2. 对每一项：
   a. detect → 四态：present(0) / absent(1) / incomplete(2) / not-applicable(3)
   b. present 或 N/A → 记录、跳过
   c. absent 或 incomplete → 按 remediation_type 补救：
        - requires_consent 非空（network|destructive|secret-area）→ 汇总待批，统一一次性征询
        - --dry-run 只报不改
   d. 执行 remediation
   e. verify_after：再跑 detect 确认达成；失败 → 从带时间戳备份回滚 + 标红报告
3. 落盘结构化报告 .rig/install-report.json（逐项：期望→detect→动作→复验→待决）
4. 末尾固定提示：hook 变更需开新会话生效
```

### 两类缺失的处理差异（核心）

| 类别 | templatable | 补救路径 | 引擎行为 |
|---|---|---|---|
| **可模板**（机制脚本、目录骨架、模板文件、配置片段、黑名单、工具安装） | `true` | `template-copy` / `merge` / `install-command` | 可**自动**落地（联网/破坏性除外需同意），内容固定与项目无关 |
| **项目专属·不可模板**（真实规范条目、域设计、ADR 决策、验收命令、红线、占位符回填） | `false` | `organize-existing` / `derive-from-code` / `author-with-user` | **禁止凭模板伪造**。先 `organize-existing`（归并既有）→ 无则 `derive-from-code`（扫码推导草稿）→ 再 `author-with-user`（选择/确认题访谈定稿）。安装器只负责"建骨架 + 识别候选 + 发起"，内容以代码/用户为准 |

### detect 四态约定（退出码）
`0=present(已达成)` / `1=absent(缺失)` / `2=incomplete(存在但未达成，如占位符/不完整 change)` / `3=not-applicable(本项目/本机不适用)`。
**关键**：纯 `test -f/-d` 只能区分 present/absent；凡涉及"文件在但是空壳/占位符/不完整"的项，detect 必须额外判 incomplete（如 grep `<占位>`）。

### 字段语义
`id` · `what`（期望终态与缺失后果）· `detect`（四态探测）· `remediation_type` · `remediation` · `templatable` · `scope`(global/project/both)。引擎附加字段（表中省略，从 schema 取默认）：`applies_when`、`depends_on`、`requires_consent`、`verify_after`(默认=重跑 detect)。

---

## 类别 M · Manifest 引擎与契约（元层，scope=both）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| manifest-desired-state-file `[ready]` | 本文件存在并取代步骤0/3硬编码枚举 | skill 目录有 reference/manifest.md 且 SKILL 步骤0/3 为遍历式 | author-with-user | 维护本清单；SKILL 改遍历 | true |
| manifest-machine-profile `[ready]` | 机器画像探测层，据此为每项选 template-copy/install-command/跳过 | 跑 scripts/detect-env.sh 产出画像 | derive-from-code | 开场跑 detect-env.sh，结果供后续选策略 | true |
| detect-tristate-and-applicability | detect 四态+applies_when，否则对 demo 报假缺失、对空壳报已存在 | 条目 detect 含四态与 applies_when | author-with-user | 固化退出码约定与适用性表达式 | true |
| remediation-verify-and-rollback | 补后复验+失败回滚+dry-run，闭合幂等铁律 | 每项有 verify_after；有 --dry-run；merge 后 jq empty+permissions 不减 | author-with-user | 引擎统一 remediate→re-detect→pass记录/fail回滚 | true |
| consent-and-network-gating-model | 把联网/破坏/写敏感区建模为 requires_consent，批量统一征询 | 条目有 requires_consent；写操作前有统一同意点 | author-with-user | 同类需许可项汇总一次批确认 | true |
| installer-run-report-artifact `[declared]` | 结构化可重入报告 .rig/install-report.json，支持 --resume | 有报告产物且落盘 | template-copy | 每次运行写逐项状态，--resume 跳过已达成 | true |
| installer-version-and-migration `[declared]` | 版本戳 + 跨版本增量迁移 | ~/.claude/.rig-version、项目 .rig/version 存在 | template-copy | 安装写版本戳；引擎按版本差跑 migrations/ | true |
| package-manager-abstraction `[ready]` | install-command 按探测到的包管理器分发而非假定 brew | detect-env.sh 探测 brew/apt/dnf/pacman/winget；条目声明"包名"而非命令 | author-with-user | install-command 项声明包名，引擎按 profile 选命令；未知平台输出手动指引 | true |
| conflict-precedence-resolver | 多来源规范冲突裁决（项目>全局、canonical>派生、新>旧），归并遇矛盾不静默并列 | 归并时检测同主题矛盾 | author-with-user | 定优先级裁决表；冲突项标记让用户裁决，落 canonical 后派生物重生成 | false |
| detect-source-registry-extensible `[ready]` | 既有规则"探测源"做成可追加数组而非硬编码列举 | 本文件类别 R 的 rule-sources 即此数组 | author-with-user | 新工具只追加一行；探测=遍历该数组 | true |
| tool-adapter-registry `[ready]` | 工具适配表：每个已装工具如何消费 canonical | detect-env.sh 列 ~/.claude ~/.codex ~/.cursor + which copilot | author-with-user | 见类别 R 各 *-adapter 条目；引擎遍历已装工具逐个适配 | true |
| installer-self-bootstrap-into-skills `[ready]` | rig skill 注册进工具 skills 目录(Claude=~/.claude/skills/rig)，AI 可发现可调用 | test -L ~/.claude/skills/rig（缺则 absent） | organize-existing | bootstrap 直接软链 ~/.claude/skills/rig 指向克隆目录(不走 cc-switch) | false |
| installer-golden-fixture-test `[declared]` | 安装器自身回归测试：golden 夹具跑全流程+两遍幂等断言 | skill 下有 test/fixtures + run-on-fixture.sh | template-copy | 对空项目/已有.cursorrules/已有AGENTS/多语言 monorepo 夹具断言终态且二次无 diff（注：运行时 hook 链路的确定性评分部分已由 repo 根 `eval-demo.sh` 覆盖；本项余下范围=安装器幂等夹具，仍 declared） | true |
| backup-retention-and-restore `[ready]` | 带时间戳多层备份+restore；覆盖前 hash 比对 | 有 backups/<ts>/ + restore | template-copy | 写 ~/.claude/backups/<ts>/；覆盖前 hash 比对，有用户改动则提示 | true |

---

## 类别 P · 平台与可移植性（scope=both/global）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| platform-portability-paths `[ready]` | hooks/settings 路径平台无关（写死 /opt/homebrew/bin/node 即断） | grep -rE '/opt/homebrew\|/usr/local\|/Users/[^/]+/' settings.json hooks/*.sh→incomplete | merge | 硬路径改 $(command -v node)/$(brew --prefix)；hook 统一 $HOME | true |
| machine-local-vs-portable-split | settings 分流：portable 进 dotfiles，machine-local 留 settings.local.json | grep 机器绝对路径混入 portable 文件 | merge | merge-settings 增 portable/local 分流 | true |
| hooks-portability-path-convention `[ready]` | 全局 hook 用 $HOME、项目 hook 用 $CLAUDE_PROJECT_DIR | grep -E '/Users/[^/]+/\|/home/[^/]+/' settings.json | organize-existing | 改写为 $HOME/$CLAUDE_PROJECT_DIR | true |
| windows-wsl-portability `[declared]` | Windows 原生(无bash)/WSL 未建模 | detect-env.sh 探测 OS=Windows/WSL；hook 是否有 .ps1 等价物 | author-with-user | 提供 PowerShell 等价 hook 或要求 WSL/Git-Bash 并文档化 | false |
| language-neutral-detect-and-keywords | 注入触发词/章节锚点/桶标不假定中文，外置可配置（中英双列或结构锚点） | 审 hook case 关键词与 detect grep 是否硬编码单一语言 | author-with-user | 触发词/锚点/桶标提为可配置项；detect 用 HTML 注释锚点而非自然语言标题 | true |

---

## 类别 T · 前置工具链（scope=global/project，多按 applies_when 条件探测）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| jq-prerequisite `[ready]` | jq——所有 hook+merge-settings+verify 的硬前置，缺则整套机制静默空转（最隐蔽单点） | command -v jq | install-command | brew/apt install jq；步骤0显式探测，缺失升级为**阻断级** | false |
| prereq-toolchain-manifest `[ready]` | 新机器前置清单：node/npx/git/ripgrep/brew/jq 与各语言 linter 运行时 | detect-env.sh: for t in node npx git rg brew jq; do command -v $t; done | install-command | 带探测的 bootstrap 清单，逐项缺则给命令 | true |
| node-npx-runtime | Node+npx（openspec/eslint/dep-cruiser/husky） | command -v node && command -v npx | install-command | brew/nvm；按项目是否需 JS 工具或 openspec 条件探测 | false |
| bash-version-and-shell | bash 可用且版本足够（macOS 自带 3.2） | command -v bash; bash --version | install-command | 必要时 brew install bash；或核对仅用 3.2 兼容语法 | false |
| maven-runtime-and-plugins | Java 项目 mvn/gradle + checkstyle/surefire/archunit（仅 java 适用） | command -v mvn；pom grep 插件；或 gradlew | merge | pom 加 checkstyle 绑 verify；gradle 另适配 | false |
| python-go-runtime | Python/Go 运行时及各自 linter（按 pyproject/go.mod 适用） | command -v python3/go；有 pyproject/go.mod 才要求 | install-command | brew/官方安装；不需要的语言不报缺 | false |
| openspec-cli-available | openspec CLI（archive/validate/list 前提） | npx --no-install openspec --version \|\| command -v openspec | install-command | 缺则纳入批量征询问用户；同意即 `npm i -g openspec`，拒绝则标缺不铺 openspec/ | true |
| codex-prereq-install | Codex CLI/App + ~/.codex（仅当适配 Codex 时） | which codex \|\| ls /Applications/Codex.app；test -d ~/.codex | install-command | brew/官方安装 + 首次登录；auth.json 不进同步 | true |
| skill-sync-mechanism `[ready]` | skills 落地位置(默认工具自带目录 ~/.claude/skills;若用 cc-switch 等同步器才写同步源) | ls -la ~/.claude/skills/ \| grep '\->'；ls ~/.cc-switch/skills；grep skillSyncMethod | install-command | 默认直接装进 ~/.claude/skills(Claude);仅当该机确用 cc-switch 等同步器才改写同步源 | false |

---

## 类别 H · 全局 Hook 机制（scope=global，jq 为前置依赖）

> 通用拆分：每个 hook 须把"脚本存在且可执行"与"已在 settings.json 注册"当**两项独立 detect**，否则脚本在但从不触发的静默失效。

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| global-hooks-installed `[ready]` | 八个全局机制脚本就位可执行（脚本存在 与 已注册 是两项独立 detect） | for h in inject-conventions inject-active-spec lint-changed guard guard-bash verify-on-stop session-start session-end; do test -x ~/.claude/hooks/$h.sh; done | template-copy | 拷 assets/dotfiles-layer/hooks/*.sh + chmod +x | true |
| settings-hooks-registered `[ready]` | settings.json hooks 段已幂等注册全部机制命令 | jq 计数 .hooks 下命令 ≥4 且逐个命中 | merge | bash scripts/merge-settings.sh | true |
| settings-json-valid-after-merge `[ready]` | 合并后仍合法 JSON 且未破坏 permissions/其它 hooks | jq empty；对比 .bak permissions 条目数未减 | merge | merge 后 jq empty 校验，失败从 .bak 回滚 | true |
| hook-pretooluse-guard-protected-paths `[ready]` | PreToolUse(Edit\|Write\|MultiEdit) 红线拦截 | test -x guard.sh && jq PreToolUse 命中 | template-copy | 拷脚本+merge 注册 matcher | true |
| hook-posttooluse-lint-changed `[ready]` | PostToolUse 改完即 lint 回灌当场修 | test -x lint-changed.sh && jq PostToolUse 命中 | template-copy | 拷脚本+merge 注册 | true |
| stop-hook-verify-gate `[ready]` | Stop hook 跑 verify-local 把完成度守门（"没过不让收工"） | jq .hooks.Stop 非空；ls verify-on-stop.sh | template-copy | 新增 verify-on-stop.sh（调项目 verify-local.sh，无则静默跳过）+ merge | true |
| hook-sessionstart-context-bootstrap `[ready]` | SessionStart 注入会话级地图（活跃 change/分支/未读 ADR） | jq .hooks.SessionStart 非空 | template-copy | 新增 session-start.sh + merge | true |
| hook-sessionend-cleanup-reminder `[ready]` | SessionEnd 提示未归档 change/未沉淀 feature-spec/未提交 | jq .hooks.SessionEnd 非空 | template-copy | 新增 session-end.sh 扫时间戳输出待办 + merge | true |
| inject-active-spec-trigger-keywords | 编码意图关键词覆盖项目用语（英文项目"add endpoint"不触发则静默失效） | 审脚本关键词集 vs 项目惯用语；抽样测命中率 | author-with-user | 关键词外置为可配置文件随语言扩充 | false |
| inject-active-spec-output-unbounded `[ready]` | 全量 cat 多 change 无上界，长会话撑爆且放大死 change 误注入 | 放多个大 change 测输出字节数 | template-copy | 改只注入活跃 change（tasks 未全勾选）+ 超阈值降级摘要 | true |
| hook-failure-degradation-policy `[ready]` | 失败降级契约：无 jq/adapter/内容一律 exit 0 不阻断（写错成非0会阻断所有 prompt，高危） | printf 非编码 prompt \| inject-conventions.sh；echo $? 须 0 无输出 | template-copy | verify.sh 增三场景(非编码prompt/缺jq/缺adapter) 须 exit 0 断言 | true |
| bash-write-bypass-coverage `[ready]` | matcher 只盖 Edit\|Write\|MultiEdit，AI 用 Bash(sed -i/重定向)或 NotebookEdit 改源码即绕过（结构性逃逸） | 审 matcher；构造 Bash 写测是否触发 | author-with-user | Bash 加 PreToolUse 审查(写受保护路径则拦)+PostToolUse 补 lint；NotebookEdit 纳入 matcher | true |
| new-session-activation-reminder `[ready]` | settings hooks 变更只在新会话生效，当场测会"没反应"误判 | 安装后比对 settings mtime 是否晚于会话启动 | merge | verify 报告固定输出"hook 变更需开新会话生效" | true |

---

## 类别 S · 全局 settings.json（scope=both）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| settings-permissions-allowlist | permissions.allow 预批工作流命令（verify-local/lint-one/npx openspec/git），否则反复弹权限 | jq permissions.allow map(test("verify-local\|lint-one\|openspec")) any | merge | merge 工作流命令 allowlist（幂等去重不动既有） | true |
| settings-permissions-deny-secrets | permissions.deny 阻止读写 .env/密钥（与 guard 互补，作用在 Read 层） | jq permissions.deny map(test("env\|secret\|credential")) any | merge | merge deny: Read(./.env*)/Read(**/*secret*) | true |
| settings-env-vars | settings.env 设工作流依赖环境变量 | jq .env length>0 | merge | 按需 merge env 键值 | false |
| statusline-workflow-state `[declared]` | statusline 显示工作流态（活跃 change/分支/lint），可接 claude-hud | jq .statusLine.command | author-with-user | 配置 claude-hud 读 openspec/changes 或轻量脚本（个人偏好） | false |

---

## 类别 A · 子 agent（scope=global/project）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| subagent-code-reviewer `[ready]` | code-review 子 agent 收尾对 diff 做语义规则兜底（L4 遵守度/偏离度） | ls ~/.claude/agents/*.md \| grep -i review | template-copy | 新增 code-reviewer.md（注入 B 桶语义规则，输出偏离清单） | true |
| subagent-spec-author `[ready]` | feature-spec/openspec 起草子 agent，隔离长扫描不污染主线 | ls agents/*.md grep -Ei 'spec\|design' | template-copy | 提供 spec-author.md 包裹 feature-spec skill | true |
| subagent-verify-runner | L0 验证执行子 agent，构建日志不吃主上下文（项目专属命令） | ls 项目 agents/*.md grep -Ei 'verify\|test\|build' | author-with-user | 脚手架模板+访谈填本项目 build/test/run | false |

---

## 类别 C · slash command（scope=global/both）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| slash-command-new-change `[ready]` | /rig:new-change 一键起 openspec change 脚手架 | ls commands/rig/*.md grep -Ei 'change\|spec\|openspec' | template-copy | 新增 new-change.md | true |
| slash-command-archive-change `[ready]` | /rig:archive-change 合并 delta 进 specs 并提示毕业 ADR | ls commands/rig/*.md grep -Ei 'archive' | template-copy | 新增 archive-change.md | true |
| slash-command-write-adr `[ready]` | /rig:adr 统一模板起 ADR | ls commands/rig/*.md grep -i adr; test -d docs/adr | template-copy | 新增 adr.md + docs/adr 模板 | true |
| slash-command-feature-spec `[ready]` | /rig:feature-spec 显式触发 feature-spec skill | ls commands/rig/*.md grep -i 'feature-spec' | template-copy | 新增 feature-spec.md 调用 skill | true |
| slash-command-learn `[ready]` | /rig:learn 把踩坑沉淀成 lesson 并按三级进化（lesson→pattern→晋升）补"越用越聪明"环 | ls commands/rig/*.md grep -i learn | template-copy | 新增 learn.md：捕获进 docs/lessons.md（不注入）；晋升 A 桶进 lint-one、B 桶进 conventions，复用现有机制不加 hook，每级人工确认 | true |
| slash-command-review `[ready]` | /rig:review 收尾触发 code-reviewer 子 agent 做遵守度/偏离度/完成度语义复核 | ls commands/rig/*.md grep -i review | template-copy | 新增 review.md 调用 code-reviewer 子 agent | true |
| slash-command-rig-init `[ready]` | 全局 /rig:init —— 任意项目接入 rig 的入口(检测→装缺机制→铺骨架→交 AI 判断)；scope=global | test -f ~/.claude/commands/rig/init.md | template-copy | bootstrap 拷 assets/dotfiles-layer/commands/* → ~/.claude/commands/ | true |
| slash-command-rig-doctor `[ready]` | 全局 /rig:doctor —— 自检(verify.sh) + 诊断 ✗ 根因并列修复动作(经确认后修)；scope=global | test -f ~/.claude/commands/rig/doctor.md | template-copy | 同上(bootstrap 装全局命令) | true |

---

## 类别 K · skill 存在与完整性（scope=global/both）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| superpowers-installed | superpowers 在 skills 可用且 enabled（L2 brainstorm/write-plan/execute-plan 的执行体；**外部依赖、本安装器不随包交付**） | jq enabledPlugins superpowers；ls skills/superpowers；核对 brainstorm/writing-plans/executing-plans 技能文件可达 | install-command | 单独 marketplace install；装后自测三段技能可触发，否则只验目录会 present 误报 | true |
| feature-spec-skill-installed | feature-spec skill 可用（L3 后向沉淀执行体；迁移易漏） | ls skills/feature-spec/SKILL.md \|\| ~/.cc-switch/skills/ | install-command | 拷/装 feature-spec skill 目录 | true |
| skill-symlink-integrity `[ready]` | 工作流必需 skill 软链有效且目标存在（迁移/同步未完成时全悬空） | for l in ~/.claude/skills/*; do [ -L "$l" ] && [ ! -e "$l" ] && echo DANGLING; done | organize-existing | 重建软链指向目标(rig 克隆或同步源)；必需 skill 缺目标回退 template-copy 落实体 | false |
| codex-skill-registration | Codex 在 config.toml 用 [[skills.config]] 显式注册必需 skill（不自动扫描） | grep -A2 '\[\[skills.config\]\]' ~/.codex/config.toml 对照必需 skill | merge | 为每个必需 skill 幂等追加 [[skills.config]] 块 | true |
| skills-cursor-parity | Cursor 侧 skill 等价物或文档化缺位 | ls ~/.cursor/skills-cursor 对照必需能力清单 | author-with-user | 评估哪些需在 Cursor 落地，无法复用的引导重建或接受降级 | false |

---

## 类别 R · 规则文件 / canonical / 跨工具适配（scope=project/both）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| agents-md-canonical-exists `[ready]` | AGENTS.md 存在（L1 常驻上下文唯一来源） | test -f <proj>/AGENTS.md | template-copy | 拷 AGENTS.md 模板并提示填地图 | true |
| agents-md-required-sections `[ready]` | AGENTS.md 五章节齐（项目地图/行为基线/规范遵守/变更与沉淀/本地自验证） | grep 五个结构锚点 | merge | 只补缺失章节，保留原有（尤其用户已填地图） | true |
| agents-md-map-placeholders-filled | 项目地图占位符已填真实命令（占位=空地图） | grep -nE '<[^>]+>' 第1节；命令 dry-run | author-with-user | derive：从 package.json/pom/Makefile 推导 build/test/run 回填；定位句访谈确认 | false |
| agents-md-over-100-lines-or-stale | AGENTS.md ≤100 行且不与 conventions 重复 | wc -l >100；diff 出大段重复 | organize-existing | 详细规范下沉 docs/conventions，AGENTS 只留指针压回 100 行 | false |
| claude-md-imports-agents `[ready]` | CLAUDE.md 含 @AGENTS.md 单源引入 | grep -q '@AGENTS.md' CLAUDE.md | merge | 无→拷只含@AGENTS.md模板；缺行→补一行；已塞规范→建议并入 AGENTS | true |
| codex-agents-import | Codex 复用同一份 AGENTS.md；全局基线在 ~/.codex/AGENTS.md import | test -f ~/.codex/AGENTS.md | merge | 项目级共用 AGENTS.md；全局 ~/.codex/AGENTS.md 幂等加 @<全局 conventions> 导入 | true |
| cursor-project-mdc-rules | 从 canonical 派生 .cursor/rules/*.mdc（基线只读入不回写） | ls .cursor/rules/*.mdc .cursorrules | derive-from-code | 派生指针型 mdc（always-apply 指向 AGENTS.md） | true |
| copilot-instructions-derive | 从 canonical 派生 .github/copilot-instructions.md（仅当用 Copilot） | test -f；VS Code Copilot 扩展是否存在 | derive-from-code | 从 AGENTS 摘要派生（指针+关键基线） | true |
| cursorrules-legacy-detected-and-merged | .cursorrules（旧 Cursor）作为既有来源归并不丢弃 | test -f .cursorrules | organize-existing | 按三桶归并进 docs/conventions，原文件保留（可留薄壳指向 canonical） | false |
| other-tool-rule-files-detected | 其它工具规则文件穷举（Windsurf/Cline/Aider/Continue/Zed/GEMINI.md/通义/Qoder）——经 rule-sources 数组驱动 | 遍历探测源数组的 glob | organize-existing | 凡发现→正文归并三桶分类，原文件保留；需续用则收敛为指针 | false |
| global-conventions-single-source `[ready]` | ~/.claude/conventions.md 个人全局基线单一真相，被所有工具引用不复制 | test -f ~/.claude/conventions.md | template-copy | 不存在→拷模板；建立后让 Codex import、Cursor 派生形成单源多引用 | true |
| cross-device-drift-check `[declared]` | canonical 与各工具派生物漂移检查 | test -x check-rules-drift.sh 或 verify 比对源指纹 | template-copy | 扩展 verify 或新增 check-rules-drift.sh 校验派生物源指纹未过期 | true |

> **rule-sources 数组**（探测既有规则的来源，新工具只加一行）：`AGENTS.md` · `CLAUDE.md` · `.cursorrules` · `.cursor/rules/*.mdc` · `.github/copilot-instructions.md` · `.github/instructions/*` · `GEMINI.md` · `.windsurfrules` · `.clinerules` · `.aider.conf.yml` · `.continue/*` · `memory-bank/conventions/*` · `docs/conventions/*` · `README` 规范段。

---

## 类别 V · docs/conventions 三桶（scope=project）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| docs-conventions-dir-exists `[ready]` | docs/conventions/ 存在（inject-conventions 固定注入路径） | test -d docs/conventions && ls *.md | template-copy | 拷 docs/conventions 模板（README+code+structure） | true |
| docs-conventions-readme-buckets-guide `[ready]` | README.md 三桶分流元指南 | test -f docs/conventions/README.md 且含三桶表 | template-copy | 拷 README.md 模板 | true |
| scattered-conventions-not-collected | 散落规范（README/wiki/注释/PR/旧规则文件）尚未归集到权威单源 | 存在散落来源但 docs/conventions 为空/占位 | organize-existing | 逐条归并进 docs/conventions/{code,structure}.md 打 A/B/C 桶，原位置保留加指针 | false |
| conventions-still-placeholder | code.md/structure.md 非占位、有真实规则、每条标桶（空壳=AI 守了个寂寞） | grep '<.*>'/'按本项目实际填写' 仍占位→incomplete | author-with-user | 优先 organize-existing；无则 derive-from-code 给候选规则→选择/确认题让用户定稿打桶标 | false |
| conventions-bucket-a-has-linter-binding | A 桶规则真正编译进 linter/架构测试（未编译则降级 B 桶，丢硬保证） | 标 [A 桶] 条数>0 但检查器配置缺失/未接 lint-one | author-with-user | 逐条映射到本语言检查器规则项，生成/合并配置接进 lint-one+CI | false |
| missing-domain-glossary | 领域术语表（核心实体/状态机/缩写/表名↔域名）——B 桶项目专属 | 无 docs/conventions/glossary.md；代码多缩写无解释 | derive-from-code | 从实体类名/枚举/表结构推导候选→author-with-user 补释义 | false |

---

## 类别 L · linter / formatter / 架构测试（scope=project）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| lint-one-adapter-present `[ready]` | scripts/lint-one.sh 语言适配器（PostToolUse 回灌落点） | test -x $PROJECT/scripts/lint-one.sh | template-copy | 拷模板+chmod+x；补"探测语言→预填分支"派生 | true |
| lint-one-branch-matches-project-langs | lint-one.sh case 分支覆盖项目真实语言（模板只 java/ts/py/go，其余落 *)exit0） | 对比 git ls-files 扩展名集合 vs 已有 case | derive-from-code | 为缺失语言追加分支（kotlin→ktlint、rust→clippy、scala→scalafmt、php→phpcs、swift→swiftlint、sql→sqlfluff、sh→shellcheck）；新检查器命令确认 | false |
| linter-binary-installed-per-lang | 每语言 linter 可执行本机可用，未装显式报出而非静默 | 对每语言 command -v；mvn 查 checkstyle 插件 | install-command | ruff/golangci-lint/eslint/checkstyle 各装；逐语言探测+报告 | false |
| linter-config-file-present | linter 规则配置存在且被适配器引用（A 桶物化载体） | 按语言查 checkstyle.xml/.eslintrc/ruff.toml/.golangci.yml 且 lint-one 指向它 | author-with-user | 无→提供最小起步模板再编译 A 桶规则；有→organize 接上适配器 | false |
| editorconfig-exists `[ready]` | .editorconfig 最底层格式硬约束（A 桶零成本地基） | test -f .editorconfig | template-copy | 拷按语言预设模板 | true |
| formatter-config-present | 格式化器配置（prettier/gofmt/black-ruff format/rustfmt） | 按语言查格式化配置 | template-copy | 拷格式化配置模板 + lint-one 加 format 分支 | true |
| project-lint-batch-mode | lint-one 批量入口（CI/pre-commit 复用同一适配器，避免双源漂移） | lint-one 是否支持无参/--all/多文件 | template-copy | 加批量分发包装（遍历 git diff 或全量），三处共用 | true |
| arch-test-present | 架构/依赖归属测试（ArchUnit/dep-cruiser/import-linter/depguard） | Java grep ArchUnit；JS .dependency-cruiser.js；Py .importlinter；Go .go-arch-lint.yml | author-with-user | 提供各语言架构测试起步骨架，具体边界规则 derive+author | false |
| missing-module-dependency-rules | 模块依赖矩阵/方向规则（gateway 不许依赖 common-data，A 桶硬基准） | structure.md 依赖矩阵占位；多模块无依赖约束测试 | derive-from-code | 静态分析扫实际依赖图→用户区分现状/期望→写进 structure.md(A桶)+生成架构测试骨架接 lint-one/CI | false |
| secret-scan-gate | 密钥扫描闸（gitleaks/detect-secrets，lint/架构测试都不覆盖） | pre-commit/CI 是否含 gitleaks；command -v gitleaks | install-command | 加 gitleaks 进 pre-commit+CI | true |

---

## 类别 G · git hooks / CI（scope=project）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| git-pre-commit-hook | 仓库级 pre-commit/pre-push（跨 AI 工具的强制力，活在仓库不随工具走） | ls .git/hooks/pre-commit(非.sample) 或 .husky/.pre-commit-config.yaml/lefthook.yml | install-command | 推荐 pre-commit 框架或 husky/lefthook；具体 hook 按语言派生 | true |
| ci-required-check-defined | CI workflow 跑 lint+架构测试+构建（三道闸第三道） | ls .github/workflows/*.yml/.gitlab-ci.yml/Jenkinsfile 且含 lint/test/verify | template-copy | 按平台提供 workflow 模板跑 lint-one 批量+架构测试+verify-local | true |
| ci-required-check-enforced-on-branch | CI 设为 branch protection required check（否则红了也能合并） | gh api branches/{default}/protection 看 required_status_checks | author-with-user | gh api 设置（需 admin）或输出"Settings→Branches 勾选"引导 | false |
| openspec-validate-gate | openspec validate --all 进 CI/收尾 gate | grep 'openspec validate' .github/workflows | merge | 向 CI 幂等追加 openspec validate --all 步骤 | true |

---

## 类别 SP · spec / openspec / ADR / feature-spec（scope=project）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| openspec-dir-initialized | openspec/ 骨架（**是否启用由用户在批量征询里定，别按"预研"字样自动判 N/A**） | test -d openspec/changes && test -d openspec/specs && test -f openspec/project.md | install-command | 缺则进批量征询问用户：要→`npm i -g openspec` + `npx openspec init` + 拷模板；不要→跳过不铺 | true |
| openspec-active-change-wellformed `[declared]` | 进行中 change 结构完整（proposal/tasks/spec-delta），不完整则注入残缺 | 遍历 changes/*/ 测三件套→incomplete | author-with-user | 脚手架补缺占位骨架并访谈填写；openspec validate <change> 作探测器 | true |
| openspec-change-template `[ready]` | change 提案模板（proposal/tasks/spec-delta 骨架），解决"不知写什么" | ls assets/.../openspec/changes/_template | template-copy | **门控**：仅当用户在批量征询里同意启用 openspec 且 CLI 已装时，随 `openspec init` 一起拷入；用户不要或 CLI 缺则**不铺**。机械层 `rig init` 不再无条件铺 | true |
| openspec-project-md-grounded | project.md 填真实信息非 init 默认占位 | grep -qiE 'TODO\|<.*>\|占位' openspec/project.md→incomplete | derive-from-code | 从 AGENTS 地图+构建文件推导技术栈/命令回填，再访谈补约定 | false |
| openspec-archive-lifecycle | 完成的 change 跑 archive（否则死 change 持续误注入膨胀上下文） | find changes 非 archive 子目录 tasks 全勾选却未归档→STALE | author-with-user | 归档约定文档+可选 Stop hook 提示；引导跑 openspec archive | true |
| adr-dir-and-template `[ready]` | docs/adr/ + ADR 模板 + 空索引 README（why 唯一权威终点） | test -d docs/adr && ls docs/adr/0000-template.md | template-copy | assets 提供 ADR 模板（MADR 精简）+ README 空索引（首条从 0001 起，用 /adr 创建） | true |
| missing-adr-decisions-why | 已发生重大决策补写 ADR（散见 commit/PR/注释） | docs/adr 为空但代码/历史有明显架构决策 | author-with-user | 模板可拷；扫历史列候选决策让用户逐条确认补写（内容不可伪造） | true |
| feature-specs-dir-exists | docs/feature-specs/ 目录（L3 落点+memory-bank 迁移目标） | test -d docs/feature-specs | organize-existing | mkdir + 迁旧 memory-bank/project/feature-specs（属 memory-bank 退役，迁后随整目录删除）；新建用 feature-spec skill derive | true |
| missing-domain-design-docs | 业务域设计文档 docs/feature-specs/<domain>.md（as-built 真相） | docs/feature-specs 空但存在明显业务域 | derive-from-code | 调 feature-spec skill 新建模式扫码生成；安装器只检测+识别候选域+建目录+发起 | false |
| missing-architecture-map-doc | docs/architecture.md（AGENTS 地图指向的模块详表，悬空则地图断在指针） | AGENTS grep 'docs/architecture.md' 但文件缺→incomplete | derive-from-code | 扫目录/模块/构建文件 derive 模块→职责→依赖草表交用户确认；或去掉悬空指针 | false |
| plan-template `[ready]` | 计划模板（目标/范围/步骤/验收/受影响文件/回滚） | ls docs/plans/_template.md | template-copy | 新增 plan 模板含"验收标准必须可执行"栏 | true |
| missing-acceptance-scripts-for-specs | 每变更可执行验收脚本/测试（L4 完成度=命中率，否则退化为自报） | change tasks.md 有但无对应验收脚本/测试 | author-with-user | 验收脚本骨架+引导把验收标准翻成可执行断言纳入 verify-local/mvn verify | true |
| missing-deviation-baseline-config | 偏离度以 change 范围为硬基准的接法+项目允许改动面 | grep '偏离度\|deviation\|change.*scope' scripts .claude | author-with-user | 收尾评分 prompt 读 change 范围+git diff 算偏离；引导声明允许改动面落 structure.md | true |
| verify-local-script | scripts/verify-local.sh（L0 地基：compile→test→smoke，AGENTS 引用但本体缺） | test -x $PROJECT/scripts/verify-local.sh；AGENTS §4 引用但文件不存在→incomplete | author-with-user | 提供分阶段骨架；按五方法论 derive+访谈填实际命令/Profile 隔离 | true |
| feature-spec-adr-link-discipline | feature-spec 只链接 ADR 不复制 why（防 why 漂移） | grep -rL 'docs/adr\|ADR-' docs/feature-specs/*.md 含决策叙述却不引用 | author-with-user | 模板决策章固化为"仅链接 ADR"占位；引导改造既有域文档 | false |

---

## 类别 PC · 项目约定 / 红线 / gitignore / 迁移（scope=project）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| protected-paths-customized | .claude/protected-paths.txt 项目专属红线（生成 mapper/迁移脚本/密钥/生产配置/vendored） | test -f .claude/protected-paths.txt；项目有敏感路径却未登记→incomplete | author-with-user | 拷模板后扫候选敏感路径列给用户确认写入（项目专属不可伪造） | false |
| gitignore-covers-protected-and-secrets | .gitignore 覆盖生成物/构建产物/L0 本地产物/密钥，与 guard 红线一致 | test -f .gitignore；grep target/build/node_modules/dist/.env | merge | 幂等补缺失条目，与 protected-paths 一致，不删既有 | true |
| gitignore-and-protectedpaths-cosource | 工作流本地产物（.rig/、install-report、.bak、@Profile(local)）进 gitignore 且与 protected 同源 | grep .rig/ install-report .bak 是否在 gitignore | merge | 幂等补工作流本地产物进 gitignore 与 protected，双向对齐 | true |
| global-conventions-md-exists `[ready]` | ~/.claude/conventions.md 全局个人偏好（含 karpathy 四原则，inject 第一段） | test -f ~/.claude/conventions.md | template-copy | 不存在→拷模板；已存在→展示差异问合并不覆盖 | true |
| stale-pointer-integrity | 交叉指针完整性（AGENTS→conventions/architecture/verify-local、feature-spec→ADR、CLAUDE→AGENTS）无悬空 | 解析相对路径与 @import 逐一 test -e | organize-existing | 报告所有悬空指针；按情况创建目标或修正/删除指针 | false |
| memory-bank-legacy-not-migrated | 旧 memory-bank/ 退役：按映射迁到新结构后**整目录删除**（用户已退役该个人模式） | test -d memory-bank | organize-existing | conventions→docs/conventions 打桶标(以代码核对)、project/feature-specs→docs/feature-specs、project/{architecture,modules,tech-stack,runtime} 关键事实折进 AGENTS §1 地图(详细手写版不留)、tasks/+README 丢弃；迁完 `rm -rf memory-bank/`——用户已授权的标准退役动作，git 可找回、删除进 diff 可审 | false |
| dotfiles-vcs-repo | ~/.claude 可移植部分有版本化 dotfiles 载体（否则换机只能手工重建） | git -C ~/.claude rev-parse \|\| which chezmoi stow yadm \|\| ls ~/dotfiles | author-with-user | 与用户确认载体（裸 git/chezmoi/stow），纳入 hooks/conventions/portable settings | false |
| dotfiles-secrets-gitignore `[ready]` | dotfiles 同步前 .gitignore 挡机密/机器态（auth.json/history.jsonl/sessions/telemetry/settings.local.json） | grep auth.json/history.jsonl/settings.local.json in <dotfiles>/.gitignore | template-copy | 拷固定黑名单 claude-dotfiles.gitignore 并 merge | true |
| dotfiles-bootstrap-installer `[ready]` | 一键 bootstrap（拉 dotfiles→落地→merge→触发 skill 同步→verify，全程幂等） | ls <dotfiles>/{install.sh,bootstrap.sh,Brewfile} | template-copy | 提供 bootstrap.sh 模板，少量机器特定钩子留占位 | true |

---

## 类别 MCP · MCP server（scope=project，纯项目专属）

| id | what | detect | remediation_type | remediation | templatable |
|---|---|---|---|---|---|
| mcp-servers-project | 项目级 .mcp.json 登记工作流需要的 MCP（issue/DB/docs 供 spec 取数；applies_when=项目需要） | test -f <proj>/.mcp.json \|\| ~/.claude/.mcp.json；claude mcp list | author-with-user | 访谈需要哪些 MCP，脚手架 .mcp.json 条目（项目专属不可模板） | false |
| mcp-server-trust-scope | .mcp.json 存在但未在 settings 标信任/启用则不加载 | test -f .mcp.json && jq enableAllProjectMcpServers \|\| enabledMcpjsonServers length>0 | merge | merge enabledMcpjsonServers 或 enableAllProjectMcpServers 进 settings | false |
