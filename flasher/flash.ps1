#Requires -Version 5.1
<#
    Lenovo Legion Y700 2023 (TB320FC / asphalt) 一键刷机脚本
    自动识别刷机包(AviumUI / crDroid),同一份脚本通用

    由 一键刷机.bat 调用,不建议直接运行(编码/窗口设置在 bat 里做)
#>

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = '一键刷机 - Y700 2023 (asphalt)'

# ============================================================================
#  基本配置
# ============================================================================
$ROOT        = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOG         = Join-Path $ROOT ('flash_log_{0}.txt' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$TARGET_DEV  = 'asphalt'          # ro.product.device
$TARGET_MODEL= 'TB320FC'          # ro.product.model
$FB_PRODUCT  = 'taro'             # fastboot getvar product(SM8475 平台代号)

# ============================================================================
#  输出helpers
# ============================================================================
function W  { param($m,$c='Gray')   Write-Host $m -ForegroundColor $c; Add-Content -LiteralPath $LOG -Value $m -Encoding UTF8 }
function Title { param($m)
    W ''
    W ('══ ' + $m + ' ' + ('═' * [Math]::Max(0, 62 - $m.Length))) 'Cyan'
}
function Step { param($m) W ("  ▸ $m") 'White' }
function Ok   { param($m) W ("  ✓ $m") 'Green' }
function Warn { param($m) W ("  ! $m") 'Yellow' }
function Fail { param($m) W ("  ✗ $m") 'Red' }
function Info { param($m) W ("    $m") 'DarkGray' }

function Die {
    param($m, $hint)
    W ''
    Fail $m
    if ($hint) { W '' ; W '  可能的原因和解决办法:' 'Yellow' ; foreach ($h in $hint) { W ("    · $h") 'Yellow' } }
    W ''
    W "  完整日志已保存: $LOG" 'DarkGray'
    W ''
    Read-Host '  按回车键退出'
    exit 1
}

function Ask {
    param($q, $default = 'N')
    $opt = if ($default -eq 'Y') { '[Y/n]' } else { '[y/N]' }
    while ($true) {
        Write-Host ''
        Write-Host "  $q $opt " -ForegroundColor Yellow -NoNewline
        $a = Read-Host
        Add-Content -LiteralPath $LOG -Value "$q -> $a" -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($a)) { $a = $default }
        switch ($a.Trim().ToUpper()) {
            'Y' { return $true }
            'N' { return $false }
            default { Write-Host '    请输入 y 或 n' -ForegroundColor DarkGray }
        }
    }
}

# ============================================================================
#  工具定位(优先用 bin\ 里的,其次系统 PATH,都没有就从 Google 官方下载)
# ============================================================================
$PLATFORM_TOOLS_URL = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'

