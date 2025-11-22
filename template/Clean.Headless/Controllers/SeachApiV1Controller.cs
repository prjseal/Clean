using System;
using System.Collections.Generic;
using System.Linq;
using Asp.Versioning;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Umbraco.Cms.Api.Common.Attributes;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Models.PublishedContent;
using Umbraco.Cms.Web.Common.Controllers;
using Umbraco.Extensions;

namespace Clean.Headless.Controllers;

[Route("api/v{version:apiVersion}/search")]
[ApiVersion("1.0")]
[ApiExplorerSettings(GroupName = "Search")]
[MapToApi("clean-starter")]
[ApiController]
public class SearchApiV1Controller : ControllerBase
{
	private readonly IPublishedContentQueryAccessor _publishedContentQuerAccessor;

	public SearchApiV1Controller(IPublishedContentQueryAccessor publishedContentQuerAccessor)
	{
		_publishedContentQuerAccessor = publishedContentQuerAccessor;
	}
	
	///<summary>
	///Get search results
	///</summary>
	///<returns>Search Results</returns>
	[HttpGet]
	[Route("getSearchResults")]
	[ProducesResponseType(typeof(SearchResultsModel), StatusCodes.Status200OK)]
	[ProducesResponseType(StatusCodes.Status500InternalServerError)]
	public IActionResult GetSearchResults(string searchQuery)
	{
    	var docTypesToIgnore = new[] { "category", "categoryList", "error", "search", "xMLSitemap" };

	    if(_publishedContentQuerAccessor.TryGetValue(out var publishedContentQuery))
	    {
		    var results = publishedContentQuery.Search(searchQuery).Where(x => !docTypesToIgnore.Contains(x.Content.ContentType.Alias)).ToList();
		    var resultsModels = new SearchResultsModel()
		    {
			    Count = results.Count(),
			    Items = results.Select(result => BuildResult(result))
		    };

		    return Ok(resultsModels);
	    }
	    else
	    {
		    var message = "Caught error while getting search results";
		    return BadRequest(message);
	    }

	}

	private SearchResultsItemModel BuildResult(PublishedSearchResult result)
	{
		var output = new SearchResultsItemModel();
		output.ContentName = result.Content.Name;
		output.Url = result.Content.Url();
		output.Title = result.Content.Value<string>("title");
		output.Subtitle = result.Content.Value<string>("subtitle");
		
		if (result.Content.HasProperty("author") && result.Content.HasValue("author"))
		{
			output.Author = result.Content.Value<IPublishedContent>("author")?.Name;
		}
		
		if (result.Content.HasProperty("articleDate") && result.Content.HasValue("articleDate"))
		{
			output.ArticleDate = result.Content.Value<DateTime>("articleDate").ToString("MMMM dd, yyyy");
		}
		return output;
	}
	
	private class SearchResultsItemModel
	{
		public string? ContentName { get; set; }
		public string? Url { get; set; }
		public string? Title { get; set; }
		public string? Subtitle { get; set; }
		public string? ArticleDate { get; set; }
		public string? Author { get; set; }
	}
	
	private class SearchResultsModel
	{
		public int? Count { get; init; }
		public IEnumerable<SearchResultsItemModel> Items { get; set; } = [];
	}
}