#requires -Version 5.1
# claude-dotfiles bootstrap (Windows / PowerShell)
# 用法：在仓库根目录运行  pwsh -File .\bootstrap.ps1   （或 powershell -File .\bootstrap.ps1）
$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force -Path $ClaudeDir, (Join-Path $ClaudeDir 'skills'), (Join-Path $ClaudeDir 'hooks') | Out-Null
function Info($m){ Write-Host "[bootstrap] $m" -ForegroundColor Cyan }

# 1) 全局记忆：软链 ~/.claude/CLAUDE.md -> 仓库（更新即同步）
$linkPath = Join-Path $ClaudeDir 'CLAUDE.md'
$target   = Join-Path $RepoRoot 'claude\CLAUDE.md'
if (Test-Path $linkPath) {
    $item = Get-Item $linkPath -Force
    if ($item.LinkType -ne 'SymbolicLink') {
        Move-Item $linkPath "$linkPath.bak.$(Get-Date -Format yyyyMMddHHmmss)"
        Info "已备份原 CLAUDE.md 为 .bak"
    } else { Remove-Item $linkPath -Force }
}
try {
    New-Item -ItemType SymbolicLink -Path $linkPath -Target $target | Out-Null
    Info "已软链 CLAUDE.md -> $target"
} catch {
    Copy-Item $target $linkPath -Force
    Info "无符号链接权限，已改为复制 CLAUDE.md（cdsync 仍可同步仓库，但本机改动需手动 copy）。开启开发者模式或以管理员运行可启用软链。"
}

# 2) 自有 skills：复制进 ~/.claude/skills
Get-ChildItem (Join-Path $RepoRoot 'claude\skills') -Directory | ForEach-Object {
    $dest = Join-Path $ClaudeDir "skills\$($_.Name)"
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $_.FullName $dest -Recurse -Force
    Info "已安装 skill: $($_.Name)"
}

# 3) hooks 脚本
Copy-Item (Join-Path $RepoRoot 'claude\hooks\guard-rm.ps1')      (Join-Path $ClaudeDir 'hooks\guard-rm.ps1') -Force
Copy-Item (Join-Path $RepoRoot 'claude\hooks\guard-commit.ps1')  (Join-Path $ClaudeDir 'hooks\guard-commit.ps1') -Force
Copy-Item (Join-Path $RepoRoot 'claude\hooks\scrub-memory.ps1')  (Join-Path $ClaudeDir 'hooks\scrub-memory.ps1') -Force

# 4) 合并 settings.json（保留已有键，覆盖 hooks）
$settingsPath = Join-Path $ClaudeDir 'settings.json'
$settings = @{}
if (Test-Path $settingsPath) {
    $raw = Get-Content $settingsPath -Raw
    if ($raw.Trim()) { ($raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $settings[$_.Name] = $_.Value } }
}
$settings['skipDangerousModePermissionPrompt'] = $true
$guard  = Join-Path $ClaudeDir 'hooks\guard-rm.ps1'
$gcommit = Join-Path $ClaudeDir 'hooks\guard-commit.ps1'
$scrub  = Join-Path $ClaudeDir 'hooks\scrub-memory.ps1'
$guardCmd  = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$guard`""
$gcommitCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$gcommit`""
$scrubCmd  = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$scrub`""
$settings['hooks'] = @{
    PreToolUse  = @(@{ matcher = 'Bash'; hooks = @(
        @{ type = 'command'; command = $guardCmd },
        @{ type = 'command'; command = $gcommitCmd }
    ) })
    PostToolUse = @(@{ matcher = 'Write|Edit|MultiEdit'; hooks = @(@{ type = 'command'; command = $scrubCmd }) })
}
$jsonOut = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $jsonOut, (New-Object System.Text.UTF8Encoding $false))
Info "已合并 settings.json（guard-rm + scrub-memory hooks、跳过危险模式确认）"

# 5) 安装插件（marketplace add + install）
$claudeExe = (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
if ($claudeExe) {
    Get-Content (Join-Path $RepoRoot 'plugins.txt') | ForEach-Object {
        $l = $_.Trim(); if ($l -eq '' -or $l.StartsWith('#')) { return }
        $p = $l -split '\s+', 2
        try {
            if ($p[0] -eq 'marketplace') { & $claudeExe.Source plugin marketplace add $p[1] 2>&1 | Out-Null; Info "marketplace + $($p[1])" }
            elseif ($p[0] -eq 'plugin')  { & $claudeExe.Source plugin install $p[1] --scope user 2>&1 | Out-Null; Info "plugin + $($p[1])" }
        } catch { Write-Host "[bootstrap] 插件步骤失败（可稍后手动）: $l" -ForegroundColor Yellow }
    }
} else { Write-Host "[bootstrap] 未找到 claude CLI，跳过插件安装。" -ForegroundColor Yellow }

# 6) PowerShell $PROFILE：claude 别名（带 --dangerously-skip-permissions）+ cdsync
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
$prof = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($prof -notmatch 'dangerously-skip-permissions') {
    Add-Content $PROFILE "`nfunction claude { & (Get-Command claude -CommandType Application | Select-Object -First 1).Source --dangerously-skip-permissions @args }"
    Info "已添加 claude 别名（--dangerously-skip-permissions）到 `$PROFILE"
} else { Info "claude 别名已存在，跳过" }
if ($prof -notmatch 'function cdsync') {
    $cdsync = @'

function cdsync {
  $link = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
  $tgt  = (Get-Item $link -Force).Target
  if (-not $tgt) { Write-Host 'CLAUDE.md 不是软链，cdsync 不可用（本机为复制模式）'; return }
  $repo = Split-Path (Split-Path $tgt)
  git -C $repo pull --rebase
  git -C $repo add -A
  git -C $repo commit -m "sync $(Get-Date -Format s)" 2>$null
  git -C $repo push
}
'@
    Add-Content $PROFILE $cdsync
    Info "已添加 cdsync 到 `$PROFILE"
}

Write-Host ""
Write-Host "✅ bootstrap 完成。下一步：" -ForegroundColor Green
Write-Host "   1) 重开终端 (让 claude 别名 / cdsync 生效)"
Write-Host "   2) 以后更新全局记忆：改 ~/.claude/CLAUDE.md 后运行  cdsync"
