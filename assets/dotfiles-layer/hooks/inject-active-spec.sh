#!/usr/bin/env bash
# UserPromptSubmit hook —— 编码时注入"当前进行中的 openspec 变更"(intent + spec delta + tasks)，
# 让 AI 在变更范围(spec)内实现。与 inject-conventions.sh 并行：规范管"怎么写"，spec 管"建什么"。
# 机制：全局一份；去当前项目的 openspec/changes/ 找未归档的变更。项目没用 openspec → 静默跳过。

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
proj="$(printf '%s' "$input" | jq -r '.cwd // ""')"
[ -z "$proj" ] && proj="${CLAUDE_PROJECT_DIR:-$PWD}"

case "$prompt" in
  *代码*|*实现*|*新增*|*修改*|*重构*|*接口*|*功能*|*函数*|*方法*|*bug*|*Bug*|*BUG*|*fix*|*refactor*|*implement*|*create*|*feature*|*endpoint*|*modify*|*method*) : ;;
  *) exit 0 ;;
esac

changes_dir="$proj/openspec/changes"
[ -d "$changes_dir" ] || exit 0

found=0
total=0
LIMIT=8000   # 注入字符软上界；超过后，后续 change 降级为摘要，防多个大 change 撑爆上下文
for d in "$changes_dir"/*/; do
  name="$(basename "$d")"
  case "$name" in archive|_*) continue ;; esac   # 跳过 archive 与模板/约定目录（_template 等）
  [ -d "$d" ] || continue
  # 跳过任务已全勾选的 change（已完成待归档，不再注入以免膨胀上下文）
  [ -f "${d}tasks.md" ] && ! grep -q '\- \[ \]' "${d}tasks.md" 2>/dev/null && continue
  if [ "$found" -eq 0 ]; then
    echo "## 进行中的变更规格（openspec · 本次实现必须落在其范围内）"
    found=1
  fi
  if [ "$total" -lt "$LIMIT" ]; then
    block="### 变更：$name"$'\n'
    [ -f "${d}proposal.md" ] && block="$block#### 提案 / 意图"$'\n'"$(cat "${d}proposal.md")"$'\n'
    [ -f "${d}tasks.md" ]    && block="$block#### 任务清单"$'\n'"$(cat "${d}tasks.md")"$'\n'
    if [ -d "${d}specs" ]; then
      while IFS= read -r sd; do
        block="$block#### 规格增量（$sd）"$'\n'"$(cat "$sd")"$'\n'
      done < <(find "${d}specs" -name 'spec.md' 2>/dev/null)
    fi
    printf '%s\n' "$block"
    total=$(( total + ${#block} ))
  else
    done_n="$(grep -c '\- \[[xX]\]' "${d}tasks.md" 2>/dev/null || echo 0)"
    todo_n="$(grep -c '\- \[ \]' "${d}tasks.md" 2>/dev/null || echo 0)"
    echo "### 变更：$name（摘要·已超注入上界，详见 openspec/changes/$name/）任务 ${done_n} 完成 / ${todo_n} 待办"
  fi
done

[ "$found" -eq 1 ] && echo "> 实现请严格落在以上变更范围内；超出范围（偏离）会在 review / 偏离度评分中被标记。"
exit 0
