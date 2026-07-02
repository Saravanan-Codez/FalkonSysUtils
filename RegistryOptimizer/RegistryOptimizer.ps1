[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$Apply
)

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

$safetyPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Safety\SystemRestore.psm1"
if (Test-Path $safetyPath) { Import-Module $safetyPath -ErrorAction SilentlyContinue }

function Invoke-ContextMenuFix {
    Write-Host "[*] Restoring Classic Windows 10 Context Menu (Removes 'Show more options')..." -ForegroundColor Yellow
    
    try {
        $path = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $path -Name "(Default)" -Value "" -ErrorAction Stop
        Write-Host "[+] Context Menu Optimized." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to modify Context Menu: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-PrioritySeparation {
    Write-Host "[*] Applying Win32PrioritySeparation (Foreground task latency bias)..." -ForegroundColor Yellow
    try {
        # Value 38 (0x26) gives foreground apps optimal priority over background tasks
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -ErrorAction Stop
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
            Invoke-ContextMenuFix
            Invoke-PrioritySeparation
            
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
    }
}
elseif ($Apply) {
    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
    Invoke-ContextMenuFix
    Invoke-PrioritySeparation
}
