# PostToolUse(Write/Edit) hook：写入全局记忆 CLAUDE.md 时兜底抹除模式化 PII（邮箱 / IPv4）。
$raw = [Console]::In.ReadToEnd()
try { $fp = ($raw | ConvertFrom-Json).tool_input.file_path } catch { $fp = "" }
if ($fp -notlike "*CLAUDE.md") { exit 0 }
if (-not (Test-Path $fp)) { exit 0 }
$t = Get-Content $fp -Raw
$t = $t -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[email-redacted]'
$t = $t -replace '\b(\d{1,3}\.){3}\d{1,3}\b', '[ip-redacted]'
[System.IO.File]::WriteAllText($fp, $t, (New-Object System.Text.UTF8Encoding $false))
exit 0
