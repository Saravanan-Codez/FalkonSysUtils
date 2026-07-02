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

function Invoke-TcpOptimization {
    param([switch]$WhatIfOnly)
    Write-Host "[*] Applying TCP/IP Optimization (Nagle's Algorithm & TCPNoDelay)..." -ForegroundColor Yellow
    
    if ($WhatIfOnly) {
        Write-Host "[Dry Run] Would optimize TCP/IP Interfaces and settings." -ForegroundColor Green
        return
    }

    try {
        # TCP NoDelay and TcpAckFrequency (Nagle's Algorithm disable for gaming)
        $interfaces = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -ErrorAction Stop
        foreach ($iface in $interfaces) {
            $path = $iface.PSPath
            if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
            Set-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction Stop
            Set-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction Stop
        }
        
        # Global TCP Settings
        $out1 = netsh int tcp set global autotuninglevel=normal 2>&1
        if ($LASTEXITCODE -ne 0) { throw "netsh autotuninglevel failed: $out1" }
        
        $out2 = netsh int tcp set global ecncapability=disabled 2>&1
        if ($LASTEXITCODE -ne 0) { throw "netsh ecncapability failed: $out2" }
        
        $out3 = netsh int tcp set heuristics disabled 2>&1
        if ($LASTEXITCODE -ne 0) { throw "netsh heuristics failed: $out3" }
        
        Write-Host "[+] TCP/IP Stack Optimized." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to optimize TCP Stack: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-DnsFlush {
    param([switch]$WhatIfOnly)
    Write-Host "[*] Flushing DNS Cache and Resetting Winsock..." -ForegroundColor Yellow
    if ($WhatIfOnly) {
        Write-Host "[Dry Run] Would flush DNS and reset Winsock." -ForegroundColor Green
        return
    }
    
    try {
        $out1 = ipconfig /flushdns 2>&1
        if ($LASTEXITCODE -ne 0) { throw "ipconfig /flushdns failed: $out1" }
        
        $out2 = netsh winsock reset 2>&1
        if ($LASTEXITCODE -ne 0) { throw "netsh winsock reset failed: $out2" }
        
        Write-Host "[+] DNS Flushed & Winsock Reset." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to flush DNS / reset Winsock: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-DisableDeliveryOptimization {
    param([switch]$WhatIfOnly)
    Write-Host "[*] Disabling P2P Windows Update Delivery Optimization..." -ForegroundColor Yellow
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
    
    if ($WhatIfOnly) {
        Write-Host "[Dry Run] Would disable Delivery Optimization." -ForegroundColor Green
        return
    }

    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "DODownloadMode" -Value 0 -Type DWord -ErrorAction Stop
        Write-Host "[+] Bandwidth Hogging Disabled." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to disable Delivery Optimization: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

if ($Menu) {
    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "NETWORK OPTIMIZER" } else { Clear-Host }
        Write-Host "Select Network Action:" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host "[1] Apply Ultimate Network Profile (Gaming & Streaming)" -ForegroundColor Green
        Write-Host "[0] Back to Main Menu" -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        $choice = Read-Host "Selection"
        if ($choice -eq '0') { return }
        if ($choice -eq '1') {
            if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) { Show-FalkonLogo -SubTitle "APPLYING TWEAKS" } else { Clear-Host }
            if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
            Invoke-TcpOptimization -WhatIfOnly:$WhatIfOnly
            Invoke-DnsFlush -WhatIfOnly:$WhatIfOnly
            Invoke-DisableDeliveryOptimization -WhatIfOnly:$WhatIfOnly
            
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
    }
}
elseif ($Apply) {
    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
    Invoke-TcpOptimization -WhatIfOnly:$WhatIfOnly
    Invoke-DnsFlush -WhatIfOnly:$WhatIfOnly
    Invoke-DisableDeliveryOptimization -WhatIfOnly:$WhatIfOnly
}
