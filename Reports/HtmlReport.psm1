Set-StrictMode -Version Latest

function ConvertTo-UscHtmlEncoded {
    param([AllowNull()][object]$Value)
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function New-UscHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Run,
        [Parameter(Mandatory)][string]$OutputDirectory
    )

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    # 1. Load HTML Template
    $templatePath = Join-Path $PSScriptRoot '..\Templates\report_template.html'
    if (-not (Test-Path -LiteralPath $templatePath)) {
        # Fallback if template is missing
        Write-Warning "Report template not found at $templatePath. Generating minimal report."
        return $null
    }
    
    $htmlContent = Get-Content -LiteralPath $templatePath -Raw -ErrorAction Stop

    # 2. Build Results Table Rows
    $rows = foreach ($result in $Run.Results) {
        $name = ConvertTo-UscHtmlEncoded -Value $result.Name
        $cat = ConvertTo-UscHtmlEncoded -Value $result.Category
        $status = ConvertTo-UscHtmlEncoded -Value $result.Status
        $freedBytes = Format-UscBytes -Bytes ([Int64]$result.BytesFreed)
        $msg = ConvertTo-UscHtmlEncoded -Value $result.Message
        "<tr><td><strong>$name</strong></td><td>$cat</td><td><span class='status-badge status-$status'>$status</span></td><td>$freedBytes</td><td>$msg</td></tr>"
    }
    $resultsTable = $rows -join [Environment]::NewLine
    # 3. Build Audit Logs Table Rows
    $auditRows = foreach ($log in $Run.Audit) {
        $timestamp = ConvertTo-UscHtmlEncoded -Value $log.Timestamp
        $level = ConvertTo-UscHtmlEncoded -Value $log.Level
        $msg = ConvertTo-UscHtmlEncoded -Value $log.Message
        $errHtml = ''
        if ($log.Error) {
            $errHtml = "<br><small style='color:red;'>$([System.Net.WebUtility]::HtmlEncode($log.Error))</small>"
        }
        "<tr><td style='white-space: nowrap;'>$timestamp</td><td><span class='status-badge status-$level'>$level</span></td><td>$msg $errHtml</td></tr>"
    }
    $auditTable = $auditRows -join [Environment]::NewLine

    # 4. Compile Category Statistics & Generate SVG Bar Chart
    $categories = [ordered]@{
        'Caches'          = 0L
        'Logs'            = 0L
        'Dumps'           = 0L
        'Updates & Temp'  = 0L
    }

    foreach ($res in $Run.Results) {
        $name = $res.Name
        $freed = [Int64]$res.BytesFreed
        if ($name -match '(?i)Cache|Browser|Font') {
            $categories['Caches'] += $freed
        }
        elseif ($name -match '(?i)Log|Error|WER') {
            $categories['Logs'] += $freed
        }
        elseif ($name -match '(?i)Dump|Crash') {
            $categories['Dumps'] += $freed
        }
        else {
            $categories['Updates & Temp'] += $freed
        }
    }

    # Generate SVGs
    $svg = ''
    $maxVal = 0L
    foreach ($val in $categories.Values) {
        if ($val -gt $maxVal) { $maxVal = $val }
    }

    if ($maxVal -eq 0L) {
        $svg = '<svg width="240" height="200" viewBox="0 0 240 200">
            <text x="120" y="100" fill="#9ca3af" text-anchor="middle" font-family="sans-serif" font-size="14">No space freed in this run</text>
        </svg>'
    }
    else {
        # Render a sleek vertical bar chart in SVG
        $barWidth = 30
        $gap = 20
        $chartHeight = 150
        $svgItems = [System.Collections.Generic.List[string]]::new()
        
        $i = 0
        foreach ($entry in $categories.GetEnumerator()) {
            $catName = $entry.Key
            $val = $entry.Value
            
            # Calculate height scaled to 120 max
            $scaledHeight = if ($maxVal -gt 0) { [Math]::Round(($val / $maxVal) * 110) } else { 0 }
            if ($scaledHeight -lt 5 -and $val -gt 0) { $scaledHeight = 5 } # minimum height for visibility
            
            $x = 15 + ($i * ($barWidth + $gap))
            $y = $chartHeight - $scaledHeight
            
            $formattedVal = Format-UscBytes -Bytes $val
            
            $svgItems.Add("
                <g>
                    <rect x='$x' y='$y' width='$barWidth' height='$scaledHeight' fill='#3b82f6' rx='4' opacity='0.85'></rect>
                    <text x='$($x + $barWidth/2)' y='$($y - 8)' fill='#f3f4f6' text-anchor='middle' font-size='10' font-weight='bold'>$formattedVal</text>
                    <text x='$($x + $barWidth/2)' y='170' fill='#9ca3af' text-anchor='middle' font-size='9'>$catName</text>
                </g>
            ")
            $i++
        }
        $svg = '<svg width="240" height="200" viewBox="0 0 240 200" style="background:transparent;">' + ($svgItems -join '') + '</svg>'
    }
    # 5. Build System Metadata List
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osName = 'Windows'
    if ($osInfo) { $osName = $osInfo.Caption }
    
    $adminText = 'No'
    if ($Run.IsAdministrator) { $adminText = 'Yes' }
    
    $specs = @(
        @{ Label = 'OS Version'; Value = $osName },
        @{ Label = 'Computer Name'; Value = $Run.ComputerName },
        @{ Label = 'User Context'; Value = $Run.UserName },
        @{ Label = 'Admin Rights'; Value = $adminText },
        @{ Label = 'PSScriptRoot'; Value = $PSScriptRoot }
    )

    $specRows = foreach ($spec in $specs) {
        '<li><strong>{0}</strong><span>{1}</span></li>' -f `
            (ConvertTo-UscHtmlEncoded $spec.Label),
            (ConvertTo-UscHtmlEncoded $spec.Value)
    }
    $systemSpecs = $specRows -join [Environment]::NewLine

    # 6. Apply replacement tokens
    $htmlContent = $htmlContent.Replace('{{RUN_ID}}', $Run.RunId)
    $htmlContent = $htmlContent.Replace('{{RUN_MODE}}', $Run.Mode)
    
    $dryRunText = 'DISABLED'
    if ($Run.WhatIfOnly) { $dryRunText = 'ENABLED' }

    $htmlContent = $htmlContent.Replace('{{DRY_RUN}}', $dryRunText)
    $htmlContent = $htmlContent.Replace('{{TOTAL_FREED}}', (Format-UscBytes -Bytes ([Int64]$Run.TotalBytesFreed)))
    $htmlContent = $htmlContent.Replace('{{TIME_STAMP}}', (Get-Date).ToString('u'))
    $htmlContent = $htmlContent.Replace('{{RESULTS_TABLE}}', $resultsTable)
    $htmlContent = $htmlContent.Replace('{{AUDIT_LOG_ROWS}}', $auditTable)
    $htmlContent = $htmlContent.Replace('{{CHART_SVG}}', $svg)
    $htmlContent = $htmlContent.Replace('{{SYSTEM_SPECS}}', $systemSpecs)

    $path = Join-Path $OutputDirectory "UltimateSystemCleaner-$($Run.RunId).html"
    $htmlContent | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

Export-ModuleMember -Function New-UscHtmlReport

