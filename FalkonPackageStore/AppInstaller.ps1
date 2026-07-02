[CmdletBinding()]
param(
    [switch]$Menu
)

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

function Invoke-WingetInstall {
    param([string[]]$PackageIds, [string]$PackName)
    
    Write-Host "[*] Installing $PackName... This may take a while." -ForegroundColor Yellow
    foreach ($id in $PackageIds) {
        Write-Host " -> Installing $id..." -ForegroundColor Cyan
        
        # Reset exit code before run
        $global:LASTEXITCODE = 0
        winget install --id $id -e --accept-package-agreements --accept-source-agreements --silent | Out-Null
        
        $code = $global:LASTEXITCODE
        if ($code -eq 0) {
            Write-Host "    [+] Installed Successfully." -ForegroundColor Green
        } elseif ($code -eq 2316632065 -or $code -eq -1978335231) {
            Write-Host "    [!] Skipped: Already Installed." -ForegroundColor DarkYellow
        } else {
            Write-Host "    [-] Failed with exit code $code" -ForegroundColor Red
        }
    }
    Write-Host "[+] $PackName Process Complete." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

if ($Menu) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "PACKAGE INSTALLER" } else { Clear-Host }
        Write-Host "[!] Winget is not installed or available on this system." -ForegroundColor Red
        if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        return
    }

    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "PACKAGE INSTALLER" } else { Clear-Host }
        Write-Host "Select Software Pack to Install silently:" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host "[1] Essentials Pack (Brave, 7-Zip, VLC, Notepad++)" -ForegroundColor Green
        Write-Host "[2] Creator/Dev Pack (VS Code, Git, Python, OBS Studio)" -ForegroundColor Magenta
        Write-Host "[3] Gaming Pack (Steam, Discord, Epic Games Launcher)" -ForegroundColor Blue
        Write-Host "[0] Back to Main Menu" -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        $choice = Read-Host "Selection"
        if ($choice -eq '0') { return }
        
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "DOWNLOADING PACKAGES" } else { Clear-Host }
        
        switch ($choice) {
            '1' {
                $packages = @("Brave.Brave", "7zip.7zip", "VideoLAN.VLC", "Notepad++.Notepad++")
                Invoke-WingetInstall -PackageIds $packages -PackName "Essentials Pack"
            }
            '2' {
                $packages = @("Microsoft.VisualStudioCode", "Git.Git", "Python.Python.3.11", "OBSProject.OBSStudio")
                Invoke-WingetInstall -PackageIds $packages -PackName "Creator/Dev Pack"
            }
            '3' {
                $packages = @("Valve.Steam", "Discord.Discord", "EpicGames.EpicGamesLauncher")
                Invoke-WingetInstall -PackageIds $packages -PackName "Gaming Pack"
            }
        }
        if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
    }
}
