using Clean.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Umbraco.Cms.Core.Composing;
using Umbraco.Cms.Core.DependencyInjection;
using Umbraco.Cms.Infrastructure.Manifest;
using Umbraco.Cms.Infrastructure.Migrations.Notifications;

namespace Clean
{
    public class CleanComposer : IComposer
    {
        public void Compose(IUmbracoBuilder builder)
        {
            builder.Services.AddSingleton<IPackageManifestReader, CleanManifestReader>();
            builder.AddNotificationAsyncHandler<MigrationPlansExecutedNotification, PostMigrationNotificationHandler>();
        }
    }
}