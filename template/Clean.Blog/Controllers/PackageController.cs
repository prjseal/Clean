using Asp.Versioning;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Umbraco.Cms.Api.Common.Attributes;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Mapping;
using Umbraco.Cms.Core.Packaging;
using Umbraco.Cms.Core.Security;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Core.Services.OperationStatus;

namespace Umbraco.Cms.Api.Management.Controllers.Package.Created;

[Route("api/v{version:apiVersion}/package")]
[ApiVersion("1.0")]
[ApiExplorerSettings(GroupName = "Package")]
[MapToApi("clean-starter")]
[ApiController]
public class PackageController : CreatedPackageControllerBase
{
    private readonly IPackagingService _packagingService;
    private readonly IUmbracoMapper _umbracoMapper;
    private readonly IBackOfficeSecurityAccessor _backOfficeSecurityAccessor;
    private readonly IPublishedContentQuery _publishedContentQuery;
    private readonly IMediaService _mediaService;
    private readonly IContentTypeService _contentTypeService;
    private readonly IDataTypeService _dataTypeService;
    private readonly IMediaTypeService _mediaTypeService;
    private readonly ITemplateService _templateService;
    private readonly IFileService _fileService;
    private readonly IPartialViewService _partialViewService;
    private readonly IStylesheetService _stylesheetService;
    private readonly IDictionaryItemService _dictionaryItemService;
    private readonly ILogger<PackageController> _logger;

    public PackageController(
        IPackagingService packagingService,
        IUmbracoMapper umbracoMapper,
        IBackOfficeSecurityAccessor backOfficeSecurityAccessor,
        IPublishedContentQuery publishedContentQuery,
        IMediaService mediaService,
        IContentTypeService contentTypeService,
        IDataTypeService dataTypeService,
        IMediaTypeService mediaTypeService,
        ITemplateService templateService,
        IPartialViewService partialViewService,
        IStylesheetService stylesheetService,
        IDictionaryItemService dictionaryItemService,
        ILogger<PackageController> logger)
    {
        _packagingService = packagingService;
        _umbracoMapper = umbracoMapper;
        _backOfficeSecurityAccessor = backOfficeSecurityAccessor;
        _publishedContentQuery = publishedContentQuery;
        _mediaService = mediaService;
        _contentTypeService = contentTypeService;
        _dataTypeService = dataTypeService;
        _mediaTypeService = mediaTypeService;
        _templateService = templateService;
        _partialViewService = partialViewService;
        _stylesheetService = stylesheetService;
        _dictionaryItemService = dictionaryItemService;
        _logger = logger;
    }

    /// <summary>
    ///     Creates a package for the backoffice.
    /// </summary>
    /// <param name="id">The version id of the package.</param>
    /// <returns>The created package.</returns>
    [HttpGet("{id}")]
    [MapToApiVersion("1.0")]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPackage(CancellationToken cancellationToken, string id)
    {
        _logger.LogInformation("Deleting all existing created packages before creating a new one.");
        var existingPackages = await _packagingService.GetCreatedPackagesAsync(0, int.MaxValue);

        if(existingPackages.Items.Any() && existingPackages.Items.Count() > 0)
        {
            foreach(var pkg in existingPackages.Items)
            {
                var deleteResult = await _packagingService.DeleteCreatedPackageAsync(pkg.PackageId, CurrentUserKey(_backOfficeSecurityAccessor));
                if(deleteResult.Success)
                {
                    _logger.LogInformation("Deleted existing package with ID: {PackageId}", pkg.PackageId);
                }
                else
                {
                    _logger.LogWarning("Failed to delete existing package with ID: {PackageId}. Status: {Status}", pkg.PackageId, deleteResult.Status);
                }
            }
        }
        else
        {
            _logger.LogInformation("No existing created packages found.");
        }

        _logger.LogInformation("Starting GetPackage for id: {Id}", id);

        var homepage = _publishedContentQuery.ContentAtRoot().FirstOrDefault();
        _logger.LogInformation("Queried homepage content root.");

        if (homepage == null)
        {
            _logger.LogWarning("Homepage not found. Returning 404.");
            return CreatedPackageNotFound();
        }

        _logger.LogInformation("Homepage found with key: {Key}", homepage.Key);

        var package = new PackageDefinition
        {
            Name = "Clean " + id,
            ContentNodeId = homepage.Key.ToString(),
            ContentLoadChildNodes = true
        };

        _logger.LogDebug("Initialized PackageDefinition for id: {Id}", id);

        var mediaUdis = _mediaService.GetRootMedia()
            .Select(m => new GuidUdi(Constants.UdiEntityType.Media, m.Key))
            .ToList();
        package.MediaUdis = mediaUdis;
        package.MediaLoadChildNodes = true;
        _logger.LogInformation("Retrieved {Count} root media items.", mediaUdis.Count);

        var documentTypes = _contentTypeService.GetAll().Select(dt => dt.Key.ToString()).ToList();
        package.DocumentTypes = documentTypes;
        _logger.LogInformation("Retrieved {Count} document types.", documentTypes.Count);

        var mediaTypes = _mediaTypeService.GetAll().Where(x => x.Alias == "Image").Select(mt => mt.Key.ToString()).ToList();
        package.MediaTypes = mediaTypes;
        _logger.LogInformation("Retrieved {Count} media types.", mediaTypes.Count);

        var dataTypes = await _dataTypeService.GetAllAsync();
        package.DataTypes = dataTypes.Where(x => x.Name.StartsWith("[")).Select(dt => dt.Key.ToString()).ToList();
        _logger.LogInformation("Retrieved {Count} data types matching criteria.", package.DataTypes.Count);

        var templates = await _templateService.GetAllAsync();
        package.Templates = templates.Select(t => t.Key.ToString()).ToList();
        _logger.LogInformation("Retrieved {Count} templates.", package.Templates.Count);

        var partialViews = await _partialViewService.GetAllAsync();
        package.PartialViews = partialViews
            .Where(x =>
                x.VirtualPath.Contains("/Views/Partials/blocklist/") ||
                x.VirtualPath.Count(c => c == '/') == 3)
            .Select(pv => pv.VirtualPath.Replace("/Views/Partials", ""))
            .ToList();
        _logger.LogInformation("Retrieved {Count} partial views.", package.PartialViews.Count);

        var stylesheets = await _stylesheetService.GetAllAsync();
        package.Stylesheets = stylesheets.Select(s => s.VirtualPath.Replace("/css", "")).ToList();
        _logger.LogInformation("Retrieved {Count} stylesheets.", package.Stylesheets.Count);

        var dictionaryItems = (await _dictionaryItemService.GetAtRootAsync()).Select(di => di.Key.ToString()).ToList();
        package.DictionaryItems = dictionaryItems;
        _logger.LogInformation("Retrieved {Count} dictionary items.", dictionaryItems.Count);

        _logger.LogInformation("Calling PackagingService to create package...");
        var result = await _packagingService.CreateCreatedPackageAsync(package, CurrentUserKey(_backOfficeSecurityAccessor));

        if (result.Success)
        {
            _logger.LogInformation("Package created successfully with ID: {PackageId}", result.Result.PackageId);
            return Ok(result.Result.PackageId);
        }
        else
        {
            _logger.LogError("Package creation failed with status: {Status}", result.Status);
            return PackageOperationStatusResult(result.Status);
        }
    }
}