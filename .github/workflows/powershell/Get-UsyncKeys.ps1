<#
.SYNOPSIS
    Extracts content keys from uSync configuration files.

.DESCRIPTION
    This script reads uSync configuration files from the v17 directory structure
    and extracts the Key (GUID) values for published content items.

.PARAMETER WorkspacePath
    The root workspace path containing the template directory

.PARAMETER UsyncFileType
    The type of uSync files to process (e.g., "Content", "DataType", "MediaType")

.PARAMETER PublishedOnly
    If specified, only returns keys for items that are published (only applies to Content type)

.EXAMPLE
    .\Get-UsyncKeys.ps1 -WorkspacePath "C:\workspace" -UsyncFileType "Content" -PublishedOnly

.EXAMPLE
    .\Get-UsyncKeys.ps1 -WorkspacePath "C:\workspace" -UsyncFileType "DataType"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath,

    [Parameter(Mandatory = $true)]
    [string]$UsyncFileType,

    [Parameter(Mandatory = $false)]
    [switch]$PublishedOnly
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Extracting uSync Keys" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Workspace Path: $WorkspacePath" -ForegroundColor Yellow
Write-Host "uSync File Type: $UsyncFileType" -ForegroundColor Yellow
Write-Host "Published Only: $PublishedOnly" -ForegroundColor Yellow

# Construct path to uSync directory
$usyncPath = Join-Path $WorkspacePath "template\Clean.Blog\uSync\v17\$UsyncFileType"

if (-not (Test-Path $usyncPath)) {
    Write-Host "ERROR: uSync directory not found at: $usyncPath" -ForegroundColor Red
    exit 1
}

Write-Host "`nSearching for .config files in: $usyncPath" -ForegroundColor Yellow

# Get all .config files
$configFiles = Get-ChildItem -Path $usyncPath -Filter "*.config" -File

if ($configFiles.Count -eq 0) {
    Write-Host "WARNING: No .config files found in $usyncPath" -ForegroundColor Yellow
    return @()
}

Write-Host "Found $($configFiles.Count) config file(s)" -ForegroundColor Green

$keys = @()

foreach ($file in $configFiles) {
    try {
        Write-Host "`nProcessing: $($file.Name)" -ForegroundColor Cyan

        # Load XML content
        [xml]$xmlContent = Get-Content $file.FullName -Raw

        # Extract the Key attribute from the root element
        $rootElement = $xmlContent.DocumentElement
        $key = $rootElement.GetAttribute("Key")

        if ([string]::IsNullOrWhiteSpace($key)) {
            Write-Host "  WARNING: No Key attribute found in $($file.Name)" -ForegroundColor Yellow
            continue
        }

        # If PublishedOnly is specified and this is Content type, check Published status
        if ($PublishedOnly -and $UsyncFileType -eq "Content") {
            $publishedNode = $xmlContent.SelectSingleNode("//Published[@Default='true']")

            if ($null -eq $publishedNode) {
                Write-Host "  Skipping (not published): $key" -ForegroundColor Gray
                continue
            }
        }

        # Extract alias for logging
        $alias = $rootElement.GetAttribute("Alias")

        Write-Host "  Key: $key" -ForegroundColor Green
        Write-Host "  Alias: $alias" -ForegroundColor Green

        $keys += $key

    } catch {
        Write-Host "  ERROR processing $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Extraction Complete" -ForegroundColor Cyan
Write-Host "Total Keys Extracted: $($keys.Count)" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

if ($keys.Count -gt 0) {
    Write-Host "`nExtracted Keys:" -ForegroundColor Yellow
    $keys | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
}

# Return the keys array
return $keys
