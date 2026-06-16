#!/usr/bin/env bash
# 机器画像探测 —— 安装期助手（步骤 0 最先跑）。
# 输出本机能力画像，供 manifest 的各项按 machine-profile 选择补救策略
# （选哪个包管理器、jq 是否阻断、skills 怎么写、适配哪些 AI 工具、项目有哪些语言）。
# 用法：detect-env.sh [project-dir]
proj="${1:-$PWD}"
have() { command -v "$1" >/dev/null 2>&1 && echo yes || echo no; }
first_of() { for c in "$@"; do command -v "$c" >/dev/null 2>&1 && { echo "$c"; return; }; done; echo none; }

echo "## machine-profile"
echo "os: $(uname -s)        arch: $(uname -m)"
case "$(uname -s)" in
  Darwin) plat=macos ;;
  Linux) grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null && plat=wsl || plat=linux ;;
  MINGW*|MSYS*|CYGWIN*) plat=windows-bash ;;
  *) plat=unknown ;;
esac
echo "platform: $plat"
echo "package-manager: $(first_of brew apt dnf pacman zypper winget scoop)"

echo
echo "## 前置工具（缺 jq = 阻断级，整套机制空转）"
for t in jq node npx git rg mvn gradle python3 go cargo; do
  printf '  %-8s %s\n' "$t" "$(have "$t")"
done

echo
echo "## 已装 AI 工具（决定适配哪些）"
printf '  claude-code  %s\n' "$([ -d "$HOME/.claude" ] && echo yes || echo no)"
printf '  codex        %s\n' "$([ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1 && echo yes || echo no)"
printf '  cursor       %s\n' "$([ -d "$HOME/.cursor" ] && echo yes || echo no)"
printf '  copilot-cli  %s\n' "$(have gh)"

echo
echo "## skills 同步机制（写 skills 前必看，别直写软链目标）"
ccsw="$HOME/.cc-switch/skills"
if [ -d "$ccsw" ]; then
  echo "  cc-switch: yes ($ccsw) —— skills 写同步源，不直写 ~/.claude/skills"
else
  echo "  cc-switch: no"
fi
if [ -d "$HOME/.claude/skills" ]; then
  links=$(find "$HOME/.claude/skills" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')
  dangling=$(find "$HOME/.claude/skills" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
  echo "  ~/.claude/skills: 软链 $links 个，悬空 $dangling 个"
else
  echo "  ~/.claude/skills: 不存在"
fi

echo
echo "## dotfiles 同步载体（换机器可携带性）"
if git -C "$HOME/.claude" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "  ~/.claude 是 git 仓库: yes"
else
  echo "  ~/.claude 是 git 仓库: no   | chezmoi:$(have chezmoi) stow:$(have stow) yadm:$(have yadm) | ~/dotfiles:$([ -d "$HOME/dotfiles" ] && echo yes || echo no)"
fi

echo
echo "## 项目语言矩阵（lint-one.sh 需覆盖这些；$proj）"
if git -C "$proj" rev-parse >/dev/null 2>&1; then
  git -C "$proj" ls-files 2>/dev/null | sed -n 's/.*\.\([A-Za-z0-9]\{1,6\}\)$/\1/p' \
    | sort | uniq -c | sort -rn | head -15 | awk '{printf "  .%-6s %s\n", $2, $1}'
else
  echo "  （$proj 非 git 仓库，跳过语言统计）"
fi
