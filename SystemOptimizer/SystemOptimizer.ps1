[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$Apply,
    [switch]$BypassSafetyNet
)

$ErrorActionPreference = 'Stop'

# Import Safety Net (Relative Path)
$safetyPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Safety\SystemRestore.psm1"
if (Test-Path $safetyPath) { Import-Module $safetyPath -ErrorAction SilentlyContinue }

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

function Invoke-UltimatePowerPlan {
    Write-FalkonLog -Level Info -Message "Unlocking Ultimate Performance Power Plan..."

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
            Write-FalkonLog -Level Success -Message "Ultimate Performance Plan unlocked and activated."
        } else {
            Write-FalkonLog -Level Warning -Message "Failed to activate Ultimate Performance."
        }
    } catch {
        Write-FalkonLog -Level Error -Message "Error configuring power plan" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-WindowsUpdateControl {
    Write-FalkonLog -Level Info -Message "Blocking Forced Windows Update Driver Installations..."
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $regPath }
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $regPath -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "OEM Driver Overrides Prevented."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to block Driver Updates" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-TaskbarDebloat {
    Write-FalkonLog -Level Info -Message "Unpinning Chat, Widgets, and Copilot from Taskbar..."
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $regPath }
        Set-ItemProperty -Path $regPath -Name "TaskbarMn" -Value 0 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "TaskbarDa" -Value 0 -Type DWord -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "UI Bloat Disabled."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to unpin Taskbar bloat" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-TelemetryNuke {
    Write-FalkonLog -Level Info -Message "Nuking Telemetry & Data Collection..."
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $regPath }
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $regPath -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction Stop
        
        Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        
        Stop-Service "dmwappushservice" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue

        # Disable scheduled telemetry tasks
        $telemetryTasks = @(
            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
        )
        foreach ($task in $telemetryTasks) {
            $taskName = Split-Path $task -Leaf
            $taskPath = Split-Path $task -Parent
            if (Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue) {
                Disable-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue | Out-Null
                Write-FalkonLog -Level Success -Message "Disabled telemetry task: $taskName"
            }
        }
        
        Write-FalkonLog -Level Success -Message "Telemetry & Tasks Nuked."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to disable Telemetry" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-Debloat {
    param([string]$Profile)
    Write-FalkonLog -Level Info -Message "Eradicating Bloatware ($Profile Profile)..."
    $commonBloat = @("*Microsoft.BingNews*", "*Microsoft.GetHelp*", "*Microsoft.Getstarted*", "*Microsoft.Microsoft3DViewer*", "*king.com.CandyCrush*")
    
    if ($Profile -eq 'Performance') {
        $commonBloat += "*Microsoft.MicrosoftOfficeHub*"
    }
    elseif ($Profile -eq 'Stability') {
        $commonBloat += "*Microsoft.XboxApp*"
        $commonBloat += "*Microsoft.XboxGamingOverlay*"
    }

    foreach ($app in $commonBloat) {
        try {
            $pkg = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            if ($pkg) {
                $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                Write-FalkonLog -Level Success -Message "Removed $app"
            } else {
                Write-FalkonLog -Level Info -Message "Skipped $app (Not Found)"
            }
        } catch {
            Write-FalkonLog -Level Error -Message "Failed to remove $app" -Exception $_.Exception
        }
    }
    Start-Sleep -Seconds 1
}

function Invoke-OptimizeServices {
    param([string]$Profile)
    Write-FalkonLog -Level Info -Message "Optimizing Windows Services ($Profile Profile)..."
    
    # Common services optimization
    $services = @{
        "SysMain" = "Automatic"  # Kept automatic for disk caching stability unless performance is requested
        "XblAuthManager" = "Manual"
        "XblGameSave" = "Manual"
    }

    if ($Profile -eq 'Performance') {
        $services["SysMain"] = "Disabled"
        $services["MapsBroker"] = "Disabled"
        $services["WbioSrvc"] = "Disabled"
    }

    foreach ($srv in $services.Keys) {
        try {
            if (Get-Service -Name $srv -ErrorAction SilentlyContinue) {
                Set-Service -Name $srv -StartupType $services[$srv] -ErrorAction Stop
                Write-FalkonLog -Level Success -Message "Set Service $srv to $($services[$srv])"
            }
        } catch {
            Write-FalkonLog -Level Error -Message "Failed to update service $srv" -Exception $_.Exception
        }
    }
    Start-Sleep -Seconds 1
}

if ($Menu) {
    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) {
            Show-FalkonLogo -SubTitle "PRIVACY & SERVICES OPTIMIZER"
            Show-FalkonBox -Title "CHOOSE PROFILE" -Lines @(
                "[1] Apply Privacy & Telemetry Nuke only",
                "[2] Apply Performance Profile (Removes Cortana/News bloat)",
                "[3] Apply Stability Profile (Preserves Xbox & System integrations)",
                "[0] Back to Main Menu"
            ) -Color "Cyan"
            Write-Host ""
        } else { Clear-Host }
        
        $choice = Read-Host "  Profile Selection"
        if ($choice -eq '0') { return }
        
        if ($choice -eq '1') {
            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING TELEMETRY NUKE" } else { Clear-Host }
            if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) {
                Invoke-FalkonSafetyNet -BypassSafetyNet:$BypassSafetyNet
            }
            Invoke-TelemetryNuke
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
        elseif ($choice -eq '2') {
            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING PERFORMANCE PROFILE" } else { Clear-Host }
            if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) {
                Invoke-FalkonSafetyNet -BypassSafetyNet:$BypassSafetyNet
            }
            Invoke-TelemetryNuke
            Invoke-Debloat -Profile "Performance"
            Invoke-OptimizeServices -Profile "Performance"
            Invoke-UltimatePowerPlan
            Invoke-WindowsUpdateControl
            Invoke-TaskbarDebloat
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
        elseif ($choice -eq '3') {
            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING STABILITY PROFILE" } else { Clear-Host }
            if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) {
                Invoke-FalkonSafetyNet -BypassSafetyNet:$BypassSafetyNet
            }
            Invoke-TelemetryNuke
            Invoke-Debloat -Profile "Stability"
            Invoke-OptimizeServices -Profile "Stability"
            Invoke-UltimatePowerPlan
            Invoke-WindowsUpdateControl
            Invoke-TaskbarDebloat
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
    }
}
elseif ($Apply) {
    $applyStart = Get-Date
    $appliedTweaks = [System.Collections.Generic.List[string]]::new()

    # Engage Safety Net Before Modifying
    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) {
        Invoke-FalkonSafetyNet -BypassSafetyNet:$BypassSafetyNet
    }
    
    Invoke-TelemetryNuke; $appliedTweaks.Add('Telemetry Disable & Registry Wipe')
    Invoke-Debloat -Profile "Stability"; $appliedTweaks.Add('Stability-Safe App Debloat')
    Invoke-OptimizeServices -Profile "Stability"; $appliedTweaks.Add('Service Profile Optimization')
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
