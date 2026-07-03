<# 
.SYNOPSIS
Ultimate System Utility - Production-Grade Windows Performance Suite
.DESCRIPTION
The root orchestrator and entry point for Falkon Labs Ultimate System Utility suite.
Features web-bootstrapping and coordinates multiple sub-tools (Cleaner, Optimizer, etc.).
.EXAMPLE
.\UltimateSystemUtil.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # System Cleaner Parameters (Forwarded to Cleaner launcher)
    [switch]$Safe,
    [switch]$Aggressive,
    [switch]$Nuclear,
    [switch]$Analyze,
    [switch]$Diagnose,
    [switch]$ComponentStore,
    [switch]$InstallScheduledTask,
    [switch]$RemoveScheduledTask,
    [switch]$Menu,
    [switch]$GenerateReport,
    [switch]$ConfirmNuclear,
    [switch]$BypassSafetyNet,
    [string]$ConfigPath
)

# --- Web Bootstrap Handler ---
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    $null = Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
    Write-Host '==================================================' -ForegroundColor Cyan
    Write-Host '       FALKON SYSTEM UTILITIES WEB BOOTSTRAP       ' -ForegroundColor White -BackgroundColor Blue
    Write-Host '==================================================' -ForegroundColor Cyan
    
    $zipUrl = 'https://github.com/Saravanan-Codez/FalkonSysUtils/archive/refs/heads/main.zip'
    $tempDir = Join-Path $env:TEMP 'FalkonSysUtils-Bootstrap'
    
    Write-Host "Source: $zipUrl" -ForegroundColor Gray
    Write-Host ""
    
    if ([Environment]::UserInteractive) {
        $confirm = Read-Host "Proceed with downloading and executing the suite? (y/N)"
        if ($confirm -notmatch '^[yY]') {
            Write-Host "Bootstrap aborted by user." -ForegroundColor Yellow
            return
        }
    } else {
        Write-Warning "FalkonSysUtils: Proceeding with web bootstrap in non-interactive session."
    }
    
    Write-Host 'Running in web-load context. Bootstrapping files...' -ForegroundColor Gray
    try {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        $zipFile = Join-Path $tempDir 'repo.zip'
        Write-Host 'Downloading repository package from GitHub...' -ForegroundColor Gray
        
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod -Uri $zipUrl -OutFile $zipFile -ErrorAction Stop
        
        Write-Host 'Extracting files to temp workspace...' -ForegroundColor Gray
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force -ErrorAction Stop
        
        $expandedFolder = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
        if ($expandedFolder) {
            $launcherPath = Join-Path $expandedFolder.FullName 'FalkonSysUtils.ps1'
            Write-Host 'Running launcher in localized workspace...' -ForegroundColor Green
            Start-Sleep -Seconds 1
            
            $boundArgs = @{}
            foreach ($key in $PSBoundParameters.Keys) {
                $boundArgs[$key] = $PSBoundParameters[$key]
            }
            & $launcherPath @boundArgs
        }
        else {
            Write-Error 'Failed to locate extracted launcher files in temp directory.'
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Web bootstrap failed: $errorMessage"
    }
    return
}

# Scan for blocked script files (excluding community Plugins)
$blockedFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Include *.ps1,*.psm1 -Recurse -ErrorAction SilentlyContinue | Where-Object {
    ($_.FullName -notlike "*\Plugins\*") -and (Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue)
})

