using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Models.Membership;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Core.Services.OperationStatus;
using Umbraco.Cms.Infrastructure.Security;

namespace Clean.Blog.Composing;

// Provisions the backoffice API client used by CreateNuGetPackages.ps1 to export
// the package via the management API. This replaces uSync.Command.Setup, which has
// no Umbraco 18 release; content/schema sync itself is handled by uSync.
internal static class ApiClientSetup
{
    public static async Task EnsureAsync(IServiceProvider rootServices, CancellationToken ct = default)
    {
        using var scope = rootServices.CreateScope();
        var sp = scope.ServiceProvider;
        var configuration = sp.GetRequiredService<IConfiguration>();
        var logger = sp.GetRequiredService<ILogger<ApiClientSetupMarker>>();

        try
        {
            if (configuration.GetValue("uSync:Command:AddIfMissing", false) is false)
            {
                return;
            }

            var clientId = configuration.GetValue("uSync:Command:ClientId", string.Empty);
            var clientSecret = configuration.GetValue("uSync:Command:Secret", string.Empty);
            if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(clientSecret))
            {
                logger.LogWarning("Clean.Blog API client setup is enabled but ClientId or Secret is missing from configuration");
                return;
            }

            var userService = sp.GetRequiredService<IUserService>();
            if (await userService.FindByClientIdAsync(clientId) is not null)
            {
                return;
            }

            var fallbackEmail = $"{Path.GetFileNameWithoutExtension(Path.GetRandomFileName())}@example.com";
            var userGroupKeys = new HashSet<Guid>
            {
                configuration.GetValue("uSync:Command:UserGroupKey", Constants.Security.AdminGroupKey),
            };

            var createAttempt = await userService.CreateAsync(
                Constants.Security.SuperUserKey,
                new UserCreateModel
                {
                    Email = configuration.GetValue("uSync:Command:Email", fallbackEmail),
                    UserName = configuration.GetValue("uSync:Command:Username", fallbackEmail),
                    Kind = UserKind.Api,
                    Name = configuration.GetValue("uSync:Command:Name", "Clean API User"),
                    UserGroupKeys = userGroupKeys,
                },
                approveUser: false);

            if (createAttempt.Success is false)
            {
                logger.LogWarning("Could not create the API user: {status}", createAttempt.Status);
                return;
            }

            var userKey = createAttempt.Result.CreatedUser?.Key;
            if (userKey.HasValue is false)
            {
                logger.LogWarning("Could not create the API user: no key returned");
                return;
            }

            var addClientIdStatus = await userService.AddClientIdAsync(userKey.Value, clientId);
            if (addClientIdStatus != UserClientCredentialsOperationStatus.Success)
            {
                logger.LogWarning("Could not attach client id to user: {status}", addClientIdStatus);
                return;
            }

            var applicationManager = sp.GetService<IBackOfficeApplicationManager>();
            if (applicationManager is null)
            {
                logger.LogWarning("IBackOfficeApplicationManager is not available; OpenIddict client not registered");
                return;
            }

            await applicationManager.EnsureBackOfficeClientCredentialsApplicationAsync(clientId, clientSecret, ct);
            await userService.EnableAsync(userKey.Value, new HashSet<Guid> { userKey.Value });

            logger.LogInformation("Provisioned API client '{clientId}' for Clean.Blog", clientId);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error provisioning the Clean.Blog API client");
        }
    }

    private sealed class ApiClientSetupMarker { }
}
