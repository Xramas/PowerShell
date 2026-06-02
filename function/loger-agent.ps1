# ==========================================
# 1. 配置网络与安全协议
# ==========================================
try {
    # 启用 Tls12 (3072) 和 Tls13 (12288) 确保现代 HTTPS 握手正常
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    Write-Warning "无法配置指定的安全协议，将使用系统默认设置。"
}

# 如果您的 localhost 服务器使用的是自签名证书，请取消注释以下 3 行以忽略证书信任验证：
# [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
# $WebClient = New-Object System.Net.WebClient
# [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}


# ==========================================
# 2. 定义变量配置
# ==========================================
$DownloadUrl        = "https://gh-proxy.org/https://github.com/Xramas/loger/blob/master/loger.exe"
$TargetDirectory    = "C:\Program Files\HardwareMonitor"
$BinaryPath         = Join-Path $TargetDirectory "loger.exe"
$ServiceName        = "LogerHardwareMonitor"
$ServiceDisplayName = "Loger Hardware Monitor Service"


# ==========================================
# 3. 创建目录并下载文件
# ==========================================
try {
    # 确保目标文件夹存在
    if (-not (Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
        Write-Host "已创建安装目录: $TargetDirectory"
    }

    # 下载监控程序
    Write-Host "正在从内网服务器下载程序..."
    # 使用 Invoke-WebRequest 下载，-UseBasicParsing 可提升在无 GUI 环境下的执行速度
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
    Write-Host "文件下载完成: $BinaryPath"
} catch {
    Write-Error "文件下载或目录创建失败，原因为: $_"
    exit
}


# ==========================================
# 4. 注册并启动系统服务
# ==========================================
try {
    # 检查服务是否已存在
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "提示: 服务 [$ServiceName] 已存在，正在检查更新状态..."
    } else {
        Write-Host "正在创建系统服务..."
        # 创建服务并设置为开机自动启动
        New-Service -Name $ServiceName `
                    -BinaryPathName "`"$BinaryPath`"" `
                    -DisplayName $ServiceDisplayName `
                    -StartupType Automatic
        Write-Host "服务创建成功。"
    }

    # 检查服务运行状态，未启动则启动它
    $ServiceStatus = Get-Service -Name $ServiceName
    if ($ServiceStatus.Status -ne "Running") {
        Write-Host "正在启动监控服务..."
        Start-Service -Name $ServiceName
        Write-Host "服务已成功启动，正在后台进行硬件监控。"
    } else {
        Write-Host "服务已经在运行中。"
    }

} catch {
    Write-Error "服务注册或启动失败，原因为: $_"
}
