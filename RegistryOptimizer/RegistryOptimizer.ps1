[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$Apply,
    [switch]$WhatIfOnly
)

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

$safetyPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Safety\SystemRestore.psm1"
if (Test-Path $safetyPath) { Import-Module $safetyPath -ErrorAction SilentlyContinue }

function Invoke-ContextMenuFix {
    param([switch]$WhatIfOnly)
    Write-Host "[*] Restoring Classic Windows 10 Context Menu (Removes 'Show more options')..." -ForegroundColor Yellow
    
    $path = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    if ($WhatIfOnly) {
        Write-Host "[Dry Run] Would restore Classic Windows 10 Context Menu." -ForegroundColor Green
        return
    }

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        
        $serverPath = "$path\InprocServer32"
        if (-not (Test-Path $serverPath)) {
            New-Item -Path $serverPath -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $serverPath -Name "(Default)" -Value "" -ErrorAction Stop
        Write-Host "[+] Context Menu Optimized." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to modify Context Menu: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-PrioritySeparation {
    param([switch]$WhatIfOnly)
    Write-Host "[*] Applying Win32PrioritySeparation (Foreground task latency bias)..." -ForegroundColor Yellow
    
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    if ($WhatIfOnly) {
        Write-Host "[Dry Run] Would set Win32PrioritySeparation to 38." -ForegroundColor Green
        return
    }

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        
        # Value 38 (0x26) gives foreground apps optimal priority over background tasks
        Set-ItemProperty -Path $path -Name "Win32PrioritySeparation" -Value 38 -Type DWord -ErrorAction Stop
        Write-Host "[+] Win32PrioritySeparation Applied." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to apply Priority Separation: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

if ($Menu) {
    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "REGISTRY OPTIMIZER" } else { Clear-Host }
        Write-Host "Select Registry Optimization Action:" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host "[1] Apply Ultimate Registry Tweaks (Context Menu & Latency)" -ForegroundColor Green
        Write-Host "[0] Back to Main Menu" -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        $choice = Read-Host "Selection"
        if ($choice -eq '0') { return }
        if ($choice -eq '1') {
            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING TWEAKS" } else { Clear-Host }
            if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
            Invoke-ContextMenuFix -WhatIfOnly:$WhatIfOnly
            Invoke-PrioritySeparation -WhatIfOnly:$WhatIfOnly
            
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
    }
}
elseif ($Apply) {
    $applyStart = Get-Date
    $appliedTweaks = [System.Collections.Generic.List[string]]::new()

    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
    Invoke-ContextMenuFix -WhatIfOnly:$WhatIfOnly; $appliedTweaks.Add('Context Menu Latency Fix (Win 11)')
    Invoke-PrioritySeparation -WhatIfOnly:$WhatIfOnly; $appliedTweaks.Add('Win32 Priority Separation (Foreground Boost)')

    $applyDuration = [Math]::Round(((Get-Date) - $applyStart).TotalSeconds, 1)
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "  REGISTRY OPTIMIZER COMPLETE ($applyDuration sec)" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "=================================================" -ForegroundColor Cyan
    foreach ($tweak in $appliedTweaks) {
        Write-Host "  [+] $tweak" -ForegroundColor Green
    }
    Write-Host "=================================================" -ForegroundColor Cyan
}
