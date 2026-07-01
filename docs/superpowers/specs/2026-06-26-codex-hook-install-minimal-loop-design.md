---
title: Codex 机制安装 — 注入+lint 最小闭环 设计
date: 2026-06-26
status: approved（brainstorming 定稿，待转实现计划）
owner: zhangyh
scope: 让 rig init --codex 真正给 Codex 装"编码前注入规范 + 改完 lint 拦"两个核心 hook
---

# Codex 机制安装：注入 + lint 最小闭环

## 1. 背景与动机

- **Codex CLI 现已支持完整生命周期 hook**：`PreToolUse` / `PostToolUse` / `PermissionRequest` / `UserPromptSubmit` / `Stop` / `SubagentStop` / `SessionStart` / `SubagentStart` / `PreCompact` / `PostCompact`，配置在 `~/.codex/hooks.json` 或 `config.toml` 的 `[hooks]` 表，支持 user/project/session 三层。来源：<https://developers.openai.com/codex/hooks>。
- **rig 现状是占位**：`bin/rig` 对 `tool != claude` 跳过全局机制、只 `scaffold_project` + echo "$tool 后续补"；`README.md:80` 写明"Codex / Cursor 仅 canonical + CI 兜底（`--codex` 暂为占位）"。这个判断是 **Codex 还没 hook 时写的，已过时**。
- **目标**：让 `rig init --codex` 真正给 Codex 装上两个最核心的闸——编码前注入规范、改完即时 lint 拦——验证 Codex 的 hook 协议能承载 rig 那套门禁。

## 2. 范围（最小闭环）

**做**：`UserPromptSubmit`（注入规范）+ `PostToolUse`（改完 lint）两个 hook 在 Codex 跑通。

**不做（YAGNI，验证协议后再铺）**：其余 hook（`guard` / `guard-bash` / `verify-on-stop` / `session-start` / `session-end` / `inject-active-spec`）、Codex skills 注册、`doctor` 的 Codex 自检。

## 3. 设计原则

1. **遵 Codex 官方惯用法，不照搬 Claude**（用户明确要求）：官方文档说 `exit 2` 是 *legacy convenience*，结构化 JSON `hookSpecificOutput` 才是 *documented standard*。
2. **单脚本自适应**（用户选定）：核心逻辑共享，输出层按目标 agent 分叉。
3. **单源**：全局规范读同一份 `~/.claude/conventions.md`（不复制）；hook 脚本物理一份，`~/.codex/hooks/` 软链到 `~/.claude/hooks/`。
4. **隔离**：Codex 注册用独立 `~/.codex/hooks.json`，**绝不动用户的 `config.toml`**（内含 rmcp / mode-injectors）。符合 Codex"一层一种表示"推荐。

## 4. 架构：核心共享 + 输出分叉

```
~/.claude/hooks/inject-conventions.sh   ← 同一份物理脚本
        ▲                       ▲
        │ (无参数 = claude)       │ (--codex)
  settings.json (Claude 注册)   ~/.codex/hooks.json (Codex 注册)
                                 ~/.codex/hooks → 软链到 ~/.claude/hooks
```

- 脚本开头：`MODE=claude; [ "$1" = "--codex" ] && MODE=codex`。
- 中段（找规范、判编码 prompt、调 `lint-one.sh`）**完全共享**。
- 结尾**按 MODE 选输出格式**。一处维护、两边不漂。

## 5. 两个 hook 的 Codex 形态（对照 Claude）

| hook | Claude 做法（现状） | Codex 惯用法（本设计） |
|---|---|---|
| `UserPromptSubmit` 注入 | 裸 stdout 文本 | `{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<规范全文>"}}` |
| `PostToolUse` lint 不过 | `exit 2` + stderr | `{"decision":"block","reason":"❌ 规范检查未通过:<文件>\n<问题清单>"}` |

- `decision:"block"` 的语义（官方原文）：*Codex records the feedback, **replaces the tool result with that feedback**, and continues the model from the hook-provided message* —— 比 exit2 回灌更准，强制模型按反馈当场修。
- 注册时给两条都配 `statusMessage`（"注入项目规范…" / "按规范检查改动…"）与 `timeout: 45`。

