# Contributing to Clean Starter Kit for Umbraco

First off, thank you for considering contributing to the Clean Starter Kit! It's people like you that make this project a great tool for the Umbraco community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Important: Understanding uSync](#important-understanding-usync)
- [Development Workflow](#development-workflow)
- [Database Changes and uSync](#database-changes-and-usync)
- [Making Changes](#making-changes)
- [Testing Your Changes](#testing-your-changes)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Project Structure](#project-structure)
- [Version Support](#version-support)
- [Resources](#resources)

## Code of Conduct

This project adheres to a code of professionalism and respect. By participating, you are expected to uphold this standard. Please be respectful, constructive, and collaborative in all interactions.

## Getting Started

### Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) or higher (depending on which version you're working with)
- [Git](https://git-scm.com/)
- A code editor ([Visual Studio](https://visualstudio.microsoft.com/), [VS Code](https://code.visualstudio.com/), or [Rider](https://www.jetbrains.com/rider/))
- Basic understanding of [Umbraco CMS](https://umbraco.com/)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/Clean.git
   cd Clean
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/prjseal/Clean.git
   ```
4. Create a new branch for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Building the Project

```bash
# Restore dependencies
dotnet restore

# Build the solution
dotnet build

# Run the Clean.Blog project for testing
dotnet run --project template/Clean.Blog
```

## Important: Understanding uSync

### What is uSync?

The Clean Starter Kit uses [uSync](https://jumoo.co.uk/usync/) to serialize Umbraco configuration and content into source-controlled files. This is **critical** for maintaining consistency across installations and development environments.

### uSync First Boot

**All coherent configuration and settings are applied on startup via uSync first boot.** When you first run the Clean Starter Kit, uSync automatically:

- Creates all Document Types, Media Types, and Member Types
- Sets up Data Types and their configurations
- Imports Dictionary items for translations
- Configures Languages
- Creates initial content structure
- Applies Templates and other site structure

This means:
- ✅ The database is automatically configured on first run
- ✅ All developers get the same starting point
- ✅ Schema changes are version controlled
- ⚠️ **Any database changes MUST be exported to uSync config files**

### uSync Directory Structure

The uSync configuration files are located in:
```
template/Clean.Blog/uSync/
├── v16/                    # Umbraco 16 configuration
├── v17/                    # Umbraco 17 configuration
│   ├── Content/           # Content nodes
│   ├── ContentTypes/      # Document Types
│   ├── DataTypes/         # Data Type definitions
│   ├── Dictionary/        # Dictionary items for translations
│   ├── Languages/         # Language configurations
│   ├── Media/             # Media items
│   ├── MediaTypes/        # Media Type definitions
│   ├── MemberTypes/       # Member Type definitions
│   ├── RelationTypes/     # Relation Type definitions
│   ├── Templates/         # Razor templates
│   └── usync.config       # uSync version metadata
└── v17-backup/            # Backup configuration
```

## Database Changes and uSync

### ⚠️ CRITICAL: Exporting Changes to uSync

**If you make ANY changes to the Umbraco schema or content structure, you MUST export them to uSync config files.**

This includes:
- Creating or modifying Document Types
- Creating or modifying Media Types
- Creating or modifying Member Types
- Creating or modifying Data Types
- Adding or changing Templates
- Adding or changing Dictionary items
- Modifying Languages
- Creating initial Content or Media (if it should be part of the starter kit)
- Changing Relation Types

### How to Export Changes

1. **Make your changes in the Umbraco backoffice** (usually at `/umbraco`)

2. **Export via uSync Dashboard:**
   - Navigate to the uSync section in the Umbraco backoffice
   - Click "Export" to serialize your changes to disk
   - The changes will be written to the appropriate uSync folder

3. **Verify the exported files:**
   ```bash
   git status
   ```
   You should see new or modified `.config` files in the `template/Clean.Blog/uSync/` directory

4. **Review the changes:**
   ```bash
   git diff template/Clean.Blog/uSync/
   ```
   Ensure the changes match what you intended

5. **Commit the uSync files:**
   ```bash
   git add template/Clean.Blog/uSync/
   git commit -m "Add/Update: [description of schema changes]"
   ```

### Testing uSync Changes

After exporting your changes, test that they import correctly:

1. **Delete your test database** (or use a fresh Umbraco installation)
2. **Run the project again:**
   ```bash
   dotnet run --project template/Clean.Blog
   ```
3. **Verify that uSync imports your changes** on first boot
4. **Check the Umbraco backoffice** to ensure everything is configured correctly

## Development Workflow

### 1. Keep Your Fork Up to Date

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

### 2. Create a Feature Branch

```bash
git checkout -b feature/descriptive-name
```

Use prefixes like:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Adding or updating tests

### 3. Make Your Changes

- Write clean, readable code
- Follow existing code style and patterns
- Add comments for complex logic
- Update documentation as needed

### 4. Test Thoroughly

- Test your changes locally
- Ensure the project builds without errors
- Test across different Umbraco versions if applicable
- Verify uSync imports work correctly on a fresh installation

### 5. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "Add: Brief description of what you added"
```

Good commit message examples:
- `Add: Support for custom property editors in blog posts`
- `Fix: Incorrect rendering of tags on category pages`
- `Update: Headless API to include author information`
- `Refactor: Simplify blog post controller logic`

### 6. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

## Making Changes

### Code Changes

When modifying C# code:

1. **Maintain compatibility** with the supported Umbraco and .NET versions
2. **Follow existing patterns** used in the codebase
3. **Use nullable reference types** appropriately (`string?`, `int?`, etc.)
4. **Add XML documentation** for public APIs
5. **Handle errors gracefully** with appropriate logging

### View Changes

When modifying Razor views:

1. **Maintain the Bootstrap theme** consistency
2. **Ensure responsive design** works across devices
3. **Use existing helpers and tag helpers** where possible
4. **Test with and without the Content Delivery API** enabled

### API Changes

When modifying API controllers:

1. **Update OpenAPI documentation** (Swagger annotations)
2. **Maintain backward compatibility** when possible
3. **Follow RESTful conventions**
4. **Test endpoints** using the Swagger UI at `/umbraco/swagger/`

## Testing Your Changes

### Manual Testing

1. **Test with a fresh installation:**
   ```bash
   # Delete the Umbraco database file (if using SQLite)
   rm template/Clean.Blog/umbraco.db

   # Run the project
   dotnet run --project template/Clean.Blog
   ```

2. **Test the backoffice:**
   - Login with default credentials
   - Verify your changes work as expected
   - Check for console errors

3. **Test the frontend:**
   - View the site at `http://localhost:5000` (or your configured port)
   - Check responsive design
   - Verify all features work

4. **Test headless/API features:**
   - Enable the Content Delivery API in `appsettings.json`
   - Test API endpoints
   - Check Swagger documentation

### Testing Multiple Versions

If your changes affect multiple Umbraco versions:

1. Test against the appropriate version branches
2. Ensure uSync configs are compatible
3. Note any version-specific considerations in your pull request

## Submitting Changes

### Before Submitting a Pull Request

✅ Checklist:
- [ ] Code builds without errors or warnings
- [ ] Changes have been tested locally
- [ ] Database/schema changes are exported to uSync config files
- [ ] uSync import has been tested on a fresh installation
- [ ] Documentation has been updated (if applicable)
- [ ] Commit messages are clear and descriptive
- [ ] Code follows existing style and patterns

### Creating a Pull Request

1. **Push your changes** to your fork on GitHub

2. **Create a Pull Request** from your fork to the main repository

3. **Fill out the PR template** with:
   - Clear description of what you changed
   - Why you made the change
   - How to test the change
   - Screenshots (if UI changes)
   - Related issue numbers (if applicable)

4. **Address review feedback** promptly and professionally

### Pull Request Guidelines

- **Keep PRs focused** - One feature/fix per PR when possible
- **Write descriptive titles** - "Fix blog post rendering bug" not "Fix bug"
- **Explain your reasoning** - Help reviewers understand your approach
- **Be responsive** - Reply to review comments in a timely manner
- **Update your branch** - Rebase or merge from main if needed

## Coding Standards

### C# Style

- Use **PascalCase** for class names, method names, and properties
- Use **camelCase** for local variables and parameters
- Use **meaningful names** that describe the purpose
- **Keep methods focused** - one responsibility per method
- **Use async/await** for asynchronous operations
- **Enable nullable reference types** in new code

### Razor Views

- Use **Tag Helpers** over HTML helpers
- Keep **logic minimal** in views
- Use **partial views** for reusable components
- Follow the **existing naming conventions**

### JavaScript/TypeScript

- Follow **existing patterns** in the codebase
- Use **modern ES6+ syntax**
- **Avoid jQuery** in new code (unless Umbraco backoffice requires it)

## Project Structure

### Main Packages

The Clean Starter Kit consists of four NuGet packages:

1. **Clean** - Main package with views, assets, and content
2. **Clean.Core** - Core library with components and helpers
3. **Clean.Headless** - Headless CMS functionality and API controllers
4. **Umbraco.Community.Templates.Clean** - dotnet CLI template

### Directory Structure

```
Clean/
├── template/
│   ├── Clean.Blog/          # Main web project for testing
│   ├── Clean/               # Main package content
│   ├── Clean.Core/          # Core library
│   ├── Clean.Headless/      # Headless/API features
│   └── Clean.Models/        # Generated models
├── .github/                 # GitHub workflows and configs
├── LICENSE                  # MIT License
├── README.md               # Project documentation
└── CONTRIBUTING.md         # This file
```

## Version Support

The Clean Starter Kit supports multiple versions of Umbraco:

| Clean Version | Umbraco Version | .NET Version | Support Type |
|--------------|-----------------|--------------|--------------|
| 4.x          | 13              | .NET 8       | LTS          |
| 5.x          | 15              | .NET 9       | STS          |
| 6.x          | 16              | .NET 9       | STS          |
| 7.x          | 17              | .NET 10      | LTS          |

When contributing:
- **Target the appropriate version** for your changes
- **Consider backward compatibility** when possible
- **Test against the correct Umbraco version**
- **Note version-specific changes** in your PR description

## Resources

### Umbraco Documentation

- [Umbraco CMS Documentation](https://docs.umbraco.com/)
- [Umbraco Content Delivery API](https://docs.umbraco.com/umbraco-cms/reference/content-delivery-api)
- [uSync Documentation](https://docs.jumoo.co.uk/usync/)

### Project Links

- [GitHub Repository](https://github.com/prjseal/Clean)
- [NuGet Package](https://www.nuget.org/packages/Clean)
- [Issue Tracker](https://github.com/prjseal/Clean/issues)

### Getting Help

- **Open an issue** - For bugs or feature requests
- **Discussions** - For questions and general discussion
- **Umbraco Community** - [Our Umbraco Forums](https://our.umbraco.com/)

## License

By contributing to Clean Starter Kit, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

## Questions?

If you have questions about contributing, feel free to:
- Open an issue for discussion
- Reach out to the maintainers
- Ask in the Umbraco community forums

**Thank you for contributing to the Clean Starter Kit!** 🎉
