using System;
using System.Collections.Generic;
using System.Linq;
using Asp.Versioning;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Umbraco.Cms.Api.Common.Attributes;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Web.Common.Controllers;

namespace Clean.Headless.Controllers;

[Route("api/v{version:apiVersion}/dictionary")]
[ApiVersion("1.0")]
[MapToApi("clean-starter")]
[ApiExplorerSettings(GroupName = "Translation")]
[ApiController]
public class DictionaryApiV1Controller(
	IDictionaryItemService dictionaryItemService,
	ILogger<DictionaryApiV1Controller> logger)
	: ControllerBase()
{
	
	///<summary>
	///Get all dictionary items
	///</summary>
	///<returns>All dictionary items</returns>
	[HttpGet]
	[Route("getdictionarytranslations")]
	[ProducesResponseType(typeof(IEnumerable<TranslationModel>), StatusCodes.Status200OK)]
	[ProducesResponseType(StatusCodes.Status500InternalServerError)]
	public async Task<IActionResult> GetDictionaryTranslations()
	{
		try
		{
			var culture = "en-US";
			var rootItems = await dictionaryItemService.GetAtRootAsync();
			var dictionaryItems = new List<IDictionaryItem>();

			foreach (var rootItem in rootItems)
			{
				dictionaryItems.Add(rootItem);
				var descendants = await dictionaryItemService.GetDescendantsAsync(rootItem.Key);
				dictionaryItems.AddRange(descendants);
			}

			var translationModels = dictionaryItems.Select(dictionaryItem => GetTranslationForDictionaryItem(dictionaryItem, culture));

			return Ok(translationModels);
		}
		catch (Exception exception)
		{
			var message = "Caught error while getting translations for dictionary";
			logger.LogError(exception, message);
			return BadRequest(message);
		}
	}

	/// <summary>
	/// Gets the translation model for a dictionary item for the given culture
	/// </summary>
	/// <param name="dictionaryItem">dictionaryitem of which the translation is required</param>
	/// <param name="culture">language to which is translated. format: ISO (nl-NL)</param>
	/// <returns> translation model</returns>
	private static TranslationModel GetTranslationForDictionaryItem(IDictionaryItem dictionaryItem, string culture)
	{
		return new TranslationModel
		{
			Id = dictionaryItem.Key,
			Key = dictionaryItem.ItemKey,
			Value = dictionaryItem.Translations.FirstOrDefault(translation => translation.LanguageIsoCode.Equals(culture, StringComparison.OrdinalIgnoreCase))?.Value ?? dictionaryItem.ItemKey
		};
	}

	public class TranslationModel
	{
		public Guid? Id { get; init; }
		public string? Key { get; init; }
		public string? Value { get; init; }
			
	}
}