function Find-Tool {
    param($name)
    $local = Join-Path $ROOT "bin\$name"
    if (Test-Path -LiteralPath $local) { return $local }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Install-PlatformTools {
    <#  从 Google 官方下载 Android SDK Platform Tools。
        不随仓库分发是因为它有自己的许可协议,而且官方版本会持续更新。 #>
    Step '未找到 adb / fastboot,准备从 Google 官方下载…'
    Info $PLATFORM_TOOLS_URL

    $binDir = Join-Path $ROOT 'bin'
    $zip    = Join-Path $env:TEMP 'platform-tools.zip'
    $tmpDir = Join-Path $env:TEMP ('pt_' + [Guid]::NewGuid().ToString('N'))

    try {
        # 老版本 PowerShell 默认可能还在用 TLS1.0,Google 那边已经不接受了
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

        Step '下载中(不到 10 MB)…'
        $ProgressPreference = 'SilentlyContinue'   # 进度条会严重拖慢下载
        Invoke-WebRequest -Uri $PLATFORM_TOOLS_URL -OutFile $zip -UseBasicParsing -TimeoutSec 180
        $ProgressPreference = 'Continue'

        if (-not (Test-Path -LiteralPath $zip)) { throw '下载没有产生文件' }
        Ok ('下载完成 ({0:N1} MB)' -f ((Get-Item -LiteralPath $zip).Length / 1MB))

        Step '解压中…'
        Expand-Archive -LiteralPath $zip -DestinationPath $tmpDir -Force
        $src = Join-Path $tmpDir 'platform-tools'
        if (-not (Test-Path -LiteralPath $src)) { throw '压缩包结构和预期不符' }

        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        foreach ($f in @('adb.exe','fastboot.exe','AdbWinApi.dll','AdbWinUsbApi.dll','libwinpthread-1.dll')) {
            $p = Join-Path $src $f
            if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $binDir -Force }
        }

        if (-not (Test-Path -LiteralPath (Join-Path $binDir 'adb.exe'))) { throw '解压后没找到 adb.exe' }
        Ok "已安装到 $binDir"
        return $true
    }
    catch {
        Fail "自动下载失败: $($_.Exception.Message)"
        return $false
    }
    finally {
        Remove-Item -LiteralPath $zip   -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$ADB = Find-Tool 'adb.exe'
$FB  = Find-Tool 'fastboot.exe'

function Adb  { & $ADB @args 2>&1 }
function Fb   { & $FB  @args 2>&1 }

# ============================================================================
#  设备状态
# ============================================================================
function Get-AdbState {
    # 返回: none / device / recovery / sideload / unauthorized / offline
    $out = Adb devices
    foreach ($line in $out) {
        if ($line -match '^(\S+)\s+(device|recovery|sideload|unauthorized|offline)\s*$') {
            return [pscustomobject]@{ Serial = $Matches[1]; State = $Matches[2] }
        }
    }
    return [pscustomobject]@{ Serial = $null; State = 'none' }
}

function Get-FbState {
    $out = Fb devices
    foreach ($line in $out) {
        if ($line -match '^(\S+)\s+fastboot\s*$') {
            return [pscustomobject]@{ Serial = $Matches[1]; State = 'fastboot' }
        }
    }
    return [pscustomobject]@{ Serial = $null; State = 'none' }
}

function Get-FbVar {
    param($name)
    $out = Fb getvar $name
    foreach ($line in $out) {
        if ($line -match "^$([regex]::Escape($name)):\s*(.+?)\s*$") { return $Matches[1] }
    }
    return $null
}

function Wait-For {
    param(
        [ValidateSet('adb','fastboot','sideload','recovery')] $What,
        $TimeoutSec = 120,
        $Message = '等待设备'
    )
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Host ("    $Message ") -NoNewline -ForegroundColor DarkGray
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
        switch ($What) {
            'fastboot' { if ((Get-FbState).State  -eq 'fastboot') { Write-Host ' 就绪' -ForegroundColor Green; return $true } }
            'adb'      { if ((Get-AdbState).State -eq 'device')   { Write-Host ' 就绪' -ForegroundColor Green; return $true } }
            'sideload' { if ((Get-AdbState).State -eq 'sideload') { Write-Host ' 就绪' -ForegroundColor Green; return $true } }
            'recovery' { if ((Get-AdbState).State -in @('recovery','sideload')) { Write-Host ' 就绪' -ForegroundColor Green; return $true } }
        }
        Write-Host '.' -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
    }
    Write-Host ' 超时' -ForegroundColor Red
    return $false
}

# ============================================================================
#  文件定位与校验
# ============================================================================
function Find-File {
    param($pattern)
    foreach ($dir in @($ROOT, (Join-Path $ROOT 'images'), (Join-Path $ROOT 'rom'))) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $f = Get-ChildItem -LiteralPath $dir -Filter $pattern -File -ErrorAction SilentlyContinue |
             Sort-Object Length -Descending | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

function Merge-Parts {
    <#  刷机包超过 GitHub 单文件 2GB 上限,发布时切成了 .00.part / .01.part
        这里自动合并回完整 zip  #>
    $parts = @()
    foreach ($dir in @($ROOT, (Join-Path $ROOT 'images'))) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $p = Get-ChildItem -LiteralPath $dir -Filter '*.zip.*.part' -File -ErrorAction SilentlyContinue | Sort-Object Name
        if ($p.Count -gt 0) { $parts = $p; break }
    }
    if ($parts.Count -eq 0) { return $null }

    $target = $parts[0].FullName -replace '\.zip\.\d+\.part$', '.zip'
    if (Test-Path -LiteralPath $target) {
        Info "已存在合并好的 $(Split-Path $target -Leaf),跳过合并"
        return $target
    }

    Step "检测到 $($parts.Count) 个分卷,正在合并…"
    $totalMB = [Math]::Round(($parts | Measure-Object Length -Sum).Sum / 1MB)
    $free = (Get-PSDrive ((Split-Path $target -Qualifier).TrimEnd(':'))).Free / 1MB
    if ($free -lt $totalMB * 1.05) {
        Die "磁盘空间不足,合并需要约 $totalMB MB,当前可用 $([Math]::Round($free)) MB" @(
            '腾出空间后重新运行本脚本',
            '或者把整个刷机文件夹移到空间更充裕的磁盘'
        )
    }

    $out = [IO.File]::Create($target)
    try {
        foreach ($p in $parts) {
            Info "  合并 $($p.Name)"
            $in = [IO.File]::OpenRead($p.FullName)
            try { $in.CopyTo($out, 1MB) } finally { $in.Close() }
        }
    } finally { $out.Close() }
    Ok "已合并为 $(Split-Path $target -Leaf)"
    return $target
}

function Test-Sha256 {
    param($file, $expected)
    Step "校验 $(Split-Path $file -Leaf) …(2GB 文件约需 20–60 秒)"
    $h = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower()
    if ($h -eq $expected.ToLower()) { Ok '校验通过,文件完整'; return $true }
    Fail '校验失败!'
    Info "期望: $expected"
    Info "实际: $h"
    return $false
}

function Verify-Files {
    param($files)   # hashtable: 文件全路径 -> 期望sha256
    $sums = Find-File 'SHA256SUMS.txt'
    if (-not $sums) { Warn '没找到 SHA256SUMS.txt,跳过完整性校验(建议下载它以确保文件没损坏)'; return $true }

    $map = @{}
    foreach ($line in (Get-Content -LiteralPath $sums)) {
        if ($line -match '^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$') { $map[$Matches[2]] = $Matches[1] }
    }
    $allOk = $true
    foreach ($f in $files) {
        $name = Split-Path $f -Leaf
        if ($map.ContainsKey($name)) {
            if (-not (Test-Sha256 $f $map[$name])) { $allOk = $false }
        } else {
            Info "$name 不在校验清单里,跳过"
        }
    }
    return $allOk
}

# ============================================================================
#  安全检查
# ============================================================================
function Check-DeviceIdentity {
    <#  防止把 Y700 的包刷进别的设备 —— 这是最重要的一道保险  #>
    $st = Get-AdbState
    if ($st.State -eq 'device') {
        $dev   = (Adb shell getprop ro.product.device) -join '' -replace '\s',''
        $model = (Adb shell getprop ro.product.model)  -join '' -replace '\s',''
        Info "设备代号: $dev    型号: $model"
        if ($dev -ne $TARGET_DEV) {
            Die "机型不匹配!这个包是给 $TARGET_DEV (联想 Y700 2023 / TB320FC) 的,当前设备是 [$dev / $model]" @(
                '刷错设备会导致无法开机,已中止',
                '请确认你连的是正确的平板,并拔掉其他 Android 设备后重试'
            )
        }
        Ok "机型确认: $model ($dev)"
        return $true
    }
    $fb = Get-FbState
    if ($fb.State -eq 'fastboot') {
        $prod = Get-FbVar 'product'
        Info "fastboot product: $prod"
        if ($prod -and $prod -ne $FB_PRODUCT) {
            Die "平台不匹配!期望 $FB_PRODUCT (骁龙 8+ Gen1 / SM8475),实际是 [$prod]" @(
                '刷错设备会导致无法开机,已中止'
            )
        }
        Warn 'fastboot 模式下只能确认 SoC 平台,无法 100% 确认是 Y700'
        Info '如果你不确定,建议先让设备正常开机,脚本会做更严格的机型校验'
        return $true
    }
    return $false
}

function Check-Bootloader {
    $unlocked = Get-FbVar 'unlocked'
    Info "bootloader 解锁状态: $unlocked"
    if ($unlocked -eq 'no') {
        Die 'bootloader 处于锁定状态,无法刷机' @(
            '需要先解锁 bootloader(会清空数据)',
            '解锁方法请参考 lolipuru 的设备树仓库或相关论坛帖',
            '注意:解锁 bootloader 本身也会清空设备所有数据'
        )
    }
    if ($unlocked -eq 'yes') { Ok 'bootloader 已解锁' }
    else { Warn '无法读取解锁状态,继续尝试(如果后面刷写被拒绝,多半就是没解锁)' }
}

function Check-Battery {
    $st = Get-AdbState
    if ($st.State -ne 'device') { return }
    $out = Adb shell dumpsys battery
    $lvl = $null
    foreach ($l in $out) { if ($l -match '^\s*level:\s*(\d+)') { $lvl = [int]$Matches[1]; break } }
    if ($null -eq $lvl) { return }
    Info "当前电量: $lvl%"
    if ($lvl -lt 30) {
        Warn "电量偏低 ($lvl%)。刷机中途没电可能导致变砖"
        if (-not (Ask '确定要继续吗?建议先充到 50% 以上' 'N')) { exit 0 }
    } elseif ($lvl -lt 50) {
        Warn "电量 $lvl%,建议充到 50% 以上再刷"
    } else { Ok "电量充足 ($lvl%)" }
}

# ============================================================================
#  刷写动作
# ============================================================================
function Enter-Fastboot {
    $fb = Get-FbState
    if ($fb.State -eq 'fastboot') { Ok '设备已在 fastboot 模式'; return }

    $st = Get-AdbState
    switch ($st.State) {
        'device' {
            Step '正在重启到 fastboot 模式…'
            Adb reboot bootloader | Out-Null
        }
        'recovery' {
            Step '正在从 recovery 重启到 fastboot 模式…'
            Adb reboot bootloader | Out-Null
        }
        'sideload' {
            Step '正在从 sideload 重启到 fastboot 模式…'
            Adb reboot bootloader | Out-Null
        }
        'unauthorized' {
            Die 'USB 调试未授权' @(
                '请看平板屏幕,应该有"允许 USB 调试吗?"的弹窗,勾选"一律允许"并确定',
                '如果没看到弹窗,拔插一次数据线'
            )
        }
        default {
            W ''
            Warn '当前没有检测到设备'
            W '  请手动让平板进入 fastboot 模式:' 'Yellow'
            W '    1. 完全关机' 'Yellow'
            W '    2. 长按【音量减】+【电源键】,直到屏幕出现 fastboot 界面' 'Yellow'
            W '    3. 用数据线连接电脑(务必插平板【长边】那个 USB 口)' 'Yellow'
            Read-Host '  完成后按回车继续'
        }
    }
    if (-not (Wait-For 'fastboot' 120 '等待进入 fastboot')) {
        Die '设备没有进入 fastboot 模式' @(
            'USB 线要插在平板【长边】的接口上,短边那个口不能刷机',
            '换一根支持数据传输的线(不是纯充电线)',
            '换电脑上的另一个 USB 口,优先主板后置接口,避免用前置面板或 USB Hub',
            '在设备管理器里看看有没有带感叹号的未知设备,有的话需要装 Android bootloader 驱动'
        )
    }
}

function Flash-Recovery {
    param($img)
    Title '第 1 步:刷入 Recovery'
    Info '这一步是让平板认得我们这个刷机包'
    Enter-Fastboot
    Check-DeviceIdentity | Out-Null
    Check-Bootloader

    foreach ($slot in @('recovery_a','recovery_b')) {
        Step "刷入 $slot …"
        $out = Fb flash $slot $img
        $txt = $out -join "`n"
        Add-Content -LiteralPath $LOG -Value $txt -Encoding UTF8
        if ($txt -match 'FAILED|error') {
            Die "刷入 $slot 失败" @(
                '完整错误信息见日志文件',
                "如果提示 'not allowed in locked state',说明 bootloader 没解锁",
                "如果提示 'partition not found',说明设备型号可能不对"
            )
        }
        Ok "$slot 完成"
    }
}

function Do-FullFlash {
    param($zip, $recoveryImg)

    Flash-Recovery $recoveryImg

    Title '第 2 步:进入 Recovery'
    Step '正在重启到 Recovery…'
    Fb reboot recovery | Out-Null
    Start-Sleep -Seconds 8

    Title '第 3 步:清空数据(需要你在平板上操作)'
    W ''
    W '  ⚠ 下面这步会清空平板上的所有数据(应用、账号、内部存储的文件)' 'Red'
    W ''
    W '  请在平板屏幕上操作(音量键上下移动,电源键确认):' 'Yellow'
    W ''
    W '    1. 选择  Factory reset' 'White'
    W '    2. 选择  Format data / factory reset' 'White'
    W '    3. 确认执行,等待出现 "Data wipe complete."' 'White'
    W '    4. 返回主菜单,选择  Apply update' 'White'
    W '    5. 选择  Apply from ADB' 'White'
    W ''
    W '  当屏幕显示 "Now send the package you want to apply..." 时,' 'Yellow'
    W '  说明平板已经在等着接收了。' 'Yellow'
    W ''
    Read-Host '  完成以上操作后,按回车继续'

    if (-not (Wait-For 'sideload' 180 '等待平板进入 sideload 状态')) {
        Die '平板没有进入 sideload 接收状态' @(
            '确认已经在 Recovery 里选了 Apply update -> Apply from ADB',
            '屏幕上应该显示 "Now send the package you want to apply..."',
            '如果 adb devices 显示 unauthorized,拔插一次数据线'
        )
    }

    Title '第 4 步:传输并安装系统'
    Info '2GB 左右,大约需要 5–10 分钟,请勿拔线或操作平板'
    W ''
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $ADB sideload $zip 2>&1 | Tee-Object -Variable sideloadOut | ForEach-Object {
        if ($_ -match '(\d+)%') { Write-Host ("`r    传输进度: {0}%   " -f $Matches[1]) -NoNewline -ForegroundColor Cyan }
    }
    Write-Host ''
    $sw.Stop()
    Add-Content -LiteralPath $LOG -Value ($sideloadOut -join "`n") -Encoding UTF8
    Info ("传输耗时 {0:mm\:ss}" -f $sw.Elapsed)

    $txt = $sideloadOut -join "`n"
    if ($txt -match 'Total xfer') {
        Ok '传输完成'
    } elseif ($txt -match 'no devices|closed') {
        Die '传输中断' @(
            '数据线接触不良,换一根线或换个 USB 口重试',
            '重试前需要重新在 Recovery 里选一次 Apply update -> Apply from ADB'
        )
    }

    Title '第 5 步:确认结果'
    W ''
    W '  请看平板屏幕最下面几行:' 'Yellow'
    W ''
    W '    ✓ 显示 "Install completed with status 0" 或直接回到菜单 = 成功' 'Green'
    W '    ✗ 显示 "status 7" / "kInstallDeviceOpenError"        = 分区布局不匹配' 'Red'
    W '    ? 显示 "status 3"                                     = 见下面说明' 'Yellow'
    W ''
    W '  【重要】如果看到 status 3,先别慌:' 'Yellow'
    W '  Recovery 屏幕有时会残留上一次失败时的旧文字没刷新掉。' 'DarkGray'
    W '  真正的判断标准是【能不能正常开机】,直接往下走试试重启。' 'DarkGray'
    W ''

    if (Ask '看到 status 7 / kInstallDeviceOpenError 了吗?' 'N') {
        W ''
        Warn 'status 7 = 打开目标分区失败,通常是 super 分区布局和这个包对不上'
        Info '常见于从别的第三方 ROM 直接跨着刷过来'
        $se = Find-File 'super_empty.img'
        if ($se) {
            if (Ask '要不要现在自动修复?(会重置 super 分区,然后重新刷一次)' 'Y') {
                Do-SuperReset $se
                W ''
                Ok 'super 分区已重置,现在请重新运行本脚本走一遍完整刷机流程'
                W ''
                Read-Host '  按回车退出'
                exit 0
            }
        } else {
            Warn '没找到 super_empty.img,无法自动修复'
            Info '请从 Release 页面下载 super_empty.img 放到 images 文件夹后重试'
        }
        return
    }

    Title '完成'
    W ''
    W '  在平板上选择  Reboot  →  System  开机' 'Green'
    W ''
    W '  首次开机会明显比平时慢很多,3–8 分钟的转圈/黑屏都是正常的' 'Yellow'
    W '  (系统在做首次 dex 优化),这个阶段千万不要断电或强制重启。' 'Yellow'
    W ''
}

function Do-SuperReset {
    param($img)
    Title '重置 super 分区'
    Warn '这会清除 system / vendor / product 等所有系统分区'
    Warn '执行后设备将无法开机,必须接着完整刷入系统'
    if (-not (Ask '确定继续?' 'N')) { return }
    Enter-Fastboot
    Check-DeviceIdentity | Out-Null
    Check-Bootloader
    Step '刷入 super_empty.img …'
    $out = Fb flash super $img
    Add-Content -LiteralPath $LOG -Value ($out -join "`n") -Encoding UTF8
    if (($out -join "`n") -match 'FAILED|error') { Die 'super 分区重置失败' @('完整错误见日志') }
    Ok 'super 分区已重置'
}

function Do-FlashBoot {
    param($img, $label)
    Title "刷入 $label"
    Enter-Fastboot
    Check-DeviceIdentity | Out-Null
    Check-Bootloader

    $slot = Get-FbVar 'current-slot'
    if (-not $slot) { $slot = 'a' }
    Info "当前活动槽位: $slot"
    Step "刷入 boot_$slot …"
    $out = Fb flash "boot_$slot" $img
    Add-Content -LiteralPath $LOG -Value ($out -join "`n") -Encoding UTF8
    if (($out -join "`n") -match 'FAILED|error') { Die "刷入失败" @('完整错误见日志') }
    Ok '完成'
    if (Ask '现在重启设备吗?' 'Y') { Fb reboot | Out-Null }
}

# ============================================================================
#  主流程
# ============================================================================
Clear-Host
W ''
W '  ╔════════════════════════════════════════════════════════════════╗' 'Cyan'
W '  ║   联想 Y700 2023  一键刷机脚本                                  ║' 'Cyan'
W '  ║   联想拯救者 Y700 2023  (TB320FC / asphalt)                    ║' 'Cyan'
W '  ╚════════════════════════════════════════════════════════════════╝' 'Cyan'
W ''
W '  非官方社区构建 · 刷机有风险,操作前请务必备份重要数据' 'DarkGray'
W ''

Title '环境自检'

if ((-not $ADB) -or (-not $FB)) {
    if (Install-PlatformTools) {
        $ADB = Find-Tool 'adb.exe'
        $FB  = Find-Tool 'fastboot.exe'
    }
}
if ((-not $ADB) -or (-not $FB)) {
    Die '缺少 adb / fastboot,且自动下载失败' @(
        '检查一下网络能不能访问 dl.google.com(国内可能需要代理)',
        '也可以手动下载 Android SDK Platform Tools,',
        '  把 adb.exe / fastboot.exe 和几个 dll 解压到脚本目录下的 bin 文件夹里:',
        '  https://developer.android.com/tools/releases/platform-tools',
        '或者安装后把它加入系统 PATH,脚本也能自动找到'
    )
}
Ok "adb:      $ADB"
Ok "fastboot: $FB"

# 刷机包(可能是分卷)。支持的 ROM 按顺序探测
$ROM_KINDS = @(
    @{ Name = 'crDroid'; Pattern = 'crDroidAndroid-*.zip' },
    @{ Name = 'AviumUI'; Pattern = 'AviumUI-*.zip' }
)
$ROM_NAME = $null
$zip = $null
foreach ($k in $ROM_KINDS) {
    $zip = Find-File $k.Pattern
    if ($zip) { $ROM_NAME = $k.Name; break }
}
if (-not $zip) { $zip = Merge-Parts }
if ($zip -and -not $ROM_NAME) {
    $leaf = Split-Path $zip -Leaf
    foreach ($k in $ROM_KINDS) { if ($leaf -like $k.Pattern) { $ROM_NAME = $k.Name; break } }
    if (-not $ROM_NAME) { $ROM_NAME = 'ROM' }
}
if (-not $zip) {
    Die '找不到刷机包' @(
        '请把刷机包(crDroidAndroid-*.zip 或 AviumUI-*.zip)放到脚本目录或 images 子目录下',
        '如果下载的是 .00.part / .01.part 分卷,把两个都放进去,脚本会自动合并',
        '下载地址见项目 Release 页面'
    )
}
Ok "刷机包:   $(Split-Path $zip -Leaf)  ($([Math]::Round((Get-Item -LiteralPath $zip).Length/1GB,2)) GB)"

$recovery = Find-File 'recovery.img'
if ($recovery) { Ok "recovery: $(Split-Path $recovery -Leaf)" }
else { Warn '没找到 recovery.img(完整刷机需要它)' }

$bootClean  = Find-File 'boot.img'
$bootMagisk = Find-File 'boot_magisk.img'
$superEmpty = Find-File 'super_empty.img'

# 完整性校验
W ''
if (Ask '要校验文件完整性吗?(推荐,可以排除下载损坏导致的刷机失败)' 'Y') {
    $toCheck = @($zip)
    if ($recovery)   { $toCheck += $recovery }
    if ($bootClean)  { $toCheck += $bootClean }
    if ($bootMagisk) { $toCheck += $bootMagisk }
    if (-not (Verify-Files $toCheck)) {
        W ''
        Fail '有文件校验不通过,说明下载不完整或已损坏'
        if (-not (Ask '仍然要继续吗?(强烈不建议,可能刷到一半失败)' 'N')) { exit 1 }
    }
}

# 设备状态
Title '设备检测'
$adbSt = Get-AdbState
$fbSt  = Get-FbState
if     ($fbSt.State  -eq 'fastboot')     { Ok "已连接: $($fbSt.Serial)  [fastboot 模式]" }
elseif ($adbSt.State -eq 'device')       { Ok "已连接: $($adbSt.Serial)  [系统已开机]"; Check-DeviceIdentity | Out-Null; Check-Battery }
elseif ($adbSt.State -eq 'recovery')     { Ok "已连接: $($adbSt.Serial)  [Recovery 模式]" }
elseif ($adbSt.State -eq 'sideload')     { Ok "已连接: $($adbSt.Serial)  [sideload 等待接收]" }
elseif ($adbSt.State -eq 'unauthorized') { Warn '设备已连接但【未授权】—— 请在平板屏幕上确认"允许 USB 调试"' }
else {
    Warn '当前没有检测到设备'
    Info 'USB 线要插平板【长边】那个口(短边的口不能刷机)'
    Info '手机上要打开【开发者选项 → USB 调试】'
}

# 菜单
while ($true) {
    Title '请选择要做什么'
    W ''
    W ('    1  完整刷入 {0,-14} (刷 Recovery → 清数据 → 刷系统)' -f $ROM_NAME) 'White'
    W '       ⚠ 会清空平板所有数据' 'DarkGray'
    W ''
    W '    2  只刷 boot.img (干净版)  用于去掉 root / 恢复原始内核' 'White'
    W '    3  只刷 boot_magisk.img    用于获取 root(已预打 Magisk 补丁)' 'White'
    W ''
    W '    4  重置 super 分区         修复 status 7 / kInstallDeviceOpenError' 'White'
    W '    5  只做环境和设备检查       不做任何写入操作' 'White'
    W ''
    W '    0  退出' 'DarkGray'
    W ''
    Write-Host '  请输入编号: ' -ForegroundColor Yellow -NoNewline
    $c = Read-Host
    Add-Content -LiteralPath $LOG -Value "menu -> $c" -Encoding UTF8

    try {
        switch ($c.Trim()) {
            '1' {
                if (-not $recovery) { Die '缺少 recovery.img,无法完整刷机' @('请从 Release 页面下载 recovery.img') }
                W ''
                W '  ⚠ 这个操作会清空平板上的所有数据:' 'Red'
                W '     · 所有已安装的应用及其数据' 'Red'
                W '     · 微信/QQ 等的聊天记录' 'Red'
                W '     · 内部存储里的照片、下载文件等' 'Red'
                W ''
                if (Ask '已经备份好数据,确定要开始吗?' 'N') { Do-FullFlash $zip $recovery }
            }
            '2' { if ($bootClean)  { Do-FlashBoot $bootClean  'boot.img (干净版)' } else { Fail '找不到 boot.img' } }
            '3' { if ($bootMagisk) { Do-FlashBoot $bootMagisk 'boot_magisk.img (含 Magisk)' } else { Fail '找不到 boot_magisk.img' } }
            '4' { if ($superEmpty) { Do-SuperReset $superEmpty } else { Fail '找不到 super_empty.img' } }
            '5' {
                Title '检查结果'
                $a = Get-AdbState; $f = Get-FbState
                Info "adb 状态:      $($a.State)  $($a.Serial)"
                Info "fastboot 状态: $($f.State)  $($f.Serial)"
                if ($a.State -eq 'device') {
                    Info "设备代号: $((Adb shell getprop ro.product.device) -join '')"
                    Info "系统版本: $((Adb shell getprop ro.build.display.id) -join '')"
                    Info "当前槽位: $((Adb shell getprop ro.boot.slot_suffix) -join '')"
                }
                if ($f.State -eq 'fastboot') {
                    Info "product:      $(Get-FbVar 'product')"
                    Info "unlocked:     $(Get-FbVar 'unlocked')"
                    Info "current-slot: $(Get-FbVar 'current-slot')"
                }
            }
            '0' { break }
            default { Warn '无效的输入,请输入 0-5' }
        }
    } catch {
        W ''
        Fail "出现异常: $($_.Exception.Message)"
        Add-Content -LiteralPath $LOG -Value ($_ | Out-String) -Encoding UTF8
        Info "详细信息已记录到 $LOG"
    }

    if ($c.Trim() -eq '0') { break }
    W ''
    Read-Host '  按回车返回菜单'
}

W ''
W "  日志已保存: $LOG" 'DarkGray'
W ''
