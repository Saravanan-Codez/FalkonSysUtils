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

function Invoke-TcpOptimization {
    Write-FalkonLog -Level Info -Message "Applying TCP/IP Optimization (Nagle's Algorithm & TCPNoDelay)..."
    
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
        
        Write-FalkonLog -Level Success -Message "TCP/IP Stack Optimized."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to optimize TCP Stack" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-DnsFlush {
    Write-FalkonLog -Level Info -Message "Flushing DNS Cache and Resetting Winsock..."
    
    try {
        $out1 = ipconfig /flushdns 2>&1
        if ($LASTEXITCODE -ne 0) { throw "ipconfig /flushdns failed: $out1" }
        
        $out2 = netsh winsock reset 2>&1
        if ($LASTEXITCODE -ne 0) { throw "netsh winsock reset failed: $out2" }
        
        Write-FalkonLog -Level Success -Message "DNS Flushed & Winsock Reset."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to flush DNS / reset Winsock" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-DisableDeliveryOptimization {
    Write-FalkonLog -Level Info -Message "Disabling P2P Windows Update Delivery Optimization..."
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
    
    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "DODownloadMode" -Value 0 -Type DWord -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "Bandwidth Hogging Disabled."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to disable Delivery Optimization" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

function Invoke-NetworkThrottlingTweak {
    Write-FalkonLog -Level Info -Message "Disabling Windows Network Throttling Index..."
    $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    try {
        if (Get-Command Backup-FalkonRegistryKey -ErrorAction SilentlyContinue) { Backup-FalkonRegistryKey -Path $path }
        if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $path -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $path -Name "SystemResponsiveness" -Value 0 -Type DWord -ErrorAction Stop
        Write-FalkonLog -Level Success -Message "Network Throttling Disabled & Responsiveness optimized."
    } catch {
        Write-FalkonLog -Level Error -Message "Failed to optimize Network Throttling / Responsiveness" -Exception $_.Exception
    }
    Start-Sleep -Seconds 1
}

if ($Menu) {
    while ($true) {
        if (Get-Command Show-FalkonLogo -ErrorAction SilentlyContinue) {
            Show-FalkonLogo -SubTitle "NETWORK OPTIMIZER"
            Show-FalkonBox -Title "NETWORK OPTIMIZER ACTIONS" -Lines @(
                "[1] Apply Ultimate Network Profile (Gaming, Streaming & Throttling Fix)",
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
            Invoke-TcpOptimization
            Invoke-DnsFlush
            Invoke-DisableDeliveryOptimization
            Invoke-NetworkThrottlingTweak
            
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
    Invoke-TcpOptimization; $appliedTweaks.Add('TCP/IP Tuning (CTCP, Window Scaling, Nagle Disable)')
    Invoke-DnsFlush; $appliedTweaks.Add('DNS Cache Flush')
    Invoke-DisableDeliveryOptimization; $appliedTweaks.Add('Delivery Optimization (Bandwidth Hog) Disabled')
    Invoke-NetworkThrottlingTweak; $appliedTweaks.Add('Network Throttling Index Disabled & Multimedia Priority Optimized')

    $applyDuration = [Math]::Round(((Get-Date) - $applyStart).TotalSeconds, 1)
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "  NETWORK OPTIMIZER COMPLETE ($applyDuration sec)" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "=================================================" -ForegroundColor Cyan
    foreach ($tweak in $appliedTweaks) {
        Write-Host "  [+] $tweak" -ForegroundColor Green
    }
    Write-Host "=================================================" -ForegroundColor Cyan
}
