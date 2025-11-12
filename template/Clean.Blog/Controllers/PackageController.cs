using Asp.Versioning;
using Microsoft.AspNetCore.Mvc;
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

    public PackageController(
        IPackagingService packagingService,
        IUmbracoMapper umbracoMapper,
        IBackOfficeSecurityAccessor backOfficeSecurityAccessor,
        IPublishedContentQuery publishedContentQuery, IMediaService mediaService,
        IContentTypeService contentTypeService, IDataTypeService dataTypeService, 
        IMediaTypeService mediaTypeService, ITemplateService templateService, 
        IPartialViewService partialViewService, IStylesheetService stylesheetService, 
        IDictionaryItemService dictionaryItemService)
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
    public async Task<IActionResult> GetPackage(
        CancellationToken cancellationToken,
        string id)
    {
        var package = new PackageDefinition();

        var homepage = _publishedContentQuery
            .ContentAtRoot().FirstOrDefault();

        if (homepage == null)
        {
            return CreatedPackageNotFound();
        }

        package.Name = "Clean " + id;

        var contentNodeId = homepage.Key.ToString();
        package.ContentNodeId = homepage.Key.ToString();
        package.ContentLoadChildNodes = true;

        var mediaUdis = _mediaService.GetRootMedia()
            .Select(m => new GuidUdi(Constants.UdiEntityType.Media, m.Key))
            .ToList();
        package.MediaUdis = mediaUdis;

        package.MediaLoadChildNodes = true;

        var documentTypes = _contentTypeService.GetAll().Select(dt => dt.Key.ToString()).ToList();
        package.DocumentTypes = documentTypes;

        var mediaTypes = _mediaTypeService.GetAll().Where(x => x.Alias == "Image").Select(mt => mt.Key.ToString()).ToList();
        package.MediaTypes = mediaTypes;

        var dataTypes = await _dataTypeService.GetAllAsync();
        package.DataTypes = dataTypes.Where(x => x.Name.StartsWith("[")).Select(dt => dt.Key.ToString()).ToList();
        
        var templates = await _templateService.GetAllAsync();
        package.Templates = templates.Select(t => t.Key.ToString()).ToList();

        var partialViews = await _partialViewService.GetAllAsync();

        package.PartialViews = partialViews
            .Where(x =>
                    x.VirtualPath.Contains("/Views/Partials/blocklist/") ||
                    x.VirtualPath.Count(c => c == '/') == 3
            )
            .Select(pv => pv.VirtualPath.Replace("/Views/Partials", ""))
            .ToList();


        var stylesheets = await _stylesheetService.GetAllAsync();
        package.Stylesheets = stylesheets.Select(s => s.VirtualPath.Replace("/css","")).ToList();

        var dictionaryItems = _dictionaryItemService.GetAtRootAsync().Result.Select(di => di.Key.ToString()).ToList();
        package.DictionaryItems = dictionaryItems;
        Attempt<PackageDefinition, PackageOperationStatus> result = await _packagingService.CreateCreatedPackageAsync(package, CurrentUserKey(_backOfficeSecurityAccessor));

        var packageId = result.Success ? result.Result.PackageId : Guid.Empty;

        return result.Success
            ? Ok(packageId)
            : PackageOperationStatusResult(result.Status);
    }
}