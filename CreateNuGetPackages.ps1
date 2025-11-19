param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

# Detect PowerShell version and configure SSL certificate handling
$psVersion = $PSVersionTable.PSVersion.Major
Write-Host "PowerShell Version: $psVersion"

# Create a hashtable for certificate skip parameter based on PS version
$certSkipParam = @{}
if ($psVersion -ge 7) {
    Write-Host "Using PowerShell 7+ SkipCertificateCheck parameter"
    $certSkipParam = @{ SkipCertificateCheck = $true }
} else {
    Write-Host "Using PowerShell 5.1 ICertificatePolicy approach"
    # For PowerShell 5.1 with .NET Framework, use ICertificatePolicy
    # This doesn't exist in .NET Core, but works perfectly in .NET Framework
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
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Create and trust development certificate for HTTPS
Write-Host "Setting up development certificate for HTTPS..." -ForegroundColor Cyan

try {
    # Clean any existing dev certs
    Write-Host "Cleaning existing certificates..."
    dotnet dev-certs https --clean | Out-Null

    # Create a new dev certificate
    Write-Host "Creating new development certificate..."
    dotnet dev-certs https | Out-Null

    # Export the certificate to a PFX file
    $certPath = Join-Path $env:TEMP "aspnetcore-dev-cert.pfx"
    $certPassword = "DevCertPassword"
    Write-Host "Exporting certificate..."
    dotnet dev-certs https --export-path $certPath --password $certPassword | Out-Null

    # Import the certificate into the trusted root store
    Write-Host "Importing certificate to trusted root store..."
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $certPassword)
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()

    Write-Host "Development certificate created and trusted successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to set up development certificate: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Continuing anyway - certificate skip parameters will be used for API calls" -ForegroundColor Yellow
}

# Enable verbose output
$VerbosePreference = "Continue"

if (-not $Version) {
    Write-Host "Error: Version parameter is required." -ForegroundColor Red
    exit 1
}

# Get the script's directory
$CurrentDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Get current process ID
$currentPid = $PID

# Find processes related to the template path
$processes = Get-Process | Where-Object {
    $_.Path -like "*$CurrentDir*" -and $_.Id -ne $currentPid
}

foreach ($proc in $processes) {
    Write-Host "Stopping process: $($proc.ProcessName) (PID: $($proc.Id))"
    Stop-Process -Id $proc.Id -Force
}

# find a file within $CurrentDir or descendant directories named ImportPackageXmlMigration.cs
function Get-PackageZipRoot {
    $packageMigrationFiles = Get-ChildItem -Path $CurrentDir -Filter *ImportPackageXmlMigration.cs -Recurse -File
    if ($packageMigrationFiles.Count -eq 0) {
        throw "Could not find ImportPackageXmlMigration.cs in any parent directory."
    }
    
    # return the directory of the first found csproj file
    return $packageMigrationFiles[0].Directory.FullName
}

$OutputFolder = Get-PackageZipRoot

Write-Verbose "Output folder for downloaded package: $OutputFolder"

# write the script directory to verbose output
Write-Verbose "Script directory: $CurrentDir"

$artifactsRoot = Join-Path $CurrentDir ".artifacts"

# Define NuGet destination path
$nugetDestination = Join-Path $artifactsRoot "nuget"

#check if the nuget destination exists, if not create it
if (-not (Test-Path -Path $nugetDestination)) {
    Write-Verbose "Creating NuGet destination directory: $nugetDestination"
    New-Item -ItemType Directory -Path $nugetDestination | Out-Null
}

# iterate through the directory parts to find the solution root (where the Clean.Blog.csproj file is located) 
function Get-SolutionRoot {
    $csprojFiles = Get-ChildItem -Path $CurrentDir -Filter *Clean.Blog.csproj -Recurse -File
    if ($csprojFiles.Count -eq 0) {
        throw "Could not find Clean.Blog.csproj in any parent directory."
    }
    
    # return the directory of the first found csproj file
    return $csprojFiles[0].Directory.FullName
}

# Set the solution root directory
$solutionRoot = Get-SolutionRoot
# Change to the solution root directory
Set-Location -Path $solutionRoot

# write the solution root to verbose output
Write-Verbose "Solution root directory: $solutionRoot"


