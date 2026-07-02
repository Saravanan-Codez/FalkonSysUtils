[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$Apply
)

$corePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\FalkonCore.psm1"
if (Test-Path $corePath) { Import-Module $corePath -ErrorAction SilentlyContinue }

$safetyPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Safety\SystemRestore.psm1"
if (Test-Path $safetyPath) { Import-Module $safetyPath -ErrorAction SilentlyContinue }

function Invoke-TcpOptimization {
    Write-Host "[*] Applying TCP/IP Optimization (Nagle's Algorithm & TCPNoDelay)..." -ForegroundColor Yellow
    
    try {
        # TCP NoDelay and TcpAckFrequency (Nagle's Algorithm disable for gaming)
        $interfaces = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -ErrorAction Stop
        foreach ($iface in $interfaces) {
            $path = $iface.PSPath
            Set-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction Stop
            Set-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction Stop
        }
        
        # Global TCP Settings
        netsh int tcp set global autotuninglevel=normal | Out-Null
        netsh int tcp set global ecncapability=disabled | Out-Null
        netsh int tcp set heuristics disabled | Out-Null
        
        Write-Host "[+] TCP/IP Stack Optimized." -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to optimize TCP Stack: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

function Invoke-DnsFlush {
    Write-Host "[*] Flushing DNS Cache and Resetting Winsock..." -ForegroundColor Yellow
    ipconfig /flushdns | Out-Null
    netsh winsock reset | Out-Null
    Write-Host "[+] DNS Flushed." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Invoke-DisableDeliveryOptimization {
    Write-Host "[*] Disabling P2P Windows Update Delivery Optimization..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "[+] Bandwidth Hogging Disabled." -ForegroundColor Green
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
            Invoke-TcpOptimization
            Invoke-DnsFlush
            Invoke-DisableDeliveryOptimization
            
            if (Get-Command Invoke-FalkonPause -ErrorAction SilentlyContinue) { Invoke-FalkonPause }
        }
    }
}
elseif ($Apply) {
    if (Get-Command Invoke-FalkonSafetyNet -ErrorAction SilentlyContinue) { Invoke-FalkonSafetyNet }
    Invoke-TcpOptimization
    Invoke-DnsFlush
    Invoke-DisableDeliveryOptimization
}
