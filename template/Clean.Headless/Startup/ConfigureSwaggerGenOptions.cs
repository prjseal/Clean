using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi;

using Swashbuckle.AspNetCore.SwaggerGen;

namespace Clean.Headless.Startup;

internal class ConfigureSwaggerGenOptions : IConfigureOptions<SwaggerGenOptions>
{
    public void Configure(SwaggerGenOptions options)
    {
        options.SwaggerDoc(
            "clean-starter",
            new OpenApiInfo
            {
                Title = "Clean starter kit",
                Version = "Latest",
                Description = "Contains headless endpoints for search, dictionaries and forms"
            });

    }
}