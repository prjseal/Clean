# How to Run a Local HTTPS Site Inside a GitHub Action Without the Dev Certificate Trust Issue

## The Problem

I recently needed to run an Umbraco CMS site locally within a GitHub Actions workflow. The workflow needed to:

1. Start the Umbraco site with HTTPS on `https://localhost:44340`
2. Make API calls to the Umbraco Management API

Sounds straightforward, right? Well, it turned out to be a painful journey through the depths of Windows certificate management, PowerShell scripting, and GitHub Actions limitations.

The core issue: **ASP.NET Core development sites use self-signed HTTPS certificates, and Windows won't trust them without user interaction - something you can't get in a CI/CD environment.**

## Attempt 1: Programmatic Certificate Trust in the Workflow

My first approach seemed logical: just add a step to the GitHub Actions workflow to create and trust the development certificate programmatically.

```yaml
- name: Create and trust dev certificate
  run: |
    dotnet dev-certs https --clean
    dotnet dev-certs https --export-path $env:TEMP\dev-cert.pfx --password "password123"
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import("$env:TEMP\dev-cert.pfx", "password123", "MachineKeySet")
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
```

**Result:** The workflow hung indefinitely. The certificate import to the Root store was waiting for some kind of confirmation that would never come in an automated environment.

**Learning:** Even "programmatic" certificate operations can have hidden interactive requirements on Windows.

## Attempt 2: Native PowerShell Certificate Creation

I thought the `dotnet dev-certs` command might be the culprit, so I switched to PowerShell's native `New-SelfSignedCertificate` cmdlet:

```powershell
$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "ASP.NET Core HTTPS development certificate"
$certPath = "C:\temp\dev-cert.pfx"
$password = ConvertTo-SecureString -String "password123" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $password
Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root -Password $password
```

**Result:** Same issue. The import to the Root store hung for 3+ minutes before timing out.

**Learning:** The problem wasn't the tool; it was Windows requiring administrator consent to modify the trusted root certificate store.

## Attempt 3: Skip the Root Store

Maybe I didn't need the certificate in the Root store at all? I tried removing that step and just keeping it in the LocalMachine\My store, then configuring Kestrel to accept self-signed certificates:

```powershell
$env:ASPNETCORE_Kestrel__Certificates__Default__AllowInvalid = "true"
Start-Process -FilePath "dotnet" -ArgumentList "run --project Clean.Blog.csproj"
```

**Result:** The site started fine, but when my PowerShell script tried to make HTTPS calls to the Management API, they failed with certificate validation errors.

**Learning:** The server accepting its own certificate is different from the client (PowerShell) trusting the server's certificate.

## Attempt 4: The Simple `dotnet dev-certs https --trust`

After finding a blog post about SSL certificates in .NET GitHub workflows, I tried the simplest approach:

```yaml
- name: Install SSL Certificates
  run: |
    dotnet dev-certs https --trust
```

**Result:** The workflow hung again. This time at the `--trust` step, which launches a modal dialog asking "Do you want to install this certificate?" - a dialog that can't be clicked in a headless GitHub Actions runner.

**Learning:** The `--trust` flag requires interactive user consent on Windows. It works great for local development, but it's a non-starter for CI/CD.

## The Breakthrough: Skip Certificate Validation for Localhost