### 实现要点：先攒后输出
现有脚本是"边算边 echo"。改为**先把要注入的文本/lint 结果攒进变量，结尾按 MODE 统一输出**：
- Claude 模式：`printf` 文本到 stdout（注入）/ `exit 2` + stderr（lint）。
- Codex 模式：用 `jq -n --arg ... '{hookSpecificOutput:{...}}'` 组合法 JSON。

## 6. 输入适配（单脚本兼容两套字段）

| 要拿的 | Claude 字段 | Codex 适配（防御性多路 fallback） |
|---|---|---|
| 用户 prompt | `.prompt` | `.prompt // .user_prompt // .input`（**字段名待真实 Codex 验证**） |
| 改动文件 | `.tool_input.file_path` | `.tool_input.file_path` → 从 `apply_patch` 的 patch 解析 → `git diff --name-only`（**结构待真实 Codex 验证**） |
| 工作目录 | `.cwd` | `.cwd`（一致） |

两个"待验证"点用**防御性多路 fallback** 降低对单一字段确认的依赖，并在真实 Codex 跑通时定死。

## 7. 注册：`~/.codex/hooks.json`

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ {
        "type": "command",
        "command": "bash \"$HOME/.codex/hooks/inject-conventions.sh\" --codex",
        "statusMessage": "注入项目规范…",
        "timeout": 45
      } ] }
    ],
    "PostToolUse": [
      { "matcher": "apply_patch|Edit|Write",
        "hooks": [ {
          "type": "command",
          "command": "bash \"$HOME/.codex/hooks/lint-changed.sh\" --codex",
          "statusMessage": "按规范检查改动…",
          "timeout": 45
        } ] }
    ]
  }
}
```

- 独立文件，不碰 `config.toml`。
- `UserPromptSubmit` 不需要 matcher（官方：该事件忽略 matcher）。

## 8. trust（Codex 特有，安装必告知）

Codex CLI 中，非 managed 的 command hook 首次要在 `/hooks` 里 review + 信任（按 SHA hash；脚本变更需重新信任）。Codex Desktop App 当前普通会话不支持 `/hooks`，安装末尾必须把 CLI 与 Desktop 入口差异说清楚，否则容易出现"把 /hooks 当聊天消息发送"的误导。

## 9. `bin/rig --codex` 改动

`tool=codex` 分支从"只 scaffold + echo 占位"改为：
1. `scaffold_project`（不变）；
2. 确保 hook 脚本在 `~/.codex/hooks/`（软链到 `~/.claude/hooks/`，幂等）；
3. 写/幂等合并 `~/.codex/hooks.json` 的两条 hook（已存在不重复加、不覆盖既有）；
4. 打印 trust 提示。

全局 conventions 仍单源（读 `~/.claude/conventions.md`，不复制到 `~/.codex`）。

## 10. 环境约束（诚实记录）

本机 `codex` 二进制损坏（`codex --version` 报 `ENOENT`，vendor 下实际二进制缺失，疑需 `npm i -g @openai/codex` 重装）。因此**无法端到端用真实 Codex 跑闭环**。应对：
- 实现阶段用**模拟事件测试**：构造 Codex 风格事件 JSON 喂脚本，断言输出（`additionalContext` / `decision:block` 是合法 JSON、字段正确）。
- 第 6 节两个"待验证"字段先用防御性多路 fallback。
- **真实 Codex 端到端验证作为待办**，等本机 codex 修好（用户侧）再跑。

## 11. 测试策略

1. **单脚本双模式单测**：同一脚本分别喂 Claude 事件 / Codex 事件 JSON，断言两种输出格式各自正确。
2. **hooks.json 生成**：幂等性（重复跑不重复加）+ `jq empty` 校验合法 JSON。
3. **Claude 侧回归不破**：跑 `test/eval-demo.sh`（注入/lint 行为）+ `test/resolve-self.sh`（结构自洽），确保改脚本没破坏 Claude 路径。

## 12. 验收标准

最小闭环达成 =
- （本机可验）单脚本双模式单测通过 + `eval-demo.sh` Claude 侧回归全绿；
- （待环境）真实 Codex 跑通：编码 prompt 注入生效 + 故意违规被 `decision:block` 回灌、Codex 当场修。

## 13. 本次不做（YAGNI 边界）

其余 6 个 hook、Codex skills 注册、`doctor` 的 Codex 自检——等本闭环验证 Codex hook 协议可行后，再以同一"输出分叉 + 注册"范式逐个铺开。
