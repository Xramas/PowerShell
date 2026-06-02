[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    Write-Warning "Could not configure security protocols. Using system defaults."
}

$DownloadUrl        = "https://gh-proxy.org/https://github.com/Xramas/loger/raw/master/loger.exe"
$TargetDirectory    = "C:\Program Files\HardwareMonitor"
$BinaryPath         = Join-Path $TargetDirectory "loger.exe"
$ServiceName        = "LogerHardwareMonitor"
$ServiceDisplayName = "Loger Hardware Monitor Service"

try {
    $ExistingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($ExistingService) {
        Write-Host "Existing service found. Cleaning up for clean installation..."
        if ($ExistingService.Status -eq "Running") {
            Stop-Service -Name $ServiceName -Force
            Start-Sleep -Seconds 3
        }
        $ServiceProcess = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'"
        if ($ServiceProcess) {
            $ServiceProcess.Delete() | Out-Null
            Start-Sleep -Seconds 3
        }
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

    Write-Host "Downloading application from server..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
    Write-Host "Download completed: $BinaryPath"
} catch {
    Write-Error "Download or directory creation failed: $_"
    exit
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
