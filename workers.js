export default {
  async fetch(request, env, ctx) {
    const userAgent = request.headers.get('user-agent') || '';

    // ==========================================
    // 1. POWERSHELL 终端访问逻辑
    // ==========================================
    if (userAgent.includes('PowerShell')) {
      
      // 注意：下面所有的 $baseUrl、$mainExit 等内部变量，我都加上了 \ 进行转义
      // 防止被 JavaScript 错误地当成 JS 变量吞掉
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
    Write-Host ""
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
    Write-Host ""
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
    Write-Host ""
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
                        Invoke-RemoteScript -url "(\$baseUrl/7zip.ps1)"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "2" {
                        Write-Host " >> Installing V2Ray..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "(\$baseUrl/v2ray.ps1)"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "3" {
                        Write-Host " >> Installing VLC Media Player..." -ForegroundColor Cyan
                        Invoke-RemoteScript -url "(\$baseUrl/vlc.ps1)"
                        Write-Host ""
                        Read-Host " >> Press Enter to continue..."
                    }
                    "4" {
                        Write-Host " >> Launching Geek Uninstaller..." -ForegroundColor Cyan
                        # 🌟 修复关键点：通过 JS 转义确保 \$baseUrl 正确下发给终端
                        Invoke-RemoteScript -url "(\$baseUrl/geek.ps1)"
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
    // 2. 浏览器访问逻辑 (优雅极简网页)
    // ==========================================
    const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ethan's Toolbox</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
            background-color: #0d1117;
            color: #c9d1d9;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            padding: 0 20px;
        }
        .container {
            text-align: center;
            max-width: 500px;
            width: 100%;
            background: #161b22;
            padding: 40px;
            border-radius: 12px;
            border: 1px solid #30363d;
            box-shadow: 0 8px 24px rgba(0,0,0,0.3);
        }
        h1 {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 8px;
            color: #f0f6fc;
            letter-spacing: -0.5px;
        }
        p {
            font-size: 14px;
            color: #8b949e;
            margin-bottom: 28px;
        }
        .code-box {
            background-color: #010409;
            border: 1px solid #30363d;
            padding: 14px 16px;
            border-radius: 6px;
            font-family: ui-monospace, SFMono-Regular, SF Pro Text, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            font-size: 13px;
            color: #79c0ff;
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            text-align: left;
        }
        .code-text {
            word-break: break-all;
            user-select: all;
        }
        .copy-btn {
            background: #21262d;
            border: 1px solid #f0f6fc1f;
            color: #c9d1d9;
            padding: 6px 12px;
            font-size: 12px;
            font-weight: 500;
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.2s cubic-bezier(0.3, 0, 0.5, 1);
            margin-left: 12px;
            white-space: nowrap;
        }
        .copy-btn:hover {
            background: #30363d;
            border-color: #8b949e;
        }
        .copy-btn.copied {
            background: #238636;
            color: #ffffff;
            border-color: #2ea44f;
        }
    </style>
</head>
<body>

<div class="container">
    <h1>Ethan's Toolbox</h1>
    <p>Run this command in Windows PowerShell to launch the utility.</p>
    
    <div class="code-box">
        <span class="code-text" id="cmdText">irm powershell.fucker.li | iex</span>
        <button class="copy-btn" id="copyBtn" onclick="copyCommand()">Copy</button>
    </div>
</div>

<script>
function copyCommand() {
    const text = document.getElementById('cmdText').innerText;
    navigator.clipboard.writeText(text).then(() => {
        const btn = document.getElementById('copyBtn');
        btn.innerText = 'Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
            btn.innerText = 'Copy';
            btn.classList.remove('copied');
        }, 2000);
    });
}
</script>

</body>
</html>
    `;

    return new Response(htmlContent, {
      headers: { 'content-type': 'text/html; charset=utf-8' },
      status: 200
    });
  },
};
