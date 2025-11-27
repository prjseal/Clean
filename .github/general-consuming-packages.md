# Consuming Clean Packages from GitHub Packages

This repository publishes preview/development NuGet packages to GitHub Packages on every PR build. This allows you to test and use preview versions before they're released to NuGet.org.

## Prerequisites

You need a GitHub Personal Access Token (PAT) with the `read:packages` scope to consume packages from GitHub Packages.

### Creating a GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name (e.g., "NuGet Package Access")
4. Select the `read:packages` scope
5. Click "Generate token"
6. Copy the token - you won't be able to see it again!

## Configuring Your Project

### Option 1: Using nuget.config (Recommended)

Create or update a `nuget.config` file in your solution root:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="GitHubPackages" value="https://nuget.pkg.github.com/prjseal/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <GitHubPackages>
      <add key="Username" value="YOUR_GITHUB_USERNAME" />
      <add key="ClearTextPassword" value="YOUR_GITHUB_PAT" />
    </GitHubPackages>
  </packageSourceCredentials>
</configuration>
```

**Important:** Don't commit your PAT to source control! Use environment variables or a local nuget.config that's gitignored.

### Option 2: Using Environment Variables (More Secure)

Create a `nuget.config` with a placeholder:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="GitHubPackages" value="https://nuget.pkg.github.com/prjseal/index.json" />
  </packageSources>
</configuration>
```

Then add the source with credentials via command line:

```bash
dotnet nuget add source https://nuget.pkg.github.com/prjseal/index.json \
  --name GitHubPackages \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_PAT \
  --store-password-in-clear-text
```

### Option 3: Using dotnet CLI

Add the source and install packages directly:

```bash
# Add the GitHub Packages source
dotnet nuget add source https://nuget.pkg.github.com/prjseal/index.json \
  --name GitHubPackages \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_PAT

# Install a preview package
dotnet add package Clean --version 1.0.0.123 --source GitHubPackages
```

## Finding Package Versions

Preview packages are published with version numbers in the format: `{base_version}.{build_number}`

For example:
- `1.0.0.45` - Build #45 from a PR
- `1.0.0.46` - Build #46 from a PR

You can find available versions at:
https://github.com/prjseal/Clean/packages

## Using in Your Project

Once configured, you can reference packages as normal:

```xml
<ItemGroup>
  <PackageReference Include="Clean" Version="1.0.0.123" />
  <PackageReference Include="Clean.Core" Version="1.0.0.123" />
  <PackageReference Include="Clean.Headless" Version="1.0.0.123" />
</ItemGroup>
```

## CI/CD Considerations

### GitHub Actions

In GitHub Actions, you can use the built-in `GITHUB_TOKEN`:

```yaml
- name: Restore packages
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    dotnet nuget add source https://nuget.pkg.github.com/prjseal/index.json \
      --name GitHubPackages \
      --username ${{ github.repository_owner }} \
      --password $GITHUB_TOKEN \
      --store-password-in-clear-text
    dotnet restore
```

### Other CI Systems

For other CI systems (Azure DevOps, TeamCity, etc.), store your GitHub PAT as a secret/variable and use it in the build configuration.

## Troubleshooting

### 401 Unauthorized Error

This usually means:
1. Your PAT is invalid or expired
2. Your PAT doesn't have the `read:packages` scope
3. The package source isn't properly configured

### Package Not Found

1. Check that the package was successfully published in the PR workflow logs
2. Verify you're using the correct package name and version
3. Ensure your credentials are correctly configured

### TLS/SSL Errors

On some systems, you may need to specify the protocol version:

```xml
<add key="GitHubPackages" value="https://nuget.pkg.github.com/prjseal/index.json" protocolVersion="3" />
```

## Security Best Practices

1. **Never commit PATs to source control**
2. Use environment variables or CI/CD secrets for PATs
3. Create read-only PATs with minimal scopes (`read:packages` only)
4. Rotate PATs regularly
5. Use different PATs for different purposes (development vs. CI/CD)
6. Add `nuget.config` to `.gitignore` if it contains credentials

## Public Packages

GitHub Packages are public for public repositories, but authentication is still required to consume them. This is a GitHub limitation, not specific to this package.

## Related Documentation

- [PR Workflow](workflow-pr.md) - Explains when and how development packages are published
- [Contributing Guide](general-contributing.md) - Guidelines for contributing to the project
- [Package Architecture](clean-packages.md) - Understanding the different NuGet packages
- [Clean Documentation](clean-documentation.md) - Comprehensive documentation index

## Questions or Issues?

If you encounter problems consuming packages from GitHub Packages, please open an issue at:
https://github.com/prjseal/Clean/issues