# run dotnet run in the current directory to start the Umbraco project
Write-Verbose "Starting Umbraco project to ensure API is running..."

# Start the process and keep a reference
$umbracoProcess = Start-Process -FilePath "dotnet" -ArgumentList "run --project Clean.Blog.csproj" -NoNewWindow -PassThru

Write-Host "Umbraco process started with ID: $($umbracoProcess.Id)"

# wait for the website to start, checking every 10 seconds if the umbraco path is reachable
$maxRetries = 12
$retryCount = 0
$umbracoStarted = $false

while ($retryCount -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "https://localhost:44340/umbraco" -UseBasicParsing @certSkipParam -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "Umbraco project is running and responding." -ForegroundColor Green
            $umbracoStarted = $true
            break
        }
    }
    catch {
        Write-Verbose "Waiting for Umbraco project to start... (Attempt $($retryCount + 1) of $maxRetries): $($_.Exception.Message)"
        Start-Sleep -Seconds 10
        $retryCount++
    }
}

# Check if Umbraco started successfully
if (-not $umbracoStarted) {
    Write-Host "ERROR: Umbraco failed to start after $maxRetries attempts." -ForegroundColor Red
    if ($umbracoProcess -and !$umbracoProcess.HasExited) {
        Write-Host "Stopping Umbraco process with ID: $($umbracoProcess.Id)"
        Stop-Process -Id $umbracoProcess.Id -Force
    }
    exit 1
}

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

    $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody -Headers $tokenHeaders @certSkipParam -ErrorAction Stop
    $accessToken = $response.access_token

    if (-not $accessToken) {
        throw "Failed to retrieve access token."
    }
    Write-Verbose "Access token retrieved successfully."

    # Step 2: Call Package Info API
    Write-Verbose "Creating package for package version: $Version"
    $packageInfoUrl = "https://localhost:44340/api/v1/package/$Version"
    $authHeaders = @{
        "Authorization" = "Bearer $accessToken"
    }

    $packageInfo = Invoke-RestMethod -Method Get -Uri $packageInfoUrl -Headers $authHeaders @certSkipParam -ErrorAction Stop
    Write-Verbose "Package info retrieved successfully."

    # Step 3: Download Package
    Write-Verbose "Downloading package..."
    $downloadUrl = "https://localhost:44340/umbraco/management/api/v1/package/created/$packageInfo/download/"
    $outputFile = Join-Path $OutputFolder "package.zip"

    Invoke-RestMethod -Method Get -Uri $downloadUrl -Headers $authHeaders -OutFile $outputFile @certSkipParam -ErrorAction Stop
    Write-Host "✅ Package downloaded successfully to $outputFile" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred during package download: $($_.Exception.Message)" -ForegroundColor Red

    if ($umbracoProcess -and !$umbracoProcess.HasExited) {
        Write-Host "Stopping Umbraco process with ID: $($umbracoProcess.Id)"
        Stop-Process -Id $umbracoProcess.Id -Force
    }

    exit 1
}


if ($umbracoProcess -and !$umbracoProcess.HasExited) {
    Write-Host "Stopping Umbraco process with ID: $($umbracoProcess.Id)"
    Stop-Process -Id $umbracoProcess.Id -Force
}

# update the Version and PackageVersion in all .csproj files except Clean.Blog.csproj and Clean.Models.csproj

$excludedFiles = @("Clean.Blog.csproj", "Clean.Models.csproj")
$csprojFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *.csproj | Where-Object {
    $_.FullName -notmatch "\\bin\\" -and ($excludedFiles -notcontains $_.Name)
}

$updatedFiles = @()
$templatePackPath = $null
$cleanCsprojPath = $null
$umbracoVersion = $null

# Extract base version without suffix (e.g., "7.0.0-rc1" -> "7.0.0")
$baseVersion = $Version -replace '-.*$', ''

