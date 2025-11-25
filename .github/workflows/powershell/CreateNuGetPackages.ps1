param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

# ============================================================================
# TEMPORARY WORKAROUND - Remove when Umbraco fixes issue #20801
# https://github.com/umbraco/Umbraco-CMS/issues/20801
#
# Set to $false to disable the BlockList label fix
# Delete this entire section when Umbraco releases a fix
# ============================================================================
$FixBlockListLabels = $true

function Fix-BlockListLabels {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageXmlPath,
        [Parameter(Mandatory = $true)]
        [string]$USyncConfigPath
    )

    try {
        Write-Host "Fixing BlockList labels in package.xml..." -ForegroundColor Yellow

        # Read and parse uSync config to get label mappings
        [xml]$usyncXml = Get-Content $USyncConfigPath -Encoding UTF8
        $configCData = $usyncXml.DataType.Config.'#cdata-section'
        $usyncConfig = $configCData | ConvertFrom-Json

        # Create label mapping
        $labelMap = @{}
        foreach ($block in $usyncConfig.blocks) {
            if ($block.contentElementTypeKey -and $block.label) {
                # Strip markdown bold markers
                $label = $block.label -replace '\*\*', ''
                $labelMap[$block.contentElementTypeKey] = $label
            }
        }

        Write-Verbose "Found $($labelMap.Count) block labels in uSync config"

        # Read package.xml
        $packageXmlContent = Get-Content $PackageXmlPath -Raw -Encoding UTF8

        # Find and extract the [BlockList] Main Content DataType Configuration
        $pattern = '(<DataType Name="\[BlockList\] Main Content"[^>]*Configuration=")([^"]+)(")'
        $match = [regex]::Match($packageXmlContent, $pattern)

        if (-not $match.Success) {
            Write-Host "Warning: Could not find [BlockList] Main Content DataType in package.xml" -ForegroundColor Yellow
            return $false
        }

        # Decode HTML entities and parse JSON
        $configEncoded = $match.Groups[2].Value
        $configJson = [System.Web.HttpUtility]::HtmlDecode($configEncoded)
        $config = $configJson | ConvertFrom-Json

        # Display BEFORE
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "BEFORE - DataType Configuration:" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host $match.Value -ForegroundColor Gray
        Write-Host "`nDecoded Configuration JSON:" -ForegroundColor Cyan
        Write-Host ($configJson | ConvertFrom-Json | ConvertTo-Json -Depth 10) -ForegroundColor Gray

        # Add labels to each block
        $labelsAdded = 0
        foreach ($block in $config.blocks) {
            if ($block.contentElementTypeKey -and $labelMap.ContainsKey($block.contentElementTypeKey)) {
                # Add the label property
                $block | Add-Member -MemberType NoteProperty -Name "label" -Value $labelMap[$block.contentElementTypeKey] -Force
                $labelsAdded++
            }
        }

        # Convert back to JSON (compact format)
        $modifiedJson = $config | ConvertTo-Json -Depth 10 -Compress

        # Unicode-escape single quotes to match Umbraco format
        $modifiedJson = $modifiedJson -replace "'", '\u0027'

        # HTML-encode for XML attribute (properly escape all special XML characters: <, >, &, ", ')
        $modifiedEncoded = [System.Web.HttpUtility]::HtmlEncode($modifiedJson)

        # Replace in the original XML content
        $prefix = $match.Groups[1].Value
        $suffix = $match.Groups[3].Value
        $replacement = $prefix + $modifiedEncoded + $suffix
        $packageXmlContent = $packageXmlContent -replace [regex]::Escape($match.Value), $replacement

        # Display AFTER
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "AFTER - DataType Configuration:" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host $replacement -ForegroundColor Green
        Write-Host "`nDecoded Configuration JSON:" -ForegroundColor Cyan
        Write-Host ($modifiedJson | ConvertFrom-Json | ConvertTo-Json -Depth 10) -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Cyan

        # Write back to file
        $packageXmlContent | Set-Content $PackageXmlPath -Encoding UTF8 -NoNewline

        Write-Host "Successfully added $labelsAdded labels to [BlockList] Main Content" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error fixing BlockList labels: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose $_.ScriptStackTrace
        return $false
    }
}
# ============================================================================

# Enable verbose output
$VerbosePreference = "Continue"

if (-not $Version) {
    Write-Host "Error: Version parameter is required." -ForegroundColor Red
    exit 1
}

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

