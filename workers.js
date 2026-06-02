export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const host = url.hostname.toLowerCase();
    const userAgent = request.headers.get('user-agent') || '';

    // ==========================================
    // 1. User-Agent 精准分流 (仅区分 PowerShell 和 浏览器)
    // ==========================================
    const isPowerShell = userAgent.includes('PowerShell') || userAgent.includes('pwsh');

    if (isPowerShell) {
      // 主控脚本主体
      const psScript = `
# 安全兼容性初始化：强制开启全版本 TLS
try {
    [Net.ServicePointManager]::SecurityProtocol = 192 -bor 768 -bor 3072 -bor 12288
} catch {}

function Show-MainMenu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "                 fucker.li                   " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Activated" -ForegroundColor Yellow
    Write-Host "  [2] Install" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [0] Quit" -ForegroundColor Red
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-ActivatedMenu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "             ACTIVATED MENU                  " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Windows All" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [0] Back to Main Menu" -ForegroundColor Gray
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-InstallMenu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "              INSTALL MENU                   " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] 7-Zip" -ForegroundColor Yellow
    Write-Host "  [2] V2Ray" -ForegroundColor Yellow
    Write-Host "  [3] VLC" -ForegroundColor Yellow
    Write-Host "  [4] Geek Uninstaller" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [0] Back to Main Menu" -ForegroundColor Gray
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

# 静态资源完全托管于 Cloudflare Pages 独立站点
$baseUrl = "https://powershell.fucker.li/install"
$mainExit = $false

# =================================================================
# 2. 优化后的远程执行函数：增强异常捕获与进程退出码检查
# =================================================================
function Invoke-RemoteScript {
    param ([string]$url)
    try {
        # 获取远程脚本纯文本内容
        $scriptContent = irm $url -UseBasicParsing
        
        # 将代码转换为 Unicode 字节数组并进行 Base64 编码
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($scriptContent)
        $encoded = [Convert]::ToBase64String($bytes)
        
        # 启动新进程执行编码后的命令，并捕获进程对象以监控运行状态
        $proc = Start-Process "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -PassThru -Wait -NoNewWindow
        
        # 检查子脚本进程的退出码 (ExitCode)
        if ($null -ne $proc -and $proc.ExitCode -ne 0) {
            Write-Host " !! Script executed but returned a non-zero exit code: $($proc.ExitCode)" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host " !! Execution failed. Unable to fetch or run the remote script." -ForegroundColor Red
        Write-Host " !! Error Details: $_" -ForegroundColor DarkRed
    }
}

# 主菜单循环
do {
    Show-MainMenu
    $mainChoice = Read-Host " >> Enter your choice [1-2, 0]"
    Write-Host ""

    switch ($mainChoice) {
        "1" {
            $subExit = $false
            do {
                Show-ActivatedMenu
                $subChoice = Read-Host " >> Enter your choice [1, 0]"
                Write-Host ""
                switch ($subChoice) {
                    "1" {
                        Write-Host " >> Loading activation script..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "https://get.activated.win"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "0" { $subExit = $true }
                    Default {
                        Write-Host " !! Invalid choice." -ForegroundColor DarkYellow
                        Start-Sleep -Seconds 1
                    }
                }
            } while (!$subExit)
            break
        }
        "2" {
            $subExit = $false
            do {
                Show-InstallMenu
                $subChoice = Read-Host " >> Enter your choice [1-4, 0]"
                Write-Host ""
                switch ($subChoice) {
                    "1" {
                        Write-Host " >> Installing 7-Zip..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "$baseUrl/7zip.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "2" {
                        Write-Host " >> Installing V2Ray..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "$baseUrl/v2ray.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "3" {
                        Write-Host " >> Installing VLC Media Player..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "$baseUrl/vlc.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "4" {
                        Write-Host " >> Launching Geek Uninstaller..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "$baseUrl/geek.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "0" { $subExit = $true }
                    Default {
                        Write-Host " !! Invalid choice." -ForegroundColor DarkYellow
                        Start-Sleep -Seconds 1
                    }
                }
            } while (!$subExit)
            break
        }
        "0" {
            Write-Host " >> Goodbye." -ForegroundColor Gray
            $mainExit = $true
            break
        }
        Default {
            Write-Host " !! Invalid choice." -ForegroundColor DarkYellow
            Start-Sleep -Seconds 1
        }
    }

} while (!$mainExit)
      `;

      return new Response(psScript, {
        headers: { 
          'content-type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store' 
        },
      });
    }

    // ==========================================
    // 3. 浏览器访问非 www 域名时，进行 301 重定向
    // ==========================================
    if (host === 'fucker.li') {
      return Response.redirect("https://www.fucker.li", 301);
    }

    // 如果是 www.fucker.li 的浏览器访问，直接放行（让绑定的 Pages 静态站或 KV/前端环境正常响应）
    return fetch(request);
  },
};
