# Script to create a development certificate for HTTPS in CI/CD environments
Write-Host "Setting up development certificate for HTTPS..." -ForegroundColor Cyan

try {
    # Remove any existing localhost certificates to avoid conflicts
    Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=localhost" } | Remove-Item -Force -ErrorAction SilentlyContinue

    # Create a self-signed certificate using PowerShell (no interactive prompts)
    Write-Host "Creating self-signed certificate for localhost..."
    $cert = New-SelfSignedCertificate `
        -DnsName "localhost" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable `
        -KeySpec Signature `
        -KeyLength 2048 `
        -KeyAlgorithm RSA `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears(1)

    Write-Host "Certificate created successfully with thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
    Write-Host "Certificate is stored in: Cert:\CurrentUser\My\$($cert.Thumbprint)" -ForegroundColor Green

    # Try to import to Root store (this may fail in CI/CD without admin rights)
    try {
        Write-Host "Attempting to add certificate to trusted root store..."
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
        $store.Open("ReadWrite")
        $store.Add($cert)
        $store.Close()
        Write-Host "Certificate added to trusted root store successfully" -ForegroundColor Green
    } catch {
        Write-Host "Could not add to Root store (this is OK): $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "The application will use SkipCertificateCheck instead" -ForegroundColor Yellow
    }

    # Set environment variable for .NET to use this certificate
    $env:ASPNETCORE_Kestrel__Certificates__Default__Path = ""
    $env:ASPNETCORE_Kestrel__Certificates__Default__KeyPath = ""

    Write-Host "Development certificate setup complete" -ForegroundColor Green

} catch {
    Write-Host "Error setting up development certificate: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    Write-Host "Continuing anyway - the application will skip certificate validation" -ForegroundColor Yellow
}
