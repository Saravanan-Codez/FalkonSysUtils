# Ultimate System Utility (UltimateSystemUtil)

A modular, production-grade PowerShell utility suite for Windows optimization, cleanup, and maintenance. 

## Structure
- [UltimateSystemUtil.ps1](file:///d:/Falkon_labs/UltimateSystemUtil/UltimateSystemUtil.ps1): The root entry orchestrator displaying the main multi-tool utility menu.
- [SystemCleaner/](file:///d:/Falkon_labs/UltimateSystemUtil/SystemCleaner/): The system cleanup utility with Safe, Aggressive, and Nuclear modes.
- *Upcoming Utilities*: Registry Optimizer, Network Optimizer, and telemetry managers will be placed in dedicated subdirectories.

---

## Quick Start

### Web Installer (Direct In-Memory Load)
Run the following in an elevated PowerShell session to download, extract, and start the interactive suite in one command:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
irm https://raw.githubusercontent.com/Saravanan-Codez/UltimateSystemUtil/main/UltimateSystemUtil.ps1 | iex
```

### Local CLI Execution
Clone or extract the ZIP locally and invoke the root orchestrator:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
# Launch interactive TUI suite
.\UltimateSystemUtil.ps1

# Direct CLI pass-through to System Cleaner
.\UltimateSystemUtil.ps1 -Analyze
.\UltimateSystemUtil.ps1 -Safe -GenerateReport
.\UltimateSystemUtil.ps1 -Aggressive -WhatIfOnly
```

---

## Ultimate System Cleaner Features

The default configuration sets `DryRunDefault` to `true`, meaning cleanup operations are safely simulated unless disabled in configurations or explicitly run.

### Nuclear Mode Safeguards
Nuclear mode deletes volume shadow copies, removes restore points, and runs `DISM /ResetBase`. Because these operations permanently remove rollback paths, they are dual-gated:
1. Change `"ConfirmNuclearActions"` to `true` in `SystemCleaner/Config/settings.json`.
2. Launch the execution with `-Nuclear -ConfirmNuclear` switches or confirm the prompt interactively.

### Reports & Logs
- **HTML/JSON/CSV Reports**: Written to `%ProgramData%\UltimateSystemCleaner\Reports`
- **JSON-Lines Audit Logs**: Written to `%ProgramData%\UltimateSystemCleaner\Logs`

### Scheduled Task Manager
Install or remove a weekly automated task running the Safe cleanup utility:
```powershell
.\UltimateSystemUtil.ps1 -InstallScheduledTask
.\UltimateSystemUtil.ps1 -RemoveScheduledTask
```

### Digital Signatures & Audit
The utility contains local code-signing modules. You can generate a self-signed certificate and sign all module files directly through the **Local Code-Signing Utilities** menu option (Option `8`) in the System Cleaner TUI interface.
