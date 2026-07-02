function Invoke-FalkonSafetyNet {
    Write-Host "[*] Checking System Protection Status..." -ForegroundColor Yellow
    
    # Enable System Restore on the OS drive if it's disabled
    $osDrive = $env:SystemDrive + "\"
    Enable-ComputerRestore -Drive $osDrive -ErrorAction SilentlyContinue | Out-Null
    
    Write-Host "[*] Generating Falkon Pre-Optimization Snapshot..." -ForegroundColor Yellow
    try {
        Checkpoint-Computer -Description "Falkon Pre-Optimization Snapshot" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "[+] System Restore Point Created Successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Could not create restore point (it may have been created recently or system protection is off in group policy). Proceeding anyway." -ForegroundColor DarkYellow
    }
    Start-Sleep -Seconds 1
}

Export-ModuleMember -Function Invoke-FalkonSafetyNet
