# Ultimate System Cleaner

A modular PowerShell cleanup project with Safe, Aggressive, and Nuclear modes, audit logging, dry-run defaults, reports, Storage Sense integration, component store analysis, scheduled task support, and conservative gating for destructive actions.

## Quick start

Run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\UltimateSystemCleaner.ps1 -Analyze
.\UltimateSystemCleaner.ps1 -Safe -GenerateReport
.\UltimateSystemCleaner.ps1 -Aggressive -WhatIfOnly
```

The default configuration sets `DryRunDefault` to `true`, so cleanup operations are simulated unless you disable that setting or explicitly adjust the config.

## Nuclear mode

Nuclear mode does not delete recovery options by default. To enable dangerous actions you must:

1. Change the matching setting under `Config\settings.json`.
2. Run `.\UltimateSystemCleaner.ps1 -Nuclear -ConfirmNuclear`.

Actions such as `DISM /ResetBase`, deleting shadow copies, and removing restore points can permanently reduce rollback options.

## Reports

Runs generate JSON, CSV, and HTML reports in the configured `ReportDirectory`, defaulting to:

```text
%ProgramData%\UltimateSystemCleaner\Reports
```

Logs are JSON-lines audit records in:

```text
%ProgramData%\UltimateSystemCleaner\Logs
```

## Scheduled task

Install or remove a weekly Safe-mode task:

```powershell
.\UltimateSystemCleaner.ps1 -InstallScheduledTask
.\UltimateSystemCleaner.ps1 -RemoveScheduledTask
```

## Digital signature

This project is signature-ready but not signed. Sign the launcher and modules with your own code-signing certificate:

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
Get-ChildItem . -Include *.ps1,*.psm1 -Recurse | Set-AuthenticodeSignature -Certificate $cert
```
