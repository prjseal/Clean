# Create NuGet Packages Script

## Overview

This comprehensive script creates NuGet packages by starting Umbraco, downloading the package via API, updating .csproj versions, and building all packages in dependency order.

## Script Location

`.github/workflows/powershell/CreateNuGetPackages.ps1`

## Purpose

Orchestrates the entire package creation process including running Umbraco, downloading content package, updating versions, and building all NuGet packages.

## When It's Used

- **Release Workflow**: Main package creation step after README updates

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Version` | string | Yes | The version number for the packages |

## What It Does

1. **Stops Running Processes** - Kills any Umbraco processes
2. **Configures NuGet Sources** - Detects all configured sources
3. **Restores Solution** - Explicitly restores with all sources
4. **Starts Umbraco** - Runs Clean.Blog project
5. **Waits for API** - Polls until Umbraco responds
6. **Downloads Package** - Gets package.zip via API
7. **Updates Versions** - Sets version in all .csproj files
8. **Builds Packages** - In dependency order: Core → Headless → Clean → Template

## Key Features

### Dependency Order Building

1. **Clean.Core** - Base package
2. **Clean.Headless** - Depends on Core
3. **Clean** - Depends on Core and Headless
4. **template-pack** - Template package

Uses local NuGet source to avoid NU1102 errors.

### Version Updates

Updates in .csproj files:
- `<Version>` or `<PackageVersion>`
- `<InformationalVersion>` (base version without suffix)
- `<AssemblyVersion>` (base version without suffix)
- `<PackageReference>` for Clean.* packages

## Output

Packages created in `.artifacts/nuget/`:
- Clean.Core.{version}.nupkg
- Clean.Headless.{version}.nupkg
- Clean.{version}.nupkg
- Umbraco.Community.Templates.Clean.{version}.nupkg

## Troubleshooting

### Issue: Umbraco Fails to Start

**Solution**: Check logs, increase timeout, verify configuration

### Issue: API Authentication Fails

**Solution**: Verify client ID/secret in appsettings

### Issue: Build Fails with NU1102

**Solution**: Ensure dependency order is correct, local source is configured

## Related Documentation

- [workflow-versioning-releases.md](workflow-versioning-releases.md) - Parent workflow

## Notes

- **Most complex script** in the workflow
- **Builds in dependency order** to avoid package resolution errors
- **Uses local NuGet source** for intermediate packages
- **Supports both PowerShell 5.x and Core 6+**
