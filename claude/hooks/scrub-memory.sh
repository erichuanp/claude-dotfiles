#!/usr/bin/env bash
# PostToolUse(Write/Edit) hook：当写入的是全局记忆 CLAUDE.md 时，
# 兜底抹除模式化 PII（邮箱 / IPv4）。人名等靠 CLAUDE.md 自律规则避免写入。
input="$(cat)"
fp=""
if command -v python3 >/dev/null 2>&1; then
  fp="$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception: pass' 2>/dev/null)"
fi
# fail-safe：取不到 file_path 时，默认对全局记忆文件做脱敏（幂等，无害）
[ -z "$fp" ] && fp="$HOME/.claude/CLAUDE.md"
case "$fp" in
  *CLAUDE.md) ;;
  *) exit 0 ;;
esac
[ -f "$fp" ] || exit 0
sed -i.bak -E \
  -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[email-redacted]/g' \
  -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/[ip-redacted]/g' \
  "$fp" 2>/dev/null && mv -f "$fp.bak" "$HOME/.claude/.scrub-bak" 2>/dev/null
exit 0
