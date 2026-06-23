Set-StrictMode -Version Latest

function New-UscJsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Run,
        [Parameter(Mandatory)][string]$OutputDirectory
    )

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $path = Join-Path $OutputDirectory "UltimateSystemCleaner-$($Run.RunId).json"
    $Run | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function New-UscCsvReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Results,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [Parameter(Mandatory)][string]$RunId
    )

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $path = Join-Path $OutputDirectory "UltimateSystemCleaner-$RunId.csv"
    $Results | Select-Object Name, Category, Status, BytesBefore, BytesAfter, BytesFreed, Message, Timestamp |
        Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
    return $path
}

Export-ModuleMember -Function New-UscJsonReport, New-UscCsvReport
