#!/usr/bin/env bash
# 幂等合并 settings.json 的 hooks —— 安装期助手（不是被安装的脚本）。
# 把 <source> 里的 hooks 安全并入 <target>：
#   - target 不存在 → 用 source 的 hooks 新建
#   - target 已存在 → 逐事件按 command 去重追加；保留用户既有 permissions / 其它 hooks / 全部其它字段
#   - 幂等：重复运行不会重复加
# 用法：merge-settings.sh <target-settings.json> <source-settings.json>
set -euo pipefail

target="${1:?用法: merge-settings.sh <target> <source>}"
source="${2:?用法: merge-settings.sh <target> <source>}"

command -v jq >/dev/null 2>&1 || { echo "需要 jq（brew install jq）" >&2; exit 1; }
[ -f "$source" ] || { echo "source 不存在: $source" >&2; exit 1; }

# target 不存在 → 只取 source 的 hooks 建新文件
if [ ! -f "$target" ]; then
  mkdir -p "$(dirname "$target")"
  jq '{hooks: (.hooks // {})}' "$source" > "$target"
  echo "created $target"
  exit 0
fi

cp "$target" "$target.bak"

jq -n --slurpfile t "$target" --slurpfile s "$source" '
  ($t[0]) as $tgt
  | ($s[0].hooks // {}) as $src
  | reduce ($src | keys[]) as $ev (
      $tgt;
      ( .hooks[$ev] // [] ) as $tev
      | ( [ $tev[]?.hooks[]?.command ] ) as $have
      | ( [ $src[$ev][]
            | .hooks |= map(select(((.command // "") as $c | ($have | index($c))) | not))
            | select((.hooks | length) > 0)
          ] ) as $newgroups
      | .hooks[$ev] = ($tev + $newgroups)
    )
' > "$target.tmp"

mv "$target.tmp" "$target"
echo "merged hooks into $target（备份: $target.bak）"
