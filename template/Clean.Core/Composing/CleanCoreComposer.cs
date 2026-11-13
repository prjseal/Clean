using Clean.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Umbraco.Cms.Core.Composing;
using Umbraco.Cms.Core.DependencyInjection;

namespace Clean.Core.Composing;

/// <summary>
/// Registers the Clean.Core services.
/// </summary>
public class CleanCoreComposer : IComposer
{
    /// <inheritdoc />
    public void Compose(IUmbracoBuilder builder)
        => builder.Services.AddScoped<ISiteSearchService, SiteSearchService>();
}
