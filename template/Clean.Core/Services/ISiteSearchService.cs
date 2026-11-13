#nullable enable
using System.Collections.Generic;
using System.Threading.Tasks;
using Umbraco.Cms.Core.Models.PublishedContent;

namespace Clean.Core.Services;

/// <summary>
/// Searches the published content of the site through Umbraco Search.
/// </summary>
public interface ISiteSearchService
{
    /// <summary>
    /// Searches the published content index for pages matching a term.
    /// </summary>
    /// <param name="term">The text to search for.</param>
    /// <param name="culture">The culture to search in. Invariant content is always included.</param>
    /// <param name="page">The page of results to return, starting at 1.</param>
    /// <param name="pageSize">The number of results per page.</param>
    /// <returns>The requested page of results and the total number of matches.</returns>
    Task<SiteSearchResult> SearchAsync(string? term, string? culture = null, int page = 1, int pageSize = SiteSearchResult.DefaultPageSize);
}

/// <summary>
/// A page of site search results.
/// </summary>
/// <param name="Total">The total number of matching pages, regardless of paging.</param>
/// <param name="Items">The matching pages for the requested page of results.</param>
/// <param name="Page">The page of results that was returned, starting at 1.</param>
/// <param name="PageSize">The number of results per page.</param>
public sealed record SiteSearchResult(long Total, IReadOnlyList<IPublishedContent> Items, int Page, int PageSize)
{
    /// <summary>The number of results per page when none is specified.</summary>
    public const int DefaultPageSize = 10;

    /// <summary>The largest number of results a single page can hold.</summary>
    public const int MaxPageSize = 100;

    /// <summary>Creates an empty result for the given paging values.</summary>
    public static SiteSearchResult Empty(int page, int pageSize) => new(0, [], page, pageSize);
}
