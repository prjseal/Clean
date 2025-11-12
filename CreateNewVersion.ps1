param (
    [string]$Version,
    [string]$Destination
)

if (-not $Version) {
    Write-Host "Error: Version parameter is required." -ForegroundColor Red
    exit 1
}

if (-not $Destination) {
    Write-Host "Error: Destination parameter is required." -ForegroundColor Red
    exit 1
}

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
        Copy-Item $pkg.FullName -Destination $Destination -Force
    }
    Write-Host "`nCopied all matching packages to: $Destination"
} else {
    Write-Host "`nNo matching NuGet packages found in Release folders."
}

# Generate and execute script from external API if Umbraco version was found
if ($umbracoVersion) {
    $payload = @{
        TemplateName = "Umbraco.Templates"
        TemplateVersion = $umbracoVersion
        Packages = "clean|$Version"
        SolutionName = "MySolution"
        ProjectName = "MyProject"
        UserFriendlyName = "Administrator"
        UserEmail = "admin@example.com"
        UserPassword = "1234567890"
        IncludeStarterKit = $false
        UseUnattendedInstall = $true
        DatabaseType = "SQLite"
    } | ConvertTo-Json -Depth 3

    Write-Host "`nCalling ScriptGenerator API with payload:"
    Write-Host $payload

    $response = Invoke-RestMethod -Uri "https://psw.codeshare.co.uk/api/ScriptGeneratorApi/generatescript" -Method Post -Body $payload -ContentType "application/json"

    Write-Host "`nExecuting Script Commands from API:"
    $response -split "`r?`n" | ForEach-Object {
        Write-Host "Running: $_"
        Invoke-Expression $_
    }
} else {
    Write-Host "`nUmbraco version not found in Clean.csproj. Skipping script generation API call."
}