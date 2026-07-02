# Falkon System Utilities (FalkonSysUtils) - The Holy Grail Update

A profound, production-grade PowerShell utility suite for extreme Windows optimization, debloat, and maintenance. Tailored for both high-performance gaming and stable enterprise environments.

## Feature Modules

- **Falkon System Cleaner**: Advanced disk space recovery featuring Safe, Aggressive, and Nuclear modes (with Windows Update cache and Component Store resetbase capabilities).
- **Falkon System Optimizer (Tweaker)**: Unlocks the hidden "Ultimate Performance" power plan, blocks forced OEM driver updates, debloats the Taskbar (Copilot/Widgets), and nukes telemetry.
- **Falkon Network Optimizer**: Modifies the TCP/IP stack to lower network latency (disables Nagle's Algorithm via TCPNoDelay), resets Winsock, and halts bandwidth-hogging Delivery Optimization (P2P Windows Updates).
- **Falkon Registry Optimizer**: Restores the classic Windows 10 context menu (bypassing the slow 'Show more options' delay) and injects `Win32PrioritySeparation` tweaks to prioritize foreground task processing.
- **Falkon Package Store**: A silent, 1-click Winget batch installer for setting up fresh machines with Essential, Creator/Dev, or Gaming software packs in seconds.
- **The Safety Net**: Fully automated Windows System Restore point generation. The tool forces a "Pre-Optimization Snapshot" before executing any major system modifications to guarantee absolute safety.

---

## Quick Start

### Web Installer (Direct In-Memory Load)
Run the following in an elevated PowerShell session to download, extract, and start the dynamic interactive dashboard:
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
```

---

## Dynamic Dashboard
The main orchestrator (`FalkonSysUtils.ps1`) automatically queries WMI/CIM objects on boot to display your current OS System, Processor model, and installed RAM capacity in real-time above the module selection menu.
