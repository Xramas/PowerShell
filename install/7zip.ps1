# =================================================================
# 1. 解决乱码：强制将当前控制台的输入/输出以及输出流编码设为 UTF-8
# =================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

# =================================================================
# 2. 协议支持：同时允许 TLS 1.0, 1.1, 1.2, 1.3
# =================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -or 
                                              [Net.SecurityProtocolType]::Tls11 -or 
                                              [Net.SecurityProtocolType]::Tls12 -or 
                                              [Net.SecurityProtocolType]::Tls13

# 3. 动态获取 GitHub 上 7-Zip 的最新版本号
Write-Host "正在检索 GitHub 获取 7-Zip 最新版本号..." -ForegroundColor Cyan

try {
    $githubApiUrl = "https://api.github.com/repos/ip7z/7zip/releases/latest"
    $apiResponse = Invoke-RestMethod -Uri $githubApiUrl -UserAgent "Mozilla/5.0" -TimeoutSec 5
    
    $latestVersion = $apiResponse.tag_name
    $versionClean = $latestVersion -replace '\.', ''
    
    Write-Host "检测到最新版本为: $latestVersion" -ForegroundColor Green
} catch {
    Write-Host "无法获取最新版本号，将启用保底版本 26.01" -ForegroundColor Yellow
    $latestVersion = "26.01"
    $versionClean = "2601"
}

# 4. 动态拼接下载地址
$githubUrl = "https://github.com/ip7z/7zip/releases/download/$latestVersion/7z$versionClean-x64.exe"
$mirrorUrl = "https://mirror.nju.edu.cn/github-release/ip7z/7zip/LatestRelease/7z$versionClean-x64.exe"
$installerPath = Join-Path $env:TEMP "7z-installer.exe"

# 5. 检测 IP 归属地
Write-Host "正在检测您的 IP 地理位置..." -ForegroundColor Cyan
$downloadUrl = $githubUrl 

try {
    $ipInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5
    if ($ipInfo.countryCode -eq "CN") {
        Write-Host "检测到境内 IP，使用南京大学镜像源。" -ForegroundColor Green
        $downloadUrl = $mirrorUrl
    } else {
        Write-Host "检测到境外 IP (${$ipInfo.countryCode})，直接使用 GitHub 源。" -ForegroundColor Green
    }
} catch {
    Write-Host "IP 检测失败，默认切换至国内镜像源以确保速度。" -ForegroundColor Yellow
    $downloadUrl = $mirrorUrl
}

# 6. 开始下载
Write-Host "开始下载 7-Zip: $downloadUrl" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "下载完成！" -ForegroundColor Green
} catch {
    Write-Error "下载失败，请检查网络。错误信息: $_"
    exit 1
}

# 7. 静默安装
Write-Host "正在开始静默安装 7-Zip..." -ForegroundColor Cyan
try {
    $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/S" -PassThru -Wait
    if ($installProcess.ExitCode -eq 0) {
        Write-Host "7-Zip 最新版安装成功！" -ForegroundColor Green
    } else {
        Write-Warning "安装程序返回了非零状态码: $($installProcess.ExitCode)"
    }
} catch {
    Write-Error "安装过程中出现错误: $_"
} finally {
    # 8. 清理临时文件
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
        Write-Host "临时安装包已清理。" -ForegroundColor Gray
    }
}
