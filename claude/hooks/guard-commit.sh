#!/usr/bin/env bash
# PreToolUse(Bash) hook：拦截带 "Co-Authored-By: ...Claude..." 的 git commit，
# 退出码 2 阻止，要求去掉 AI 署名 trailer（contributor 只保留当前 gh 用户）。
input="$(cat)"
cmd=""
if command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: pass' 2>/dev/null)"
fi
[ -z "$cmd" ] && cmd="$input"
# 仅针对 git commit；命中 co-authored-by + claude 即拦
if printf '%s' "$cmd" | grep -qiE 'git[[:space:]]+commit' \
   && printf '%s' "$cmd" | grep -qiE 'co-authored-by:.*claude'; then
  echo "⛔ commit message 含 Co-Authored-By: ...Claude... 署名（guard-commit hook）。请删掉该 trailer 后重新提交，contributor 只保留当前 gh 用户。" >&2
  exit 2
fi
exit 0
