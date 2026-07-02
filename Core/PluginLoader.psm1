function Get-FalkonPlugins {
    $pluginDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Plugins"
    if (-not (Test-Path $pluginDir)) { return @() }
    
    $plugins = Get-ChildItem -Path $pluginDir -Filter "*.ps1" -ErrorAction SilentlyContinue
    $pluginList = @()
    
    foreach ($file in $plugins) {
        $content = Get-Content -Path $file.FullName -TotalCount 20 -ErrorAction SilentlyContinue
        $name = $file.BaseName
        $description = "Custom User Plugin"
        
        foreach ($line in $content) {
            if ($line -match '^#\s*PluginName:\s*(.*)$') {
                $name = $Matches[1].Trim()
            }
            if ($line -match '^#\s*Description:\s*(.*)$') {
                $description = $Matches[1].Trim()
            }
        }
        
        $pluginList += [PSCustomObject]@{
            Path        = $file.FullName
            Name        = $name
            Description = $description
        }
    }
    return $pluginList
}

function Invoke-FalkonPlugin {
    param(
        [PSCustomObject]$Plugin
    )
    if (-not (Test-Path $Plugin.Path)) {
        Write-Host "[-] Plugin file not found: $($Plugin.Path)" -ForegroundColor Red
        return
    }
    
    Write-Host "[*] Launching community plugin: $($Plugin.Name)..." -ForegroundColor Yellow
    try {
        & $Plugin.Path
        Write-Host "[+] Plugin executed successfully." -ForegroundColor Green
    } catch {
        Write-Host "[-] Plugin execution failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Export-ModuleMember -Function Get-FalkonPlugins, Invoke-FalkonPlugin
