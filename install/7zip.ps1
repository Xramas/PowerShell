# =================================================================
# 1. 网络协议支持：使用位运算符 (-bor) 启用所有 TLS 协议
# =================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor 
                                              [Net.SecurityProtocolType]::Tls11 -bor 
                                              [Net.SecurityProtocolType]::Tls12 -bor 
                                              [Net.SecurityProtocolType]::Tls13

# =================================================================
# 2. 动态获取 GitHub 上 7-Zip 的最新版本号
# =================================================================
Write-Host "Checking GitHub for the latest 7-Zip version..." -ForegroundColor Cyan

try {
    $githubApiUrl = "https://api.github.com/repos/ip7z/7zip/releases/latest"
    $apiResponse = Invoke-RestMethod -Uri $githubApiUrl -UserAgent "Mozilla/5.0" -TimeoutSec 5
    
    $latestVersion = $apiResponse.tag_name
    $versionClean = $latestVersion -replace '\.', ''
    
    Write-Host "Latest version found: $latestVersion" -ForegroundColor Green
} catch {
    # 如果解析 API 失败，使用保底版本，防止脚本崩溃
    Write-Host "Warning: Failed to fetch version from GitHub API. Falling back to v26.01." -ForegroundColor Yellow
    $latestVersion = "26.01"
    $versionClean = "2601"
}

# =================================================================
# 3. 动态拼接下载地址
# =================================================================
$githubUrl = "https://github.com/ip7z/7zip/releases/download/$latestVersion/7z$versionClean-x64.exe"
$mirrorUrl = "https://mirror.nju.edu.cn/github-release/ip7z/7zip/LatestRelease/7z$versionClean-x64.exe"
$installerPath = Join-Path $env:TEMP "7z-installer.exe"

# =================================================================
# 4. 检测 IP 归属地并选择下载源
# =================================================================
Write-Host "Detecting your IP geolocation..." -ForegroundColor Cyan
$downloadUrl = $githubUrl 

try {
    $ipInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5
    if ($ipInfo.countryCode -eq "CN") {
        Write-Host "Location: Mainland China (CN). Using NJU mirror for acceleration." -ForegroundColor Green
        $downloadUrl = $mirrorUrl
    } else {
        Write-Host "Location: International. Using GitHub source directly." -ForegroundColor Green
    }
} catch {
    # IP 检测失败时的保底策略：走国内镜像加速
    Write-Host "Warning: IP detection timeout or failed. Defaulting to NJU mirror for stability." -ForegroundColor Yellow
    $downloadUrl = $mirrorUrl
}

# =================================================================
# 5. 执行下载
# =================================================================
Write-Host "Downloading 7-Zip from: $downloadUrl" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "Download completed successfully." -ForegroundColor Green
} catch {
    Write-Error "Error: Download failed. Please check your network connection. Details: $_"
    exit 1
}

# =================================================================
# 6. 静默安装
# =================================================================
Write-Host "Starting silent installation..." -ForegroundColor Cyan
try {
    $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/S" -PassThru -Wait
    if ($installProcess.ExitCode -eq 0) {
        Write-Host "7-Zip has been successfully installed/updated!" -ForegroundColor Green
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
