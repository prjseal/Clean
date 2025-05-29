# Clean Starter Kit for Umbraco 13, 15 and 16

## version 4.1.0 is for Umbraco 13 (Long Term Support)

## version 5.0.0 is for Umbraco 15 (Standard Term Support)

## version 6.0.0 is for Umbraco 16 (Standard Term Support)


If you want the older versions you need to go to the ones lower than version 4.0.0

Latest Release Details:
- Made it specifically for .NET 8 and above and Umbraco 13 and above
- Removed dependency on Contentment

To try it out on Windows, Mac or Linux, make sure you have [downloaded the latest .Net 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) and then run this block of commands in a folder somewhere.

## Umbraco 13
### NuGet Package

```ps
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::13.8.1 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject"  --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"


#Add Packages
dotnet add "MyProject" package Clean --version 4.2.2

dotnet run --project "MyProject"
#Running
```

## Umbraco 15
### NuGet Package

```ps
# Ensure we have the version specific Umbraco templates
dotnet new install Umbraco.Templates::15.4.1 --force

# Create solution/project
dotnet new sln --name "MySolution"
dotnet new umbraco --force -n "MyProject"  --friendly-name "Administrator" --email "admin@example.com" --password "1234567890" --development-database-type SQLite
dotnet sln add "MyProject"


#Add Packages
dotnet add "MyProject" package Clean --version 5.2.2

dotnet run --project "MyProject"
#Running
```

### dotnet template

```ps
#Install the template for Clean Starter Kit
dotnet new install Umbraco.Community.Templates.Clean::5.2.0 --force

#Create a new project using the umbraco-starter-clean template
dotnet new umbraco-starter-clean -n MyProject

#Go to the folder of the project that we created
cd MyProject

#Run the new website we created
dotnet run --project "MyProject.Blog"

# Login with admin@example.com and 1234567890. 
# Save and publish the home page and do a save on one of the dictionary items in the translation section. 
# The site should be running and visible on the front end now
```

## Umbraco 16
### dotnet template

```ps
#Install the template for Clean Starter Kit
dotnet new install Umbraco.Community.Templates.Clean::6.0.0-rc2 --force

#Create a new project using the umbraco-starter-clean template
dotnet new umbraco-starter-clean -n MyProject

#Go to the folder of the project that we created
cd MyProject

#Run the new website we created
dotnet run --project "MyProject.Blog"

# Login with admin@example.com and 1234567890. 
# Save and publish the home page and do a save on one of the dictionary items in the translation section. 
# The site should be running and visible on the front end now
```

| :zap:        If you're looking for Clean for Umbraco V9-12, see [Clean Starter Kit](https://github.com/prjseal/Clean-Starter-Kit-for-Umbraco-v9)!   |
|-----------------------------------------|

## Headless Implementation
Phil Whittaker has created a headless version of this starter kit available at [Clean Starter Kit Headless](https://github.com/hifi-phil/clean-headless)

To set this up you will need to create an umbraco instance of the site as above

Then turn on the content delivery API with the following change to the Umbraco property of the appsettings.json file

```
      "DeliveryApi": {
        "Enabled": true
      }
```

Finally to enable revalidation of content you will need to update the Enabled property as below (enmabled is currently set to false). 

```
  "NextJs": {
    "Revalidate": {
      "Enabled": true,
      "WebHookUrls": "[\"http://localhost:3000/api/revalidate\"]",
      "WebHookSecret": "SOMETHING_SECRET"
    }
  }
```

This presumes that your healdess implementation will be loated at localhost:3000

## New API endpoint

We have added a new suite af API endpoints for bespoke functionality within the starter kit

- Dictionary - access to the dictionary items
- Search - the search form
- Contact - the contact form submission

We have added an OpenAPI instance available at 
/umbraco/swagger/index.html?urls.primaryName=Clean%20starter%20kit
