using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Asp.Versioning;
using Clean.Core.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Umbraco.Cms.Api.Common.Attributes;
using Umbraco.Cms.Core.Models.PublishedContent;
using Umbraco.Extensions;

namespace Clean.Headless.Controllers;

[Route("api/v{version:apiVersion}/search")]
[ApiVersion("1.0")]
[ApiExplorerSettings(GroupName = "Search")]
[Tags("Search")]
[MapToApi("clean-starter")]
[ApiController]
public class SearchApiV1Controller(
	ISiteSearchService siteSearchService,
	ILogger<SearchApiV1Controller> logger)
	: ControllerBase
{
	///<summary>
	///Get search results
	///</summary>
	///<param name="searchQuery">The text to search for</param>
	///<param name="page">The page of results to return, starting at 1</param>
	///<param name="pageSize">The number of results per page</param>
	///<returns>Search Results</returns>
	[HttpGet]
	[Route("getSearchResults")]
	[ProducesResponseType(typeof(SearchResultsModel), StatusCodes.Status200OK)]
	[ProducesResponseType(StatusCodes.Status500InternalServerError)]
	public async Task<IActionResult> GetSearchResults(string? searchQuery, int page = 1, int pageSize = SiteSearchResult.DefaultPageSize)
	{
		try
		{
			var results = await siteSearchService.SearchAsync(searchQuery, page: page, pageSize: pageSize);
			var resultsModels = new SearchResultsModel
			{
				Count = (int)results.Total,
				Items = results.Items.Select(BuildResult).ToList()
			};

			return Ok(resultsModels);
		}
		catch (Exception exception)
		{
			var message = "Caught error while getting search results";
			logger.LogError(exception, "{Message}", message);
			return BadRequest(message);
		}
	}

	private static SearchResultsItemModel BuildResult(IPublishedContent content)
	{
		var output = new SearchResultsItemModel
		{
			ContentName = content.Name,
			Url = content.Url(),
			Title = content.Value<string>("title"),
			Subtitle = content.Value<string>("subtitle")
		};

		if (content.HasProperty("author") && content.HasValue("author"))
		{
			output.Author = content.Value<IPublishedContent>("author")?.Name;
		}

		if (content.HasProperty("articleDate") && content.HasValue("articleDate"))
		{
			output.ArticleDate = content.Value<DateTime>("articleDate").ToString("MMMM dd, yyyy");
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
