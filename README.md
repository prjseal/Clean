# Clean Starter Kit for Umbraco 13 and 15

## version 4.1.0 is for Umbraco 13 (Long Term Support)

## version 5.0.0 is for Umbraco 15 (Standard Term Support)

If you want the older versions you need to go to the ones lower than version 4.0.0

Latest Release Details:
- Now works on Umbraco 15 with dotnet 9
- You can now use the dotnet new template to install Clean Starter Kit with the Source Code rather than as a package

To try it out on Windows, Mac or Linux, make sure you have [downloaded the latest .Net 9 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/9.0) and then run this block of commands in a folder somewhere.

## Install it using the dotnet template

```ps
# Ensure we have the latest Clean Starter Kit Template installed
dotnet new install Umbraco.Community.Templates.Clean --force

dotnet new umbraco-starter-clean -n MyProject
```

## Install it as a Package

### Install on Umbraco 15

```ps
# Ensure we have the latest Umbraco templates
dotnet new install Umbraco.Templates::15.0.0 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

#Add starter kit
dotnet add "MyProject" package Clean --version 5.0.0

#Add Packages
#Ignored Clean as it was added as a starter kit

dotnet run --project "MyProject"
```

### Install on Umbraco 13

```ps
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::13.5.2 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject" --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"

#Add starter kit
dotnet add "MyProject" package clean -version 4.1.0

dotnet run --project "MyProject"
#Running
```


| :zap:        If you're looking for Clean for Umbraco V9-12, see [Clean Starter Kit](https://github.com/prjseal/Clean-Starter-Kit-for-Umbraco-v9)!   |
|-----------------------------------------|
