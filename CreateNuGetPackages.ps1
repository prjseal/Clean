param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)


# Run in an elevated PowerShell session
Write-Host "Cleaning existing .NET dev HTTPS certificates..."
dotnet dev-certs https --clean

Write-Host "Generating and exporting new dev certificate..."
$certPath = "C:\temp\aspnetcore-dev-cert.pfx"
$password = "password123"
dotnet dev-certs https --export-path $certPath --password $password

Write-Host "Importing certificate into LocalMachine Root store silently..."
$mypwd = ConvertTo-SecureString -String $password -Force -AsPlainText

# Use X509Store directly for better control
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$cert.Import($certPath, $password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet)

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$store.Add($cert)
$store.Close()

Write-Host "✅ Certificate trusted successfully without modal."

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
while ($retryCount -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "https://localhost:44340/umbraco" -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Verbose "Umbraco project is running."
            break
        }
    }
    catch {
        Write-Verbose "Waiting for Umbraco project to start... (Attempt $($retryCount + 1) of $maxRetries)"
        Start-Sleep -Seconds 10
        $retryCount++
    }
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

    $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody -Headers $tokenHeaders -ErrorAction Stop
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

    $packageInfo = Invoke-RestMethod -Method Get -Uri $packageInfoUrl -Headers $authHeaders -ErrorAction Stop
    Write-Verbose "Package info retrieved successfully."

    # Wait for 30 seconds to ensure package is ready
    Write-Verbose "Waiting for 30 seconds to ensure package is ready..."

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

foreach ($file in $csprojFiles) {
    [xml]$xml = Get-Content $file.FullName

    $ns = $xml.DocumentElement.NamespaceURI
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsmgr.AddNamespace("ns", $ns)

    $packageVersionNode = $xml.SelectSingleNode("//ns:PackageVersion", $nsmgr)
    $versionNode = $xml.SelectSingleNode("//ns:Version", $nsmgr)

    if ($packageVersionNode) {
        if ($packageVersionNode.InnerText -ne $Version) {
            $packageVersionNode.InnerText = $Version
            $xml.Save($file.FullName)
            $updatedFiles += "$($file.FullName) (PackageVersion)"
        }
    } elseif ($versionNode) {
        if ($versionNode.InnerText -ne $Version) {
            $versionNode.InnerText = $Version
            $xml.Save($file.FullName)
            $updatedFiles += "$($file.FullName) (Version)"
        }
    } else {
        $propertyGroup = $xml.SelectSingleNode("//ns:PropertyGroup", $nsmgr)
        if ($propertyGroup) {
            $newNode = $xml.CreateElement("Version", $ns)
            $newNode.InnerText = $Version
            $propertyGroup.AppendChild($newNode) | Out-Null
            $xml.Save($file.FullName)
            $updatedFiles += "$($file.FullName) (Version added)"
        }
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

$slnFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *.sln
foreach ($sln in $slnFiles) {
    Write-Host "`nProcessing solution: $($sln.FullName)"
    dotnet clean $sln.FullName
    dotnet build $sln.FullName
    dotnet pack $sln.FullName
}

if ($templatePackPath) {
    Write-Host "`nPacking template-pack.csproj: $templatePackPath"
    dotnet pack $templatePackPath
} else {
    Write-Host "`ntemplate-pack.csproj not found or excluded."
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