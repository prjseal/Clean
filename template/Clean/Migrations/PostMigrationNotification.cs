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
using Umbraco.Cms.Core.Packaging;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.Migrations;
using Umbraco.Cms.Infrastructure.Migrations.Notifications;

namespace Clean.Migrations
{
    public class PostMigrationNotificationHandler : INotificationAsyncHandler<MigrationPlansExecutedNotification>
    {
        private readonly IContentService _contentService;
        private readonly IElementService _elementService;
        private readonly ILogger<PostMigrationNotificationHandler> _logger;

        public PostMigrationNotificationHandler(
            IContentService contentService,
            IElementService elementService,
            ILogger<PostMigrationNotificationHandler> logger)
        {
            _contentService = contentService;
            _elementService = elementService;
            _logger = logger;
        }

        public Task HandleAsync(MigrationPlansExecutedNotification notification, CancellationToken cancellationToken)
        {
            // Check if we have run the right migration, otherwise skip  
            if (HasMigrationRun(notification.ExecutedPlans) is false)
            {
                return Task.CompletedTask;
            }

            var contentHome = _contentService.GetRootContent().FirstOrDefault(x => x.ContentType.Alias == "home");
            if (contentHome != null)
            {
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

            PublishPackageElements();

            return Task.CompletedTask;
        }

        // The package import creates element library items unpublished, so publish the
        // ones the package marks as published. Only the package's own elements are
        // touched, so existing elements on the site are left as they are.
        private void PublishPackageElements()
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

                var publishResult = _elementService.Publish(element, ["*"]);
                _logger.LogInformation("Result of publishing element '{elementName}' = {publishResult}", element.Name, publishResult.Result.ToString());
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
