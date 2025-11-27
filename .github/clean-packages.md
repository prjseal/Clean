# Package Architecture

The Clean Starter Kit consists of four NuGet packages, each serving a specific purpose in the architecture.

---

## Package Overview

### 1. Clean (Main Package)

The complete starter kit including views, assets, and Umbraco package content.

- **Package ID**: `Clean`
- **Dependencies**: Clean.Core, Clean.Headless
- **Use Case**: Install this package to add the full Clean starter kit to your existing Umbraco project

**⚠️ Important Post-Installation Step**: After installing the `Clean` package and running your project for the first time (once all content, settings, and assets have been created in your Umbraco installation), you should update your package reference from `Clean` to `Clean.Core`. This prevents the Razor views and other assets from being overridden during future updates.

To make this change:

```powershell
# Remove the Clean package
dotnet remove package Clean

# Add Clean.Core instead
dotnet add package Clean.Core
```

Or manually edit your `.csproj` file to change:

```xml
<PackageReference Include="Clean" Version="x.x.x" />
```

to:

```xml
<PackageReference Include="Clean.Core" Version="x.x.x" />
```

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

---

## Package Dependencies

```
Clean (Main Package)
├── Clean.Core
│   └── Umbraco.Cms.Web.Website
└── Clean.Headless
    ├── Umbraco.Cms.Web.Website
    └── Umbraco.Cms.Api.Common
```

---

## When to Use Each Package

| Package | When to Use |
|---------|-------------|
| **Clean** | Initial installation - provides all views, assets, and content |
| **Clean.Core** | After initial setup - provides core functionality without overwriting your customizations |
| **Clean.Headless** | Automatically included - provides API and headless functionality |
| **Umbraco.Community.Templates.Clean** | Starting a new project from scratch using dotnet CLI |

---

## Migration Path

The recommended workflow is:

1. **Initial Setup**: Install `Clean` package to get all assets and content
2. **First Run**: Run the project, publish content, save dictionary items
3. **Switch Packages**: Change from `Clean` to `Clean.Core` to protect your customizations
4. **Future Updates**: Continue using `Clean.Core` for updates without losing customizations

---

## Related Documentation

- [README](../README.md) - Installation instructions and quick start guide
- [Headless/API Implementation](clean-headless-api.md) - Information about Clean.Headless package features
- [Clean Documentation](clean-documentation.md) - Comprehensive documentation index
- [Contributing Guide](general-contributing.md) - Guidelines for contributing to the packages
- [Consuming GitHub Packages](general-consuming-packages.md) - Using development versions of packages
- [PR Workflow](workflow-pr.md) - How packages are built and tested in CI/CD
