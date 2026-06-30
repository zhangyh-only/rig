#!/usr/bin/env bash
# 新设备一键 bootstrap：把全局机制装到 ~/.claude（幂等）。在 rig/ 下跑：bash scripts/bootstrap.sh
set -u
# 解析真实包根:经 skill 软链(~/.claude/skills/rig)或 PATH 软链调用也要落到真实克隆,
# 否则下面 2d 的 ln 会把软链指向它自己成环(Too many levels of symbolic links)。
__src="${BASH_SOURCE[0]:-$0}"
while [ -h "$__src" ]; do
  __dir="$(cd -P "$(dirname "$__src")" && pwd)"
  __src="$(readlink "$__src")"
  case "$__src" in /*) ;; *) __src="$__dir/$__src" ;; esac
done
here="$(cd -P "$(dirname "$__src")/.." && pwd)"   # skill 根目录(真实物理路径)
# 前置硬门:jq 是阻断级——settings 合并/注入/红线判断全靠它。缺了就提前干净退出,
# 别让后面的 cp/ln 装出"半装的死 harness"(hook 都在、却一个都不注册触发)。
if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then __ic="brew install jq"
  elif command -v apt >/dev/null 2>&1; then __ic="sudo apt install -y jq"
  elif command -v dnf >/dev/null 2>&1; then __ic="sudo dnf install -y jq"
  elif command -v yum >/dev/null 2>&1; then __ic="sudo yum install -y jq"
  elif command -v pacman >/dev/null 2>&1; then __ic="sudo pacman -S jq"
  else __ic="用你的包管理器安装 jq"; fi
  echo "✗ 缺 jq（阻断级）——整套 hook 机制依赖它(settings 合并/规范注入/红线判断)。" >&2
  echo "  先装再重跑:$__ic" >&2
  echo "  (未做任何改动就退出,避免半装。)" >&2
  exit 1
fi
echo "== 0. 备份现有全局机制（覆盖前留还原点；不存在的自动跳过）=="
bash "$here/scripts/backup.sh" "$HOME/.rig/hooks" "$HOME/.claude/hooks" "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/.claude/settings.json" "$HOME/.claude/conventions.md" 2>/dev/null || true
echo "== 1. 机器画像 =="
bash "$here/scripts/detect-env.sh" "$PWD" | sed -n '1,12p'
echo "== 2. 装全局 hook =="
mkdir -p "$HOME/.rig/hooks"
cp "$here"/assets/dotfiles-layer/hooks/*.sh "$HOME/.rig/hooks/" && chmod +x "$HOME/.rig/hooks/"*.sh
echo "  已拷 $(ls "$here"/assets/dotfiles-layer/hooks/*.sh | wc -l | tr -d ' ') 个 hook/辅助脚本到 ~/.rig/hooks（多工具共享源）"
mkdir -p "$HOME/.claude/hooks"
cp "$here"/assets/dotfiles-layer/hooks/*.sh "$HOME/.claude/hooks/" && chmod +x "$HOME/.claude/hooks/"*.sh
echo "  已同步到 ~/.claude/hooks（Claude Code 入口）"
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
if [ "$here" = "$HOME/.claude/skills/rig" ]; then
  echo "  ⚠ 包根解析成软链自身,跳过注册以防自环(请用真实克隆路径运行)" >&2
else
  ln -sfn "$here" "$HOME/.claude/skills/rig"
  echo "  已注册 ~/.claude/skills/rig -> $here"
fi
echo "== 3. 全局个人偏好（不覆盖既有）=="
if [ -f "$HOME/.claude/conventions.md" ]; then echo "  已存在，跳过（如需合并请手动）"; else cp "$here"/assets/dotfiles-layer/conventions.md "$HOME/.claude/conventions.md"; echo "  已拷 conventions.md"; fi
if [ -f "$HOME/.claude/conventions-always.md" ]; then echo "  conventions-always.md 已存在，跳过（你的个人文件）"; else cp "$here"/assets/dotfiles-layer/conventions-always.md "$HOME/.claude/conventions-always.md"; echo "  已拷 conventions-always.md —— 每轮注入层，请填你的语言/语气指令"; fi
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
[ "$ok4" -eq 1 ] || exit 1   # 半装时退非零,让调用方(rig init)能程序化感知
