# Security Policy

## Supported Versions

Only the latest release on the `main` branch of FalkonSysUtils is actively supported with security patches and bug fixes.

## Integrity & Signature Auditing
FalkonSysUtils integrates modular code signing audits to prevent execution of tampered modules:
1. All core modules are checked for valid Authenticode signatures via `Get-AuthenticodeSignature` before loading.
2. If unsigned or modified modules are detected, interactive sessions will block execution and require explicit user trust.
3. Automated or scheduled passes will log signature verification details directly to the audit database.

## Safe Plugin Guidelines
Dynamic community plugins loaded via the `Plugins/` folder must be audited before execution:
1. **Source Verifiability**: Never load or unblock scripts obtained from untrusted third parties.
2. **Explicit Consent**: The TUI forces an interactive consent prompt detailing the selected plugin path and description before running.
3. **No Automatic Unblocking**: Unlike core modules, files placed inside the `Plugins/` folder are excluded from global script unblocking rules, requiring administrators to consciously unblock or sign them.

## Reporting a Vulnerability

If you discover a security vulnerability in this utility, please do not disclose it publicly. Email the details to falkon-labs-security@falkon.com (simulated) or open a draft security advisory on GitHub. We aim to respond and provide patches within 48 hours.
