# 安装手册 —— AI Coding 工作流

本目录 `rig/` 就是**完整、自包含的资源包**，也是一个 **skill**。
两条安装路径：**AI 辅助（推荐）** 与 **人工**。两者都幂等、合并不覆盖。

```
rig/                  ← 整个包 = 一个 skill
├── SKILL.md                         安装器大脑（探测→合并→整理→补缺→验证）
├── INSTALL.md                       本手册
├── reference/manifest.md            期望终态清单（唯一数据源；安装器遍历它逐项 detect→remediate）
├── scripts/                         安装期助手（skill 自己跑，非被装）
│   ├── detect-env.sh                机器画像：OS/包管理器/jq/已装工具/cc-switch/语言矩阵
│   ├── merge-settings.sh            幂等合并 hooks 进 settings.json，不覆盖既有
│   ├── backup.sh                    覆盖前带时间戳备份
│   ├── bootstrap.sh                 新机一键装全局机制
│   └── verify.sh                    安装后自检（注入/红线/settings/降级/新 hook）
└── assets/
    ├── dotfiles-layer/              → 全局机制（装到 ~/.claude）
    │   ├── settings.json            hooks 片段（合并进 ~/.claude/settings.json）
    │   ├── conventions.md           → ~/.claude/conventions.md（全局个人偏好）
    │   ├── claude-dotfiles.gitignore  dotfiles 同步挡机密/机器态
    │   ├── hooks/                    8 个：inject-conventions / inject-active-spec / lint-changed /
    │   │                             guard / guard-bash / verify-on-stop / session-start / session-end
    │   └── agents/                   code-reviewer / spec-author 子 agent
    └── project-layer/               → 项目内容（接入到某个 repo）
        ├── AGENTS.md / CLAUDE.md     地图+基线+指针 / @AGENTS.md
        ├── .claude/commands/         /new-change /archive-change /adr /feature-spec /review
        ├── .claude/                  protected-paths.txt / settings.example.json（可选覆盖+红线）
        ├── scripts/                  lint-one.sh（语言适配）+ verify-local.sh（L0 自验证骨架）
        ├── docs/conventions/         规范全文（三桶分流）
        ├── docs/adr/  docs/plans/    ADR 模板+索引 / 计划模板
        ├── openspec/changes/_template/  change 三件套模板
        └── .editorconfig             格式底层约束
```

---

## 路径一：AI 辅助安装（推荐，一步到位）

1. 把整个 `rig/` 复制进你的 skills 目录：
   - 标准 Claude Code：`~/.claude/skills/rig/`
   - 若用 cc-switch：`~/.cc-switch/skills/rig/`
2. 开一个新会话，在**目标项目**里对 AI 说：「**安装这套 AI coding 工作流**」。
3. AI 会按 `SKILL.md`：探测现状 → 问你装全局机制 / 接入本项目 → **合并**（不覆盖）安装 → **整理**项目已有规范 → 补齐缺失 skills/工具 → 跑验证并报告。

> 换新设备：第 1 步复制一次，之后每个项目里说一句"安装工作流"即可——全局机制装一次、项目内容逐个接入，都自动幂等处理。

---

## 路径二：人工安装

### 全局机制（每台机器一次）
```bash
mkdir -p ~/.claude/hooks
cp assets/dotfiles-layer/hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
# 子 agent（code-reviewer / spec-author）→ ~/.claude/agents（/review 依赖它，勿漏）
mkdir -p ~/.claude/agents
cp assets/dotfiles-layer/agents/*.md ~/.claude/agents/
# 全局个人偏好：不存在才拷，已有则手动合并（勿覆盖）
[ -f ~/.claude/conventions.md ] || cp assets/dotfiles-layer/conventions.md ~/.claude/conventions.md
# 合并 hooks 进 ~/.claude/settings.json（幂等、不覆盖既有 permissions/其它 hooks，自动备份 .bak）
bash scripts/merge-settings.sh ~/.claude/settings.json assets/dotfiles-layer/settings.json
# 开新会话使 hook 生效
```
建议把 `~/.claude/{hooks,settings.json,conventions.md}` 纳入个人 dotfiles git 仓库，换机器 clone 即可。

### 项目接入（每个项目一次，注意合并）
```bash
P=<项目根>
# AGENTS.md / CLAUDE.md：不存在才拷；已存在则把模板里缺的章节【手动并入】，勿覆盖
[ -f $P/AGENTS.md ] || cp assets/project-layer/AGENTS.md $P/AGENTS.md
[ -f $P/CLAUDE.md ] || cp assets/project-layer/CLAUDE.md $P/CLAUDE.md   # 内容仅 @AGENTS.md
# 脚本：语言适配器 + L0 自验证骨架
mkdir -p $P/scripts && cp -n assets/project-layer/scripts/*.sh $P/scripts/ && chmod +x $P/scripts/*.sh
# slash 命令 + 红线
mkdir -p $P/.claude && cp -rn assets/project-layer/.claude/commands $P/.claude/
cp -n assets/project-layer/.claude/protected-paths.txt $P/.claude/ 2>/dev/null
# docs：规范三桶（把既有规范归并进来）+ ADR + plan 模板
mkdir -p $P/docs && cp -rn assets/project-layer/docs/conventions assets/project-layer/docs/adr assets/project-layer/docs/plans $P/docs/
# 格式底层 + openspec change 模板
cp -n assets/project-layer/.editorconfig $P/ 2>/dev/null
npx openspec init        # 已有 openspec/ 则跳过
mkdir -p $P/openspec/changes && cp -rn assets/project-layer/openspec/changes/_template $P/openspec/changes/
# 接好本语言 linter（checkstyle.xml/.eslintrc/...）并在 CI 设 required check
# 注意：完整清单以 reference/manifest.md 为准；AI 辅助路径会自动按 manifest 补齐
```

---

## 验证（两条路径都适用）
```bash
bash scripts/verify.sh <项目根>     # 六段检查：注入 / 红线拦 / 红线放 / settings 注册 / 失败降级 / 新 hook 行为
# 地雷验收：故意写一行违规代码，确认 lint-changed.sh 拦回让 AI 修
# 或 claude --debug 看 hook 触发
```

## 换 AI 工具（Codex / 通义灵码…）
- 可平移：`docs/conventions/`、`scripts/lint-one.sh`、linter 配置、`AGENTS.md`、`openspec/`、CI。
- 要换：`~/.claude/hooks` 的注入触发 → 新工具等价机制（Cursor 用 glob 规则；Codex 原生读 AGENTS.md）。
- 不变：`mvn verify` / CI required check 与工具无关，照样兜底。
