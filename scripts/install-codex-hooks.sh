#!/usr/bin/env bash
# 安装 Codex hook 接线：共享 hook 源在 ~/.rig/hooks，Codex 入口在 ~/.codex/hooks。
# 只写 ~/.codex/hooks.json，不改 ~/.codex/config.toml。
set -u

__src="${BASH_SOURCE[0]:-$0}"
while [ -h "$__src" ]; do
  __dir="$(cd -P "$(dirname "$__src")" && pwd)"
  __src="$(readlink "$__src")"
  case "$__src" in /*) ;; *) __src="$__dir/$__src" ;; esac
done
here="$(cd -P "$(dirname "$__src")/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "✗ 缺 jq（阻断级）——Codex hooks.json 合并和 hook JSON 输出都依赖 jq。" >&2
  echo "  先安装 jq 后重跑。" >&2
  exit 1
fi

write_codex_hooks_json(){
  target="$1"
  dir="$(dirname "$target")"
  mkdir -p "$dir"
  base="$target.base.$$"
  tmp="$target.tmp.$$"
  inject_cmd='bash "$HOME/.codex/hooks/inject-conventions.sh" --codex'
  lint_cmd='bash "$HOME/.codex/hooks/lint-changed.sh" --codex'

  if [ -f "$target" ]; then
    if jq empty "$target" >/dev/null 2>&1; then
      cp "$target" "$base"
    else
      echo "✗ $target 不是合法 JSON；为避免覆盖你的既有配置，已停止写入。" >&2
      echo "  请先修复该文件后重跑。" >&2
      return 1
    fi
  else
    printf '%s\n' '{"hooks":{}}' > "$base"
  fi

  if jq --arg inject "$inject_cmd" --arg lint "$lint_cmd" '
    .hooks = (.hooks // {}) |
    if ([.hooks.UserPromptSubmit[]?.hooks[]?.command] | index($inject)) then .
    else
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{
        hooks:[{
          type:"command",
          command:$inject,
          statusMessage:"注入项目规范...",
          timeout:45
        }]
      }])
    end |
    if ([.hooks.PostToolUse[]?.hooks[]?.command] | index($lint)) then .
    else
      .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{
        matcher:"apply_patch|Edit|Write|MultiEdit",
        hooks:[{
          type:"command",
          command:$lint,
          statusMessage:"按规范检查改动...",
          timeout:45
        }]
      }])
    end
  ' "$base" > "$tmp"; then
    mv "$tmp" "$target"
    rm -f "$base"
  else
    rm -f "$base" "$tmp"
    return 1
  fi
}

mkdir -p "$HOME/.rig/hooks" "$HOME/.codex"
cp "$here"/assets/dotfiles-layer/hooks/*.sh "$HOME/.rig/hooks/" && chmod +x "$HOME/.rig/hooks/"*.sh

if [ -e "$HOME/.codex/hooks" ] && [ ! -L "$HOME/.codex/hooks" ]; then
  mkdir -p "$HOME/.codex/hooks"
  cp "$HOME"/.rig/hooks/*.sh "$HOME/.codex/hooks/" && chmod +x "$HOME/.codex/hooks/"*.sh
  echo "  ✓ Codex hook 入口已同步: ~/.codex/hooks"
else
  ln -sfn "$HOME/.rig/hooks" "$HOME/.codex/hooks"
  echo "  ✓ Codex hook 入口已关联: ~/.codex/hooks -> ~/.rig/hooks"
fi

write_codex_hooks_json "$HOME/.codex/hooks.json"
echo "  ✓ Codex hook 注册已写入: ~/.codex/hooks.json"
echo "  ⚠ Codex CLI 首次使用需在 /hooks 中 review + trust；Codex Desktop App 当前普通会话不支持 /hooks，若客户端提示 hook 待信任，请按提示处理。"
