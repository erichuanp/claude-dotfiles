#!/usr/bin/env bash
# claude-dotfiles bootstrap (macOS / Linux)
# 用法：在仓库根目录运行  bash bootstrap.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="$HOME/.claude"
mkdir -p "$CLAUDE/skills" "$CLAUDE/hooks"
info(){ printf '\033[36m[bootstrap]\033[0m %s\n' "$1"; }

# 1) 全局记忆：软链 ~/.claude/CLAUDE.md -> 仓库
link="$CLAUDE/CLAUDE.md"; target="$REPO/claude/CLAUDE.md"
if [[ -e "$link" || -L "$link" ]]; then
  if [[ -L "$link" ]]; then rm -f "$link"; else mv "$link" "$link.bak.$(date +%Y%m%d%H%M%S)"; info "已备份原 CLAUDE.md"; fi
fi
ln -s "$target" "$link"; info "已软链 CLAUDE.md -> $target"

# 2) 自有 skills
for d in "$REPO"/claude/skills/*/; do
  name="$(basename "$d")"; rm -rf "$CLAUDE/skills/$name"; cp -r "$d" "$CLAUDE/skills/$name"; info "已安装 skill: $name"
done

# 3) hooks
cp "$REPO/claude/hooks/guard-rm.sh"      "$CLAUDE/hooks/guard-rm.sh";      chmod +x "$CLAUDE/hooks/guard-rm.sh"
cp "$REPO/claude/hooks/guard-commit.sh"  "$CLAUDE/hooks/guard-commit.sh";  chmod +x "$CLAUDE/hooks/guard-commit.sh"
cp "$REPO/claude/hooks/scrub-memory.sh"  "$CLAUDE/hooks/scrub-memory.sh";  chmod +x "$CLAUDE/hooks/scrub-memory.sh"

# 4) 合并 settings.json（用 python3）
SETTINGS="$CLAUDE/settings.json"
GUARD="$CLAUDE/hooks/guard-rm.sh"
GCOMMIT="$CLAUDE/hooks/guard-commit.sh"
SCRUB="$CLAUDE/hooks/scrub-memory.sh"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" "$GUARD" "$GCOMMIT" "$SCRUB" <<'PY'
import json, os, sys
path, guard, gcommit, scrub = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
s = {}
if os.path.exists(path):
    try: s = json.load(open(path))
    except Exception: s = {}
s["skipDangerousModePermissionPrompt"] = True
s["hooks"] = {
    "PreToolUse":  [{"matcher": "Bash", "hooks": [
        {"type": "command", "command": "bash %s" % guard},
        {"type": "command", "command": "bash %s" % gcommit},
    ]}],
    "PostToolUse": [{"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": "bash %s" % scrub}]}],
}
json.dump(s, open(path, "w"), indent=2, ensure_ascii=False)
PY
  info "已合并 settings.json（guard-rm + scrub-memory hooks）"
else
  info "未装 python3，跳过 settings.json 合并（请手动配置 hooks）"
fi

# 5) 安装插件
# 清理历史污染：旧版手动跨机拷 ~/.claude 会把 Windows 路径写进 known_marketplaces.json，
# 导致 marketplace 更新/安装报 "corrupted installLocation"。非 Windows 上一旦出现 C: 路径即重置。
KM="$CLAUDE/plugins/known_marketplaces.json"
if [[ -f "$KM" ]] && grep -q 'C:' "$KM"; then
  mv "$KM" "$KM.corrupt.$(date +%Y%m%d%H%M%S).bak"
  info "known_marketplaces.json 含 Windows 路径（历史污染），已备份并重置"
fi
if command -v claude >/dev/null 2>&1; then
  while IFS= read -r line; do
    line="${line%%$'\r'}"; [[ -z "$line" || "$line" == \#* ]] && continue
    kind="${line%% *}"; arg="${line#* }"
    if [[ "$kind" == "marketplace" ]]; then claude plugin marketplace add "$arg" >/dev/null 2>&1 && info "marketplace + $arg" || true
    elif [[ "$kind" == "plugin" ]]; then claude plugin install "$arg" --scope user >/dev/null 2>&1 && info "plugin + $arg" || true
    fi
  done < "$REPO/plugins.txt"
else
  info "未找到 claude CLI，跳过插件安装"
fi

# 6) shell rc：claude 别名 + cdsync（检查是否已存在 --dangerously-skip-permissions）
case "${SHELL##*/}" in
  zsh) RC="$HOME/.zshrc" ;;
  *)   RC="$HOME/.bashrc" ;;
esac
touch "$RC"
if ! grep -q -- '--dangerously-skip-permissions' "$RC"; then
  printf "\nalias claude='claude --dangerously-skip-permissions'\n" >> "$RC"
  info "已添加 claude 别名到 $RC"
else
  info "已存在指向 --dangerously-skip-permissions 的别名，跳过"
fi
if ! grep -q 'cdsync()' "$RC"; then
  cat >> "$RC" <<'EOF'

cdsync() {
  local link="$HOME/.claude/CLAUDE.md"
  local tgt; tgt="$(readlink "$link" 2>/dev/null)" || { echo "CLAUDE.md 非软链，cdsync 不可用"; return 1; }
  local repo; repo="$(cd "$(dirname "$tgt")/.." && pwd)"
  git -C "$repo" pull --rebase && git -C "$repo" add -A && git -C "$repo" commit -m "sync $(date +%Y-%m-%dT%H:%M:%S)" 2>/dev/null; git -C "$repo" push
}
EOF
  info "已添加 cdsync 到 $RC"
fi

echo ""
echo "✅ bootstrap 完成。下一步："
echo "   1) source $RC  （或重开终端，让 claude 别名 / cdsync 生效）"
echo "   2) 以后更新全局记忆：改 ~/.claude/CLAUDE.md 后运行 cdsync"
