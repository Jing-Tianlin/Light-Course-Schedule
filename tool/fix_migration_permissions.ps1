# 修复数据迁移后常见的目录权限问题
# 请以“管理员身份”运行 PowerShell 后执行本脚本：
#   先进入项目根目录，再执行：
#   cd D:\TRAE\CODE\Kebiao\kebiao_app
#   powershell -ExecutionPolicy Bypass -File .\tool\fix_migration_permissions.ps1
#
# 背景：将 C 盘用户缓存/Flutter/Gradle 等目录迁移到 D 盘后，
# 可能因 ACL 未正确继承导致“拒绝访问”、Flutter 无法创建 lockfile、
# Dart/Java 无法写入缓存等。本脚本会为当前用户重新授予完全控制权。

$ErrorActionPreference = 'Stop'

$profile = $env:USERPROFILE
$targets = @(
    'D:\Flutter\flutter\bin\cache',
    'D:\GradleHome',
    'D:\JetBrains\Local',
    'D:\JetBrains\Roaming',
    "$profile\.gradle",
    "$profile\.pub-cache",
    "$profile\AppData\Local\Pub\Cache",
    "$profile\AppData\Roaming\.dart-tool",
    "$profile\AppData\Local\Android\Sdk"
)

$currentUser = "$env:USERDOMAIN\$env:USERNAME"

foreach ($target in $targets) {
    if (-not (Test-Path $target -ErrorAction SilentlyContinue)) {
        Write-Host "[跳过] 路径不存在: $target"
        continue
    }

    Write-Host "[修复] $target"
    Write-Host "  正在取得所有权，文件较多时可能需要几分钟..."
    # 取得所有权（需管理员）
    takeown /F $target /R /D Y 2>$null | Out-Null
    # 为当前用户授予完全控制权并继承到子对象
    icacls $target /grant "${currentUser}:(OI)(CI)F" /T /C /Q | Out-Null
    Write-Host "  完成: $target"
}

Write-Host ""
Write-Host "全部处理完成。建议重新打开终端/IDE 后再执行 flutter --version 验证。"
