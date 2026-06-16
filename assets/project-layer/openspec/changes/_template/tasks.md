# 任务清单：<change-id>

> 与 `proposal.md` 配套。每完成一项勾选 `[x]`，让进度可被 review、可被 resume。

## 1. 理解差距

- [ ] 读 `proposal.md`，确认要解决的问题和边界
- [ ] 对照 `openspec/specs/<能力域>/` 现有 spec，确认当前行为
- [ ] 扫相关代码与 L3 feature-spec，确认现在怎么搭的
- [ ] 列出受影响的模块/接口/数据，确认改动范围
- [ ] 核对 `spec-delta`（## ADDED/MODIFIED/REMOVED Requirements）覆盖了全部目标行为

## 2. 实现

- [ ] <按 spec-delta 拆出第一条实现任务>
- [ ] <第二条……一条任务对应一处可独立验证的改动>
- [ ] 顺手清理被替换/废弃的旧逻辑（避免遗留死代码）

## 3. 写可执行验收

- [ ] 为每条 ADDED/MODIFIED Requirement 写对应的自动化测试
- [ ] 覆盖关键边界与失败路径，不只测 happy path
- [ ] 验收口径与 spec-delta 的描述一致，能直接证明"建对了"

## 4. 自验证（L0 Harness）

- [ ] 跑测试 / lint / 类型检查 / 构建，全部通过
- [ ] 在本地实际跑一遍改动路径，确认行为符合预期
- [ ] 确认没有破坏既有用例（回归通过）

## 5. 文档同步

- [ ] 更新受影响的 L3 feature-spec（事实层：现在怎么搭的）
- [ ] 涉及跨域决策"为什么"的，新增或更新 ADR，并在 feature-spec 链接它（不复制）
- [ ] 必要时更新 AGENTS.md（地图 / 行为基线 / 规范指针）

---

> 全部勾选后，运行 `/archive-change <change-id>` 归档：tasks 收尾、spec-delta 合并进 `openspec/specs/`。
