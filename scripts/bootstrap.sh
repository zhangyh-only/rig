#!/usr/bin/env bash
# 新设备一键 bootstrap：把全局机制装到 ~/.claude（幂等）。在 rig/ 下跑：bash scripts/bootstrap.sh
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"   # skill 根目录
echo "== 1. 机器画像 =="
bash "$here/scripts/detect-env.sh" "$PWD" | sed -n '1,12p'
echo "== 2. 装全局 hook =="
mkdir -p "$HOME/.claude/hooks"
cp "$here"/assets/dotfiles-layer/hooks/*.sh "$HOME/.claude/hooks/" && chmod +x "$HOME/.claude/hooks/"*.sh
echo "  已拷 $(ls "$here"/assets/dotfiles-layer/hooks/*.sh | wc -l | tr -d ' ') 个 hook"
echo "== 2b. 装子 agent（code-reviewer / spec-author，/review 等依赖）=="
mkdir -p "$HOME/.claude/agents"
cp "$here"/assets/dotfiles-layer/agents/*.md "$HOME/.claude/agents/"
echo "  已拷 $(ls "$here"/assets/dotfiles-layer/agents/*.md | wc -l | tr -d ' ') 个子 agent"
echo "== 3. 全局个人偏好（不覆盖既有）=="
if [ -f "$HOME/.claude/conventions.md" ]; then echo "  已存在，跳过（如需合并请手动）"; else cp "$here"/assets/dotfiles-layer/conventions.md "$HOME/.claude/conventions.md"; echo "  已拷 conventions.md"; fi
echo "== 4. 合并 hooks 进 settings.json（幂等不覆盖）=="
bash "$here/scripts/merge-settings.sh" "$HOME/.claude/settings.json" "$here/assets/dotfiles-layer/settings.json"
echo "== 完成 =="
echo "开新会话使 hook 生效。建议把 ~/.claude/{hooks,settings.json,conventions.md} 纳入 dotfiles 仓库（用 assets/dotfiles-layer/claude-dotfiles.gitignore 挡机密）。"
