[CmdletBinding()]
param(
    [switch]$Menu
)

$ErrorActionPreference = 'Stop'

function Show-InstallerHeader {
    Clear-Host
    Write-Host '==================================================' -ForegroundColor Cyan
    Write-Host '         FALKON ESSENTIAL APP INSTALLER           ' -ForegroundColor White -BackgroundColor DarkMagenta
    Write-Host '==================================================' -ForegroundColor Cyan
}

function Invoke-WingetInstall {
    param([string[]]$PackageIds, [string]$PackName)
    
    Write-Host "[*] Installing $PackName... This may take a while." -ForegroundColor Yellow
    foreach ($id in $PackageIds) {
        Write-Host " -> Installing $id..." -ForegroundColor Cyan
        # Try to install silently and accept source agreements
        winget install --id $id -e --accept-package-agreements --accept-source-agreements --silent | Out-Null
        if ($?) {
            Write-Host "    [+] Installed." -ForegroundColor Green
        } else {
            Write-Host "    [-] Failed or already installed." -ForegroundColor DarkYellow
        }
    }
    Write-Host "[+] $PackName Installation Complete." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

if ($Menu) {
    # Check if winget is available
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Show-InstallerHeader
        Write-Host "[!] Winget is not installed or available on this system." -ForegroundColor Red
        Write-Host "Press any key to return..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    while ($true) {
        Show-InstallerHeader
        Write-Host "Select Software Pack to Install silently:" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host "[1] Essentials Pack (Brave, 7-Zip, VLC, Notepad++)" -ForegroundColor Green
        Write-Host "[2] Creator/Dev Pack (VS Code, Git, Python, OBS Studio)" -ForegroundColor Magenta
        Write-Host "[3] Gaming Pack (Steam, Discord, Epic Games Launcher)" -ForegroundColor Blue
        Write-Host "[0] Back to Main Menu" -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        $choice = Read-Host "Selection"
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
            '0' { return }
            default { continue }
        }
    }
}
