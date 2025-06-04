using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Linq;
using System.Threading.Tasks;
using Umbraco.Cms.Core.Configuration.Models;
using Umbraco.Cms.Core.IO;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.PropertyEditors;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Core.Strings;
using Umbraco.Cms.Infrastructure.Migrations;
using Umbraco.Cms.Infrastructure.Packaging;

namespace Clean.Migrations
{
    public class ImportPackageXmlMigration : AsyncPackageMigrationBase
    {
        private readonly IContentService _contentService;
        private readonly ILogger<ImportPackageXmlMigration> _logger;

        public ImportPackageXmlMigration(
            IPackagingService packagingService,
            IMediaService mediaService,
            MediaFileManager mediaFileManager,
            MediaUrlGeneratorCollection mediaUrlGenerators,
            IShortStringHelper shortStringHelper,
            IContentTypeBaseServiceProvider contentTypeBaseServiceProvider,
            IMigrationContext context,
            IOptions<PackageMigrationSettings> packageMigrationSettings,
            IContentService contentService,
            ILogger<ImportPackageXmlMigration> logger)
            : base(packagingService,
                mediaService,
                mediaFileManager,
                mediaUrlGenerators,
                shortStringHelper,
                contentTypeBaseServiceProvider,
                context, packageMigrationSettings)
        {
            _contentService = contentService;
            _logger = logger;
        }

        protected async override Task MigrateAsync()
        {
            //import the xml package
            ImportPackage.FromEmbeddedResource(GetType()).Do();

            //publish the home page with all descendants
            await Task.Run(() =>
            {
                var contentHome = _contentService.GetRootContent().FirstOrDefault(x => x.ContentType.Alias == "home");
                if (contentHome != null)
                {
                    _contentService.PublishBranch(contentHome, PublishBranchFilter.All, new[] { "en-US" });
                }
                else
                {
                    _logger.LogWarning("The installed Home page was not found");
                }
            });
        }
    }
}