Set-StrictMode -Version Latest

function Invoke-UscParallel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$InputObject,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [int]$ThrottleLimit = [Environment]::ProcessorCount,
        [hashtable]$ArgumentList = @{}
    )

    if ($InputObject.Count -eq 0) { return @() }

    $pool = $null
    $jobs = [System.Collections.Generic.List[object]]::new()

    try {
        # Enable thread-safe session state sharing
        $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        
        # We want to allow the runspaces to use environment variables and default hosts
        $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $ThrottleLimit), $sessionState, $Host)
        $pool.ApartmentState = 'MTA'
        $pool.Open()

        foreach ($item in $InputObject) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($ScriptBlock)
            [void]$ps.AddArgument($item)
            [void]$ps.AddArgument($ArgumentList)
            
            $jobs.Add([pscustomobject]@{
                PowerShell = $ps
                Handle     = $ps.BeginInvoke()
                Item       = $item
                Disposed   = $false
            })
        }

        $results = [System.Collections.Generic.List[object]]::new()
        foreach ($job in $jobs) {
            try {
                $output = $job.PowerShell.EndInvoke($job.Handle)
                
                # Harvest child-runspace streams
                if ($job.PowerShell.HadErrors) {
                    $errors = $job.PowerShell.Streams.Error | ForEach-Object { if ($null -ne $_.Exception) { $_.Exception.Message } else { $_.ToString() } }
                    Write-UscLog -Level Warning -Message "Non-terminating errors occurred in parallel runspace job for item '$($job.Item)'" -Data @{ Errors = $errors }
                }
                
                # Forward warning and verbose messages from runspace if they exist
                foreach ($warning in $job.PowerShell.Streams.Warning) {
                    Write-UscLog -Level Warning -Message "Runspace warning for '$($job.Item)': $($warning.Message)"
                }
                foreach ($verbose in $job.PowerShell.Streams.Verbose) {
                    Write-UscLog -Level Debug -Message "Runspace verbose for '$($job.Item)': $($verbose.Message)"
                }
                
                foreach ($result in $output) { 
                    $results.Add($result) 
                }
            }
            catch {
                Write-UscLog -Level Critical -Message "Runspace execution crashed for item '$($job.Item)'" -Exception $_.Exception
                # Create a failed operation result object as a fallback
                $results.Add((New-UscOperationResult -Name "Parallel Job: $($job.Item)" -Category Clean -Status Failed -Message $_.Exception.Message))
            }
            finally {
                $job.PowerShell.Dispose()
                $job.Disposed = $true
            }
        }
        return @($results)
    }
    finally {
        if ($null -ne $jobs) {
            foreach ($job in $jobs) {
                if ($null -ne $job.PowerShell -and -not $job.Disposed) {
                    try { $job.PowerShell.Dispose() } catch {}
                }
            }
        }
        if ($null -ne $pool) {
            try { $pool.Close() } catch {}
            try { $pool.Dispose() } catch {}
        }
    }
}

Export-ModuleMember -Function Invoke-UscParallel