After all these attempts at making Windows trust the certificate, I aksed my friends if they had ever done anything like this. 
My friend and former colleague [Matt Hart](https://mattou07.net/) gave me some pointers and shared a GitHub action with me that was doing something along the lines of what I needed.
After reading that I realised : **Why try to trust the certificate at all?**

The site and the PowerShell script making API calls are both running on the same machine in a controlled build environment. There's no security risk in bypassing certificate validation for these specific localhost HTTPS calls.

Here's the final solution:

### 1. Remove the Certificate Trust Step

No more trying to install or trust certificates in the workflow. Just let ASP.NET Core create its default development certificate:

```yaml
- name: Setup .NET 10
  uses: actions/setup-dotnet@v4
  with:
    dotnet-version: '10.0.x'

# That's it - no certificate trust step needed!
```

### 2. Configure PowerShell to Skip Certificate Validation

At the top of the PowerShell script, add code to bypass SSL validation for both Windows PowerShell 5.x and PowerShell Core 6+:

```powershell
# Skip SSL certificate validation for localhost calls (needed for CI/CD with self-signed certs)
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell Core 6+ approach
    Write-Verbose "Configuring certificate validation bypass for PowerShell Core"
} else {
    # Windows PowerShell 5.x approach
    Write-Verbose "Configuring certificate validation bypass for Windows PowerShell"
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint svcPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}
```

### 3. Update HTTP Calls to Use Certificate Bypass

For PowerShell Core, add the `-SkipCertificateCheck` parameter to all HTTPS calls:

```powershell
# Health check
$webRequestParams = @{
    Uri = "https://localhost:44340/umbraco"
    UseBasicParsing = $true
    ErrorAction = "Stop"
}
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $webRequestParams['SkipCertificateCheck'] = $true
}
$response = Invoke-WebRequest @webRequestParams

# API calls
$tokenParams = @{
    Method = "Post"
    Uri = $tokenUrl
    Body = $tokenBody
    Headers = $tokenHeaders
    ErrorAction = "Stop"
}
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $tokenParams['SkipCertificateCheck'] = $true
}
$response = Invoke-RestMethod @tokenParams
```

**Result:** Success! The site starts with its self-signed HTTPS certificate, and the PowerShell script can make API calls without certificate validation errors.

## Bonus Issue: Wrong OAuth Credentials

After solving the certificate issue, I encountered one more problem:

```
The authentication demand was rejected because the client application
was not found: 'umbraco-back-office-test'.
```

My PowerShell script was using test OAuth credentials that didn't exist. I needed to check my `appsettings.Development.json` to find the actual credentials:

```json
{
  "uSync": {
    "Command": {
      "AddIfMissing": true,
      "ClientId": "umbraco-back-office-clean-api-user",
      "Secret": "c9DK0CxvRWklbjR"
    }
  }
}
```

After updating the script with the correct credentials, everything worked perfectly.

## Key Takeaways

1. **Don't fight the system** - Instead of trying to make Windows trust a certificate non-interactively (which is intentionally difficult for security reasons), bypass the validation in a controlled way.

2. **Different approaches for different PowerShell versions** - Windows PowerShell 5.x uses `ServicePointManager`, while PowerShell Core 6+ has the `-SkipCertificateCheck` parameter built into web cmdlets.

3. **Security context matters** - Skipping certificate validation is safe when:
   - Both client and server are on the same machine
   - You control both the client and server
   - You're in a temporary build environment
   - You're only calling localhost

## Final Workflow

Here's what the final GitHub Actions workflow looks like:

```yaml
name: PR - Build NuGet Packages

on:
  pull_request:
    branches:
      - main

jobs:
  build-packages:
    runs-on: windows-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup .NET 10
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'

      - name: Run CreateNuGetPackages script
        shell: pwsh
        run: |
          ./CreateNuGetPackages.ps1 -Version "1.0.0.${{ github.run_number }}"

      - name: Upload NuGet packages as artifacts
        uses: actions/upload-artifact@v4
        with:
          name: nuget-packages
          path: .artifacts/nuget/*.nupkg
```

Clean, simple, and it works. No certificate gymnastics required.

## Conclusion

Sometimes the best solution isn't fighting to make something work the "right" way, but finding an alternative approach that achieves the same goal more simply. In this case, bypassing certificate validation for controlled localhost calls was far easier than trying to programmatically trust certificates on Windows.

If you're facing a similar issue with HTTPS development certificates in GitHub Actions or other CI/CD environments, I hope this saves you the days I spent figuring it out.

---

**Related Resources:**
- [PowerShell Invoke-WebRequest documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest)
- [ASP.NET Core HTTPS development certificates](https://docs.microsoft.com/en-us/aspnet/core/security/enforcing-ssl#trust-the-aspnet-core-https-development-certificate-on-windows-and-macos)
- [ServicePointManager.CertificatePolicy](https://docs.microsoft.com/en-us/dotnet/api/system.net.servicepointmanager.certificatepolicy)
