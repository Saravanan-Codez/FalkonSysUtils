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
        Write-Host "[!] WARNING: Could not create restore point (Windows rate-limits checkpoints to 1 per 24 hours, or System Protection is disabled)." -ForegroundColor Red
        if ($Host.UI -ne $null -and ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Visual Studio Code Host')) {
            $confirm = Read-Host "Registry/System optimizations will run without rollback protection. Proceed anyway? (y/N)"
            if ($confirm -notmatch '^[yY]') {
                throw "Execution aborted: restore point generation failed and user chose not to bypass safety checkpoint."
            }
        } else {
            Write-Warning "Non-interactive context. Proceeding without restore point rollback capability."
        }
    }
}

Export-ModuleMember -Function Invoke-FalkonSafetyNet
