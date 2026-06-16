#!/usr/bin/env bash
# 新设备一键 bootstrap：把全局机制装到 ~/.claude（幂等）。在 rig/ 下跑：bash scripts/bootstrap.sh
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"   # skill 根目录
echo "== 0. 备份现有 ~/.claude（覆盖前留还原点；不存在的自动跳过）=="
bash "$here/scripts/backup.sh" "$HOME/.claude/hooks" "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/.claude/settings.json" "$HOME/.claude/conventions.md" 2>/dev/null || true
echo "== 1. 机器画像 =="
bash "$here/scripts/detect-env.sh" "$PWD" | sed -n '1,12p'
echo "== 2. 装全局 hook =="
mkdir -p "$HOME/.claude/hooks"
cp "$here"/assets/dotfiles-layer/hooks/*.sh "$HOME/.claude/hooks/" && chmod +x "$HOME/.claude/hooks/"*.sh
echo "  已拷 $(ls "$here"/assets/dotfiles-layer/hooks/*.sh | wc -l | tr -d ' ') 个 hook"
echo "== 2b. 装子 agent（code-reviewer / spec-author，/rig:review 等依赖）=="
mkdir -p "$HOME/.claude/agents"
cp "$here"/assets/dotfiles-layer/agents/*.md "$HOME/.claude/agents/"
echo "  已拷 $(ls "$here"/assets/dotfiles-layer/agents/*.md | wc -l | tr -d ' ') 个子 agent"
echo "== 2c. 装全局 /rig: 命令（init / doctor，任意项目可用）=="
mkdir -p "$HOME/.claude/commands"
cp -R "$here"/assets/dotfiles-layer/commands/* "$HOME/.claude/commands/"
echo "  已装 $(ls "$here"/assets/dotfiles-layer/commands/rig/*.md | wc -l | tr -d ' ') 个全局命令 (/rig:*)"
echo "== 2d. 注册 rig skill（软链到 ~/.claude/skills/rig，AI 可发现）=="
mkdir -p "$HOME/.claude/skills"
ln -sfn "$here" "$HOME/.claude/skills/rig"
echo "  已注册 ~/.claude/skills/rig -> $here"
echo "== 3. 全局个人偏好（不覆盖既有）=="
if [ -f "$HOME/.claude/conventions.md" ]; then echo "  已存在，跳过（如需合并请手动）"; else cp "$here"/assets/dotfiles-layer/conventions.md "$HOME/.claude/conventions.md"; echo "  已拷 conventions.md"; fi
echo "== 4. 合并 hooks 进 settings.json（幂等不覆盖）=="
ok4=0
if bash "$here/scripts/merge-settings.sh" "$HOME/.claude/settings.json" "$here/assets/dotfiles-layer/settings.json"; then
  n=$(jq '[(.hooks // {}) | to_entries[].value[]?.hooks[]?.command] | length' "$HOME/.claude/settings.json" 2>/dev/null || echo 0)
  if [ "${n:-0}" -ge 1 ]; then echo "  ✓ 已注册 ${n} 个 hook 命令"; ok4=1
  else echo "  ✗ 合并后未见 hook 注册——hook 不会触发！把本段输出贴给我排查。" >&2; fi
else
  echo "  ✗ merge-settings 失败——hook 未注册，整套机制不会触发！把本段输出贴给我排查。" >&2
fi
if [ "$ok4" -eq 1 ]; then echo "== 完成 =="; else echo "== 未完成：第 4 步失败（见上 ✗），hook 不会生效，先修这一步 =="; fi
echo "开新会话使 hook 与 /rig: 命令生效。建议把 ~/.claude/{hooks,agents,commands,settings.json,conventions.md} 纳入 dotfiles 仓库（用 assets/dotfiles-layer/claude-dotfiles.gitignore 挡机密）。"
