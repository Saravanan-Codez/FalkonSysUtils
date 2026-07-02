function Show-FalkonLogo {
    param(
        [string]$SubTitle = ""
    )
    Clear-Host
    Write-Host '      ___  _   _     _  __  ___   _   _' -ForegroundColor Magenta
    Write-Host '     | __|/ \ | |   | |/ / /   \ | \ | |' -ForegroundColor Magenta
    Write-Host '     | _|/ _ \| |__ |   <  | () | |  \| |' -ForegroundColor DarkMagenta
    Write-Host '     |_|/_/ \_\____||_|\_\ \___/ |_|\___|' -ForegroundColor DarkMagenta
    Write-Host '          F A L K O N   S Y S   U T I L S' -ForegroundColor Cyan
    
    if (-not [string]::IsNullOrWhiteSpace($SubTitle)) {
        Write-Host '==================================================' -ForegroundColor Cyan
        $padLength = [math]::Max(0, (50 - $SubTitle.Length) / 2)
        $paddedTitle = $SubTitle.PadLeft($padLength + $SubTitle.Length).PadRight(50)
        Write-Host $paddedTitle -ForegroundColor White -BackgroundColor DarkMagenta
    }
    Write-Host '==================================================' -ForegroundColor Cyan
}

function Invoke-FalkonPause {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "Operation Complete." -ForegroundColor Green
    Write-Host "Press any key to return to the menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Backup-FalkonRegistryKey {
    param(
        [string]$Path
    )
    $backupDir = Join-Path $env:ProgramData "FalkonSysUtils\Rollbacks"
    try {
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        
        # Format PS path (e.g. HKCU:\...) to reg.exe path (e.g. HKCU\...)
        $regPath = $Path -replace '^HKLM:\\', 'HKLM\' -replace '^HKCU:\\', 'HKCU\' -replace '^HKLM:', 'HKLM' -replace '^HKCU:', 'HKCU'
        
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $safeName = ($regPath -replace '[\\:*?"<>|]', '_')
        $backupFile = Join-Path $backupDir "RegBackup_${safeName}_${timestamp}.reg"
        
        if (Test-Path -LiteralPath $Path) {
            $output = & reg.exe export $regPath $backupFile /y 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[*] Registry backup generated: $backupFile" -ForegroundColor Gray
            } else {
                Write-Warning "Failed to export registry path $regPath: $($output -join ' ')"
            }
        }
    } catch {
        Write-Warning "Error during registry backup: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Show-FalkonLogo, Invoke-FalkonPause, Backup-FalkonRegistryKey
