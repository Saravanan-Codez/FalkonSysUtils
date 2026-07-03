[CmdletBinding()]
param(
    [switch]$Menu
)

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

function Invoke-WingetInstall {
    param([string[]]$PackageIds, [string]$PackName)
    
    Write-FalkonLog -Level Info -Message "Installing $PackName... This may take a while."
    foreach ($id in $PackageIds) {
        Write-FalkonLog -Level Info -Message "Installing $id..."
        
        # Reset exit code before run
        $LASTEXITCODE = 0
        winget install --id $id -e --accept-package-agreements --accept-source-agreements --silent | Out-Null
        
        $code = $LASTEXITCODE
        if ($code -eq 0) {
            Write-FalkonLog -Level Success -Message "Installed $id Successfully."
        } elseif ($code -eq 2316632065 -or $code -eq -1978335231) {
            Write-FalkonLog -Level Warning -Message "Skipped $id: Already Installed."
        } else {
            Write-FalkonLog -Level Error -Message "Failed to install $id with exit code $code"
        }
    }
    Write-FalkonLog -Level Success -Message "$PackName Process Complete."
    Start-Sleep -Seconds 2
}

if ($Menu) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "PACKAGE INSTALLER" } else { Clear-Host }
        Write-FalkonLog -Level Error -Message "Winget is not installed or available on this system."
        if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        return
    }

    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) {
            Show-FalkonLogo -SubTitle "PACKAGE INSTALLER"
            Show-FalkonBox -Title "SILENT APP INSTALLER ACTIONS" -Lines @(
                "[1] Essentials Pack (Brave, 7-Zip, VLC, Notepad++)",
                "[2] Creator/Dev Pack (VS Code, Git, Python, OBS Studio)",
                "[3] Gaming Pack (Steam, Discord, Epic Games Launcher)",
                "[0] Back to Main Menu"
            ) -Color "Cyan"
            Write-Host ""
        } else { Clear-Host }
        
        $choice = Read-Host "  Selection"
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