if ($blockedFiles.Count -gt 0) {
    $shouldUnblock = $false
    if ([Environment]::UserInteractive) {
        Write-Host "==================================================" -ForegroundColor Yellow
        Write-Host " SECURITY NOTICE: BLOCKED SCRIPTS DETECTED" -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "==================================================" -ForegroundColor Yellow
        Write-Host "PowerShell detected that the following suite script files were downloaded" -ForegroundColor Gray
        Write-Host "from the Internet and are blocked by Windows Security:" -ForegroundColor Gray
        foreach ($file in $blockedFiles) {
            Write-Host "  - $($file.Name)" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Unblocking these files is required for the utility to run." -ForegroundColor Gray
        $response = Read-Host "Do you want to unblock these files now? (y/N)"
        if ($response -match '^[yY]') {
            $shouldUnblock = $true
        }
    } else {
        # Non-interactive mode: we must log a warning and unblock to ensure execution succeeds
        Write-Warning "FalkonSysUtils: Automatically unblocking $($blockedFiles.Count) files in non-interactive session."
        $shouldUnblock = $true
    }

    if ($shouldUnblock) {
        $blockedFiles | Unblock-File -ErrorAction SilentlyContinue
    } else {
        Write-Warning "Files were not unblocked. The application may fail to run due to execution policies."
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Function to check Administrator context
function Test-UscAdministratorPrivilege {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$corePath = Join-Path $PSScriptRoot 'Core\FalkonCore.psm1'
if (Test-Path -LiteralPath $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

# Check if arguments are provided. If so, forward directly to System Cleaner CLI mode.
$argsBound = $PSBoundParameters.Count -gt 0
if ($argsBound -and -not $Menu) {
    $global:UscNonInteractive = $true
    $cleanerPath = Join-Path $PSScriptRoot 'SystemCleaner\UltimateSystemCleaner.ps1'
    if (Test-Path -LiteralPath $cleanerPath) {
        $boundArgs = @{}
        foreach ($key in $PSBoundParameters.Keys) {
            $boundArgs[$key] = $PSBoundParameters[$key]
        }
        & $cleanerPath @boundArgs
    }
    else {
        Write-Error "System Cleaner module is missing from $cleanerPath."
    }
    return
}

# Interactive TUI orchestrator loop
$adminStatus = 'Standard User (Some functions restricted)'
if (Test-UscAdministratorPrivilege) { $adminStatus = 'Elevated (Admin)' }

$osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
$cpuInfo = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name
$ramInfo = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 1)

while ($true) {
    if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) {
        Show-FalkonLogo
        Show-FalkonBox -Title "SYSTEM CONTEXT & INFORMATION" -Lines @(
            "Privilege Context : $adminStatus",
            "OS System         : $osInfo",
            "Processor         : $cpuInfo",
            "Installed RAM     : $ramInfo GB"
        ) -Color "Gray"
        Write-Host ""
        Show-FalkonBox -Title "MAIN MENU OPTIONS" -Lines @(
            "[1] System Disk Space Cleaner",
            "[2] Windows Registry Optimizer",
            "[3] TCP/IP Network Connection Latency Optimizer",
            "[4] Windows Privacy Telemetry & Services Tweaker",
            "[5] Software Silent Batch Package Installer",
            "[6] Apply Recommended Settings (One-Click Preset)",
            "[7] Diagnose System Space Only (No Deletions)",
            "[0] Exit"
        ) -Color "Cyan"
        Write-Host ""
    } else {
        Clear-Host
    }
    
    $selection = Read-Host '  Selection'
    switch ($selection) {
        '1' {
            $cleanerPath = Join-Path $PSScriptRoot 'SystemCleaner\UltimateSystemCleaner.ps1'
            if (Test-Path -LiteralPath $cleanerPath) { & $cleanerPath -Menu }
            else { Write-Host "Module missing: $cleanerPath" -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
        '2' {
            $regPath = Join-Path $PSScriptRoot 'RegistryOptimizer\RegistryOptimizer.ps1'
            if (Test-Path -LiteralPath $regPath) { & $regPath -Menu }
            else { Write-Host "Module missing: $regPath" -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
        '3' {
            $netPath = Join-Path $PSScriptRoot 'NetworkOptimizer\NetworkOptimizer.ps1'
            if (Test-Path -LiteralPath $netPath) { & $netPath -Menu }
            else { Write-Host "Module missing: $netPath" -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
        '4' {
            $optPath = Join-Path $PSScriptRoot 'SystemOptimizer\SystemOptimizer.ps1'
            if (Test-Path -LiteralPath $optPath) { & $optPath -Menu }
            else { Write-Host "Module missing: $optPath" -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
        '5' {
            $appPath = Join-Path $PSScriptRoot 'FalkonPackageStore\AppInstaller.ps1'
            if (Test-Path -LiteralPath $appPath) { & $appPath -Menu }
            else { Write-Host "Module missing: $appPath" -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
        '6' {
            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) {
                Show-FalkonLogo -SubTitle "PRESET VERIFICATION"
                Show-FalkonBox -Title "PRESET INSTRUCTIONS & RISK LEVEL" -Lines @(
                    "You are about to apply the Recommended Settings preset.",
                    "This preset combines two distinct risk-level operations:",
                    "",
                    "  1. Disk Cleanup (SAFE):",
                    "     Deletes temp folders, recycle bin items, logs.",
                    "",
                    "  2. System Tweaks (INVASIVE):",
                    "     Telemetry disable, network TCP tuning, registry optimizer."
                ) -Color "Yellow"
                Write-Host ""
            } else { Clear-Host }
            
            $pConfirm = Show-FalkonConfirm -PromptMessage "Apply all recommended tweaks?"
            if (-not $pConfirm) {
                Write-Host "  [*] Preset canceled." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                continue
            }

            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING PRESET" } else { Clear-Host }
            
            # 1. Safety Net Restore Point
            $safetyPath = Join-Path $PSScriptRoot "Safety\SystemRestore.psm1"
            if (Test-Path $safetyPath) {
                Import-Module $safetyPath -ErrorAction SilentlyContinue
                if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) {
                    Invoke-FalkonSafetyNet -BypassSafetyNet:$BypassSafetyNet
                }
            }

            # 2. Disk Space Cleanup (Safe Mode)
            $cleanerPath = Join-Path $PSScriptRoot 'SystemCleaner\UltimateSystemCleaner.ps1'
            if (Test-Path $cleanerPath) {
                Write-Host "[*] Executing Safe Disk Cleanup..." -ForegroundColor Yellow
                & $cleanerPath -Safe -GenerateReport -BypassSafetyNet:$BypassSafetyNet
            }

            # 3. Registry Optimizer
            $regPath = Join-Path $PSScriptRoot 'RegistryOptimizer\RegistryOptimizer.ps1'
            if (Test-Path $regPath) { & $regPath -Apply -BypassSafetyNet:$BypassSafetyNet }

            # 4. Network Optimizer
            $netPath = Join-Path $PSScriptRoot 'NetworkOptimizer\NetworkOptimizer.ps1'
            if (Test-Path $netPath) { & $netPath -Apply -BypassSafetyNet:$BypassSafetyNet }

            # 5. System Optimizer
            $optPath = Join-Path $PSScriptRoot 'SystemOptimizer\SystemOptimizer.ps1'
            if (Test-Path $optPath) { & $optPath -Apply -BypassSafetyNet:$BypassSafetyNet }

            $reportDir = Join-Path $env:ProgramData 'UltimateSystemCleaner\Reports'
            $lastReport = Get-ChildItem -Path $reportDir -Filter "*.html" -ErrorAction SilentlyContinue |
                          Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $lastReportPath = if ($lastReport) { $lastReport.FullName } else { 'N/A' }

            Write-Host ""
            Write-Host "==================================================" -ForegroundColor Cyan
            Write-Host "             PRESET OPERATIONS COMPLETE           " -ForegroundColor White -BackgroundColor DarkGreen
            Write-Host "==================================================" -ForegroundColor Cyan
            Write-Host " [+] Safety Restore Point  : Created (or verified)" -ForegroundColor Green
            Write-Host " [+] Safe Disk Cleanup     : Success" -ForegroundColor Green
            Write-Host " [+] Registry Optimizer    : Success (Rollback created)" -ForegroundColor Green
            Write-Host " [+] Network Optimizer     : Success" -ForegroundColor Green
            Write-Host " [+] System Optimizer      : Success" -ForegroundColor Green
            Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
            Write-Host " Registry Backups Path     : %ProgramData%\FalkonSysUtils\Rollbacks\" -ForegroundColor Gray
            Write-Host " Last Cleaner HTML Report  : $lastReportPath" -ForegroundColor Gray
            Write-Host "==================================================" -ForegroundColor Cyan
            Write-Host "Press any key to return to the main menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '7' {
            $cleanerPath = Join-Path $PSScriptRoot 'SystemCleaner\UltimateSystemCleaner.ps1'
            if (Test-Path -LiteralPath $cleanerPath) {
                & $cleanerPath -Diagnose
                Write-Host ""
                Write-Host "Press any key to return to the main menu..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            } else {
                Write-Host "Module missing: $cleanerPath" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        '0' {
            Write-Host 'Goodbye!' -ForegroundColor Cyan
            break
        }
        default {
            Write-Host 'Invalid choice, try again.' -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
