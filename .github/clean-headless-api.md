# Headless/API Implementation

## Delivery API Setup

The Clean starter kit includes full support for headless implementations. To enable the Content Delivery API, update your `appsettings.json`:

```json
{
    "Umbraco": {
        "CMS": {
            "DeliveryApi": {
                "Enabled": true
            }
        }
    }
}
```

Update your `program.cs`:

```csharp
builder.CreateUmbracoBuilder()
    .AddBackOffice()
    .AddWebsite()
    .AddDeliveryApi()
    .AddComposers()
    .Build();
```

Once the Content Delivery API is enabled, the next step is to rebuild the Delivery API content index **DeliveryApiContentIndex**. This can be done using the Examine Management dashboard in the Settings section of the Umbraco Backoffice.



## Headless Frontend Example

Phil Whittaker has created a complete headless Next.js frontend for this starter kit:

**[Clean Starter Kit Headless Frontend](https://github.com/hifi-phil/clean-headless)**

This implementation demonstrates how to use the Clean starter kit as a headless CMS with a modern Next.js frontend.

 **Note for Umbraco 18**:  DeliveryApi configuration must also include `GenerateContentTypeSchemas`:


 ```json
 {
     "Umbraco": {
         "CMS": {
             "DeliveryApi": {
                 "Enabled": true,
                 "OpenApi": {
                     "GenerateContentTypeSchemas": true
                 }
             }
         }
     }
 }
 ```

---


## API Endpoints

The Clean starter kit provides a suite of custom API endpoints for common functionality:

- **Dictionary API**: Access dictionary/translation items programmatically
- **Search API**: Perform content searches via REST API
- **Contact API**: Handle contact form submissions

## OpenAPI/Swagger Documentation

Explore and test the API endpoints using the built-in Swagger UI:

**Umbraco 18+**: `/umbraco/openapi/`

**Earlier versions**: `/umbraco/swagger/`

This provides interactive documentation for all available API endpoints, including request/response schemas and the ability to test endpoints directly from the browser.

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

---

## Related Documentation

- [README](../README.md) - Installation instructions and features overview
- [Package Architecture](clean-packages.md) - Understanding the Clean.Headless package
- [Clean Documentation](clean-documentation.md) - Comprehensive documentation index
- [Contributing Guide](general-contributing.md) - Guidelines for contributing API improvements
