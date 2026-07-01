#!/usr/bin/env bash
# 安装 Codex 可发现入口：skill 目录 + 本地 plugin command surface。
# hook 本身由 install-codex-hooks.sh 负责；这里补齐用户在 Codex UI 里能发现/调用的层。
set -u

__src="${BASH_SOURCE[0]:-$0}"
while [ -h "$__src" ]; do
  __dir="$(cd -P "$(dirname "$__src")" && pwd)"
  __src="$(readlink "$__src")"
  case "$__src" in /*) ;; *) __src="$__dir/$__src" ;; esac
done
here="$(cd -P "$(dirname "$__src")/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "✗ 缺 jq（阻断级）——Codex marketplace.json 合并依赖 jq。" >&2
  echo "  先安装 jq 后重跑。" >&2
  exit 1
fi

link_dir(){
  target="$1"
  mkdir -p "$(dirname "$target")"
  if [ "$here" = "$target" ]; then
    echo "  ⚠ 包根解析成 $target 自身，跳过以防自环" >&2
  else
    ln -sfn "$here" "$target"
  fi
}

write_marketplace(){
  target="$1"
  mkdir -p "$(dirname "$target")"
  base="$target.base.$$"
  tmp="$target.tmp.$$"
  if [ -f "$target" ]; then
    if jq empty "$target" >/dev/null 2>&1; then
      cp "$target" "$base"
    else
      echo "✗ $target 不是合法 JSON；为避免覆盖你的既有插件市场配置，已停止写入。" >&2
      echo "  请先修复该文件后重跑。" >&2
      return 1
    fi
  else
    printf '%s\n' '{"name":"local","interface":{"displayName":"local plugins"},"plugins":[]}' > "$base"
  fi

  if jq '
    .name = (.name // "local") |
    .interface = (.interface // {"displayName":"local plugins"}) |
    .plugins = (.plugins // []) |
    if ([.plugins[]?.name] | index("rig")) then .
    else
      .plugins += [{
        name:"rig",
        source:{source:"local", path:"./plugins/rig"},
        policy:{installation:"AVAILABLE", authentication:"ON_INSTALL"},
        category:"Coding"
      }]
    end
  ' "$base" > "$tmp"; then
    mv "$tmp" "$target"
    rm -f "$base"
  else
    rm -f "$base" "$tmp"
    return 1
  fi
}

plugin_root="$HOME/.agents/plugins/rig"

link_dir "$HOME/.codex/skills/rig"
link_dir "$HOME/.agents/skills/rig"

mkdir -p "$plugin_root/.codex-plugin" "$plugin_root/commands" "$plugin_root/skills" "$plugin_root/agents"
cp "$here/assets/codex-plugin/.codex-plugin/plugin.json" "$plugin_root/.codex-plugin/plugin.json"
cp "$here/assets/codex-plugin/commands/"*.md "$plugin_root/commands/"
cp "$here/assets/codex-plugin/agents/openai.yaml" "$plugin_root/agents/openai.yaml"
ln -sfn "$here" "$plugin_root/skills/rig"

write_marketplace "$HOME/.agents/plugins/marketplace.json"

echo "  ✓ Codex skill 已注册: ~/.codex/skills/rig -> $here"
echo "  ✓ Codex skill 已注册: ~/.agents/skills/rig -> $here"
echo "  ✓ Codex /rig:init command surface 已安装: ~/.agents/plugins/rig"
echo "  ✓ Codex plugin marketplace 已登记: ~/.agents/plugins/marketplace.json"
