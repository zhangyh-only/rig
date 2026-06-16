---
description: 对当前项目跑 rig 自检（注入/红线拦/闸/失败降级），报告绿不绿。全局命令。
---

对**当前项目**跑 rig 安装后自检：执行 `rig doctor`（或 `~/.claude/skills/rig/scripts/verify.sh "$PWD"`），把六段结果原样汇报——注入是否命中 `docs/conventions`、红线 `guard` 拦/放、`settings.json` 是否注册 hook、失败降级、新 hook 行为。有 ✗ 就指出哪条 + 可能原因（多半是项目还没接 `lint-one`/`verify-local`，或 hook 变更没开新会话）。只读、不改文件。
