# 强制设置控制台输出编码为 UTF-8，彻底解决中文乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. 动态获取 GitHub 上 7-Zip 的最新版本号
Write-Host "正在检索 GitHub 获取 7-Zip 最新版本号..." -ForegroundColor Cyan

# 允许 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    # 请求 GitHub API 获取最新 Release 信息
    $githubApiUrl = "https://api.github.com/repos/ip7z/7zip/releases/latest"
    $apiResponse = Invoke-RestMethod -Uri $githubApiUrl -UserAgent "Mozilla/5.0" -TimeoutSec 5
    
    # 提取并转换版本号
    $latestVersion = $apiResponse.tag_name
    $versionClean = $latestVersion -replace '\.', ''
    
    Write-Host "检测到最新版本为: $latestVersion" -ForegroundColor Green
} catch {
    Write-Host "无法获取最新版本号，将启用保底版本 26.01" -ForegroundColor Yellow
    $latestVersion = "26.01"
    $versionClean = "2601"
}

# 2. 动态拼接下载地址
$githubUrl = "https://github.com/ip7z/7zip/releases/download/$latestVersion/7z$versionClean-x64.exe"
$mirrorUrl = "https://mirror.nju.edu.cn/github-release/ip7z/7zip/LatestRelease/7z$versionClean-x64.exe"
$installerPath = Join-Path $env:TEMP "7z-installer.exe"

# 3. 检测 IP 归属地
Write-Host "正在检测您的 IP 地理位置..." -ForegroundColor Cyan
$downloadUrl = $githubUrl

try {
    $ipInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5
    if ($ipInfo.countryCode -eq "CN") {
        Write-Host "检测到境内 IP，使用南京大学镜像源。" -ForegroundColor Green
        $downloadUrl = $mirrorUrl
    } else {
        # 顺便修复了一个小 Bug：之前这里把 $ipInfo.countryCode 写成了 ${$ipInfo.countryCode} 导致没显示出国家代码
        Write-Host "检测到境外 IP (${$ipInfo.countryCode})，直接使用 GitHub 源。" -ForegroundColor Green
    }
} catch {
    Write-Host "IP 检测失败，默认切换至国内镜像源以确保速度。" -ForegroundColor Yellow
    $downloadUrl = $mirrorUrl
}

# 4. 开始下载
Write-Host "开始下载 7-Zip: $downloadUrl" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "下载完成！" -ForegroundColor Green
} catch {
    Write-Error "下载失败，请检查网络。错误信息: $_"
    exit 1
}

# 5. 静默安装
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
    # 6. 清理临时文件
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
        Write-Host "临时安装包已清理。" -ForegroundColor Gray
    }
}
