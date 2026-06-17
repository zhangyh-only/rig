#!/usr/bin/env bash
# PreToolUse(Bash) hook —— best-effort:拦截试图【写】受保护路径的 Bash 命令
# (堵 sed -i / 重定向 等绕过 Edit/Write 红线 guard.sh 的洞)。
#
# 关键:只把红线 glob 匹配到【真实写目标】——重定向目标(> >> 后的文件)、tee 的文件参数、
# cp/mv 的终点、sed -i 的文件、dd 的 of=。**读取或仅在字符串里提到受保护路径不拦**,
# 避免误伤正常命令(如 `grep X .env > /tmp/out`、`echo /target/x > notes.md`、`pytest 2>&1`)。
# 匹配用与 guard.sh 同款 `case glob`(非子串),默认红线也与 guard.sh 对齐。
# 非穷尽 fail-safe:提取不确定时宁可放行(Edit/Write 层 guard.sh 是主防线)。
input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$cmd" ] && exit 0
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"

# 红线:与 guard.sh 同一套默认(口径一致),项目 .claude/protected-paths.txt 可覆盖
patterns=$'*/generated/*\n*.g.*\n*/build/*\n*/target/*\n*/node_modules/*\n*/dist/*'
deny="$proj/.claude/protected-paths.txt"
[ -f "$deny" ] && patterns="$(cat "$deny")"

# 1) 重定向写目标:> file / >> file / n> file / &> file ——排除 fd 复制如 2>&1、>&2(后接 & 不算文件)
redir="$(printf '%s\n' "$cmd" | grep -oE '[0-9]?>>?[[:space:]]*[^[:space:]&|;<>]+' | sed -E 's/^[0-9]?>>?[[:space:]]*//')"
# 2) tee 的文件参数、cp/mv 的终点、sed -i 的文件、dd 的 of= —— 按 token 扫描(只取写终点)
other="$(printf '%s\n' "$cmd" | awk '
  { for(i=1;i<=NF;i++){
      if($i=="tee"){ for(j=i+1;j<=NF;j++){ if($j ~ /^-/) continue; if($j ~ /^[|&;<>]/) break; print $j } }
      else if($i=="dd"){ for(j=i+1;j<=NF;j++){ if($j ~ /^of=/){ s=$j; sub(/^of=/,"",s); print s } } }
      else if($i=="cp"||$i=="mv"){ last=""; for(j=i+1;j<=NF;j++){ if($j ~ /^[|&;<>]/) break; if($j !~ /^-/) last=$j } if(last!="") print last }
      else if($i=="sed"){ hasi=0; for(j=i+1;j<=NF;j++){ if($j=="-i"||$j ~ /^-i/) hasi=1 }
                          if(hasi){ for(j=NF;j>i;j--){ if($j !~ /^-/ && $j !~ /^[|&;<>]/){ print $j; break } } } }
    } }')"

targets="$(printf '%s\n%s\n' "$redir" "$other")"
[ -z "$(printf '%s' "$targets" | tr -d '[:space:]')" ] && exit 0

while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    case "$pat" in \#*) continue ;; esac
    # shellcheck disable=SC2254
    case "$tok" in
      $pat)
        echo "🚫 Bash 命令疑似【写】受保护路径:$tok(命中红线:$pat)" >&2
        echo "如确需,改用受控方式或在 .claude/protected-paths.txt 调整红线。" >&2
        exit 2 ;;
    esac
  done <<< "$patterns"
done <<< "$targets"
exit 0
