# Clean Starter Kit for Umbraco

A modern, clean, and fully-featured starter kit for Umbraco CMS that provides a ready-to-use blog theme with headless/API capabilities. Built with Bootstrap and designed to get you up and running quickly with Umbraco 13, 15, 16, and 17.

## Features

- **Modern Blog Theme**: Clean, responsive design built with Bootstrap
- **Pre-configured Content Types**: Blog posts, categories, tags, and more
- **Headless/API Support**: Full Content Delivery API integration with Next.js revalidation support
- **API Endpoints**: Built-in endpoints for dictionary, search, and contact functionality
- **OpenAPI Documentation**: Swagger UI for exploring and testing API endpoints
- **Multi-version Support**: Compatible with Umbraco 13-17 and .NET 8-10
- **SQLite by Default**: Quick setup with SQLite database for development
- **No External Dependencies**: Removed dependency on third-party packages like Contentment

## Packages

This starter kit consists of four NuGet packages:

### 1. Clean (Main Package)
The complete starter kit including views, assets, and Umbraco package content.
- **Package ID**: `Clean`
- **Dependencies**: Clean.Core, Clean.Headless
- **Use Case**: Install this package to add the full Clean starter kit to your existing Umbraco project

### 2. Clean.Core
Core library containing components, controllers, helpers, and tag helpers.
- **Package ID**: `Clean.Core`
- **Dependencies**: Umbraco.Cms.Web.Website
- **Use Case**: Automatically installed as a dependency of the Clean package

### 3. Clean.Headless
Headless CMS functionality with API controllers and Next.js revalidation support.
- **Package ID**: `Clean.Headless`
- **Dependencies**: Umbraco.Cms.Web.Website, Umbraco.Cms.Api.Common
- **Use Case**: Automatically installed as a dependency of the Clean package

### 4. Umbraco.Community.Templates.Clean
dotnet CLI template for creating new Umbraco projects with Clean pre-installed.
- **Package ID**: `Umbraco.Community.Templates.Clean`
- **Use Case**: Use with `dotnet new` to scaffold a complete Umbraco project with Clean

## Version Mapping

| Clean Version | Umbraco Version | .NET Version | Support Type |
|--------------|-----------------|--------------|--------------|
| 4.x          | 13              | .NET 8       | LTS (Long Term Support) |
| 5.x          | 15              | .NET 9       | STS (Standard Term Support) |
| 6.x          | 16              | .NET 9       | STS (Standard Term Support) |
| 7.x          | 17              | .NET 10      | LTS (Long Term Support) |

**Note**: For older Umbraco versions (9-12), see the [Clean Starter Kit for Umbraco v9](https://github.com/prjseal/Clean-Starter-Kit-for-Umbraco-v9) repository.

## Latest Release Details (v4.0.0+)

- Specifically designed for .NET 8+ and Umbraco 13+
- Removed dependency on Contentment package
- Enhanced API capabilities with OpenAPI documentation
- Improved headless support with Next.js integration

## Installation

### Prerequisites

Download and install the latest [.NET 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) or higher for your operating system (Windows, Mac, or Linux).

---

## Umbraco 13 (LTS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::13.8.1 --force

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

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::4.2.0 --force

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

## Umbraco 15 (STS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::15.4.1 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 5.2.2

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::5.2.0 --force

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

## Umbraco 16 (STS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::16.0.0-rc4 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 6.0.0-rc3

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::6.0.0-rc3 --force

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

## Umbraco 17 (LTS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::17.0.0-rc1 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 7.0.0-rc1

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::7.0.0-rc1 --force

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

## Headless/API Implementation

### Delivery API Setup

The Clean starter kit includes full support for headless implementations. To enable the Content Delivery API, update your `appsettings.json`:

```json
{
  "Umbraco": {
    "DeliveryApi": {
      "Enabled": true
    }
  }
}
```

### Next.js Revalidation

To enable automatic revalidation of content in Next.js applications, configure the following in your `appsettings.json`:

```json
{
  "NextJs": {
    "Revalidate": {
      "Enabled": true,
      "WebHookUrls": "[\"http://localhost:3000/api/revalidate\"]",
      "WebHookSecret": "SOMETHING_SECRET"
    }
  }
}
```

**Note**: Update the `WebHookUrls` to match your Next.js application's URL.

### Headless Frontend Example

Phil Whittaker has created a complete headless Next.js frontend for this starter kit:

**[Clean Starter Kit Headless Frontend](https://github.com/hifi-phil/clean-headless)**

This implementation demonstrates how to use the Clean starter kit as a headless CMS with a modern Next.js frontend.

---

## API Endpoints

The Clean starter kit provides a suite of custom API endpoints for common functionality:

- **Dictionary API**: Access dictionary/translation items programmatically
- **Search API**: Perform content searches via REST API
- **Contact API**: Handle contact form submissions

### OpenAPI/Swagger Documentation

Explore and test the API endpoints using the built-in Swagger UI:

**URL**: `/umbraco/swagger/index.html?urls.primaryName=Clean%20starter%20kit`

This provides interactive documentation for all available API endpoints, including request/response schemas and the ability to test endpoints directly from the browser.

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

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests on GitHub.

---

## Authors

- **Paul Seal** - Main Package
- **Phil Whittaker** - Headless Extensions

---

## Legacy Versions

Looking for Clean for Umbraco V9-12? Visit the [Clean Starter Kit for Umbraco v9](https://github.com/prjseal/Clean-Starter-Kit-for-Umbraco-v9) repository.
