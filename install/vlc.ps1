# =================================================================
# 1. 网络协议支持
# =================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor 
                                              [Net.SecurityProtocolType]::Tls11 -bor 
                                              [Net.SecurityProtocolType]::Tls12 -bor 
                                              [Net.SecurityProtocolType]::Tls13

# =================================================================
# 2. 动态获取 VLC 最新版本号 (解析官方文本流)
# =================================================================
Write-Host "Checking VideoLAN for the latest VLC version..." -ForegroundColor Cyan

try {
    # 请求官方专门提供给检测更新的版本文本接口（只返回一个纯文本版本号，如 3.0.23）
    $vlcVersionUrl = "https://update.videolan.org/vlc/status-win-x64"
    $versionRaw = Invoke-RestMethod -Uri $vlcVersionUrl -UserAgent "Mozilla/5.0" -TimeoutSec 5
    
    # 提取第一行或匹配数字版本号
    if ($versionRaw -match '(\d+\.\d+\.\d+)') {
        $latestVersion = $Matches[1]
        Write-Host "Latest VLC version found: $latestVersion" -ForegroundColor Green
    } else {
        throw "Could not parse version string."
    }
} catch {
    # 保底机制，防止接口挂掉导致脚本罢工
    Write-Host "Warning: Failed to fetch online version. Falling back to v3.0.23." -ForegroundColor Yellow
    $latestVersion = "3.0.23"
}

# =================================================================
# 3. 动态拼接你提供的“实体文件”真实链接
# =================================================================
$officialUrl   = "https://get.videolan.org/vlc/last/win64/vlc-$latestVersion-win64.exe"
$mirrorUrl     = "https://mirror.nju.edu.cn/videolan-ftp/vlc/last/win64/vlc-$latestVersion-win64.exe"
$installerPath = Join-Path $env:TEMP "vlc-installer.exe"

# =================================================================
# 4. 检测 IP 归属地并选择下载源
# =================================================================
Write-Host "Detecting your IP geolocation..." -ForegroundColor Cyan
$downloadUrl = $officialUrl 

try {
    $ipInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5
    if ($ipInfo.countryCode -eq "CN") {
        Write-Host "Location: Mainland China (CN). Using NJU mirror for acceleration." -ForegroundColor Green
        $downloadUrl = $mirrorUrl
    } else {
        Write-Host "Location: International. Using VLC official source directly." -ForegroundColor Green
    }
} catch {
    Write-Host "Warning: IP detection timeout or failed. Defaulting to NJU mirror for stability." -ForegroundColor Yellow
    $downloadUrl = $mirrorUrl
}

# =================================================================
# 5. 执行下载
# =================================================================
Write-Host "Downloading VLC Media Player from: $downloadUrl" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "Download completed successfully." -ForegroundColor Green
} catch {
    Write-Error "Error: Download failed. Details: $_"
    exit 1
}

# =================================================================
# 6. 静默安装 (NSIS 架构使用大写 /S)
# =================================================================
Write-Host "Starting VLC silent installation..." -ForegroundColor Cyan
try {
    $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/S /NCRC" -PassThru -Wait
    if ($installProcess.ExitCode -eq 0) {
        Write-Host "VLC Media Player has been successfully installed!" -ForegroundColor Green
    } else {
        Write-Warning "Installation finished with a non-zero exit code: $($installProcess.ExitCode)"
    }
} catch {
    Write-Error "Error: An error occurred during installation. Details: $_"
} finally {
    # =================================================================
    # 7. 清理临时文件
    # =================================================================
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
        Write-Host "Temporary installer cleared." -ForegroundColor Gray
    }
}
