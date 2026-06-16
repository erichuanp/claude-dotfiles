# claude-dotfiles

可移植的 Claude Code 配置：通用全局记忆、自有 skills、安全 hooks、插件清单、shell 别名。
一套配置，任何机器复刻相同体验。全局记忆只含通用偏好、不含任何个人信息。

## 在新机器上使用

1. 安装 Claude Code（`npm i -g @anthropic-ai/claude-code` 或官方安装方式）。
2. `git clone <this-repo>` 到任意目录（建议 `~/claude-dotfiles`）。
3. `cd` 进该目录运行 `claude`，对它说：**「看 readme，执行」**。
4. 完成后重开终端，让 `claude` 别名和 `cdsync` 生效。

> 也可以不经 Claude，手动跑：Windows `pwsh -File .\bootstrap.ps1`；macOS/Linux `bash bootstrap.sh`。

---

## 给 Claude 的执行指令（当用户让你读到该readme并且执行时，照以下步骤办，让你读readme但没提及执行时，就告知用户即将做的事情，再请求用户同意执行）

按顺序执行，每步验证：

1. **判断 OS**，选对应脚本：
   - Windows → `pwsh -File ./bootstrap.ps1`（无 pwsh 则 `powershell -File ./bootstrap.ps1`）
   - macOS / Linux → `bash ./bootstrap.sh`
2. **运行该 bootstrap**。它会（幂等，可重复跑）：
   - 软链 `~/.claude/CLAUDE.md` → 本仓库 `claude/CLAUDE.md`（全局记忆；Windows 需开发者模式/管理员才能软链，否则自动退为复制）
   - 复制 `claude/skills/*`（diagnose、grill-with-docs、teach）到 `~/.claude/skills/`
   - 复制 `claude/hooks/` 安全脚本，并合并进 `~/.claude/settings.json`：**PreToolUse `guard-rm`**（拦 `rm`）+ **`guard-commit`**（拦 AI 署名 commit）+ **PostToolUse `scrub-memory`**（写 CLAUDE.md 兜底脱敏），同时设 `skipDangerousModePermissionPrompt`
   - 按 `plugins.txt` 执行 `claude plugin marketplace add` + `claude plugin install`
   - 在 shell 配置里加 `claude` 别名（`--dangerously-skip-permissions`，已存在则跳过）和 `cdsync` 同步函数
3. **检查 shell 别名**：确认当前 shell 配置（Win: `$PROFILE`；bash: `~/.bashrc`；zsh: `~/.zshrc`）里存在一条指向 `claude --dangerously-skip-permissions` 的别名/函数；没有则按 OS 规则补上（bootstrap 已处理，复核即可）。
4. **报告结果**，并提醒用户：① 重开终端让 `claude` 别名和 `cdsync` 生效；② 插件若有未装上的，手动 `claude plugin install <name@marketplace>`。

不要把仓库里任何真实人名/密钥写进 commit（见 CLAUDE.md 隐私规则）。

---

## 仓库结构

```
claude/CLAUDE.md          全局记忆（软链目标，always-loaded，仅通用偏好/无 PII）
claude/skills/            自有 skills：diagnose / grill-with-docs / teach
claude/hooks/             guard-rm（拦 rm）/ guard-commit（拦 AI 署名）/ scrub-memory（脱敏 CLAUDE.md），各 .ps1 + .sh
plugins.txt              插件清单（marketplace + plugin 行）
bootstrap.ps1 / .sh      安装脚本
```

## 安全 hooks

- **guard-rm**（PreToolUse / Bash）：硬拦截一切 `rm`，退出码 2 阻止执行，并提示改用 `mv` 到 `./trash/`。删除不再是单向操作。
- **guard-commit**（PreToolUse / Bash）：拦截带 `Co-Authored-By: ...Claude...` 的 `git commit`，确保 contributor 只有当前 gh 用户、commit 不含 AI 署名。
- **scrub-memory**（PostToolUse / Write·Edit）：写入全局记忆 `CLAUDE.md` 时自动抹除邮箱、IPv4 等模式化 PII，作为「全局记忆不写个人信息」规则的兜底。

> 人名等非模式化 PII 靠 `CLAUDE.md` 里的自律规则避免写入；hook 负责模式化兜底。

## 日常同步（解决"更新记忆很麻烦"）

全局记忆是 `~/.claude/CLAUDE.md`，已软链到本仓库。要改记忆/偏好就直接编辑它，然后：

```
cdsync      # = git pull --rebase && add -A && commit && push，一条命令同步到所有机器
```

其它机器拉更新：`cd <repo> && git pull`（或下次 `cdsync` 自动 pull）。

> 各机器的**项目/机器专属**自动记忆留在本地 `~/.claude/projects/*/memory/`，不进仓库，避免互相污染。

## 不进仓库的东西（见 .gitignore）

凭据、会话/日志/缓存、插件二进制缓存（由 plugins.txt 重装）。
