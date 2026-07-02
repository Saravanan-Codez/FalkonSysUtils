# Falkon System Utilities (FalkonSysUtils)

A modular, production-grade PowerShell utility suite for Windows optimization, cleanup, and maintenance.

## Structure
- [FalkonSysUtils.ps1](file:///d:/Falkon_labs/UltimateSystemUtil/FalkonSysUtils.ps1): The root entry orchestrator displaying the main multi-tool utility menu.
- [SystemCleaner/](file:///d:/Falkon_labs/UltimateSystemUtil/SystemCleaner/): The system cleanup utility with Safe, Aggressive, and Nuclear modes.
- *Upcoming Utilities*: Registry Optimizer, Network Optimizer, and telemetry managers will be placed in dedicated subdirectories.

---

## Quick Start

### Web Installer (Direct In-Memory Load)
Run the following in an elevated PowerShell session to download, extract, and start the interactive suite in one command:
```powershell
irm https://raw.githubusercontent.com/Saravanan-Codez/FalkonSysUtils/main/FalkonSysUtils.ps1 | iex
```

### Local CLI Execution
Clone or extract the ZIP locally and invoke the root orchestrator:
```powershell
# Launch interactive TUI suite
.\FalkonSysUtils.ps1

# Direct CLI pass-through to System Cleaner
.\FalkonSysUtils.ps1 -Analyze
.\FalkonSysUtils.ps1 -Safe -GenerateReport
.\FalkonSysUtils.ps1 -Aggressive -WhatIfOnly
```

---

## Falkon System Cleaner Features

The default configuration sets `DryRunDefault` to `true`, meaning cleanup operations are safely simulated unless disabled in configurations or explicitly run.

### Nuclear Mode Safeguards
Nuclear mode deletes volume shadow copies, removes restore points, and runs `DISM /ResetBase`. Because these operations permanently remove rollback paths, they are dual-gated:
1. Change `"ConfirmNuclearActions"` to `true` in `SystemCleaner/Config/settings.json`.
2. Launch the execution with `-Nuclear -ConfirmNuclear` switches or confirm the prompt interactively.

### Reports & Logs
- **HTML/JSON/CSV Reports**: Written to `%ProgramData%\UltimateSystemCleaner\Reports`
- **JSON-Lines Audit Logs**: Written to `%ProgramData%\UltimateSystemCleaner\Logs`
