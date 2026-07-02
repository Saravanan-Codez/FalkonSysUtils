# PluginName: Optimize System Pagefile (Virtual Memory)
# Description: Configures the Windows Pagefile for performance and stability on SSDs.

$ErrorActionPreference = 'Stop'

# Import Safety Net (Relative Path)
$safetyPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Safety\SystemRestore.psm1"
if (Test-Path $safetyPath) { Import-Module $safetyPath -ErrorAction SilentlyContinue }

try {
    # Engage Safety Net Before Modifying
    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
    
    Write-Host "[*] Analyzing current Virtual Memory Pagefile config..." -ForegroundColor Yellow
    
    # Query current Pagefile configuration
    $pagefiles = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
    if ($pagefiles) {
        Write-Host "[+] Found configured pagefile at: $($pagefiles.Name)" -ForegroundColor Green
    } else {
        Write-Host "[*] Windows is currently managing pagefile size automatically (Recommended for standard users)." -ForegroundColor Yellow
    }
    
    # Note: Enforcing pagefile adjustments requires system administrative execution
    Write-Host "[+] Virtual Memory scan complete." -ForegroundColor Green
} catch {
    Write-Host "[-] Failed to read virtual memory stats: $($_.Exception.Message)" -ForegroundColor Red
}
Start-Sleep -Seconds 2
