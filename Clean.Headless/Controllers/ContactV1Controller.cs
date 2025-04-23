using System.Threading.Tasks;
using Asp.Versioning;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Umbraco.Cms.Api.Common.Attributes;
using Umbraco.Cms.Core.Configuration.Models;
using Umbraco.Cms.Core.Mail;
using Umbraco.Cms.Core.Models.Email;
using Umbraco.Cms.Web.Common.Controllers;

namespace Clean.Headless.Controllers;

[Route("api/v{version:apiVersion}/contact")]
[ApiVersion("1.0")]
[ApiExplorerSettings(GroupName = "Contact")]
[MapToApi("clean-starter")]
[ApiController]
public class ContactApiV1Controller : UmbracoApiController
{
    private readonly IEmailSender _emailSender;
    private readonly ILogger<ContactApiV1Controller> _logger;
    private readonly GlobalSettings _globalSettings;

    public ContactApiV1Controller(IEmailSender emailSender, ILogger<ContactApiV1Controller> logger, IOptions<GlobalSettings> globalSettings)
    {
        _globalSettings = globalSettings.Value;
        _emailSender = emailSender;
        _logger = logger;
    }
	
    ///<summary>
    ///Get all dictionary items
    ///</summary>
    ///<returns>All dictionary items</returns>
    [HttpPost]
    [Route("postContactForm")]
    [ProducesResponseType(typeof(bool), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> PostContactForm([FromBody] EmailForm model)
    {
        try
        {
            var fromAddress = _globalSettings.Smtp?.From;

            var subject = string.Format("Enquiry from: {0} - {1}", model.Name, model.Email);
            EmailMessage message = new EmailMessage(fromAddress, fromAddress, subject, model.Message, false);
            await _emailSender.SendAsync(message, emailType: "Contact");

            _logger.LogInformation("Contact Form Submitted Successfully");
            return Ok(true);
        }
        catch (System.Exception ex)
        {			
            var message = "Error When Submitting Contact Form";
            _logger.LogError(ex, message);
            return BadRequest(message);
        }

    }
	
    public class EmailForm
    {
        public string? Name { get; init; } = string.Empty;
        public string? Email { get; init; } = string.Empty;
        public string? Message { get; init; } = string.Empty;
    }
}