# Get the script's directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Find repository root by looking for .git directory
function Get-RepositoryRoot {
    param([string]$StartPath)

    $currentPath = $StartPath
    while ($currentPath) {
        if (Test-Path (Join-Path $currentPath ".git")) {
            return $currentPath
        }
        $parent = Split-Path -Parent $currentPath
        if ($parent -eq $currentPath) {
            break
        }
        $currentPath = $parent
    }
    throw "Could not find repository root (no .git directory found)"
}

# Get the repository root directory
$CurrentDir = Get-RepositoryRoot -StartPath $ScriptDir

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

# ============================================================================
# Configure NuGet sources for package restore
# Extract all configured NuGet sources (including custom ones from PR workflow)
# ============================================================================
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Configuring NuGet Sources for Restore" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$allSourcesOutput = dotnet nuget list source
$sourceUrls = @()

# Parse the output to extract source URLs
foreach ($line in $allSourcesOutput) {
    if ($line -match '^\s+(https?://\S+)') {
        $url = $matches[1].Trim()
        $sourceUrls += $url
        Write-Host "  Found source: $url" -ForegroundColor Cyan
    }
}

if ($sourceUrls.Count -eq 0) {
    Write-Host "  Warning: No NuGet sources found, using default behavior" -ForegroundColor Yellow
} else {
    Write-Host "`nFound $($sourceUrls.Count) NuGet source(s)" -ForegroundColor Green
}

# Explicitly restore the solution with all configured sources before starting Umbraco
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Restoring Solution with All Sources" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($sourceUrls.Count -gt 0) {
    $restoreArgs = @("restore", "Clean.Blog.csproj")
    foreach ($sourceUrl in $sourceUrls) {
        $restoreArgs += "--source"
        $restoreArgs += $sourceUrl
    }

    Write-Host "Running: dotnet $($restoreArgs -join ' ')" -ForegroundColor Yellow
    & dotnet $restoreArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "Restore completed successfully" -ForegroundColor Green
    }
} else {
    Write-Host "Running: dotnet restore Clean.Blog.csproj" -ForegroundColor Yellow
    dotnet restore Clean.Blog.csproj

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}

Write-Host "================================================`n" -ForegroundColor Cyan

# Extract Umbraco version from Clean.csproj and update README.md before starting Umbraco
Write-Host "`nExtracting Umbraco version from Clean.csproj..."
$cleanCsprojFile = Get-ChildItem -Path $CurrentDir -Recurse -Filter "Clean.csproj" -File | Where-Object {
    $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\" -and $_.Name -eq "Clean.csproj"
} | Select-Object -First 1

