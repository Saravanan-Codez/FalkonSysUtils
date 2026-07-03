[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$Apply,
    [switch]$BypassSafetyNet
)

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

$safetyPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Safety\SystemRestore.psm1"
if (Test-Path $safetyPath) { Import-Module $safetyPath -ErrorAction SilentlyContinue }

function Invoke-ContextMenuFix {
    Write-FalkonLog -Level Info -Message "Restoring Classic Windows 10 Context Menu (Removes 'Show more options')..."
    
    $path = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        
        $serverPath = "$path\InprocServer32"
        if (-not (Test-Path $serverPath)) {
            New-Item -Path $serverPath -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $serverPath -Name "(Default)" -Value "" -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "Context Menu Optimized."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to modify Context Menu" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-PrioritySeparation {
    Write-FalkonLog -Level Info -Message "Applying Win32PrioritySeparation (Foreground task latency bias)..."
    
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        
        # Value 38 (0x26) gives foreground apps optimal priority over background tasks
        Set-ItemProperty -Path $path -Name "Win32PrioritySeparation" -Value 38 -Type DWord -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "Win32PrioritySeparation Applied."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to apply Priority Separation" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-StartupDelayTweak {
    Write-FalkonLog -Level Info -Message "Disabling Windows Startup Delay..."
    
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $path -Name "StartupDelayInMSec" -Value 0 -Type DWord -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "Startup Delay Disabled."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to disable Startup Delay" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-MenuShowDelayTweak {
    Write-FalkonLog -Level Info -Message "Optimizing Menu Show Delay (Instant menus)..."
    
    $path = "HKCU:\Control Panel\Desktop"
    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        Set-ItemProperty -Path $path -Name "MenuShowDelay" -Value "10" -Type String -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "Menu Show Delay Speedup Applied."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to optimize Menu Show Delay" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

if ($Menu) {
    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) {
            Show-FalkonLogo -SubTitle "REGISTRY OPTIMIZER"
            Show-FalkonBox -Title "REGISTRY OPTIMIZER ACTIONS" -Lines @(
                "[1] Apply Ultimate Registry Tweaks (Context Menu, Delay & Latency)",
                "[0] Back to Main Menu"
            ) -Color "Cyan"
            Write-Host ""
        } else { Clear-Host }
        
        $choice = Read-Host "  Selection"
        if ($choice -eq '0') { return }
        if ($choice -eq '1') {
            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING TWEAKS" } else { Clear-Host }
            if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) {
                Invoke-FalkonSafetyNet -BypassSafetyNet:$BypassSafetyNet
            }
            Invoke-ContextMenuFix
            Invoke-PrioritySeparation
            Invoke-StartupDelayTweak
            Invoke-MenuShowDelayTweak
            
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
    }
}
elseif ($Apply) {
    $applyStart = Get-Date
    $appliedTweaks = [System.Collections.Generic.List[string]]::new()

    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) {
        Invoke-FalkonSafetyNet -BypassSafetyNet:$BypassSafetyNet
    }
    Invoke-ContextMenuFix; $appliedTweaks.Add('Context Menu Latency Fix (Win 11)')
    Invoke-PrioritySeparation; $appliedTweaks.Add('Win32 Priority Separation (Foreground Boost)')
    Invoke-StartupDelayTweak; $appliedTweaks.Add('Windows Startup Delay Disabled')
    Invoke-MenuShowDelayTweak; $appliedTweaks.Add('Instant Windows Menu Show Delay (10ms)')

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
