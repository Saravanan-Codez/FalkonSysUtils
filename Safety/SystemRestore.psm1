function Invoke-FalkonSafetyNet {
    param(
        [switch]$BypassSafetyNet
    )

    if ($global:FalkonRestorePointCreated) {
        if (Get-Command Write-FalkonLog -ErrorAction SilentlyContinue) {
            Write-FalkonLog -Level Info -Message "Session Restore Point already created. Skipping duplicate checkpoint."
        } else {
            Write-Host "  [*] Session Restore Point already created. Skipping duplicate checkpoint." -ForegroundColor Gray
        }
        return
    }

    if (Get-Command Write-FalkonLog -ErrorAction SilentlyContinue) {
        Write-FalkonLog -Level Info -Message "Checking System Protection Status..."
    } else {
        Write-Host "  [*] Checking System Protection Status..." -ForegroundColor Yellow
    }
    
    # Enable System Restore on the OS drive if it's disabled
    $osDrive = $env:SystemDrive + "\"
    Enable-ComputerRestore -Drive $osDrive -ErrorAction SilentlyContinue | Out-Null
    
    if (Get-Command Write-FalkonLog -ErrorAction SilentlyContinue) {
        Write-FalkonLog -Level Info -Message "Generating Falkon Pre-Optimization Snapshot..."
    } else {
        Write-Host "  [*] Generating Falkon Pre-Optimization Snapshot..." -ForegroundColor Yellow
    }

    $srRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $registryValName = "SystemRestorePointCreationFrequency"
    $originalVal = $null
    $registryModified = $false

    if (Test-Path -LiteralPath $srRegistryPath) {
        try {
            $originalVal = Get-ItemPropertyValue -Path $srRegistryPath -Name $registryValName -ErrorAction Stop
        } catch {
            # Property doesn't exist, which is fine
        }
        try {
            Set-ItemProperty -Path $srRegistryPath -Name $registryValName -Value 0 -Type DWord -Force -ErrorAction Stop
            $registryModified = $true
        } catch {
            if (Get-Command Write-FalkonLog -ErrorAction SilentlyContinue) {
                Write-FalkonLog -Level Warning -Message "Failed to temporarily adjust System Restore rate limit registry key."
            } else {
                Write-Warning "Failed to temporarily adjust System Restore rate limit registry key."
            }
        }
    }

    try {
        Checkpoint-Computer -Description "Falkon Pre-Optimization Snapshot" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        $global:FalkonRestorePointCreated = $true
        if (Get-Command Write-FalkonLog -ErrorAction SilentlyContinue) {
            Write-FalkonLog -Level Success -Message "System Restore Point Created Successfully."
        } else {
            Write-Host "  [+] System Restore Point Created Successfully." -ForegroundColor Green
        }
    }
    catch {
        $exc = $_.Exception
        if (Get-Command Write-FalkonLog -ErrorAction SilentlyContinue) {
            Write-FalkonLog -Level Warning -Message "Could not create restore point (Windows rate-limits checkpoints to 1 per 24 hours, or System Protection is disabled)."
        } else {
            Write-Host "  [!] WARNING: Could not create restore point (Windows rate-limits checkpoints to 1 per 24 hours, or System Protection is disabled)." -ForegroundColor Red
        }

        if ($BypassSafetyNet) {
            if (Get-Command Write-FalkonLog -ErrorAction SilentlyContinue) {
                Write-FalkonLog -Level Warning -Message "Proceeding without restore point rollback capability as requested by -BypassSafetyNet."
            } else {
                Write-Warning "Proceeding without restore point rollback capability as requested by -BypassSafetyNet."
            }
        } else {
            $isInteractive = [Environment]::UserInteractive -and ($null -ne $Host.UI)
            if ($isInteractive) {
                $confirm = Read-Host "Registry/System optimizations will run without rollback protection. Proceed anyway? (y/N)"
                if ($confirm -notmatch '^[yY]') {
                    throw "Execution aborted: restore point generation failed and user chose not to bypass safety checkpoint."
                }
            } else {
                throw "Execution aborted: System Restore point creation failed in non-interactive context, and -BypassSafetyNet was not specified. Error: $($exc.Message)"
            }
        }
    }
    finally {
        if ($registryModified) {
            try {
                if ($null -eq $originalVal) {
                    Remove-ItemProperty -Path $srRegistryPath -Name $registryValName -Force -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty -Path $srRegistryPath -Name $registryValName -Value $originalVal -Type DWord -Force -ErrorAction Stop
                }
            } catch {}
        }
    }
}

Export-ModuleMember -Function Invoke-FalkonSafetyNet
