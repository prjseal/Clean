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

namespace Clean.Core.Services;

/// <summary>
/// Searches the published content index through Umbraco Search, leaving out the page types that
/// should never appear in search results.
/// </summary>
public sealed class SiteSearchService(
    ISearcherResolver searcherResolver,
    IContentTypeService contentTypeService,
    IPublishedContentCache publishedContentCache) : ISiteSearchService
{
    /// <summary>The aliases of the document types that are left out of search results.</summary>
    public static readonly string[] ExcludedContentTypeAliases = ["error", "search", "xMLSitemap"];

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
            filters: GetFilters(),
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

    private Filter[] GetFilters()
    {
        var excludedContentTypeKeys = ExcludedContentTypeAliases
            .Select(alias => contentTypeService.Get(alias)?.Key)
            .OfType<Guid>()
            .Select(key => key.ToString())
            .ToArray();

        return excludedContentTypeKeys.Length == 0
            ? []
            : [new KeywordFilter(Constants.Search.FieldNames.ContentTypeId, excludedContentTypeKeys, Negate: true)];
    }
}
