# PreToolUse(Bash) hook：硬拦截一切 rm 调用，退出码 2 阻止执行并把指令反馈给 Claude。
$raw = [Console]::In.ReadToEnd()
try { $cmd = ($raw | ConvertFrom-Json).tool_input.command } catch { $cmd = "" }
if ($cmd -match '(^|[;&|(}\s])rm(\s|$)') {
  [Console]::Error.WriteLine("⛔ rm 被禁止执行（guard-rm hook）。请改用：mkdir -p ./trash 然后 mv <目标> ./trash/ ，并明确告诉用户：你不能执行 rm，已把文件 mv 到 ./trash/<path>。")
  exit 2
}
exit 0
