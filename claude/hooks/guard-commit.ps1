# PreToolUse(Bash) hook：拦截带 "Co-Authored-By: ...Claude..." 的 git commit。
$raw = [Console]::In.ReadToEnd()
try { $cmd = ($raw | ConvertFrom-Json).tool_input.command } catch { $cmd = "" }
if (-not $cmd) { $cmd = $raw }
if (($cmd -imatch 'git\s+commit') -and ($cmd -imatch 'co-authored-by:.*claude')) {
  [Console]::Error.WriteLine("⛔ commit message 含 Co-Authored-By: ...Claude... 署名（guard-commit hook）。请删掉该 trailer 后重新提交，contributor 只保留当前 gh 用户。")
  exit 2
}
exit 0
