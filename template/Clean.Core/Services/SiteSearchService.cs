using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Models.PublishedContent;
using Umbraco.Cms.Core.PublishedCache;
using Umbraco.Cms.Core.Search;
using Umbraco.Cms.Core.Search.Querying.Filtering;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Core.Services.Navigation;

namespace Clean.Core.Services;

/// <summary>
/// Searches the published content index through Umbraco Search, leaving out the page types that
/// should never appear in search results and the pages that have Hide From Search turned on.
/// </summary>
public sealed class SiteSearchService(
    ISearcherResolver searcherResolver,
    IContentTypeService contentTypeService,
    IPublishedContentCache publishedContentCache,
    IDocumentNavigationQueryService documentNavigationQueryService) : ISiteSearchService
{
    /// <summary>The aliases of the document types that are left out of search results.</summary>
    public static readonly string[] ExcludedContentTypeAliases = ["error", "search", "xMLSitemap"];

    /// <summary>The alias of the Hide From Search toggle, which leaves a page out of search results.</summary>
    public const string HideFromSearchPropertyAlias = "umbracoNaviHide";

    /// <inheritdoc />
    public async Task<SiteSearchResult> SearchAsync(string? term, string? culture = null, int page = 1, int pageSize = SiteSearchResult.DefaultPageSize)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, SiteSearchResult.MaxPageSize);

        if (string.IsNullOrWhiteSpace(term))
        {
            return SiteSearchResult.Empty(page, pageSize);
        }

        ISearcher searcher = searcherResolver.GetRequiredSearcher(Constants.Search.IndexAliases.PublishedContent);

        var result = await searcher.SearchAsync(
            Constants.Search.IndexAliases.PublishedContent,
            query: term.Trim(),
            filters: await GetFiltersAsync(culture),
            culture: culture,
            skip: (page - 1) * pageSize,
            take: pageSize);

        var items = new List<IPublishedContent>();
        foreach (var document in result.Documents)
        {
            if (document.ObjectType is not Umbraco.Cms.Core.Models.UmbracoObjectTypes.Document)
            {
                continue;
            }

            var content = await publishedContentCache.GetByIdAsync(document.Id);
            if (content is not null)
            {
                items.Add(content);
            }
        }

        return new SiteSearchResult(result.Total, items, page, pageSize);
    }

    // The exclusions are filters in the query, not checks on the results, so the total and the
    // paging stay correct.
    private async Task<List<Filter>> GetFiltersAsync(string? culture)
    {
        var filters = new List<Filter>();

        var excludedContentTypeKeys = ExcludedContentTypeAliases
            .Select(alias => contentTypeService.Get(alias)?.Key)
            .OfType<Guid>()
            .Select(key => key.ToString())
            .ToArray();

        if (excludedContentTypeKeys.Length > 0)
        {
            filters.Add(new KeywordFilter(Constants.Search.FieldNames.ContentTypeId, excludedContentTypeKeys, Negate: true));
        }

        // The search provider indexes the toggle without a type it can filter on, so leave the
        // hidden pages out by their keys instead.
        var hiddenPageKeys = await GetHiddenFromSearchKeysAsync(culture);
        if (hiddenPageKeys.Length > 0)
        {
            filters.Add(new KeywordFilter(Constants.Search.FieldNames.Id, hiddenPageKeys, Negate: true));
        }

        return filters;
    }

    // Finds the published pages that have Hide From Search turned on. Only the document types that
    // have the toggle are looked at. The toggle applies to the page itself, not the pages below it.
    private async Task<string[]> GetHiddenFromSearchKeysAsync(string? culture)
    {
        var contentTypeAliases = contentTypeService.GetAll()
            .Where(contentType => contentType.CompositionPropertyTypes.Any(property => property.Alias == HideFromSearchPropertyAlias))
            .Select(contentType => contentType.Alias)
            .ToArray();

        if (contentTypeAliases.Length == 0
            || documentNavigationQueryService.TryGetRootKeys(out IEnumerable<Guid> rootKeys) is false)
        {
            return [];
        }

        var candidateKeys = new HashSet<Guid>(rootKeys);
        foreach (Guid rootKey in rootKeys)
        {
            foreach (string contentTypeAlias in contentTypeAliases)
            {
                if (documentNavigationQueryService.TryGetDescendantsKeysOfType(rootKey, contentTypeAlias, out IEnumerable<Guid> keys))
                {
                    candidateKeys.UnionWith(keys);
                }
            }
        }

        var hiddenPageKeys = new List<string>();
        foreach (Guid key in candidateKeys)
        {
            var content = await publishedContentCache.GetByIdAsync(key);
            if (content?.GetProperty(HideFromSearchPropertyAlias)?.GetValue(culture) is true)
            {
                hiddenPageKeys.Add(key.ToString());
            }
        }

        return [.. hiddenPageKeys];
    }
}
