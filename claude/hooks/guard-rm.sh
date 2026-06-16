#!/usr/bin/env bash
# PreToolUse(Bash) hook：硬拦截一切 rm 调用，退出码 2 阻止执行并把指令反馈给 Claude。
# Claude 收到后应改用 mv 到 ./trash/ 并告知用户。
input="$(cat)"
cmd=""
if command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: pass' 2>/dev/null)"
fi
# fail-safe：没装/没取到 command 时，对整个原始输入做匹配（宁可多拦，不可漏拦 rm）
[ -z "$cmd" ] && cmd="$input"
# 词边界检测 rm：行首或分隔符/引号后出现 rm，且后接空白/引号/行尾
if printf '%s' "$cmd" | grep -qE '(^|[;&|(}[:space:]"])rm([[:space:]"]|$)'; then
  echo "⛔ rm 被禁止执行（guard-rm hook）。请改用：mkdir -p ./trash && mv <目标> ./trash/ ，然后明确告诉用户：你不能执行 rm，已把文件 mv 到 ./trash/<path>。" >&2
  exit 2
fi
exit 0
