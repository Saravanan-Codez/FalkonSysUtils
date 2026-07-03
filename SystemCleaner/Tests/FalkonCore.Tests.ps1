$coreModulePath = Join-Path $PSScriptRoot "..\..\Core\FalkonCore.psm1"

Describe "FalkonCore Module" {
    BeforeAll {
        Import-Module $coreModulePath -Force
    }

    Context "Registry Path Normalization & Export Check" {
        It "FalkonCore module exports required functions" {
            Get-Command Show-FalkonLogo -ErrorAction Stop | Out-Null
            Get-Command Invoke-FalkonPause -ErrorAction Stop | Out-Null
            Get-Command Initialize-FalkonLogger -ErrorAction Stop | Out-Null
            Get-Command Write-FalkonLog -ErrorAction Stop | Out-Null
            Get-Command Backup-FalkonRegistryKey -ErrorAction Stop | Out-Null
        }

        It "Gracefully handles nonexistent registry paths in Backup-FalkonRegistryKey" {
            # Non-existent path should not throw a terminating error
            { Backup-FalkonRegistryKey -Path "HKLM:\Software\NonexistentPathForTestingAntigravity" } | Should Not Throw
        }
    }

    Context "Logging Framework" {
        It "Initializes logger and writes entries to file" {
            Initialize-FalkonLogger
            $logPath = Join-Path $env:ProgramData "FalkonSysUtils\Logs\FalkonSysUtils.log"
            
            # Write to log so the file is created on disk
            Write-FalkonLog -Level Success -Message "Pester testing logging framework"
            
            (Test-Path $logPath) | Should Be $true
            $content = Get-Content -Path $logPath -Raw
            $content | Should Match "Pester testing logging framework"
        }
    }
}
