using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Xml.Linq;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Events;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Models.ContentPublishing;
using Umbraco.Cms.Core.Packaging;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.Migrations;
using Umbraco.Cms.Infrastructure.Migrations.Notifications;

namespace Clean.Migrations
{
    public class PostMigrationNotificationHandler : INotificationAsyncHandler<MigrationPlansExecutedNotification>
    {
        private readonly IContentService _contentService;
        private readonly IContentPublishingService _contentPublishingService;
        private readonly IElementService _elementService;
        private readonly IElementPublishingService _elementPublishingService;
        private readonly ILogger<PostMigrationNotificationHandler> _logger;

        public PostMigrationNotificationHandler(
            IContentService contentService,
            IContentPublishingService contentPublishingService,
            IElementService elementService,
            IElementPublishingService elementPublishingService,
            ILogger<PostMigrationNotificationHandler> logger)
        {
            _contentService = contentService;
            _contentPublishingService = contentPublishingService;
            _elementService = elementService;
            _elementPublishingService = elementPublishingService;
            _logger = logger;
        }

        public async Task HandleAsync(MigrationPlansExecutedNotification notification, CancellationToken cancellationToken)
        {
            // Check if we have run the right migration, otherwise skip
            if (HasMigrationRun(notification.ExecutedPlans) is false)
            {
                return;
            }

            // The elements are published first, so the pages that pick them can render them
            await PublishPackageElementsAsync();

            var contentHome = _contentService.GetRootContent().FirstOrDefault(x => x.ContentType.Alias == "home");
            if (contentHome != null)
            {
                // Publishing checks the access of the user, so it runs as the super user
                var publishResult = await _contentPublishingService.PublishBranchAsync(
                    contentHome.Key,
                    ["*"],
                    PublishBranchFilter.All,
                    Constants.Security.SuperUserKey,
                    useBackgroundThread: false);

                _logger.LogInformation("Result of publishing the '{nodeName}' branch = {publishResult}", contentHome.Name, publishResult.Status);
            }
            else
            {
                _logger.LogWarning("The installed Home page was not found");
            }
        }

        // The package import creates element library items unpublished, so publish the
        // ones the package marks as published. Only the package's own elements are
        // touched, so existing elements on the site are left as they are.
        private async Task PublishPackageElementsAsync()
        {
            if (PackageMigrationResource.TryGetEmbeddedPackageDataManifest(typeof(ImportPackageXmlMigration), out var packageXml, out var zipArchive) is false
                || packageXml?.Root is null)
            {
                _logger.LogWarning("Could not read the embedded package to publish its element library items");
                return;
            }

            zipArchive?.Dispose();

            var elementKeys = packageXml.Root
                .Elements("Elements")
                .Elements("ElementSet")
                .Elements()
                .Where(x => (string?)x.Attribute("isPublished") == "true")
                .Select(x => Guid.TryParse((string?)x.Attribute("key"), out var key) ? key : Guid.Empty)
                .Where(key => key != Guid.Empty)
                .ToList();

            foreach (var element in _elementService.GetByIds(elementKeys))
            {
                if (element.Published)
                {
                    continue;
                }

                var publishResult = await _elementPublishingService.PublishAsync(
                    element.Key,
                    [new CulturePublishScheduleModel { Culture = null }],
                    Constants.Security.SuperUserKey);

                _logger.LogInformation("Result of publishing element '{elementName}' = {publishResult}", element.Name, publishResult.Status);
            }
        }

        private bool HasMigrationRun(IEnumerable<ExecutedMigrationPlan> executedMigrationPlans)
        {
            foreach (ExecutedMigrationPlan executedMigrationPlan in executedMigrationPlans)
            {
                foreach (MigrationPlan.Transition transition in executedMigrationPlan.CompletedTransitions)
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
}
