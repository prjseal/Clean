using Clean.Core.Routing;
using Clean.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Umbraco.Cms.Core.Composing;
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

        // Serve the site's Error page for missing URLs, after any page configured in Error404Collection
        builder.SetContentLastChanceFinder(serviceProvider => ActivatorUtilities.CreateInstance<ErrorPageLastChanceFinder>(
            serviceProvider,
            ActivatorUtilities.CreateInstance<ContentFinderByConfigured404>(serviceProvider)));
    }
}
