# Headless/API Implementation

## Delivery API Setup

The Clean starter kit includes full support for headless implementations. The Content Delivery API is not turned on by default, and needs two changes.

### 1. Register the Delivery API

Add `.AddDeliveryApi()` to your `Program.cs`:

```csharp
builder.CreateUmbracoBuilder()
    .AddBackOffice()
    .AddWebsite()
    .AddDeliveryApi()
    .AddComposers()
    .Build();
```

Umbraco 19 projects only include this call if they were created with the `--use-delivery-api` option (`dotnet new umbraco --use-delivery-api`). The `Clean.Blog` project in this repository and sites created from the `umbraco-starter-clean` template leave it out, as a fresh Umbraco 19 project does. Without it, the Delivery API URLs (`/umbraco/delivery/api/v2/...`) return a 500 error, because the Delivery API's services are not registered. Clean's own endpoints under `/api/v1` work either way.

### 2. Enable it in configuration

Update your `appsettings.json`. On Umbraco 18 and 19, also set `GenerateContentTypeSchemas`:

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

### 3. Rebuild the indexes

Once the Content Delivery API is enabled, rebuild the search indexes. In Umbraco 19 this is done from **Settings > Search** in the Umbraco Backoffice, which lists each index with its health status and a rebuild action. In Umbraco 17 and earlier, rebuild **DeliveryApiContentIndex** from the Examine Management dashboard in the Settings section instead.

## Headless Frontend Example

Phil Whittaker has created a complete headless Next.js frontend for this starter kit:

**[Clean Starter Kit Headless Frontend](https://github.com/hifi-phil/clean-headless)**

This implementation demonstrates how to use the Clean starter kit as a headless CMS with a modern Next.js frontend. It reads content through the Delivery API, so turn the Delivery API on first.

---


## API Endpoints

The Clean starter kit provides a suite of custom API endpoints for common functionality:

- **Dictionary API**: Access dictionary/translation items programmatically
- **Search API**: Perform content searches via REST API
- **Contact API**: Handle contact form submissions

### Search

The search page and the Search API both use `ISiteSearchService` from `Clean.Core`. It queries the published content index through Umbraco Search (`ISearcher`, with Examine as the default provider) and leaves out the `error`, `search` and `xMLSitemap` page types.

`GET /api/v1/search/getSearchResults`

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `searchQuery` | Yes | | The text to search for |
| `page` | No | `1` | The page of results to return |
| `pageSize` | No | `10` | The number of results per page, up to 100 |

The response has a `count` with the total number of matches and an `items` array holding the requested page. Each item has `contentName`, `url`, `title`, `subtitle`, `articleDate` and `author`.

The indexes are listed under **Settings > Search** in the Umbraco Backoffice. Rebuild the published content index there if search results are missing.

## OpenAPI Documentation

Explore and test the API endpoints using the built-in OpenAPI UI:

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
