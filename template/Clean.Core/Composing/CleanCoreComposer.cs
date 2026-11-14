using Clean.Core.Routing;
using Clean.Core.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Composing;
using Umbraco.Cms.Core.Configuration.Models;
using Umbraco.Cms.Core.DependencyInjection;
using Umbraco.Cms.Core.Routing;
using Umbraco.Extensions;

namespace Clean.Core.Composing;

/// <summary>
/// Registers the Clean.Core services.
/// </summary>
public class CleanCoreComposer : IComposer
{
    /// <inheritdoc />
    public void Compose(IUmbracoBuilder builder)
    {
        builder.Services.AddScoped<ISiteSearchService, SiteSearchService>();

        // Index the text of Library blocks on the pages that use them, so the site search finds a
        // page by the text of a reusable block. Umbraco leaves this off by default. A site that sets
        // Umbraco:CMS:Indexing:IndexExternalBlockElements itself keeps its own value.
        if (builder.Config.GetSection($"{Constants.Configuration.ConfigIndexing}:{nameof(IndexingSettings.IndexExternalBlockElements)}").Exists() is false)
        {
            builder.Services.Configure<IndexingSettings>(settings => settings.IndexExternalBlockElements = true);
        }

        // Serve the site's Error page for missing URLs, after any page configured in Error404Collection
        builder.SetContentLastChanceFinder(serviceProvider => ActivatorUtilities.CreateInstance<ErrorPageLastChanceFinder>(
            serviceProvider,
            ActivatorUtilities.CreateInstance<ContentFinderByConfigured404>(serviceProvider)));
    }
}
