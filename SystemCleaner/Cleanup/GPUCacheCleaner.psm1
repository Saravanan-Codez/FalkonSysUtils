Set-StrictMode -Version Latest

function Invoke-UscGpuCacheCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][psobject]$Config,
        [switch]$WhatIfOnly
    )

    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache')
        (Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache')
        (Join-Path $env:LOCALAPPDATA 'NVIDIA\ComputeCache')
        (Join-Path $env:LOCALAPPDATA 'AMD\DxCache')
        (Join-Path $env:LOCALAPPDATA 'Intel\ShaderCache')
        (Join-Path $env:LOCALAPPDATA 'D3DSCache')
    )

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            $results.Add((New-UscOperationResult -Name 'GPU Shader Cache' -Category Clean -Status Skipped -Paths @($path) -Message 'Path does not exist'))
            continue
        }
        
        $items = @(Get-ChildItem -LiteralPath $path -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer })
        $size = Measure-UscObjectSum -InputObject $items -Property Length
        $failed = 0
        foreach ($item in $items) {
            try {
                if (-not $WhatIfOnly -and $PSCmdlet.ShouldProcess($item.FullName, 'Remove GPU cache file')) {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                }
            }
            catch {
                $failed++
                Write-UscLog -Level Debug -Message "Could not remove GPU cache file $($item.FullName)"
            }
        }

        # Remove empty subfolders
        if (-not $WhatIfOnly) {
            $subfolders = Get-ChildItem -LiteralPath $path -Directory -Force -Recurse -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending
            foreach ($dir in $subfolders) {
                try {
                    $contents = @(Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue)
                    if ($contents.Count -eq 0) {
                        Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
                    }
                }
                catch {}
            }
        }

        $results.Add((New-UscOperationResult -Name 'GPU Shader Cache' -Category Clean -Status $(if ($failed) { 'PartiallySucceeded' } else { 'Succeeded' }) -BytesFreed $size -Paths @($path) -Message "$($items.Count) candidate files, $failed skipped"))
    }
    return @($results)
}

Export-ModuleMember -Function Invoke-UscGpuCacheCleanup

