Set-StrictMode -Version Latest

function Get-UscComponentStoreAnalysis {
    [CmdletBinding()]
    param()

    # Ensure admin rights since DISM /AnalyzeComponentStore requires elevation
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $result = [ordered]@{
        Supported = $isAdmin
        RecommendedCleanup = $false
        ResetBaseRecommended = $false
        RawOutput = @()
        Parsed = @{}
        Timestamp = Get-Date
    }

    if (-not $isAdmin) {
        $result.RawOutput = @('Administrator rights are required to analyze the component store.')
        return [pscustomobject]$result
    }

    try {
        Write-UscLog -Level Information -Message 'Running DISM Component Store Analysis (this may take a few minutes)...'
        $output = & dism.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "DISM component store analysis failed (Exit Code: $LASTEXITCODE). Output: $($output -join ' ')"
        }
        $result.RawOutput = @($output)
        
        foreach ($line in $output) {
            if ($line -match '^\s*([^:]+)\s*:\s*(.+)$') {
                $key = ($matches[1] -replace '\s+', ' ').Trim()
                $value = $matches[2].Trim()
                $result.Parsed[$key] = $value
                
                if ($key -like '*Component Store Cleanup Recommended*' -and $value -match 'Yes') {
                    $result.RecommendedCleanup = $true
                }
                if ($key -like '*ResetBase Recommended*' -and $value -match 'Yes') {
                    $result.ResetBaseRecommended = $true
                }
                if ($key -like '*Number of Reclaimable Packages*' -and ($value -as [int]) -gt 0) {
                    $result.RecommendedCleanup = $true
                }
            }
        }
        Write-UscLog -Level Information -Message 'DISM Component Store Analysis completed successfully' -Data @{ Recommended = $result.RecommendedCleanup }
    }
    catch {
        $result.Supported = $false
        $result.RawOutput = @($_.Exception.Message)
        Write-UscLog -Level Warning -Message 'Component store analysis failed' -Exception $_.Exception
    }

    return [pscustomobject]$result
}

function Invoke-UscComponentStoreCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$ResetBase
    )

    $arguments = '/Online','/Cleanup-Image','/StartComponentCleanup'
    if ($ResetBase) { $arguments += '/ResetBase' }

    if ($ResetBase) {
        Write-UscLog -Level Warning -Message 'DISM ResetBase permanently removes ability to uninstall existing component updates'
    }

    try {
        if ($PSCmdlet.ShouldProcess('Windows Component Store', "DISM $($arguments -join ' ')")) {
            Write-UscLog -Level Information -Message "Starting DISM component store cleanup: $($arguments -join ' ')"
            $output = & dism.exe @arguments 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "DISM component store cleanup failed (Exit Code: $LASTEXITCODE). Output: $($output -join ' ')"
            }
            Write-UscLog -Level Information -Message 'DISM component store cleanup finished'
            return New-UscOperationResult -Name 'Component Store Cleanup' -Category Clean -Status Succeeded -Message ($output -join [Environment]::NewLine)
        }
    }
    catch {
        Write-UscLog -Level Error -Message 'Component store cleanup failed' -Exception $_.Exception
        return New-UscOperationResult -Name 'Component Store Cleanup' -Category Clean -Status Failed -Message $_.Exception.Message
    }
}

Export-ModuleMember -Function Get-UscComponentStoreAnalysis, Invoke-UscComponentStoreCleanup

