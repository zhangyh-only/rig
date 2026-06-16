#!/usr/bin/env bash
# rig 安装:把 rig CLI 软链到 PATH。用法:在 rig 仓库根目录跑  bash install.sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$here/bin/rig" "$here/scripts/"*.sh "$here/assets/dotfiles-layer/hooks/"*.sh "$here/test/"*.sh 2>/dev/null || true

# 选一个已在 PATH 里的 bin 目录;都不在则用 ~/.local/bin 并提示加进 PATH
target=""
for d in "$HOME/.local/bin" "/usr/local/bin"; do
  case ":$PATH:" in *":$d:"*) target="$d"; break ;; esac
done
if [ -z "$target" ]; then
  target="$HOME/.local/bin"
  echo "注意:$target 不在 PATH 里。请加进去,例如:"
  echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
fi
mkdir -p "$target"
ln -sf "$here/bin/rig" "$target/rig"
echo "✓ 已软链 rig → $target/rig"
echo "  验证:    rig help"
echo "  接入项目:进项目目录跑  rig init  (或在 AI 会话里让它执行)"
