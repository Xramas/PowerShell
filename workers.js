export default {
  async fetch(request, env, ctx) {
    const userAgent = request.headers.get('user-agent') || '';

    // ==========================================
    // 1. POWERSHELL 终端访问：直接下发主控脚本
    // ==========================================
    if (userAgent.includes('PowerShell')) {
      
      const psScript = `
# 安全兼容性初始化：强制开启全版本 TLS
try {
    [Net.ServicePointManager]::SecurityProtocol = 192 -bor 768 -bor 3072 -bor 12288
} catch {}

function Show-MainMenu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "             ETHAN'S TOOLBOX                 " -ForegroundColor Cyan
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

\$baseUrl = "https://powershell.fucker.li/install"
\$mainExit = \$false

# 统一下载与执行函数（包含策略拦截自动绕过）
function Invoke-RemoteScript {
    param ([string]\$url)
    try {
        # 优先尝试标准直接执行
        irm \$url | iex
    } catch {
        try {
            # 如果被拦截，强制在内存中创建 ScriptBlock 绕过执行策略
            \$script = irm \$url
            Invoke-Command -ScriptBlock ([scriptblock]::Create(\$script))
        } catch {
            Write-Host " !! Execution failed. Please check your network or execution policy." -ForegroundColor Red
        }
    }
}

# 主菜单循环
do {
    Show-MainMenu
    \$mainChoice = Read-Host " >> Enter your choice [1-2, 0]"
    Write-Host ""

    switch (\$mainChoice) {
        "1" {
            \$subExit = \$false
            do {
                Show-ActivatedMenu
                \$subChoice = Read-Host " >> Enter your choice [1, 0]"
                Write-Host ""
                switch (\$subChoice) {
                    "1" {
                        Write-Host " >> Loading activation script..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "https://get.activated.win"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "0" { \$subExit = \$true }
                    Default {
                        Write-Host " !! Invalid choice." -ForegroundColor DarkYellow
                        Start-Sleep -Seconds 1
                    }
                }
            } while (!\$subExit)
            break
        }
        "2" {
            \$subExit = \$false
            do {
                Show-InstallMenu
                \$subChoice = Read-Host " >> Enter your choice [1-4, 0]"
                Write-Host ""
                switch (\$subChoice) {
                    "1" {
                        Write-Host " >> Installing 7-Zip..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "\$baseUrl/7zip.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "2" {
                        Write-Host " >> Installing V2Ray..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "\$baseUrl/v2ray.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "3" {
                        Write-Host " >> Installing VLC Media Player..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "\$baseUrl/vlc.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "4" {
                        Write-Host " >> Launching Geek Uninstaller..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "\$baseUrl/geek.ps1"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "0" { \$subExit = \$true }
                    Default {
                        Write-Host " !! Invalid choice." -ForegroundColor DarkYellow
                        Start-Sleep -Seconds 1
                    }
                }
            } while (!\$subExit)
            break
        }
        "0" {
            Write-Host " >> Goodbye." -ForegroundColor Gray
            \$mainExit = \$true
            break
        }
        Default {
            Write-Host " !! Invalid choice." -ForegroundColor DarkYellow
            Start-Sleep -Seconds 1
        }
    }

} while (!\$mainExit)
      `;

      return new Response(psScript, {
        headers: { 
          'content-type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store' 
        },
      });
    }

    // ==========================================
    // 2. 浏览器/非终端访问：301 永久重定向
    // ==========================================
    return Response.redirect("https://www.fucker.li", 301);
  },
};
