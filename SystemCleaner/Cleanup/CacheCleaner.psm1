Set-StrictMode -Version Latest

function Invoke-UscRecycleBinCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$WhatIfOnly)

    try {
        if ($WhatIfOnly) {
            return New-UscOperationResult -Name 'Recycle Bin' -Category Clean -Status Skipped -Message 'Dry run: recycle bin would be cleared'
        }
        if ($PSCmdlet.ShouldProcess('Recycle Bin', 'Clear recycle bin')) {
            Clear-RecycleBin -Force -ErrorAction Stop
            return New-UscOperationResult -Name 'Recycle Bin' -Category Clean -Status Succeeded -Message 'Recycle bin cleared'
        }
    }
    catch {
        Write-UscLog -Level Warning -Message 'Recycle bin cleanup failed' -Exception $_.Exception
        return New-UscOperationResult -Name 'Recycle Bin' -Category Clean -Status Failed -Message $_.Exception.Message
    }
}

function Invoke-UscWerCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][psobject]$Config,
        [switch]$WhatIfOnly
    )

    $paths = @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive')
        (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue')
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WER')
    )

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            $results.Add((New-UscOperationResult -Name 'Windows Error Reporting' -Category Clean -Status Skipped -Paths @($path) -Message 'Path does not exist'))
            continue
        }

        $items = @(Get-ChildItem -LiteralPath $path -Force -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-UscExcludedPath -Path $_.FullName -Exclusions $Config.Exclusions) })
        $size = Measure-UscObjectSum -InputObject $items -Property Length
        $failed = 0

        foreach ($item in $items) {
            try {
                if (-not $WhatIfOnly -and $PSCmdlet.ShouldProcess($item.FullName, 'Remove WER item')) {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
            }
            catch {
                $failed++
                Write-UscLog -Level Warning -Message "Unable to remove WER item $($item.FullName)" -Exception $_.Exception
            }
        }

        $results.Add((New-UscOperationResult -Name 'Windows Error Reporting' -Category Clean -Status $(if ($failed) { 'PartiallySucceeded' } else { 'Succeeded' }) -BytesFreed $size -Paths @($path) -Message "$($items.Count) candidate items"))
    }
    return @($results)
}

function Invoke-UscDnsFlush {
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$WhatIfOnly)

    if ($WhatIfOnly) {
        return New-UscOperationResult -Name 'DNS Resolver Cache' -Category Clean -Status Skipped -Message 'Dry run: DNS cache resolver would be flushed'
    }

    try {
        if ($PSCmdlet.ShouldProcess('DNS Resolver Cache', 'Flush DNS Cache')) {
            Clear-DnsClientCache -ErrorAction Stop
            return New-UscOperationResult -Name 'DNS Resolver Cache' -Category Clean -Status Succeeded -Message 'DNS Cache flushed successfully'
        }
    }
    catch {
        Write-UscLog -Level Warning -Message 'DNS Cache flush failed' -Exception $_.Exception
        return New-UscOperationResult -Name 'DNS Resolver Cache' -Category Clean -Status Failed -Message $_.Exception.Message
    }
}

function Invoke-UscFontCacheCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$WhatIfOnly)

    $fontCachePath = Join-Path $env:WINDIR 'ServiceProfiles\LocalService\AppData\Local\FontCache'
    $datFile = Join-Path $env:LOCALAPPDATA 'GDIPFONTCACHEV1.dat'

    if ($WhatIfOnly) {
        return New-UscOperationResult -Name 'Font Cache' -Category Clean -Status Skipped -Message 'Dry run: Font cache databases would be deleted'
    }

    if (-not $PSCmdlet.ShouldProcess('System Font Cache', 'Stop service and delete cache files')) {
        return New-UscOperationResult -Name 'Font Cache' -Category Clean -Status Skipped -Message 'User cancelled'
    }

    $serviceName = 'FontCache'
    $serviceStopped = $false
    try {
        if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            $serviceStopped = $true
            Write-UscLog -Level Information -Message 'Stopped FontCache service for cleanup'
        }
    }
    catch {
        Write-UscLog -Level Warning -Message 'Could not stop FontCache service. Continuing anyway.' -Exception $_.Exception
    }

    $freed = 0
    $failed = 0

    $files = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $fontCachePath) {
        $files.AddRange(@(Get-ChildItem -LiteralPath $fontCachePath -File -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName))
    }
    if (Test-Path -LiteralPath $datFile) {
        $files.Add($datFile)
    }

    foreach ($file in $files) {
        try {
            $size = (Get-Item -LiteralPath $file).Length
            Remove-Item -LiteralPath $file -Force -ErrorAction Stop
            $freed += $size
        }
        catch {
            $failed++
            Write-UscLog -Level Debug -Message "Failed to delete font cache file: $file"
        }
    }

    if ($serviceStopped) {
        try {
            Start-Service -Name $serviceName -ErrorAction Stop
            Write-UscLog -Level Information -Message 'Restarted FontCache service'
        }
        catch {
            Write-UscLog -Level Warning -Message 'Could not restart FontCache service' -Exception $_.Exception
        }
    }

    return New-UscOperationResult -Name 'Font Cache' -Category Clean -Status $(if ($failed) { 'PartiallySucceeded' } else { 'Succeeded' }) -BytesFreed $freed -Message "Cleaned $freed bytes, $failed files failed"
}

function Invoke-UscDeliveryOptimizationCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$WhatIfOnly)

    $doPath = Join-Path $env:ProgramData 'Microsoft\Network\Downloader'
    if (-not (Test-Path -LiteralPath $doPath)) {
        return New-UscOperationResult -Name 'Delivery Optimization Cache' -Category Clean -Status Skipped -Message 'Path does not exist'
    }

    if ($WhatIfOnly) {
        return New-UscOperationResult -Name 'Delivery Optimization Cache' -Category Clean -Status Skipped -Message 'Dry run: Delivery Optimization cache would be purged'
    }

    if ($PSCmdlet.ShouldProcess('Delivery Optimization Cache', 'Purge DO folder files')) {
        $serviceName = 'dosvc'
        $serviceStopped = $false
        try {
            if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                $serviceStopped = $true
            }
        }
        catch {}

        $freed = 0
        $failed = 0
        try {
            $items = Get-ChildItem -LiteralPath $doPath -Force -Recurse -File -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                try {
                    $size = $item.Length
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                    $freed += $size
                }
                catch {
                    $failed++
                }
            }
        }
        finally {
            if ($serviceStopped) {
                try { Start-Service -Name $serviceName -ErrorAction Stop } catch {}
            }
        }

        return New-UscOperationResult -Name 'Delivery Optimization Cache' -Category Clean -Status $(if ($failed) { 'PartiallySucceeded' } else { 'Succeeded' }) -BytesFreed $freed -Message "DO Cache cleaned: $freed bytes freed"
    }
}

Export-ModuleMember -Function Invoke-UscRecycleBinCleanup, Invoke-UscWerCleanup, Invoke-UscDnsFlush, Invoke-UscFontCacheCleanup, Invoke-UscDeliveryOptimizationCleanup

