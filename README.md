# Clean Starter Kit for Umbraco

[![NuGet Version](https://img.shields.io/nuget/v/Clean?label=NuGet%20Version)](https://www.nuget.org/packages/Clean)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Clean?label=NuGet%20Downloads)](https://www.nuget.org/packages/Clean)
[![Release Build](https://img.shields.io/github/actions/workflow/status/prjseal/Clean/release-nuget.yml?label=Release%20Build)](https://github.com/prjseal/Clean/actions)
[![License](https://img.shields.io/github/license/prjseal/Clean?label=License)](https://github.com/prjseal/Clean/blob/main/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/prjseal/Clean?label=Stars)](https://github.com/prjseal/Clean/stargazers)

A modern, clean, and fully-featured starter kit for Umbraco CMS that provides a ready-to-use blog theme with headless/API capabilities. Built with Bootstrap and designed to get you up and running quickly with Umbraco 17.

## Features

- **Modern Blog Theme**: Clean, responsive design built with Bootstrap
- **Pre-configured Content Types**: Blog posts, categories, tags, and more
- **Headless/API Support**: Full Content Delivery API integration with Next.js revalidation support
- **API Endpoints**: Built-in endpoints for dictionary, search, and contact functionality
- **OpenAPI Documentation**: Swagger UI for exploring and testing API endpoints
- **SQLite by Default**: Quick setup with SQLite database for development

Clean targets **Umbraco 17 (LTS)**. For complete version mapping for previous versions, see the [Versioning and Releases](.github/workflow-versioning-releases.md#version-mapping) documentation.

For detailed information about the package architecture and the different NuGet packages, see the [Package Architecture](.github/clean-packages.md) documentation.

## Documentation

For detailed documentation about this package and the repository, please see the [docs](.github/clean-documentation.md).

### GitHub Workflows and Automation

The project uses automated workflows for continuous integration and deployment. Please see the workflow [worflow docs](.github/clean-documentation.md#workflow-documentation)

## Installation

### Prerequisites

Download and install the latest [.NET 10 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/10.0) or higher for your operating system (Windows, Mac, or Linux).

---

## Umbraco 17 (LTS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::17.0.0 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 7.0.1

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

**⚠️ Important**: After your site is set up and running, switch from the `Clean` package to `Clean.Core` to prevent views and assets from being overridden:

```powershell
dotnet remove "MyProject" package Clean
dotnet add "MyProject" package Clean.Core --version 7.0.1
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::7.0.1 --force

# Create a new project using the template
dotnet new umbraco-starter-clean -n MyProject

# Navigate to the project folder
cd MyProject

# Run the new website
dotnet run --project "MyProject.Blog"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front 
``` 

> **✨ Note**: As of version 7.0.0, the template now supports periods in project names (e.g., `Company.Website`). Previous versions had a limitation that prevented using periods due to internal class naming conflicts, which has been resolved.

## Umbraco 13 (LTS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::17.0.0-rc4 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 7.0.0-rc4

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

**⚠️ Important**: After your site is set up and running, switch from the `Clean` package to `Clean.Core` to prevent views and assets from being overridden:

```powershell
dotnet remove "MyProject" package Clean
dotnet add "MyProject" package Clean.Core --version 7.0.0-rc4
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::7.0.0-rc4 --force

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
