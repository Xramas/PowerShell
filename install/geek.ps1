# =================================================================
# 1. 网络协议支持
# =================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor 
                                              [Net.SecurityProtocolType]::Tls11 -bor 
                                              [Net.SecurityProtocolType]::Tls12 -bor 
                                              [Net.SecurityProtocolType]::Tls13

# =================================================================
# 2. 构建候选下载链接（官方直链 + 预留自建通用代理接口）
# =================================================================
$sourceUrls = @(
    "https://geekuninstaller.com/geek.zip"
    # 后期自建好通用代理后，删掉下面这行的井号(#)即可启用测速分流
    # "https://proxy.fucker.li/https://geekuninstaller.com/geek.zip"
)

# =================================================================
# 3. 智能选择最佳下载源 (HTTP HEAD 高效测速)
# =================================================================
Write-Host "Testing download sources for Geek Uninstaller..." -ForegroundColor Cyan
$downloadUrl = $null

foreach ($url in $sourceUrls) {
    try {
        $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $downloadUrl = $url
            Write-Host "Selected source: $downloadUrl" -ForegroundColor Green
            break
        }
    } catch {
        continue
    }
}

if ($null -eq $downloadUrl) {
    Write-Host "Warning: All proxies timed out or unavailable. Falling back to official URL." -ForegroundColor Yellow
    $downloadUrl = $sourceUrls[0]
}

# =================================================================
# 4. 执行下载
# =================================================================
$zipPath = Join-Path $env:TEMP "geek.zip"
Write-Host "Downloading Geek Uninstaller from: $downloadUrl" -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Download completed successfully." -ForegroundColor Green
} catch {
    Write-Error "Error: Download failed. Details: $_"
    exit 1
}

# =================================================================
# 5. 解压到用户特定的 AppData 目录
# =================================================================
$targetDir = Join-Path $env:LOCALAPPDATA "Geek"
Write-Host "Deploying portable binaries to: $targetDir" -ForegroundColor Cyan

try {
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
    Write-Host "Extraction completed." -ForegroundColor Green
} catch {
    Write-Error "Error: Extraction failed. Details: $_"
    exit 1
}

# =================================================================
# 6. 重命名可执行文件 (将小写 geek.exe 重命名为大写 Geek.exe)
# =================================================================
$oldExePath = Join-Path $targetDir "geek.exe"
$newExePath = Join-Path $targetDir "Geek.exe"

if (Test-Path $oldExePath) {
    try {
        if (Test-Path $newExePath) {
            Remove-Item $newExePath -Force
        }
        Rename-Item -Path $oldExePath -NewName "Geek.exe" -Force
        Write-Host "Renamed executable to Geek.exe successfully." -ForegroundColor Green
    } catch {
        Write-Error "Error: Failed to rename executable. Details: $_"
    }
}

# =================================================================
# 7. 创建桌面快捷方式
# =================================================================
Write-Host "Creating desktop shortcut..." -ForegroundColor Cyan
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "Geek.lnk"
    
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $newExePath
    $shortcut.WorkingDirectory = $targetDir
    $shortcut.Description = "Geek Uninstaller - Portable Software Remover"
    $shortcut.Save()
    
    Write-Host "Shortcut 'Geek' created on Desktop successfully!" -ForegroundColor Green
} catch {
    Write-Error "Error: Failed to create shortcut. Details: $_"
} finally {
    # =================================================================
    # 8. 清理临时压缩包
    # =================================================================
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
        Write-Host "Temporary zip package cleared." -ForegroundColor Gray
    }
}