$umbracoVersion = $null
if ($cleanCsprojFile) {
    [xml]$cleanXml = Get-Content $cleanCsprojFile.FullName
    $ns = $cleanXml.DocumentElement.NamespaceURI
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($cleanXml.NameTable)
    $nsmgr.AddNamespace("ns", $ns)

    $umbracoNode = $cleanXml.SelectSingleNode("//ns:PackageReference[@Include='Umbraco.Cms.Web.Website']", $nsmgr)
    if ($umbracoNode -and $umbracoNode.HasAttribute("Version")) {
        $umbracoVersion = $umbracoNode.Version
        Write-Host "Found Umbraco version: $umbracoVersion" -ForegroundColor Green
    } else {
        Write-Host "Warning: Could not find Umbraco.Cms.Web.Website version in Clean.csproj" -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: Could not find Clean.csproj" -ForegroundColor Yellow
}

# Update README.md with the new version for Umbraco 17 examples
$readmePath = Join-Path $CurrentDir "README.md"
if (Test-Path $readmePath) {
    Write-Host "`nUpdating README.md with version $Version for Umbraco 17 examples..."

    $readmeContent = Get-Content $readmePath -Raw
    $originalContent = $readmeContent

    # Extract the Umbraco 17 section only (between "## Umbraco 17" and the next "---")
    $umbraco17Pattern = '(?s)(## Umbraco 17.*?)(---)'
    if ($readmeContent -match $umbraco17Pattern) {
        $umbraco17Section = $matches[1]
        $originalUmbraco17Section = $umbraco17Section

        # Pattern 1: Update Umbraco.Templates version (only if $umbracoVersion is set)
        if ($umbracoVersion) {
            $pattern0 = '(dotnet new install Umbraco\.Templates::)[\d\.]+-?[\w\d]*( --force)'
            if ($umbraco17Section -match $pattern0) {
                $oldLine0 = $matches[0]
                $umbraco17Section = $umbraco17Section -replace $pattern0, "`${1}$umbracoVersion`${2}"
                if ($umbraco17Section -match $pattern0) {
                    $newLine0 = $matches[0]
                    if ($oldLine0 -ne $newLine0) {
                        Write-Host "  BEFORE: $oldLine0" -ForegroundColor Yellow
                        Write-Host "  AFTER:  $newLine0" -ForegroundColor Green
                    }
                }
            }
        }

        # Pattern 2: Update dotnet add Clean package version
        $pattern1 = '(dotnet add "MyProject" package Clean --version )[\d\.]+-?[\w\d]*'
        if ($umbraco17Section -match $pattern1) {
            $oldLine1 = $matches[0]
            $umbraco17Section = $umbraco17Section -replace $pattern1, "`${1}$Version"
            if ($umbraco17Section -match $pattern1) {
                $newLine1 = $matches[0]
                if ($oldLine1 -ne $newLine1) {
                    Write-Host "  BEFORE: $oldLine1" -ForegroundColor Yellow
                    Write-Host "  AFTER:  $newLine1" -ForegroundColor Green
                }
            }
        }

        # Pattern 3: Update dotnet add Clean.Core package version
        $pattern2 = '(dotnet add "MyProject" package Clean\.Core --version )[\d\.]+-?[\w\d]*'
        if ($umbraco17Section -match $pattern2) {
            $oldLine2 = $matches[0]
            $umbraco17Section = $umbraco17Section -replace $pattern2, "`${1}$Version"
            if ($umbraco17Section -match $pattern2) {
                $newLine2 = $matches[0]
                if ($oldLine2 -ne $newLine2) {
                    Write-Host "  BEFORE: $oldLine2" -ForegroundColor Yellow
                    Write-Host "  AFTER:  $newLine2" -ForegroundColor Green
                }
            }
        }

        # Pattern 4: Update dotnet new install template version
        $pattern3 = '(dotnet new install Umbraco\.Community\.Templates\.Clean::)[\d\.]+-?[\w\d]*( --force)'
        if ($umbraco17Section -match $pattern3) {
            $oldLine3 = $matches[0]
            $umbraco17Section = $umbraco17Section -replace $pattern3, "`${1}$Version`${2}"
            if ($umbraco17Section -match $pattern3) {
                $newLine3 = $matches[0]
                if ($oldLine3 -ne $newLine3) {
                    Write-Host "  BEFORE: $oldLine3" -ForegroundColor Yellow
                    Write-Host "  AFTER:  $newLine3" -ForegroundColor Green
                }
            }
        }

        # Replace the Umbraco 17 section in the full content
        if ($originalUmbraco17Section -ne $umbraco17Section) {
            $readmeContent = $readmeContent -replace [regex]::Escape($originalUmbraco17Section), $umbraco17Section
        }
    } else {
        Write-Host "Warning: Could not find Umbraco 17 section in README.md" -ForegroundColor Yellow
    }

    if ($readmeContent -ne $originalContent) {
        Set-Content -Path $readmePath -Value $readmeContent -NoNewline
        Write-Host "`nREADME.md updated successfully with version $Version" -ForegroundColor Green
    } else {
        Write-Host "`nREADME.md already has the correct version or no changes were needed" -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: README.md not found at $readmePath" -ForegroundColor Yellow
}


# run dotnet run in the current directory to start the Umbraco project
Write-Verbose "Starting Umbraco project to ensure API is running..."

# Start the process and keep a reference (--no-restore since we already restored explicitly)
$umbracoProcess = Start-Process -FilePath "dotnet" -ArgumentList "run --project Clean.Blog.csproj --no-restore" -NoNewWindow -PassThru

Write-Host "Umbraco process started with ID: $($umbracoProcess.Id)"

# wait for the website to start, checking every 10 seconds if the umbraco path is reachable
$maxRetries = 12
$retryCount = 0
$umbracoStarted = $false

while ($retryCount -lt $maxRetries) {
    try {
        $webRequestParams = @{
            Uri = "https://localhost:44340/umbraco"
            UseBasicParsing = $true
            ErrorAction = "Stop"
        }
        # Add SkipCertificateCheck for PowerShell Core
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $webRequestParams['SkipCertificateCheck'] = $true
        }
        $response = Invoke-WebRequest @webRequestParams
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
        client_id     = "umbraco-back-office-clean-api-user"
        client_secret = "c9DK0CxvRWklbjR"
    }
    $tokenHeaders = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    $tokenParams = @{
        Method = "Post"
        Uri = $tokenUrl
        Body = $tokenBody
        Headers = $tokenHeaders
        ErrorAction = "Stop"
    }
    # Add SkipCertificateCheck for PowerShell Core
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $tokenParams['SkipCertificateCheck'] = $true
    }
    $response = Invoke-RestMethod @tokenParams
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

    $packageInfoParams = @{
        Method = "Get"
        Uri = $packageInfoUrl
        Headers = $authHeaders
        ErrorAction = "Stop"
    }
    # Add SkipCertificateCheck for PowerShell Core
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $packageInfoParams['SkipCertificateCheck'] = $true
    }
    $packageInfo = Invoke-RestMethod @packageInfoParams
    Write-Verbose "Package info retrieved successfully."

    # Wait for 30 seconds to ensure package is ready
    Write-Verbose "Waiting for 30 seconds to ensure package is ready..."

    # Step 3: Download Package
    Write-Verbose "Downloading package..."
    $downloadUrl = "https://localhost:44340/umbraco/management/api/v1/package/created/$packageInfo/download/"
    $outputFile = Join-Path $OutputFolder "package.zip"

    $downloadParams = @{
        Method = "Get"
        Uri = $downloadUrl
        Headers = $authHeaders
        OutFile = $outputFile
        ErrorAction = "Stop"
    }
    # Add SkipCertificateCheck for PowerShell Core
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $downloadParams['SkipCertificateCheck'] = $true
    }
    Invoke-RestMethod @downloadParams
    Write-Host "✅ Package downloaded successfully to $outputFile" -ForegroundColor Green

    # ========================================================================
    # BEGIN TEMPORARY WORKAROUND - Umbraco issue #20801
    # Remove this entire block when Umbraco fixes BlockList label export
    # ========================================================================
    if ($FixBlockListLabels) {
        Write-Host ""

        # Extract package.zip to temp location
        $tempExtractPath = Join-Path $OutputFolder "temp_package_extract"
        if (Test-Path $tempExtractPath) {
            Remove-Item $tempExtractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempExtractPath | Out-Null

        # Extract the package
        Expand-Archive -Path $outputFile -DestinationPath $tempExtractPath -Force

        # Paths
        $packageXmlPath = Join-Path $tempExtractPath "package.xml"
        $usyncConfigPath = Join-Path $CurrentDir "template\Clean.Blog\uSync\v17\DataTypes\BlockListMainContent.config"

        if ((Test-Path $packageXmlPath) -and (Test-Path $usyncConfigPath)) {
            # Call the PowerShell function to fix labels
            $success = Fix-BlockListLabels -PackageXmlPath $packageXmlPath -USyncConfigPath $usyncConfigPath

            if ($success) {
                # Repack the package.zip
                if (Test-Path $outputFile) {
                    Remove-Item $outputFile -Force
                }
                Compress-Archive -Path "$tempExtractPath\*" -DestinationPath $outputFile -CompressionLevel Optimal
                Write-Host "Package repacked successfully" -ForegroundColor Green
            }
        } else {
            if (-not (Test-Path $packageXmlPath)) {
                Write-Host "Warning: package.xml not found in extracted package" -ForegroundColor Yellow
            }
            if (-not (Test-Path $usyncConfigPath)) {
                Write-Host "Warning: uSync config not found at $usyncConfigPath" -ForegroundColor Yellow
            }
        }

        # Clean up temp directory
        if (Test-Path $tempExtractPath) {
            Remove-Item $tempExtractPath -Recurse -Force
        }
    }
    # ========================================================================
    # END TEMPORARY WORKAROUND
    # ========================================================================
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
$csprojFiles = Get-ChildItem -Path $CurrentDir -Recurse -Filter *.csproj | Where-Object {
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
$binFolders = Get-ChildItem -Path $CurrentDir -Recurse -Directory | Where-Object {
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

# Get all configured NuGet sources for restore operations
Write-Host "`nGetting all configured NuGet sources..."
$allSourcesOutput = dotnet nuget list source
$sourceUrls = @()

# Parse the output to extract source URLs
# The format is typically:
# Registered Sources:
#   1.  nuget.org [Enabled]
#       https://api.nuget.org/v3/index.json
#   2.  CleanLocalPackages [Enabled]
#       D:\a\Clean\Clean\.artifacts\nuget
foreach ($line in $allSourcesOutput) {
    # Match URLs (http/https) and local paths
    if ($line -match '^\s+(https?://\S+)') {
        $url = $matches[1].Trim()
        $sourceUrls += $url
        Write-Host "  Found source: $url" -ForegroundColor Cyan
    }
    elseif ($line -match '^\s+([A-Za-z]:\\[^\s]+)') {
        # Windows absolute path (e.g., D:\path\to\folder)
        $path = $matches[1].Trim()
        $sourceUrls += $path
        Write-Host "  Found source: $path" -ForegroundColor Cyan
    }
    elseif ($line -match '^\s+(/[^\s]+)') {
        # Unix absolute path (e.g., /path/to/folder)
        $path = $matches[1].Trim()
        $sourceUrls += $path
        Write-Host "  Found source: $path" -ForegroundColor Cyan
    }
}

# Ensure local source is always included (in case parsing missed it)
if ($sourceUrls -notcontains $nugetDestination) {
    $sourceUrls += $nugetDestination
    Write-Host "  Added local source: $nugetDestination" -ForegroundColor Green
}

if ($sourceUrls.Count -eq 0) {
    Write-Host "  Warning: No NuGet sources found, using default behavior" -ForegroundColor Yellow
}

try {
    # Build and pack in dependency order to avoid NU1102 errors
    # Order: Clean.Core -> Clean.Headless -> Clean

    $cleanCorePath = Get-ChildItem -Path $CurrentDir -Recurse -Filter "Clean.Core.csproj" -File | Where-Object {
        $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\"
    } | Select-Object -First 1

    $cleanHeadlessPath = Get-ChildItem -Path $CurrentDir -Recurse -Filter "Clean.Headless.csproj" -File | Where-Object {
        $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\"
    } | Select-Object -First 1

    $cleanPath = Get-ChildItem -Path $CurrentDir -Recurse -Filter "Clean.csproj" -File | Where-Object {
        $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\" -and $_.Name -eq "Clean.csproj"
    } | Select-Object -First 1

    # Step 1: Build and pack Clean.Core
    if ($cleanCorePath) {
        Write-Host "`n=== Building Clean.Core ==="

        # Explicit restore with all configured sources
        if ($sourceUrls.Count -gt 0) {
            Write-Host "Restoring Clean.Core with all configured sources..."
            $restoreArgs = @("restore", $cleanCorePath.FullName)
            foreach ($sourceUrl in $sourceUrls) {
                $restoreArgs += "--source"
                $restoreArgs += $sourceUrl
            }
            & dotnet $restoreArgs

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Warning: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
            }
        }

        dotnet build $cleanCorePath.FullName --configuration Release --no-restore
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

        # Explicit restore with all configured sources
        if ($sourceUrls.Count -gt 0) {
            Write-Host "Restoring Clean.Headless with all configured sources..."
            $restoreArgs = @("restore", $cleanHeadlessPath.FullName)
            foreach ($sourceUrl in $sourceUrls) {
                $restoreArgs += "--source"
                $restoreArgs += $sourceUrl
            }
            & dotnet $restoreArgs

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Warning: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
            }
        }

        dotnet build $cleanHeadlessPath.FullName --configuration Release --no-restore
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

        # Explicit restore with all configured sources
        if ($sourceUrls.Count -gt 0) {
            Write-Host "Restoring Clean with all configured sources..."
            $restoreArgs = @("restore", $cleanPath.FullName)
            foreach ($sourceUrl in $sourceUrls) {
                $restoreArgs += "--source"
                $restoreArgs += $sourceUrl
            }
            & dotnet $restoreArgs

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Warning: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
            }
        }

        dotnet build $cleanPath.FullName --configuration Release --no-restore
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Packing Clean..."
            dotnet pack $cleanPath.FullName --configuration Release --no-build
        }
    }

    # Step 4: Pack template-pack if it exists
    if ($templatePackPath) {
        Write-Host "`n=== Packing template-pack ==="

        # Explicit restore with all configured sources
        if ($sourceUrls.Count -gt 0) {
            Write-Host "Restoring template-pack with all configured sources..."
            $restoreArgs = @("restore", $templatePackPath)
            foreach ($sourceUrl in $sourceUrls) {
                $restoreArgs += "--source"
                $restoreArgs += $sourceUrl
            }
            & dotnet $restoreArgs

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Warning: Restore failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
            }
        }

        dotnet pack $templatePackPath --configuration Release --no-restore
    }
}
finally {
    # Remove the temporary local source
    Write-Host "`nRemoving local NuGet source: $sourceName"
    dotnet nuget remove source $sourceName
}

$releasePackages = Get-ChildItem -Path $CurrentDir -Recurse -Filter *.nupkg | Where-Object {
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