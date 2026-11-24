using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Xml.Linq;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Cache;
using Umbraco.Cms.Core.Events;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Models.ContentPublishing;
using Umbraco.Cms.Core.Packaging;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.Migrations;
using Umbraco.Cms.Infrastructure.Migrations.Notifications;

namespace Clean.Migrations
{
    public class PostMigrationNotificationHandler :
        INotificationAsyncHandler<MigrationPlansExecutedNotification>
    {
        private readonly IContentService _contentService;
        private readonly IElementService _elementService;
        private readonly IElementPublishingService _elementPublishingService;
        private readonly AppCaches _appCaches;
        private readonly ILogger<PostMigrationNotificationHandler> _logger;

        public PostMigrationNotificationHandler(
            IContentService contentService,
            IElementService elementService,
            IElementPublishingService elementPublishingService,
            AppCaches appCaches,
            ILogger<PostMigrationNotificationHandler> logger)
        {
            _contentService = contentService;
            _elementService = elementService;
            _elementPublishingService = elementPublishingService;
            _appCaches = appCaches;
            _logger = logger;
        }

        public async Task HandleAsync(MigrationPlansExecutedNotification notification, CancellationToken cancellationToken)
        {
            // Check if we have run the right migration, otherwise skip
            if (HasMigrationRun(notification.ExecutedPlans) is false)
            {
                return;
            }

            await PublishPackageContentAsync();
        }

        private async Task PublishPackageContentAsync()
        {
            // The package import leaves the dictionary items it creates missing from the by-key
            // lookups until the dictionary item cache is cleared or the site restarts, so every
            // dictionary value renders blank on a fresh install. This is an Umbraco bug, see
            // umbraco-bugs/package-migration-dictionary-items-stale-cache.md. Remove this
            // workaround once Umbraco fixes it.
            _appCaches.IsolatedCaches.ClearCache<IDictionaryItem>();
            _logger.LogInformation("Cleared the dictionary cache after the Clean package import");

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
