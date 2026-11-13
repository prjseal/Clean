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
using Umbraco.Cms.Core.Notifications;
using Umbraco.Cms.Core.Packaging;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.Migrations;
using Umbraco.Cms.Infrastructure.Migrations.Notifications;

namespace Clean.Migrations
{
    public class PostMigrationNotificationHandler :
        INotificationAsyncHandler<MigrationPlansExecutedNotification>,
        INotificationAsyncHandler<UmbracoApplicationStartedNotification>
    {
        // Set when the package migration runs during an unattended upgrade, and cleared by the
        // handler that publishes the content once the upgrade has finished. Notification handlers
        // are transient, so this is static.
        private static int _publishPending;

        private readonly IContentService _contentService;
        private readonly IElementService _elementService;
        private readonly IElementPublishingService _elementPublishingService;
        private readonly IRuntimeState _runtimeState;
        private readonly ILogger<PostMigrationNotificationHandler> _logger;

        public PostMigrationNotificationHandler(
            IContentService contentService,
            IElementService elementService,
            IElementPublishingService elementPublishingService,
            IRuntimeState runtimeState,
            ILogger<PostMigrationNotificationHandler> logger)
        {
            _contentService = contentService;
            _elementService = elementService;
            _elementPublishingService = elementPublishingService;
            _runtimeState = runtimeState;
            _logger = logger;
        }

        public async Task HandleAsync(MigrationPlansExecutedNotification notification, CancellationToken cancellationToken)
        {
            // Check if we have run the right migration, otherwise skip
            if (HasMigrationRun(notification.ExecutedPlans) is false)
            {
                return;
            }

            // During an unattended install or upgrade, the package migration runs before Umbraco
            // rebuilds the document URLs. Publishing here queues Umbraco Search indexing, and on
            // SQLite that indexing can stop the URL rebuild getting its write lock, so the boot
            // fails. Publish once the upgrade has finished instead.
            if (_runtimeState.Level != RuntimeLevel.Run)
            {
                Interlocked.Exchange(ref _publishPending, 1);
                _logger.LogInformation("The Clean package content will be published when Umbraco has finished starting");
                return;
            }

            await PublishPackageContentAsync();
        }

        // Umbraco raises this after the unattended upgrade has finished, including the URL rebuild.
        public async Task HandleAsync(UmbracoApplicationStartedNotification notification, CancellationToken cancellationToken)
        {
            if (Interlocked.Exchange(ref _publishPending, 0) == 0)
            {
                return;
            }

            await PublishPackageContentAsync();
        }

        private async Task PublishPackageContentAsync()
        {
            // The elements are published first, so the pages that pick them can render them
            await PublishPackageElementsAsync();

            var contentHome = _contentService.GetRootContent().FirstOrDefault(x => x.ContentType.Alias == "home");
            if (contentHome != null)
            {
                // Publishing checks the access of the user. PublishBranch runs as the super user by default.
                var publishResult = _contentService.PublishBranch(contentHome, PublishBranchFilter.All, []);
                foreach (var item in publishResult)
                {
                    _logger.LogInformation("Result of publishing '{nodeName}' = {publishResult}", item.Content.Name, item.Result.ToString());
                }
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