foreach ($file in $csprojFiles) {
    [xml]$xml = Get-Content $file.FullName

    $ns = $xml.DocumentElement.NamespaceURI
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsmgr.AddNamespace("ns", $ns)

    $packageVersionNode = $xml.SelectSingleNode("//ns:PackageVersion", $nsmgr)
    $versionNode = $xml.SelectSingleNode("//ns:Version", $nsmgr)
    $informationalVersionNode = $xml.SelectSingleNode("//ns:InformationalVersion", $nsmgr)
    $assemblyVersionNode = $xml.SelectSingleNode("//ns:AssemblyVersion", $nsmgr)
    $fileModified = $false

    if ($packageVersionNode) {
        if ($packageVersionNode.InnerText -ne $Version) {
            $packageVersionNode.InnerText = $Version
            $fileModified = $true
            $updatedFiles += "$($file.FullName) (PackageVersion)"
        }
    } elseif ($versionNode) {
        if ($versionNode.InnerText -ne $Version) {
            $versionNode.InnerText = $Version
            $fileModified = $true
            $updatedFiles += "$($file.FullName) (Version)"
        }
    } else {
        $propertyGroup = $xml.SelectSingleNode("//ns:PropertyGroup", $nsmgr)
        if ($propertyGroup) {
            $newNode = $xml.CreateElement("Version", $ns)
            $newNode.InnerText = $Version
            $propertyGroup.AppendChild($newNode) | Out-Null
            $fileModified = $true
            $updatedFiles += "$($file.FullName) (Version added)"
        }
    }

    # Update InformationalVersion to base version (without suffix)
    if ($informationalVersionNode) {
        if ($informationalVersionNode.InnerText -ne $baseVersion) {
            $informationalVersionNode.InnerText = $baseVersion
            $fileModified = $true
            $updatedFiles += "$($file.FullName) (InformationalVersion)"
        }
    } else {
        $propertyGroup = $xml.SelectSingleNode("//ns:PropertyGroup", $nsmgr)
        if ($propertyGroup) {
            $newNode = $xml.CreateElement("InformationalVersion", $ns)
            $newNode.InnerText = $baseVersion
            $propertyGroup.AppendChild($newNode) | Out-Null
            $fileModified = $true
            $updatedFiles += "$($file.FullName) (InformationalVersion added)"
        }
    }

    # Update AssemblyVersion to base version (without suffix)
    if ($assemblyVersionNode) {
        if ($assemblyVersionNode.InnerText -ne $baseVersion) {
            $assemblyVersionNode.InnerText = $baseVersion
            $fileModified = $true
            $updatedFiles += "$($file.FullName) (AssemblyVersion)"
        }
    } else {
        $propertyGroup = $xml.SelectSingleNode("//ns:PropertyGroup", $nsmgr)
        if ($propertyGroup) {
            $newNode = $xml.CreateElement("AssemblyVersion", $ns)
            $newNode.InnerText = $baseVersion
            $propertyGroup.AppendChild($newNode) | Out-Null
            $fileModified = $true
            $updatedFiles += "$($file.FullName) (AssemblyVersion added)"
        }
    }

    # Update any PackageReference elements that reference Clean.* packages
    $cleanPackageRefs = $xml.SelectNodes("//ns:PackageReference[starts-with(@Include, 'Clean.')]", $nsmgr)
    foreach ($packageRef in $cleanPackageRefs) {
        if ($packageRef.HasAttribute("Version")) {
            $currentVersion = $packageRef.GetAttribute("Version")
            if ($currentVersion -ne $Version) {
                $packageRef.SetAttribute("Version", $Version)
                $fileModified = $true
                $packageName = $packageRef.GetAttribute("Include")
                $updatedFiles += "$($file.FullName) (PackageReference: $packageName)"
            }
        }
    }

    # Save the file if any modifications were made
    if ($fileModified) {
        $xml.Save($file.FullName)
    }

    if ($file.Name -eq "template-pack.csproj") {
        $templatePackPath = $file.FullName
    }

    if ($file.Name -eq "Clean.csproj") {
        $cleanCsprojPath = $file.FullName
        $umbracoNode = $xml.SelectSingleNode("//ns:PackageReference[@Include='Umbraco.Cms.Web.Website']", $nsmgr)
        if ($umbracoNode -and $umbracoNode.HasAttribute("Version")) {
            $umbracoVersion = $umbracoNode.Version
        }
    }
}

if ($updatedFiles.Count -gt 0) {
    Write-Host "`nUpdated the following .csproj files:"
    $updatedFiles | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "`nNo .csproj files were updated. All already had the correct version or were excluded."
}

