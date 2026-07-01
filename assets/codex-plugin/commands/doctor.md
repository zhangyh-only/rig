# /rig:doctor

检查当前项目的 rig 健康状态，并诊断失败原因。

## 触发条件

- 用户要求 `/rig:doctor`、`rig doctor`、检查 rig 健康状态、诊断 hook/skill/plugin/verify 接线。
- 用户反馈“装了但没生效”“命令找不到”“hook 没触发”“重复显示”“项目初始化后仍异常”。

## 边界

- 先只读诊断，不要一上来重跑 bootstrap、改配置或安装依赖。
- 联网安装、破坏性修改、覆盖配置前必须询问用户。
- “需要新会话生效”这类用户动作，要明确说出来，不要假装修好了。

## 必须动作

1. 运行 `rig doctor "$PWD"`；如果 `rig` 不在 `PATH` 中，定位 `rig` skill/package 根目录并使用其中的 `bin/rig`。
2. 报告验证分段，让用户能看清哪些检查通过、哪些失败。
3. 对失败项，先判断可能根因，再提出写入修改：
   - 缺少全局 bootstrap 或 hook 注册；
   - 缺少 `jq`；
   - hook 变更需要新会话才生效；
   - 当前项目还没有在当前 AI 工具中执行 `/rig:init`；
   - `scripts/lint-one.sh` / `scripts/verify-local.sh` 仍是占位或已损坏。
4. 对本地确定性修复，做最小安全修改后重新运行 `rig doctor`。
