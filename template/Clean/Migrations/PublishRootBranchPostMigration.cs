using System.Linq;
using Microsoft.Extensions.Logging;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.Migrations;

namespace Clean.Migrations
{
    public class PublishRootBranchPostMigration : MigrationBase
    {
        private readonly ILogger<PublishRootBranchPostMigration> _logger;
        private readonly IContentService _contentService;

        public PublishRootBranchPostMigration(
            ILogger<PublishRootBranchPostMigration> logger,
            IContentService contentService,
            IMigrationContext context) : base(context)
        {
            _logger = logger;
            _contentService = contentService;
        }

        protected override void Migrate()
        {
            var contentHome = _contentService.GetRootContent().FirstOrDefault(x => x.ContentType.Alias == "home");
            if (contentHome != null)
            {
                _contentService.PublishBranch(contentHome, PublishBranchFilter.All, new[] { "en-US" } );
            }
            else
            {
                _logger.LogWarning("The installed Home page was not found");
            }
        }
    }
}