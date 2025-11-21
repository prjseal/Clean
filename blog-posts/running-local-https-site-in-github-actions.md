# How to Run a Local HTTPS Site Inside a GitHub Action Without the Dev Certificate Trust Issue

## The Problem

I recently had to run an Umbraco CMS site locally inside a GitHub Actions workflow. The workflow needed to:

1. Start the Umbraco site with HTTPS on `https://localhost:44340`
2. Make API calls to the Umbraco Management API

Sounds simple, right? Well, it turned into a bit of a nightmare involving Windows certificate management, PowerShell scripting, and GitHub Actions limitations.

The core issue: **ASP.NET Core development sites use self-signed HTTPS certificates, and Windows won’t trust them without user interaction — something you can’t do in a CI/CD environment.**

---

## Attempt 1: Programmatic Certificate Trust in the Workflow

My first thought was: “I’ll just add a step in the workflow to create and trust the dev certificate programmatically.” Here’s what I tried:

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

**Result:** The workflow hung indefinitely. The certificate import to the Root store was waiting for some kind of confirmation that never comes in an automated environment.

**Learning:** Even “programmatic” certificate operations can have hidden interactive requirements on Windows.

---

## Attempt 2: Native PowerShell Certificate Creation

I thought maybe `dotnet dev-certs` was the problem, so I switched to PowerShell’s `New-SelfSignedCertificate`:

```powershell
$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "ASP.NET Core HTTPS development certificate"
$certPath = "C:\temp\dev-cert.pfx"
$password = ConvertTo-SecureString -String "password123" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $password
Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root -Password $password
```

**Result:** Same issue. The import to the Root store hung for 3+ minutes before timing out.

**Learning:** The problem wasn’t the tool; it was Windows requiring admin consent to modify the trusted root store.

---

## Attempt 3: Skip the Root Store

Maybe I didn’t need the certificate in the Root store? I tried removing that step and just keeping it in `LocalMachine\My`, then configuring Kestrel to allow invalid certs:

```powershell
$env:ASPNETCORE_Kestrel__Certificates__Default__AllowInvalid = "true"
Start-Process -FilePath "dotnet" -ArgumentList "run --project Clean.Blog.csproj"
```

**Result:** The site started fine, but when my PowerShell script tried to make HTTPS calls to the Management API, they failed with certificate validation errors.

**Learning:** The server accepting its own certificate is different from the client (PowerShell) trusting it.

---

## Attempt 4: The Simple `dotnet dev-certs https --trust`

I found a blog post suggesting this:

```yaml
- name: Install SSL Certificates
  run: |

    dotnet dev-certs https --trust
```

**Result:** Hung again. The `--trust` flag launches a modal dialog asking “Do you want to install this certificate?” — which you can’t click in a headless runner.

**Learning:** The `--trust` flag requires interactive consent. Great for local dev, useless for CI/CD.

---

## The Breakthrough: Skip Certificate Validation for Localhost

After all these failed attempts, I asked around. My friend https://mattou07.net/ shared a GitHub Action that gave me an idea:

**Why try to trust the certificate at all?**

The site and the PowerShell script are both running on the same machine in a controlled build environment. There’s no security risk in bypassing certificate validation for these localhost calls.

Here’s what worked:

---

### 1. Remove the Certificate Trust Step

No more trying to install or trust certificates. Just let ASP.NET Core create its default dev cert:

```yaml
- name: Setup .NET 10
  uses: actions/setup-dotnet@v4
  with:
    dotnet-version: '10.0.x'
# That’s it — no certificate trust step needed!
```

---

### 2. Configure PowerShell to Skip Certificate Validation

At the top of your PowerShell script, add this:

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

---

### 3. Update HTTP Calls to Use Certificate Bypass

For PowerShell Core, add `-SkipCertificateCheck`:

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

**Result:** Success! The site starts with its self-signed HTTPS cert, and the PowerShell script can make API calls without SSL errors.

---

## Key Takeaways

1. **Don’t fight the system** — Instead of trying to trust a cert non-interactively (which is hard for security reasons), bypass validation in a controlled way.
2. **Different approaches for different PowerShell versions** — Windows PowerShell 5.x uses `ServicePointManager`, PowerShell Core 6+ has `-SkipCertificateCheck`.
3. **Security context matters** — Skipping validation is safe when:
   - Both client and server are on the same machine
   - You control both
   - It’s a temporary build environment
   - You’re only calling localhost

---

## Final Workflow

Here’s the final GitHub Actions workflow:

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

---

## Conclusion

Sometimes the best solution isn’t forcing the “right” way but finding a simpler alternative. In this case, bypassing certificate validation for localhost was far easier than trying to trust certs on Windows.

If you’re struggling with HTTPS dev certs in GitHub Actions, I hope this saves you the time I spent figuring it out.

---

**Related Resources:**
- https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest
- https://docs.microsoft.com/en-us/aspnet/core/security/enforcing-ssl#trust-the-aspnet-core-https-development-certificate-on-windows-and-macos
- https://docs.microsoft.com/en-us/dotnet/api/system.net.servicepointmanager.certificatepolicy
