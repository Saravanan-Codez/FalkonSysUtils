function Show-FalkonLogo {
    param(
        [string]$SubTitle = ""
    )
    Clear-Host
    Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '  ║                   FALKON SYSTEM UTILS                    ║' -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    
    if (-not [string]::IsNullOrWhiteSpace($SubTitle)) {
        $paddedLength = [math]::Max(0, [math]::Floor((58 - $SubTitle.Length) / 2))
        $leftPad = $SubTitle.PadLeft($paddedLength + $SubTitle.Length)
        $fullTitle = $leftPad.PadRight(58)
        Write-Host "  ╟──────────────────────────────────────────────────────────╢" -ForegroundColor Cyan
        Write-Host "  ║$fullTitle║" -ForegroundColor Magenta -BackgroundColor Black
        Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    }
}

function Show-FalkonBox {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Lines,
        [string]$Color = 'Cyan'
    )
    # Find max line length, cap at 58
    $maxLength = $Title.Length
    foreach ($line in $Lines) {
        if ($line.Length -gt $maxLength) { $maxLength = $line.Length }
    }
    $maxLength = [math]::Min(58, [math]::Max($maxLength, 20))
    
    $top = '╔' + ('═' * ($maxLength + 2)) + '╗'
    $bottom = '╚' + ('═' * ($maxLength + 2)) + '╝'
    
    Write-Host "  $top" -ForegroundColor $Color
    
    # Title centered
    $tPad = [math]::Max(0, [math]::Floor(($maxLength - $Title.Length) / 2))
    $tLine = $Title.PadLeft($tPad + $Title.Length).PadRight($maxLength)
    Write-Host "  ║ $tLine ║" -ForegroundColor White -BackgroundColor DarkBlue
    
    Write-Host ("  ╟" + ('─' * ($maxLength + 2)) + "╢") -ForegroundColor $Color
    
    foreach ($line in $Lines) {
        $lText = $line
        if ($lText.Length -gt $maxLength) {
            $lText = $lText.Substring(0, $maxLength - 3) + '...'
        }
        $lText = $lText.PadRight($maxLength)
        Write-Host "  ║ $lText ║" -ForegroundColor Gray
    }
    Write-Host "  $bottom" -ForegroundColor $Color
}

function Show-FalkonConfirm {
    param(
        [Parameter(Mandatory)][string]$PromptMessage
    )
    if ($global:UscNonInteractive) { return $true }
    
    # Draw confirmation box
    Show-FalkonBox -Title "CONFIRMATION REQUIRED" -Lines @($PromptMessage, "", "  [Y] Yes  /  [N] No") -Color "Yellow"
    Write-Host ""
    
    $resp = Read-Host "  Your choice"
    return ($resp -match '^[yY]')
}

function Show-FalkonMenu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$SubTitle,
        [Parameter(Mandatory)][object[]]$Options
    )
    
    Show-FalkonLogo -SubTitle $SubTitle
    
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($opt in $Options) {
        $lines.Add(" [$($opt.Key)] $($opt.Label)")
    }
    
    Show-FalkonBox -Title $Title -Lines $lines.ToArray() -Color 'Cyan'
    Write-Host ""
}

function Invoke-FalkonPause {
    Write-Host ""
    Show-FalkonBox -Title "OPERATION COMPLETE" -Lines @("The operation has finished running.", "Press any key to return to the menu...") -Color "Green"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

$script:FalkonLogFile = $null

function Initialize-FalkonLogger {
    $logDir = Join-Path $env:ProgramData "FalkonSysUtils\Logs"
    try {
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $script:FalkonLogFile = Join-Path $logDir "FalkonSysUtils.log"
    } catch {
        # Fallback to console only if directory creation fails
    }
}

function Write-FalkonLog {
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success')][string]$Level = 'Info',
        [string]$Message,
        [System.Exception]$Exception
    )
    
    if ($null -eq $script:FalkonLogFile) {
        Initialize-FalkonLogger
    }
    
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $errText = if ($Exception) { " | Error: $($Exception.Message)" } else { "" }
    $logLine = "[$timestamp] [$Level] $Message$errText"
    
    if ($script:FalkonLogFile) {
        try {
            Add-Content -LiteralPath $script:FalkonLogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {}
    }
    
    # Render colors for user-facing TUI output
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        default   { 'Gray' }
    }
    
    $prefix = switch ($Level) {
        'Success' { '[+]' }
        'Warning' { '[!]' }
        'Error'   { '[-]' }
        default   { '[*]' }
    }
    
    Write-Host "  $prefix $Message" -ForegroundColor $color
    
    # Populate standard warning / verbose streams
    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Warning "[ERROR] $Message" }
        default   { Write-Verbose $Message }
    }
}

function Backup-FalkonRegistryKey {
    param(
        [string]$Path
    )
    $backupDir = Join-Path $env:ProgramData "FalkonSysUtils\Rollbacks"
    try {
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        
        # Strip registry provider prefix if present
        $cleanPath = $Path
        if ($cleanPath -match '::(.*)$') {
            $cleanPath = $Matches[1]
        }
        
        # Format PS path (e.g. HKCU:\...) to reg.exe path (e.g. HKCU\...)
        $regPath = $cleanPath
        $regPath = $regPath -replace '^HKEY_LOCAL_MACHINE\\?', 'HKLM\'
        $regPath = $regPath -replace '^HKEY_CURRENT_USER\\?', 'HKCU\'
        $regPath = $regPath -replace '^HKLM:\\?', 'HKLM\'
        $regPath = $regPath -replace '^HKCU:\\?', 'HKCU\'
        $regPath = $regPath -replace '^HKLM:\?', 'HKLM\'
        $regPath = $regPath -replace '^HKCU:\?', 'HKCU\'
        
        # Normalize slashes
        $regPath = $regPath -replace '/', '\'
        $regPath = $regPath -replace '\\+', '\'
        $regPath = $regPath.TrimEnd('\')
        
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $safeName = ($regPath -replace '[\\:*?"<>|]', '_')
        $backupFile = Join-Path $backupDir "RegBackup_${safeName}_${timestamp}.reg"
        
        if (Test-Path -LiteralPath $Path) {
            $output = & reg.exe export $regPath $backupFile /y 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-FalkonLog -Level Info -Message "Registry backup generated: $backupFile"
            } else {
                Write-FalkonLog -Level Warning -Message "Failed to export registry path ${regPath}: $($output -join ' ')"
            }
        }
    } catch {
        Write-FalkonLog -Level Warning -Message "Error during registry backup: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Show-FalkonLogo, Invoke-FalkonPause, Initialize-FalkonLogger, Write-FalkonLog, Backup-FalkonRegistryKey, Show-FalkonBox, Show-FalkonConfirm, Show-FalkonMenu
