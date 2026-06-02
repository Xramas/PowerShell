[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$DownloadUrl        = "https://gh-proxy.org/https://github.com/Xramas/loger/raw/master/loger.exe"
$TargetDirectory    = "C:\Program Files\HardwareMonitor"
$BinaryPath         = Join-Path $TargetDirectory "loger.exe"
$ServiceName        = "LogerHardwareMonitor"
$ServiceDisplayName = "Loger Hardware Monitor Service"

try {
    $ExistingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($ExistingService) {
        Write-Host "Existing service found. Cleaning up for clean installation..."
        
        if (Get-Command Set-ServiceFailure -ErrorAction SilentlyContinue) {
            & sc.exe failure $ServiceName reset= 0 actions= "" | Out-Null
        } else {
            & sc.exe failure $ServiceName reset= 0 actions= "" | Out-Null
        }
        Start-Sleep -Seconds 1

        if ($ExistingService.Status -eq "Running") {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }

        $ServiceProcess = Get-Process -Name "loger" -ErrorAction SilentlyContinue
        if ($ServiceProcess) {
            Stop-Process -Name "loger" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }

        Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Write-Host "Existing service removed successfully."
    }

    if (Test-Path $BinaryPath) {
        Remove-Item -Path $BinaryPath -Force | Out-Null
    }
} catch {
    Write-Warning "Error occurred during cleanup, attempting to proceed: $_"
}

try {
    if (-not (Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
        Write-Host "Installation directory created: $TargetDirectory"
    }
} catch {
    Write-Error "Directory creation failed: $_"
    exit
}

$DownloadSuccess = $false
try {
    Write-Host "Downloading application using Adaptive TLS (1.3 + 1.2)..."
    [Net.ServicePointManager]::SecurityProtocol = 3072 -bor 12288
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
    $DownloadSuccess = $true
} catch {
    Write-Warning "Adaptive TLS failed. Falling back and locking to TLS 1.2 standard..."
}

if (-not $DownloadSuccess) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = 3072
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
        Write-Host "Download completed via TLS 1.2 fallback strategy."
    } catch {
        Write-Error "Download failed completely even after TLS 1.2 fallback: $_"
        exit
    }
} else {
    Write-Host "Download completed successfully via adaptive protocols: $BinaryPath"
}

try {
    Write-Host "Creating system service..."
    New-Service -Name $ServiceName `
                -BinaryPathName "`"$BinaryPath`"" `
                -DisplayName $ServiceDisplayName `
                -StartupType Automatic
    Write-Host "Service created successfully."

    Write-Host "Configuring service failure recovery actions..."
    & sc.exe failure $ServiceName reset= 86400 actions= restart/10000 | Out-Null

    Write-Host "Starting hardware monitor service..."
    Start-Service -Name $ServiceName
    Write-Host "Service started successfully and is running in the background."
} catch {
    Write-Error "Service registration, configuration or startup failed: $_"
}
