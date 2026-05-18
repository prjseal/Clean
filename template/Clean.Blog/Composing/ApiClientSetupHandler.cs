using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Events;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Models.Membership;
using Umbraco.Cms.Core.Notifications;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Core.Services.OperationStatus;
using Umbraco.Cms.Infrastructure.Security;

namespace Clean.Blog.Composing;

internal sealed class ApiClientSetupHandler : INotificationAsyncHandler<UmbracoApplicationStartedNotification>
{
    private readonly IConfiguration _configuration;
    private readonly IUserService _userService;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<ApiClientSetupHandler> _logger;
    private readonly IRuntimeState _runtimeState;

    public ApiClientSetupHandler(
        IConfiguration configuration,
        IUserService userService,
        ILogger<ApiClientSetupHandler> logger,
        IRuntimeState runtimeState,
        IServiceProvider serviceProvider)
    {
        _configuration = configuration;
        _userService = userService;
        _logger = logger;
        _runtimeState = runtimeState;
        _serviceProvider = serviceProvider;
    }

    public async Task HandleAsync(UmbracoApplicationStartedNotification notification, CancellationToken cancellationToken)
    {
        try
        {
            if (_runtimeState.Level != RuntimeLevel.Run || notification.IsRestarting)
            {
                return;
            }

            await EnsureApiClientAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error provisioning the Clean.Blog API client");
        }
    }

    private async Task EnsureApiClientAsync()
    {
        if (_configuration.GetValue("uSync:Command:AddIfMissing", false) is false)
        {
            return;
        }

        var clientId = _configuration.GetValue("uSync:Command:ClientId", string.Empty);
        var clientSecret = _configuration.GetValue("uSync:Command:Secret", string.Empty);
        if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret))
        {
            _logger.LogWarning("Clean.Blog API client setup is enabled but ClientId or Secret is missing from configuration");
            return;
        }

        if (await _userService.FindByClientIdAsync(clientId) is not null)
        {
            return;
        }

        var fallbackEmail = $"{Path.GetFileNameWithoutExtension(Path.GetRandomFileName())}@example.com";
        var userGroupKeys = new HashSet<Guid>
        {
            _configuration.GetValue("uSync:Command:UserGroupKey", Constants.Security.AdminGroupKey),
        };

        var createAttempt = await _userService.CreateAsync(
            Constants.Security.SuperUserKey,
            new UserCreateModel
            {
                Email = _configuration.GetValue("uSync:Command:Email", fallbackEmail),
                UserName = _configuration.GetValue("uSync:Command:Username", fallbackEmail),
                Kind = UserKind.Api,
                Name = _configuration.GetValue("uSync:Command:Name", "Clean API User"),
                UserGroupKeys = userGroupKeys,
            },
            approveUser: false);

        if (createAttempt.Success is false)
        {
            _logger.LogWarning("Could not create the API user: {status}", createAttempt.Status);
            return;
        }

        var userKey = createAttempt.Result.CreatedUser?.Key;
        if (userKey.HasValue is false)
        {
            _logger.LogWarning("Could not create the API user: no key returned");
            return;
        }

        var addClientIdStatus = await _userService.AddClientIdAsync(userKey.Value, clientId);
        if (addClientIdStatus != UserClientCredentialsOperationStatus.Success)
        {
            _logger.LogWarning("Could not attach client id to user: {status}", addClientIdStatus);
            return;
        }

        var applicationManager = _serviceProvider.GetService<IBackOfficeApplicationManager>();
        if (applicationManager is null)
        {
            _logger.LogWarning("IBackOfficeApplicationManager is not available; OpenIddict client not registered");
            return;
        }

        await applicationManager.EnsureBackOfficeClientCredentialsApplicationAsync(clientId, clientSecret, cancellationToken: default);
        await _userService.EnableAsync(userKey.Value, new HashSet<Guid> { userKey.Value });

        _logger.LogInformation("Provisioned API client '{clientId}' for Clean.Blog", clientId);
    }
}
