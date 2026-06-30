using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.OpenApi;
using Microsoft.Extensions.DependencyInjection;
using Umbraco.Cms.Api.Common.Attributes;
using Umbraco.Cms.Api.Common.DependencyInjection;

namespace Clean.Headless.Startup;

internal static class CleanStarterOpenApi
{
    public const string DocumentName = "clean-starter";
    public const string DisplayName = "Clean starter kit";

    public static IServiceCollection AddCleanStarterOpenApi(this IServiceCollection services)
    {
        services.AddOpenApi(DocumentName, options =>
        {

            // Include DictoryApiV1Controller,  SearchApiV1Controller and ContactApiV1Controller in the OpenAPI document
            options.ShouldInclude = apiDescription =>
                apiDescription.ActionDescriptor is ControllerActionDescriptor controllerActionDescriptor
                && controllerActionDescriptor.EndpointMetadata
                    .OfType<MapToApiAttribute>()
                    .Any(attribute => attribute.ApiName == DocumentName);

            options.AddDocumentTransformer((document, _, _) =>
            {
                document.Info.Title = DisplayName;
                document.Info.Version = "Latest";
                document.Info.Description = "Contains headless endpoints for search, dictionaries and forms";
                return Task.CompletedTask;
            });
        });

        services.AddOpenApiDocumentToUi(DocumentName, DisplayName);
        return services;
    }
}
