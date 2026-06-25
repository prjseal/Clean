# Clean Starter Kit for Umbraco

[![NuGet Version](https://img.shields.io/nuget/v/Clean?label=NuGet%20Version)](https://www.nuget.org/packages/Clean)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Clean?label=NuGet%20Downloads)](https://www.nuget.org/packages/Clean)
[![Release Build](https://img.shields.io/github/actions/workflow/status/prjseal/Clean/release-nuget.yml?label=Release%20Build)](https://github.com/prjseal/Clean/actions)
[![License](https://img.shields.io/github/license/prjseal/Clean?label=License)](https://github.com/prjseal/Clean/blob/main/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/prjseal/Clean?label=Stars)](https://github.com/prjseal/Clean/stargazers)

A modern, clean, and fully-featured starter kit for Umbraco CMS that provides a ready-to-use blog theme with headless/API capabilities. Built with Bootstrap and designed to get you up and running quickly with Umbraco 18.

Clean targets **Umbraco 18 (STS)**. For complete version mapping for previous versions, see the [Versioning and Releases](https://github.com/prjseal/Clean/blob/main/.github/workflow-versioning-releases.md#version-mapping) documentation.

For detailed information about the package architecture and the different NuGet packages, see the [Package Architecture](https://github.com/prjseal/Clean/blob/main/.github/clean-packages.md) documentation.

## Documentation

For detailed documentation about this package and the repository, please see the [docs](https://github.com/prjseal/Clean/blob/main/.github/clean-documentation.md).

### GitHub Workflows and Automation

The project uses automated workflows for continuous integration and deployment. Please see the [workflow docs](https://github.com/prjseal/Clean/blob/main/.github/clean-documentation.md#workflow-documentation).

## Installation

### Prerequisites

Download and install the latest [.NET 10 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/10.0) or higher for your operating system (Windows, Mac, or Linux).

---

## Umbraco 18 (STS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::18.0.0 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 8.0.0

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

**⚠️ Important**: After your site is set up and running, switch from the `Clean` package to `Clean.Core` to prevent views and assets from being overridden:

```powershell
dotnet remove "MyProject" package Clean
dotnet add "MyProject" package Clean.Core --version 8.0.0
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::8.0.0 --force

# Create a new project using the template
dotnet new umbraco-starter-clean -n MyProject

# Navigate to the project folder
cd MyProject

# Run the new website
dotnet run --project "MyProject.Blog"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

> **✨ Note**: As of version 8.0.0, the template now supports periods in project names (e.g., `Company.Website`).

## Umbraco 17 (LTS)

If you need to use Clean with Umbraco 17 (LTS), use the latest `7.x` release. The `dev/v7` branch on GitHub is where ongoing Umbraco 17 development takes place.

- **NuGet**: `dotnet add package Clean --version 7.0.7`
- **Branch**: [dev/v7](https://github.com/prjseal/Clean/tree/dev/v7)

## Umbraco 13 (LTS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::13.14.0 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 4.2.2

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

**⚠️ Important**: After your site is set up and running, switch from the `Clean` package to `Clean.Core` to prevent views and assets from being overridden:

```powershell
dotnet remove "MyProject" package Clean
dotnet add "MyProject" package Clean.Core --version 4.2.2
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::4.2.2 --force

# Create a new project using the template
dotnet new umbraco-starter-clean -n MyProject

# Navigate to the project folder
cd MyProject

# Run the new website
dotnet run --project "MyProject.Blog"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

---

## Getting Started

After installation, you'll need to:

1. **Login to Umbraco**: Navigate to `/umbraco` and login with the credentials you specified (default: admin@example.com / 1234567890)
2. **Publish the Home Page**: Go to the Content section and publish the home page
3. **Save Dictionary Items**: Navigate to the Translation section and save at least one dictionary item to initialize translations
4. **View Your Site**: The frontend should now be accessible at the root URL

---

## Support and Resources

- **GitHub Repository**: [https://github.com/prjseal/Clean](https://github.com/prjseal/Clean)
- **Issues and Bug Reports**: [GitHub Issues](https://github.com/prjseal/Clean/issues)
- **NuGet Package**: [https://www.nuget.org/packages/Clean](https://www.nuget.org/packages/Clean)
- **License**: MIT

---

## Authors

- **Paul Seal** - Main Package
- **Phil Whittaker** - Headless Extensions

---

## Legacy Versions

Looking for Clean for Umbraco V9-12? Visit the [Clean Starter Kit for Umbraco v9](https://github.com/prjseal/Clean-Starter-Kit-for-Umbraco-v9) repository.
