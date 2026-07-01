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

write_skill(){
  dir="$1"
  name="$2"
  description="$3"
  body="$4"
  desc_escaped="${description//\\/\\\\}"
  desc_escaped="${desc_escaped//\"/\\\"}"
  mkdir -p "$dir"
  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$name"
    printf 'description: "%s"\n' "$desc_escaped"
    printf '%s\n' '---'
    printf '\n%s\n' "$body"
  } > "$dir/SKILL.md"
}

install_action_skills(){
  base="$1"
  write_skill "$base/rig-init" "rig-init" "Initialize the current project with rig for Codex: run project-level checks, install support wiring, and finish onboarding. Use when the user asks for /rig:init, rig init, 初始化 rig, or to onboard the project for Codex." "# Rig Init

Run \`rig init --codex \"\$PWD\"\` when \`rig\` is on PATH. If not, run \`~/.codex/skills/rig/bin/rig init --codex \"\$PWD\"\` or \`~/.agents/skills/rig/bin/rig init --codex \"\$PWD\"\` after confirming the file exists.

Then finish the judgment work from the main rig skill: collect existing rule files into \`docs/conventions/\`, derive build/test/run commands into \`AGENTS.md\`, replace placeholder \`scripts/verify-local.sh\` with real commands, ask before network installs, and run \`rig doctor \"\$PWD\"\`.

This is tool-specific project initialization. If the same repository was initialized in Claude Code, still run this once in Codex."
  write_skill "$base/rig-doctor" "rig-doctor" "Run rig health checks for the current project. Use when the user asks for /rig:doctor, rig doctor, or to diagnose rig installation." "# Rig Doctor

Run \`rig doctor \"\$PWD\"\`. If \`rig\` is not on PATH, use \`~/.codex/skills/rig/bin/rig doctor \"\$PWD\"\` or \`~/.agents/skills/rig/bin/rig doctor \"\$PWD\"\`.

Report hook registration, Codex skill/action skill status, command surface status, and project verification results. Diagnose root cause before changing files."
  write_skill "$base/rig-review" "rig-review" "Review the current change against rig conventions and verification expectations. Use when the user asks for /rig:review or rig review." "# Rig Review

Review the current diff against \`AGENTS.md\`, \`docs/conventions/\`, active specs, and local verification requirements. Prioritize bugs, rule drift, missing tests, and honesty gaps. Run focused verification when safe."
  write_skill "$base/rig-new-change" "rig-new-change" "Start a new spec/change workflow for rig-managed projects. Use when the user asks for /rig:new-change." "# Rig New Change

Create or prepare an openspec-style change only after confirming openspec is enabled for this project. If the CLI is missing, ask before installing \`@fission-ai/openspec\`. Keep the change grounded in the current project and user intent."
  write_skill "$base/rig-archive-change" "rig-archive-change" "Archive or close an active rig/openspec change. Use when the user asks for /rig:archive-change." "# Rig Archive Change

Validate the active change, confirm tasks are complete, run project verification, then archive according to the project's openspec workflow. Do not archive unfinished or unverified work."
  write_skill "$base/rig-adr" "rig-adr" "Create or update an ADR for an architectural decision. Use when the user asks for /rig:adr." "# Rig ADR

Draft an ADR in \`docs/adr/\` using the project template. Capture context, decision, consequences, alternatives, and verification links. Keep it grounded in actual code and user-confirmed decisions."
  write_skill "$base/rig-feature-spec" "rig-feature-spec" "Create or update an as-built feature spec for a stable domain. Use when the user asks for /rig:feature-spec." "# Rig Feature Spec

Create or update a domain feature spec from current code, docs, tests, and user-confirmed behavior. Do not invent business rules; mark uncertain points as questions."
  write_skill "$base/rig-learn" "rig-learn" "Capture a project lesson or recurring pitfall into rig conventions. Use when the user asks for /rig:learn." "# Rig Learn

Turn a confirmed pitfall into the right durable layer: lesson note, convention update, lint/guard rule, or ADR. Ask before promoting anything into hard rules."
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
    if ([.plugins[]?.name] | index("rig")) then
      .plugins = (.plugins | map(if .name=="rig" then
        .source = {source:"local", path:"./plugins/rig"} |
        .policy = {installation:"AVAILABLE", authentication:"ON_USE"} |
        .category = "Coding"
      else . end))
    else
      .plugins += [{
        name:"rig",
        source:{source:"local", path:"./plugins/rig"},
        policy:{installation:"AVAILABLE", authentication:"ON_USE"},
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
install_action_skills "$HOME/.codex/skills"
install_action_skills "$HOME/.agents/skills"

mkdir -p "$plugin_root/.codex-plugin" "$plugin_root/commands" "$plugin_root/skills" "$plugin_root/agents"
cp "$here/assets/codex-plugin/.codex-plugin/plugin.json" "$plugin_root/.codex-plugin/plugin.json"
cp "$here/assets/codex-plugin/commands/"*.md "$plugin_root/commands/"
cp "$here/assets/codex-plugin/agents/openai.yaml" "$plugin_root/agents/openai.yaml"
ln -sfn "$here" "$plugin_root/skills/rig"

write_marketplace "$HOME/.agents/plugins/marketplace.json"

echo "  ✓ Codex skill 已注册: ~/.codex/skills/rig -> $here"
echo "  ✓ Codex skill 已注册: ~/.agents/skills/rig -> $here"
echo "  ✓ Codex action skills 已安装: rig-init / rig-doctor / rig-review / ..."
echo "  ✓ Codex /rig:init command surface 已安装: ~/.agents/plugins/rig"
echo "  ✓ Codex plugin marketplace 已登记: ~/.agents/plugins/marketplace.json"
