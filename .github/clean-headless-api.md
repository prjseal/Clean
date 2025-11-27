# Headless/API Implementation

## Delivery API Setup

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

## Next.js Revalidation

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

## Headless Frontend Example

Phil Whittaker has created a complete headless Next.js frontend for this starter kit:

**[Clean Starter Kit Headless Frontend](https://github.com/hifi-phil/clean-headless)**

This implementation demonstrates how to use the Clean starter kit as a headless CMS with a modern Next.js frontend.

---

## API Endpoints

The Clean starter kit provides a suite of custom API endpoints for common functionality:

- **Dictionary API**: Access dictionary/translation items programmatically
- **Search API**: Perform content searches via REST API
- **Contact API**: Handle contact form submissions

## OpenAPI/Swagger Documentation

Explore and test the API endpoints using the built-in Swagger UI:

**URL**: `/umbraco/swagger/index.html?urls.primaryName=Clean%20starter%20kit`

This provides interactive documentation for all available API endpoints, including request/response schemas and the ability to test endpoints directly from the browser.

---

## Related Documentation

- [README](../README.md) - Installation instructions and features overview
- [Package Architecture](clean-packages.md) - Understanding the Clean.Headless package
- [Clean Documentation](clean-documentation.md) - Comprehensive documentation index
- [Contributing Guide](general-contributing.md) - Guidelines for contributing API improvements
