<#
.SYNOPSIS
    Gets the latest NuGet version and creates a build version.

.DESCRIPTION
    This script queries the NuGet API for the latest version of the Clean package,
    increments it appropriately, and creates a CI build version string.

.PARAMETER PackageId
    The NuGet package ID to query (default: Clean)

.PARAMETER BuildNumber
    The GitHub Actions build/run number

.PARAMETER WorkspacePath
    The GitHub workspace path for fallback .csproj lookup

.EXAMPLE
    .\Get-BuildVersion.ps1 -PackageId "Clean" -BuildNumber "123" -WorkspacePath "/workspace"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$PackageId = "Clean",

    [Parameter(Mandatory = $true)]
    [string]$BuildNumber,

    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath
)

# Query NuGet API for the latest version of the Clean package
$nugetApiUrl = "https://api.nuget.org/v3-flatcontainer/$PackageId/index.json"

Write-Host "Fetching latest version for package: $PackageId"

try {
    $response = Invoke-RestMethod -Uri $nugetApiUrl -ErrorAction Stop
    $versions = $response.versions

    Write-Host "Found $($versions.Count) total versions"

    # Parse and sort versions using semantic versioning
    $parsedVersions = $versions | ForEach-Object {
        $versionString = $_
        $prerelease = ""

        # Split on hyphen to separate version from prerelease tag
        if ($versionString -match '^([0-9]+\.[0-9]+\.[0-9]+)(.*)$') {
            $baseVersion = $matches[1]
            $prerelease = $matches[2]
        }
        else {
            $baseVersion = $versionString
        }

        # Create object for sorting
        [PSCustomObject]@{
            Original     = $versionString
            Version      = [Version]$baseVersion
            Prerelease   = $prerelease
            IsPrerelease = $prerelease -ne ""
        }
    }

    # Sort by version (descending), then by prerelease status (stable first)
    # This ensures 7.0.0 comes before 7.0.0-rc, but 7.0.0-rc comes before 6.x.x
    $sortedVersions = $parsedVersions | Sort-Object -Property @{Expression = { $_.Version }; Descending = $true }, @{Expression = { $_.IsPrerelease }; Descending = $false }

    # Get the highest version (could be stable or prerelease)
    $latestVersion = $sortedVersions[0].Original

    # Strip prerelease suffix (everything from - onwards) for the base version
    $baseVersionOnly = $sortedVersions[0].Version

    # If there's no prerelease suffix, increment the patch version
    if (-not $sortedVersions[0].IsPrerelease) {
        $major = $baseVersionOnly.Major
        $minor = $baseVersionOnly.Minor
        $patch = $baseVersionOnly.Build + 1
        $baseVersionOnly = [Version]::new($major, $minor, $patch)
        Write-Host "Latest is stable release, incrementing patch version"
    }
    else {
        Write-Host "Latest is prerelease, using base version without suffix"
    }

    $baseVersionString = $baseVersionOnly.ToString()

    Write-Host "Latest version found: $latestVersion"
    Write-Host "  Version number: $($sortedVersions[0].Version)"
    Write-Host "  Is prerelease: $($sortedVersions[0].IsPrerelease)"
    Write-Host "  Base version for builds: $baseVersionString"

    # Create zero-padded 7-digit ci-build-number with 'b' prefix for SemVer compliance
    # (SemVer prohibits leading zeros in numeric identifiers, so we make it alphanumeric)
    $ciBuildNumber = "b" + $BuildNumber.PadLeft(7, '0')

    # Create build version: {baseVersionString}-ci.{ci-build-number}
    $buildVersion = "$baseVersionString-ci.$ciBuildNumber"

    Write-Host "Build version: $buildVersion"

    # Output the version for use in subsequent steps
    echo "version=$buildVersion" >> $env:GITHUB_OUTPUT
    echo "base_version=$baseVersionString" >> $env:GITHUB_OUTPUT
}
catch {
    Write-Host "Error fetching version from NuGet: $_"
    Write-Host "Falling back to version from .csproj files..."

    # Try multiple .csproj files in order of preference
    $csprojFilesToTry = @("Clean.Blog.csproj", "Clean.csproj", "Clean.Core.csproj", "Clean.Headless.csproj", "template-pack.csproj")
    $fallbackVersion = "1.0.0"
    $versionFound = $false

    foreach ($fileName in $csprojFilesToTry) {
        Write-Host "Checking $fileName..."
        $csprojPath = Get-ChildItem -Path $WorkspacePath -Recurse -Filter $fileName -File |
        Where-Object { $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\" } |
        Select-Object -First 1

        if ($csprojPath) {
            [xml]$csprojXml = Get-Content $csprojPath.FullName
            $versionNode = $csprojXml.Project.PropertyGroup.Version | Select-Object -First 1
            if ($versionNode) {
                # Strip any prerelease suffix to get base version
                if ($versionNode -match '^([0-9]+\.[0-9]+\.[0-9]+)') {
                    $fallbackVersion = $matches[1]
                    Write-Host "✓ Found version in $fileName`: $versionNode"
                    Write-Host "  Using base version: $fallbackVersion"
                    $versionFound = $true
                    break
                }
            }
        }
    }

    if (-not $versionFound) {
        Write-Host "⚠ Could not find version in any .csproj file, using default: $fallbackVersion"
    }

    # Create zero-padded 7-digit ci-build-number with 'b' prefix for SemVer compliance
    # (SemVer prohibits leading zeros in numeric identifiers, so we make it alphanumeric)
    $ciBuildNumber = "b" + $BuildNumber.PadLeft(7, '0')
    $buildVersion = "$fallbackVersion-ci.$ciBuildNumber"
    Write-Host "Using fallback version: $buildVersion"
    echo "version=$buildVersion" >> $env:GITHUB_OUTPUT
    echo "base_version=$fallbackVersion" >> $env:GITHUB_OUTPUT
}
