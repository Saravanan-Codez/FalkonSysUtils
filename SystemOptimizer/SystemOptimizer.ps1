[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# Import Safety Net (Relative Path)
$safetyPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Safety\SystemRestore.psm1"
if (Test-Path $safetyPath) { Import-Module $safetyPath -ErrorAction SilentlyContinue }

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

function Invoke-UltimatePowerPlan {
    Write-Host "[*] Unlocking Ultimate Performance Power Plan..." -ForegroundColor Yellow

    try {
        # Inject the Ultimate Performance GUID
        $planGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $out = & powercfg.exe -duplicatescheme $planGuid 2>&1
        if ($LASTEXITCODE -ne 0) { throw "powercfg -duplicatescheme failed: $out" }
        
        # Attempt to set it as active
        $allPlans = powercfg -l
        if ($allPlans -match $planGuid) {
            $out2 = & powercfg.exe -setactive $planGuid 2>&1
            if ($LASTEXITCODE -ne 0) { throw "powercfg -setactive failed: $out2" }
            Write-Host "[+] Ultimate Performance Plan unlocked and activated." -ForegroundColor Green
        } else {
            Write-Host "[-] Failed to activate Ultimate Performance." -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "[-] Error configuring power plan: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-WindowsUpdateControl {
    Write-Host "[*] Blocking Forced Windows Update Driver Installations..." -ForegroundColor Yellow
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $regPath }
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $regPath -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord -ErrorAction Stop
        Write-Host "[+] OEM Driver Overrides Prevented." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to block Driver Updates: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-TaskbarDebloat {
    Write-Host "[*] Unpinning Chat, Widgets, and Copilot from Taskbar..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $regPath }
        Set-ItemProperty -Path $regPath -Name "TaskbarMn" -Value 0 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "TaskbarDa" -Value 0 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "ShowCopilotButton" -Value 0 -Type DWord -ErrorAction Stop
        Write-Host "[+] UI Bloat Disabled." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to unpin Taskbar bloat: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-TelemetryNuke {
    Write-Host "[*] Nuking Telemetry & Data Collection..." -ForegroundColor Yellow
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $regPath }
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $regPath -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction Stop
        
        Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        
        Stop-Service "dmwappushservice" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
        
        Write-Host "[+] Telemetry Nuked." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to disable Telemetry: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-Debloat {
    param([string]$Profile)
    Write-Host "[*] Eradicating Bloatware ($Profile Profile)..." -ForegroundColor Yellow
    $commonBloat = @("*Microsoft.BingNews*", "*Microsoft.GetHelp*", "*Microsoft.Getstarted*", "*Microsoft.Microsoft3DViewer*", "*king.com.CandyCrush*")
    
    if ($Profile -eq 'Performance') { $commonBloat += "*Microsoft.MicrosoftOfficeHub*" }
    elseif ($Profile -eq 'Stability') { $commonBloat += "*Microsoft.XboxApp*"; $commonBloat += "*Microsoft.XboxGamingOverlay*" }

    foreach ($app in $commonBloat) {
        try {
            $pkg = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            if ($pkg) {
                $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                Write-Host "    [+] Removed $app" -ForegroundColor Green
            } else {
                Write-Host "    [!] Skipped $app (Not Found)" -ForegroundColor DarkYellow
            }
        } catch {
            Write-Host "    [-] Failed to remove $app : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "[+] Bloatware Eradicated." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Invoke-ServicesTweaks {
    param([string]$Profile)
    Write-Host "[*] Optimizing Services ($Profile Profile)..." -ForegroundColor Yellow

    try {
        Stop-Service "SysMain" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
        
        if ($Profile -eq 'Performance') {
            Stop-Service "WSearch" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Set-Service "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
        }
        Write-Host "[+] Services Optimized." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to optimize Services: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

if ($Menu) {
    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "SYSTEM OPTIMIZER (TWEAKER)" } else { Clear-Host }
        Write-Host "Select your Optimization Profile:" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host "[1] Maximum Performance (Lowest latency, Removes built-in productivity apps)" -ForegroundColor Green
        Write-Host "[2] Maximum Stability & Productivity (Safe tweaks, Keeps productivity apps)" -ForegroundColor Blue
        Write-Host "[0] Back to Main Menu" -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        $choice = Read-Host "Profile Selection"
        $profile = ''
        switch ($choice) {
            '1' { $profile = 'Performance' }
            '2' { $profile = 'Stability' }
            '0' { return }
            default { continue }
        }
        
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING TWEAKS" } else { Clear-Host }
        Write-Host "Applying $profile Tweaks. Please wait..." -ForegroundColor Cyan
        
        # Engage Safety Net Before Modifying
        if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
        
        Invoke-TelemetryNuke
        Invoke-Debloat -Profile $profile
        Invoke-ServicesTweaks -Profile $profile
        Invoke-UltimatePowerPlan
        Invoke-WindowsUpdateControl
        Invoke-TaskbarDebloat
        
        if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
    }
}
elseif ($Apply) {
    $applyStart = Get-Date
    $appliedTweaks = [System.Collections.Generic.List[string]]::new()

    # Engage Safety Net Before Modifying
    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
    
    Invoke-TelemetryNuke; $appliedTweaks.Add('Telemetry Disable & Registry Wipe')
    Invoke-Debloat -Profile "Stability"; $appliedTweaks.Add('Stability-Safe App Debloat')
    Invoke-ServicesTweaks -Profile "Stability"; $appliedTweaks.Add('Service Profile Optimization')
    Invoke-UltimatePowerPlan; $appliedTweaks.Add('Ultimate Performance Power Plan')
    Invoke-WindowsUpdateControl; $appliedTweaks.Add('OEM Driver Override Block')
    Invoke-TaskbarDebloat; $appliedTweaks.Add('Taskbar Cleanup (Widgets, Chat, Copilot)')

    $applyDuration = [Math]::Round(((Get-Date) - $applyStart).TotalSeconds, 1)
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "  SYSTEM OPTIMIZER COMPLETE ($applyDuration sec)" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "=================================================" -ForegroundColor Cyan
    foreach ($tweak in $appliedTweaks) {
        Write-Host "  [+] $tweak" -ForegroundColor Green
    }
    Write-Host "=================================================" -ForegroundColor Cyan
}
