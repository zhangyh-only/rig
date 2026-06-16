#!/usr/bin/env bash
# 安装期助手：覆盖前把目标文件/目录备份到带时间戳目录，便于回滚。
# 用法：backup.sh <path>...   备份到 ~/.claude/backups/<ts>/
ts="$(date +%Y%m%d-%H%M%S 2>/dev/null)"; [ -z "$ts" ] && ts="manual"
dir="$HOME/.claude/backups/$ts"
mkdir -p "$dir" || { echo "无法创建备份目录 $dir" >&2; exit 1; }
n=0
for f in "$@"; do
  [ -e "$f" ] || continue
  base="$(printf '%s' "$f" | sed 's#^/##; s#/#_#g')"
  cp -R "$f" "$dir/$base" && n=$((n+1)) && echo "  备份 $f -> $dir/$base"
done
echo "已备份 $n 项到 $dir（回滚：把对应文件拷回原位）"
