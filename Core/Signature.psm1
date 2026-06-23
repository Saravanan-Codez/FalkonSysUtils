Set-StrictMode -Version Latest

function Test-UscFileSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    try {
        $sig = Get-AuthenticodeSignature -FilePath $Path -ErrorAction SilentlyContinue
        return ($sig.Status -eq 'Valid')
    }
    catch {
        return $false
    }
}

function New-UscSelfSignedCert {
    [CmdletBinding()]
    param(
        [string]$Subject = 'CN=UltimateSystemCleaner-SelfSigned',
        [switch]$ImportToRoot
    )

    try {
        $params = @{
            Subject = $Subject
            Type = 'CodeSigningCert'
            CertStoreLocation = 'Cert:\CurrentUser\My'
            FriendlyName = 'Ultimate System Cleaner Code Signing'
        }
        $cert = New-SelfSignedCertificate @params

        if ($ImportToRoot) {
            # Copy to Root (Trusted Root Certification Authorities) if run as administrator
            $rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new('Root', 'CurrentUser')
            $rootStore.Open('ReadWrite')
            $rootStore.Add($cert)
            $rootStore.Close()
        }

        # Also copy to TrustedPublisher (CurrentUser)
        $pubStore = [System.Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher', 'CurrentUser')
        $pubStore.Open('ReadWrite')
        $pubStore.Add($cert)
        $pubStore.Close()

        return $cert
    }
    catch {
        Write-Error "Failed to generate self-signed code signing certificate: $($_.Exception.Message)"
        throw
    }
}

function Set-UscFileSignature {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        $Certificate
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path '$Path' does not exist"
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Apply digital signature')) {
        $sig = Set-AuthenticodeSignature -FilePath $Path -Certificate $Certificate -ErrorAction Stop
        if ($sig.Status -ne 'Valid') {
            Write-Warning "Signature applied to '$Path' status: $($sig.Status)"
        }
        return $sig
    }
}

Export-ModuleMember -Function Test-UscFileSignature, New-UscSelfSignedCert, Set-UscFileSignature
