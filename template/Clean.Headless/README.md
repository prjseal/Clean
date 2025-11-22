# Clean.Headless

Headless CMS extension for the Clean Starter Kit for Umbraco, providing API controllers and Next.js revalidation support for building modern headless applications.

## Description

Clean.Headless extends the Clean Starter Kit with headless CMS capabilities, including:

- **API Controllers**: RESTful API endpoints for dictionary, search, and contact functionality
- **Next.js Revalidation**: Automatic webhook-based revalidation for Next.js applications
- **Content Delivery API Integration**: Full integration with Umbraco's Content Delivery API
- **OpenAPI Documentation**: Swagger UI support for exploring and testing API endpoints

## Installation

This package is automatically installed as a dependency of the main Clean package. However, you can also install it independently:

```powershell
dotnet add package Clean.Headless
```

## Configuration

### Enable Content Delivery API

Update your `appsettings.json` to enable the Content Delivery API:

```json
{
  "Umbraco": {
    "DeliveryApi": {
      "Enabled": true
    }
  }
}
```

### Configure Next.js Revalidation (Optional)

To enable automatic revalidation of content in Next.js applications:

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

## API Endpoints

Clean.Headless provides several API endpoints:

- **Dictionary API**: Access translation/dictionary items
- **Search API**: Perform content searches
- **Contact API**: Handle contact form submissions

### OpenAPI/Swagger Documentation

Explore the API endpoints using the built-in Swagger UI:

**URL**: `/umbraco/swagger/index.html?urls.primaryName=Clean%20starter%20kit`

## Requirements

- Umbraco.Cms.Web.Website 17.0.0-rc2 or higher
- Umbraco.Cms.Api.Common 17.0.0-rc2 or higher
- .NET 10.0

## Version Compatibility

| Clean.Headless Version | Umbraco Version | .NET Version |
|-----------------------|-----------------|--------------|
| 4.x                   | 13              | .NET 8       |
| 5.x                   | 15              | .NET 9       |
| 6.x                   | 16              | .NET 9       |
| 7.x                   | 17              | .NET 10      |

## Headless Frontend Example

Check out the [Clean Starter Kit Headless Frontend](https://github.com/hifi-phil/clean-headless) - a complete Next.js implementation demonstrating headless CMS integration.

## Documentation

For complete documentation and examples, visit the [Clean Starter Kit repository](https://github.com/prjseal/Clean).

## Support

- **GitHub Repository**: [https://github.com/prjseal/Clean](https://github.com/prjseal/Clean)
- **Issues**: [GitHub Issues](https://github.com/prjseal/Clean/issues)

## License

MIT License - see the [LICENSE](https://github.com/prjseal/Clean/blob/main/LICENSE) file for details.

## Authors

- Paul Seal
- Phil Whittaker