Write-Host "`nCleaning all bin folders..."
$binFolders = Get-ChildItem -Path $PSScriptRoot -Recurse -Directory | Where-Object {
    $_.Name -eq "bin" -and $_.FullName -notmatch "\\.vs\\"
}
foreach ($bin in $binFolders) {
    Write-Host "Emptying: $($bin.FullName)"
    Remove-Item "$($bin.FullName)\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# Add local NuGet source for intermediate packages
Write-Host "`nAdding local NuGet source: $nugetDestination"
$sourceName = "CleanLocalPackages"
$existingSource = dotnet nuget list source | Select-String -Pattern $sourceName
if ($existingSource) {
    dotnet nuget remove source $sourceName
}
dotnet nuget add source $nugetDestination --name $sourceName

try {
    # Build and pack in dependency order to avoid NU1102 errors
    # Order: Clean.Core -> Clean.Headless -> Clean

    $cleanCorePath = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Clean.Core.csproj" -File | Where-Object {
        $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\"
    } | Select-Object -First 1

    $cleanHeadlessPath = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Clean.Headless.csproj" -File | Where-Object {
        $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\"
    } | Select-Object -First 1

    $cleanPath = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Clean.csproj" -File | Where-Object {
        $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\" -and $_.Name -eq "Clean.csproj"
    } | Select-Object -First 1

    # Step 1: Build and pack Clean.Core
    if ($cleanCorePath) {
        Write-Host "`n=== Building Clean.Core ==="
        dotnet build $cleanCorePath.FullName --configuration Release
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Packing Clean.Core..."
            dotnet pack $cleanCorePath.FullName --configuration Release --no-build

            # Copy to nuget destination immediately
            $corePackage = Get-ChildItem -Path (Split-Path $cleanCorePath.FullName) -Recurse -Filter "Clean.Core.$Version.nupkg" | Where-Object {
                $_.FullName -match "\\Release\\"
            } | Select-Object -First 1

            if ($corePackage) {
                Copy-Item $corePackage.FullName -Destination $nugetDestination -Force
                Write-Host "Copied Clean.Core package to local source" -ForegroundColor Green
            }
        }
    }

    # Step 2: Build and pack Clean.Headless
    if ($cleanHeadlessPath) {
        Write-Host "`n=== Building Clean.Headless ==="
        dotnet build $cleanHeadlessPath.FullName --configuration Release
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Packing Clean.Headless..."
            dotnet pack $cleanHeadlessPath.FullName --configuration Release --no-build

            # Copy to nuget destination immediately
            $headlessPackage = Get-ChildItem -Path (Split-Path $cleanHeadlessPath.FullName) -Recurse -Filter "Clean.Headless.$Version.nupkg" | Where-Object {
                $_.FullName -match "\\Release\\"
            } | Select-Object -First 1

            if ($headlessPackage) {
                Copy-Item $headlessPackage.FullName -Destination $nugetDestination -Force
                Write-Host "Copied Clean.Headless package to local source" -ForegroundColor Green
            }
        }
    }

    # Step 3: Build and pack Clean (depends on Clean.Core and Clean.Headless)
    if ($cleanPath) {
        Write-Host "`n=== Building Clean ==="
        dotnet build $cleanPath.FullName --configuration Release
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Packing Clean..."
            dotnet pack $cleanPath.FullName --configuration Release --no-build
        }
    }

    # Step 4: Pack template-pack if it exists
    if ($templatePackPath) {
        Write-Host "`n=== Packing template-pack ==="
        dotnet pack $templatePackPath --configuration Release
    }
}
finally {
    # Remove the temporary local source
    Write-Host "`nRemoving local NuGet source: $sourceName"
    dotnet nuget remove source $sourceName
}

$releasePackages = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *.nupkg | Where-Object {
    $_.FullName -match "\\Release\\" -and $_.Name -like "*$Version*.nupkg"
}

if ($releasePackages.Count -gt 0) {
    Write-Host "`nGenerated the following NuGet packages:"
    foreach ($pkg in $releasePackages) {
        Write-Host $pkg.FullName -ForegroundColor Green
        Copy-Item $pkg.FullName -Destination $nugetDestination -Force
    }
    Write-Host "`nCopied all matching packages to: $nugetDestination"
} else {
    Write-Host "`nNo matching NuGet packages found in Release folders."
}