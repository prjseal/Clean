using Microsoft.Extensions.Logging;
using Umbraco.Cms.Core.Events;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.Migrations;
using Umbraco.Cms.Infrastructure.Migrations.Notifications;

namespace Clean.Blog.Migrations;

public class PostMigrationNotificationHandler : INotificationAsyncHandler<MigrationPlansExecutedNotification>
{
    private readonly IContentService _contentService;
    private readonly ILogger<PostMigrationNotificationHandler> _logger;

    public PostMigrationNotificationHandler(
        IContentService contentService,
        ILogger<PostMigrationNotificationHandler> logger)
    {
        _contentService = contentService;
        _logger = logger;
    }

    public Task HandleAsync(MigrationPlansExecutedNotification notification, CancellationToken cancellationToken)
    {
        if (HasMigrationRun(notification.ExecutedPlans) is false)
        {
            return Task.CompletedTask;
        }

        var contentHome = _contentService.GetRootContent().FirstOrDefault(x => x.ContentType.Alias == "home");
        if (contentHome is null)
        {
            _logger.LogWarning("The installed Home page was not found");
            return Task.CompletedTask;
        }

        var publishResult = _contentService.PublishBranch(contentHome, PublishBranchFilter.All, []);
        foreach (var item in publishResult)
        {
            _logger.LogInformation("Result of publishing '{nodeName}' = {publishResult}", item.Content.Name, item.Result.ToString());
        }
        return Task.CompletedTask;
    }

    private static bool HasMigrationRun(IEnumerable<ExecutedMigrationPlan> executedMigrationPlans)
    {
        foreach (var executedMigrationPlan in executedMigrationPlans)
        {
            foreach (var transition in executedMigrationPlan.CompletedTransitions)
            {
                if (transition.MigrationType == typeof(ImportPackageXmlMigration))
                {
                    return true;
                }
            }
        }
        return false;
    }
}
