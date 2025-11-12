param(
    [Parameter(Mandatory = $true)]
    [string]$PackageId,

    [Parameter(Mandatory = $true)]
    [string]$OutputFolder
)


# Ignore SSL certificate errors (use only in dev environments!)
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


# Enable verbose output
$VerbosePreference = "Continue"

try {
    Write-Verbose "Checking if output folder exists..."
    if (-not (Test-Path -Path $OutputFolder)) {
        Write-Verbose "Output folder does not exist. Creating: $OutputFolder"
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    # Step 1: Get Bearer Token
    Write-Verbose "Requesting bearer token from Umbraco API..."
    $tokenUrl = "https://localhost:44340/umbraco/management/api/v1/security/back-office/token"
    $tokenBody = @{
        grant_type    = "client_credentials"
        client_id     = "umbraco-back-office-test"
        client_secret = "test"
    }
    $tokenHeaders = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody -Headers $tokenHeaders -ErrorAction Stop
    $accessToken = $response.access_token

    if (-not $accessToken) {
        throw "Failed to retrieve access token."
    }
    Write-Verbose "Access token retrieved successfully."

    # Step 2: Call Package Info API
    Write-Verbose "Creating package for package version: $PackageId"
    $packageInfoUrl = "https://localhost:44340/api/v1/package/$PackageId"
    $authHeaders = @{
        "Authorization" = "Bearer $accessToken"
    }

    $packageInfo = Invoke-RestMethod -Method Get -Uri $packageInfoUrl -Headers $authHeaders -ErrorAction Stop
    Write-Verbose "Package info retrieved successfully."

    # Step 3: Download Package
    Write-Verbose "Downloading package..."
    $downloadUrl = "https://localhost:44340/umbraco/management/api/v1/package/created/$packageInfo/download/"
    $outputFile = Join-Path $OutputFolder "package.zip"

    Invoke-RestMethod -Method Get -Uri $downloadUrl -Headers $authHeaders -OutFile $outputFile -ErrorAction Stop
    Write-Host "✅ Package downloaded successfully to $outputFile"
}
catch {
    Write-Host "❌ An error occurred: $($_.Exception.Message)"
}