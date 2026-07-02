Import-Module "$PSScriptRoot\SystemCleaner\Core\Config.psm1" -Force
$c = Get-UscDefaultConfig
Write-Host "Safe keys: $($c.Safe.PSObject.Properties.Name -join ', ')"
Write-Host "Aggressive keys: $($c.Aggressive.PSObject.Properties.Name -join ', ')"
Write-Host "Nuclear keys: $($c.Nuclear.PSObject.Properties.Name -join ', ')"
