using Clean.Blog.Migrations;
using Umbraco.Cms.Core.Composing;
using Umbraco.Cms.Core.DependencyInjection;
using Umbraco.Cms.Core.Notifications;
using Umbraco.Cms.Infrastructure.Migrations.Notifications;

namespace Clean.Blog.Composing;

public class BlogComposer : IComposer
{
    public void Compose(IUmbracoBuilder builder)
    {
        builder.AddNotificationAsyncHandler<MigrationPlansExecutedNotification, PostMigrationNotificationHandler>();
        builder.AddNotificationAsyncHandler<UmbracoApplicationStartedNotification, ApiClientSetupHandler>();
    }
}
