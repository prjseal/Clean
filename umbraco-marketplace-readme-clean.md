# Clean Starter Kit for Umbraco

A modern, clean, and fully-featured starter kit for Umbraco CMS that gets you up and running quickly with a production-ready blog theme.

## Why Choose Clean?

Clean Starter Kit provides everything you need to launch a professional blog or content-driven website with Umbraco. Whether you're building a traditional web application or a headless CMS solution, Clean has you covered.

### ✨ Key Features

#### Modern Blog Theme

- **Responsive Design** - Built with Bootstrap for seamless experience across all devices
- **Clean, Professional Look** - Ready-to-use theme that looks great out of the box
- **Customizable** - Easy to modify and extend to match your brand

#### Pre-configured Content Structure

- **Blog Posts** - Complete blog post document type with all necessary fields
- **Categories & Tags** - Organize your content effectively
- **Media Management** - Pre-configured media types for images and videos
- **SEO-Ready** - Built-in meta fields for search engine optimization

#### Headless/API Capabilities

- **Content Delivery API** - Full integration with Umbraco's Content Delivery API
- **Next.js Revalidation** - Built-in support for Next.js on-demand revalidation
- **Custom API Endpoints** - Dictionary, search, and contact form APIs included
- **OpenAPI/Swagger** - Interactive API documentation at `/umbraco/swagger`

#### Developer Experience

- **Quick Setup** - SQLite by default for instant development environment
- **No External Dependencies** - Self-contained with no third-party package requirements
- **dotnet Template** - Install with `dotnet new umbraco-starter-clean`
- **Multi-version Support** - Works with Umbraco 13 (.NET 8) and Umbraco 17 (.NET 10)

## Package Structure

Clean Starter Kit consists of four complementary packages:

### 🎨 Clean (Main Package)

The complete starter kit including views, assets, and Umbraco package content. Install this to add the full Clean starter kit to your project.

**⚠️ Important:** After initial setup, switch to `Clean.Core` to prevent views and assets from being overridden during updates.

### ⚙️ Clean.Core

Core library with components, controllers, helpers, and tag helpers. This is what you should use after your initial site setup.

### 🚀 Clean.Headless

API controllers and headless CMS functionality. Enables full Content Delivery API integration and Next.js revalidation support.

### 📦 Umbraco.Community.Templates.Clean

dotnet CLI template for creating new projects. Use `dotnet new umbraco-starter-clean` to scaffold a complete Umbraco project with Clean pre-installed.

## Umbraco 17 (LTS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::17.0.2 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

# Add Clean package
dotnet add "MyProject" package Clean --version 7.0.3

# Run the project
dotnet run --project "MyProject"

# Login with admin@example.com and 1234567890
# Save and publish the home page and save one of the dictionary items in the translation section
# The site should now be running and visible on the front end
```

**⚠️ Important**: After your site is set up and running, switch from the `Clean` package to `Clean.Core` to prevent views and assets from being overridden:

```powershell
dotnet remove "MyProject" package Clean
dotnet add "MyProject" package Clean.Core --version 7.0.3
```

### dotnet Template Method

```powershell
# Install the Clean Starter Kit template
dotnet new install Umbraco.Community.Templates.Clean::7.0.3 --force

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

## Umbraco 13 (LTS)

### NuGet Package Method

```powershell
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::13.12.0 --force

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

> **✨ Note**: As of version 7.0.0-rc4, the template now supports periods in project names (e.g., `Company.Website`). Previous versions had a limitation that prevented using periods due to internal class naming conflicts, which has been resolved.

### Post-Installation

1. Login to Umbraco at `/umbraco` with your credentials
2. Publish the home page
3. Save a dictionary item in the Translation section
4. View your site - it's ready to go!

**Remember:** After setup, switch from `Clean` to `Clean.Core` package reference to prevent view overrides.

## Headless Implementation

Clean includes full headless CMS support. Enable the Content Delivery API in your `appsettings.json`:

```json
{
  "Umbraco": {
    "DeliveryApi": {
      "Enabled": true
    }
  }
}
```

For Next.js integration with automatic revalidation:

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

### Headless Frontend Example

Check out the complete Next.js frontend example by Phil Whittaker:
[Clean Starter Kit Headless Frontend](https://github.com/hifi-phil/clean-headless)

## API Documentation

Explore the built-in API endpoints using Swagger UI:

**URL:** `/umbraco/swagger/index.html?urls.primaryName=Clean%20starter%20kit`

Available APIs:

- **Dictionary API** - Access translation/dictionary items
- **Search API** - Full-text content search
- **Contact API** - Handle contact form submissions

## Version Compatibility

| Clean Version | Umbraco Version | .NET Version | Support Type |
| ------------- | --------------- | ------------ | ------------ |
| 4.x           | 13              | .NET 8       | LTS          |
| 7.x           | 17              | .NET 10      | LTS          |

## Getting Help

- **Documentation:** [GitHub Repository](https://github.com/prjseal/Clean)
- **Issues:** [GitHub Issues](https://github.com/prjseal/Clean/issues)
- **Video Tutorial:** [YouTube Guide](https://www.youtube.com/watch?v=tzcSNHg77fo)

## Contributing

Contributions are welcome! This is an open-source project under the MIT license. Check out the [Contributing Guide](https://github.com/prjseal/Clean/blob/main/.github/general-contributing.md) to get started.

## About the Author

Created by **Paul Seal**, Umbraco Master and 8x Umbraco MVP, with contributions from **Phil Whittaker** on the headless extensions.

---

**Ready to get started?** Install Clean Starter Kit today and launch your Umbraco blog in minutes!
