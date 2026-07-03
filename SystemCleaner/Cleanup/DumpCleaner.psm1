Set-StrictMode -Version Latest

function Invoke-UscDumpCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][psobject]$Config
    )

    $paths = @(
        (Join-Path $env:WINDIR 'MEMORY.DMP'),
        (Join-Path $env:WINDIR 'Minidump'),
        (Join-Path $env:WINDIR 'LiveKernelReports'),
        (Join-Path $env:LOCALAPPDATA 'CrashDumps')
    )

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            $results.Add((New-UscOperationResult -Name 'Crash Dumps' -Category Clean -Status Skipped -Paths @($path) -Message 'Path does not exist'))
            continue
        }
        
        $items = @(if ((Get-Item -LiteralPath $path).PSIsContainer) {
            Get-ChildItem -LiteralPath $path -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        }
        else {
            Get-Item -LiteralPath $path -Force
        })
        
        $size = Measure-UscObjectSum -InputObject $items -Property Length
        $failed = 0
        foreach ($item in $items) {
            try {
                if ($PSCmdlet.ShouldProcess($item.FullName, 'Remove crash dump')) {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                }
            }
            catch {
                $failed++
                Write-UscLog -Level Debug -Message "Unable to remove dump $($item.FullName)"
            }
        }
        $results.Add((New-UscOperationResult -Name 'Crash Dumps' -Category Clean -Status $(if ($failed) { 'PartiallySucceeded' } else { 'Succeeded' }) -BytesFreed $size -Paths @($path) -Message "$($items.Count) dump files inspected"))
    }
    return @($results)
}

function Invoke-UscNuclearRecoveryCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][psobject]$Config,
        [switch]$Confirmed
    )

    if (-not $Confirmed) {
        return New-UscOperationResult -Name 'Nuclear recovery cleanup' -Category Clean -Status Skipped -Message 'Skipped: explicit nuclear confirmation was not supplied'
    }

    $results = [System.Collections.Generic.List[object]]::new()
    
    if ($Config.Nuclear.DeleteShadowCopies) {
        $message = 'Deletes all volume shadow copies and removes a major rollback path'
        if ($PSCmdlet.ShouldProcess('All shadow copies', $message)) {
            Write-UscLog -Level Warning -Message 'Deleting all volume shadow copies via vssadmin...'
            $output = & vssadmin.exe delete shadows /all /quiet 2>&1
            $status = 'Succeeded'
            if ($LASTEXITCODE -ne 0 -and $output -notmatch '(?i)No items found') {
                $status = 'Failed'
            }
            $results.Add((New-UscOperationResult -Name 'Shadow Copies' -Category Clean -Status $status -Message ($output -join [Environment]::NewLine)))
        }
    }

    if ($Config.Nuclear.RemoveRestorePoints) {
        $message = 'Removes system restore checkpoints'
        if ($PSCmdlet.ShouldProcess('System restore checkpoints', $message)) {
            Write-UscLog -Level Warning -Message 'Deleting oldest system restore checkpoints...'
            $output = & vssadmin.exe delete shadows /for=$env:SystemDrive /oldest /quiet 2>&1
            $status = 'Succeeded'
            if ($LASTEXITCODE -ne 0 -and $output -notmatch '(?i)No items found') {
                $status = 'Failed'
            }
            $results.Add((New-UscOperationResult -Name 'Restore Points' -Category Clean -Status $status -Message ($output -join [Environment]::NewLine)))
        }
    }

    if ($Config.Nuclear.PurgeUpdateRollback) {
        $message = 'Purges older Windows Update installation rollback logs and folders'
        $updateRollbackPath = Join-Path $env:WINDIR 'winsxs\Backup'
        
        if (Test-Path -LiteralPath $updateRollbackPath) {
            $files = @(Get-ChildItem -LiteralPath $updateRollbackPath -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer })
            $size = Measure-UscObjectSum -InputObject $files -Property Length
            
            if ($PSCmdlet.ShouldProcess('Windows Update Rollback Files', $message)) {
                $failed = 0
                foreach ($file in $files) {
                    try {
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    }
                    catch {
                        $failed++
                    }
                }
                $status = if ($failed) { 'PartiallySucceeded' } else { 'Succeeded' }
                $results.Add((New-UscOperationResult -Name 'Update Rollback Files' -Category Clean -Status $status -BytesFreed $size -Message "Purged rollback files ($failed locks skipped)"))
            }
        }
        else {
            $results.Add((New-UscOperationResult -Name 'Update Rollback Files' -Category Clean -Status Skipped -Message 'Update rollback backup folder does not exist'))
        }
    }

    return @($results)
}

Export-ModuleMember -Function Invoke-UscDumpCleanup, Invoke-UscNuclearRecoveryCleanup
