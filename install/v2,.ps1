# =================================================================
# 1. 网络协议支持
# =================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor 
                                              [Net.SecurityProtocolType]::Tls11 -bor 
                                              [Net.SecurityProtocolType]::Tls12 -bor 
                                              [Net.SecurityProtocolType]::Tls13

# =================================================================
# 2. 动态获取 v2ray-core 最新版本号
# =================================================================
Write-Host "Checking GitHub for the latest v2ray-core version..." -ForegroundColor Cyan

try {
    $apiUrl = "https://api.github.com/repos/v2fly/v2ray-core/releases/latest"
    $apiResponse = Invoke-RestMethod -Uri $apiUrl -UserAgent "Mozilla/5.0" -TimeoutSec 5
    $latestVersion = $apiResponse.tag_name
    Write-Host "Latest version found: $latestVersion" -ForegroundColor Green
} catch {
    # 接口失败时的保底版本
    Write-Host "Warning: Failed to fetch version. Falling back to v5.49.0." -ForegroundColor Yellow
    $latestVersion = "v5.49.0"
}

# =================================================================
# 3. 构建所有的候选下载链接
# =================================================================
$rawPath = "v2fly/v2ray-core/releases/download/$latestVersion/v2ray-windows-64.zip"

$sourceUrls = @(
    "https://github.com/$rawPath",                           # 官方直连
    "https://ghproxy.net/https://github.com/$rawPath",       # 镜像代理 1
    "https://gh-proxy.org/https://github.com/$rawPath",      # 镜像代理 2
    "https://v4.gh-proxy.org/https://github.com/$rawPath",   # 镜像代理 3
    "https://v6.gh-proxy.org/https://github.com/$rawPath",   # 镜像代理 4
    "https://cdn.gh-proxy.org/https://github.com/$rawPath"   # 镜像代理 5
)

# =================================================================
# 4. 智能选择下载源 (HTTP HEAD 高效测速)
# =================================================================
Write-Host "Testing download sources to find the fastest responder..." -ForegroundColor Cyan
$downloadUrl = $null

foreach ($url in $sourceUrls) {
    try {
        # 使用 -Method Head 只握手不下载，设置 2 秒极其严苛的超时
        $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $downloadUrl = $url
            Write-Host "Selected fastest source: $downloadUrl" -ForegroundColor Green
            break # 只要找到第一个能通且速度快的，立刻跳出循环开始下载
        }
    } catch {
        # 当前源超时或无法访问，继续测试下一个
        continue
    }
}

# 如果全部测速都失败，强制使用官方直连作为最后保底
if ($null -eq $downloadUrl) {
    Write-Host "Warning: All proxies timed out. Falling back to official GitHub URL." -ForegroundColor Yellow
    $downloadUrl = $sourceUrls[0]
}

# =================================================================
# 5. 执行下载
# =================================================================
$zipPath = Join-Path $env:TEMP "v2ray.zip"
Write-Host "Downloading v2ray from: $downloadUrl" -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Download completed successfully." -ForegroundColor Green
} catch {
    Write-Error "Error: Download failed. Details: $_"
    exit 1
}

# =================================================================
# 6. 解压到用户特定的 AppData 目录
# =================================================================
# 动态拼接目标路径：C:\Users\<Username>\AppData\Local\v2ray
$targetDir = Join-Path $env:LOCALAPPDATA "v2ray"

Write-Host "Deploying portable binaries to: $targetDir" -ForegroundColor Cyan

try {
    # 如果目标目录不存在，则创建
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    # 使用 PowerShell 原生命令解压（-Force 参数确保覆盖旧版本文件）
    Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
    Write-Host "v2ray has been successfully deployed and updated!" -ForegroundColor Green
} catch {
    Write-Error "Error: Extraction failed. Details: $_"
} finally {
    # =================================================================
    # 7. 清理临时压缩包
    # =================================================================
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
        Write-Host "Temporary zip package cleared." -ForegroundColor Gray
    }
}
