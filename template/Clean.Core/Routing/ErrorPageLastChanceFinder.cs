using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Umbraco.Cms.Core.Models.PublishedContent;
using Umbraco.Cms.Core.PublishedCache;
using Umbraco.Cms.Core.Routing;
using Umbraco.Cms.Core.Services.Navigation;

namespace Clean.Core.Routing;

/// <summary>
/// Serves the site's Error page, with a 404 status, when no content matches the requested URL.
/// </summary>
/// <remarks>
/// The page configured in <c>Umbraco:CMS:Content:Error404Collection</c> takes precedence, so the
/// configured 404 finder runs first. Otherwise the first published Error page directly under the
/// site root is used: the root of the matched domain, or the first published Home page.
/// </remarks>
public sealed class ErrorPageLastChanceFinder(
    ContentFinderByConfigured404 configured404Finder,
    IPublishedContentCache publishedContentCache,
    IDocumentNavigationQueryService documentNavigationQueryService) : IContentLastChanceFinder
{
    /// <summary>The alias of the document type that is used as the site's 404 page.</summary>
    public const string ErrorContentTypeAlias = "error";

    /// <summary>The alias of the document type of a site root.</summary>
    public const string HomeContentTypeAlias = "home";

    /// <inheritdoc />
    public async Task<bool> TryFindContent(IPublishedRequestBuilder request)
    {
        if (await configured404Finder.TryFindContent(request))
        {
            return true;
        }

        IPublishedContent? root = await GetSiteRootAsync(request);
        if (root is null
            || documentNavigationQueryService.TryGetChildrenKeysOfType(root.Key, ErrorContentTypeAlias, out IEnumerable<Guid> errorPageKeys) is false)
        {
            return false;
        }

        foreach (Guid key in errorPageKeys)
        {
            IPublishedContent? errorPage = await publishedContentCache.GetByIdAsync(key);
            if (errorPage is not null && errorPage.IsPublished(request.Culture))
            {
                request.SetPublishedContent(errorPage);
                request.SetIs404();
                return true;
            }
        }

        return false;
    }

    private async Task<IPublishedContent?> GetSiteRootAsync(IPublishedRequestBuilder request)
    {
        if (request.Domain is not null)
        {
            return await publishedContentCache.GetByIdAsync(request.Domain.ContentId);
        }

        if (documentNavigationQueryService.TryGetRootKeysOfType(HomeContentTypeAlias, out IEnumerable<Guid> homeKeys) is false)
        {
            return null;
        }

        foreach (Guid key in homeKeys)
        {
            IPublishedContent? home = await publishedContentCache.GetByIdAsync(key);
            if (home is not null && home.IsPublished(request.Culture))
            {
                return home;
            }
        }

        return null;
    }
}
