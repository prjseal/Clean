using Asp.Versioning;
using Microsoft.AspNetCore.Mvc;
using Umbraco.Cms.Api.Common.Attributes;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Services;

namespace Umbraco.Cms.Api.Management.Controllers.Package.Created;

[Route("api/v{version:apiVersion}/test")]
[ApiVersion("1.0")]
[MapToApi("clean-starter")]
[ApiController]
public class TestController : CreatedPackageControllerBase
{
    private readonly IDataTypeService _dataTypeService;
    private readonly IEntityXmlSerializer _serializer;

    public TestController(
        IDataTypeService dataTypeService, 
        IEntityXmlSerializer serializer)
    {
        _dataTypeService = dataTypeService;
        _serializer = serializer;
    }

    [HttpGet]
    [MapToApiVersion("1.0")]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPackage(
        CancellationToken cancellationToken)
    {
        IDataType? dataType = await _dataTypeService.GetAsync("[BlockList] Main Content");
        if (dataType == null)
        {
            return NotFound("Unable to locate data type");
        }

        var output = _serializer.Serialize(dataType);

        return Ok(output);
    }
}