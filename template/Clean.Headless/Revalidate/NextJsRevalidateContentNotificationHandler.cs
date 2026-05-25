using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Umbraco.Cms.Core.Events;
using Umbraco.Cms.Core.Notifications;
using Umbraco.Cms.Core.Web;
using Umbraco.Extensions;

namespace Clean.Headless.Revalidate
{
    public class NextJsRevalidateContentNotificationHandler :
        INotificationAsyncHandler<ContentPublishedNotification>,
        INotificationAsyncHandler<ContentUnpublishedNotification>,
        INotificationAsyncHandler<ContentDeletedNotification>,
        INotificationAsyncHandler<ContentMovedToRecycleBinNotification>
    {
        private readonly NextJsRevalidateService _revalidateService;
        private readonly ILogger<NextJsRevalidateContentNotificationHandler> _logger;
        private readonly NextJsRevalidateOptions _config;
        private readonly IUmbracoContextAccessor _umbracoContextAccessor;

        public NextJsRevalidateContentNotificationHandler(NextJsRevalidateService revalidateService,
            IOptions<NextJsRevalidateOptions> options, ILogger<NextJsRevalidateContentNotificationHandler> logger,
            IUmbracoContextAccessor umbracoContextAccessor)
        {
            _revalidateService = revalidateService;
            _config = options.Value;
            _logger = logger;
            _umbracoContextAccessor = umbracoContextAccessor;
        }

        private readonly string[] _allowedContentContentType =
            new string[] { "content", "home", "contact", "articleList", "article" };

        public async Task HandleAsync(ContentPublishedNotification notification, CancellationToken cancellationToken)
        {
            if (!_config.Enabled) return;

            if (notification.PublishedEntities.Any(x => x.Level is 1 or 2 && !x.GetValue<bool>("hideFromTopNavigation")))
            {
                _logger.LogInformation("Navigation next js revalidation triggered");
                await _revalidateService.ForNavigation();
            }

            if (notification.PublishedEntities.Any(x => x.ContentType.Alias is "article" or "articleList"))
            {
                _logger.LogInformation("Articles next js revalidation triggered");
                await _revalidateService.UpdateArticles();
            }

            foreach (var content in notification.PublishedEntities)
            {
                if (_allowedContentContentType.Any(x => x == content.ContentType.Alias))
                {
                    if (_umbracoContextAccessor.TryGetUmbracoContext(out var umbracoContext) && umbracoContext.Content != null)
                    {
                        var publishedContent = umbracoContext.Content.GetById(content.Id);
                        if (publishedContent != null)
                        {
                            var path = publishedContent.Url();
                            _logger.LogInformation($"Web Content next js revalidation triggered for path {path}");
                            await _revalidateService.ForContent(path);
                        }
                    }
                }
            }
        }

        public async Task HandleAsync(ContentUnpublishedNotification notification, CancellationToken cancellationToken)
        {
            if (!_config.Enabled) return;

            if (notification.UnpublishedEntities.Any(x => _allowedContentContentType.Contains(x.ContentType.Alias)))
            {
                _logger.LogInformation("Next.js revalidation triggered for unpublished content.");
                await _revalidateService.IsUnpublished();
            }
        }

        public async Task HandleAsync(ContentMovedToRecycleBinNotification notification, CancellationToken cancellationToken)
        {
            if (!_config.Enabled) return;

            if (notification.MoveInfoCollection.Any(x => _allowedContentContentType.Contains(x.Entity.ContentType.Alias)))
            {
                _logger.LogInformation("Next.js revalidation triggered for trashed content.");
                await _revalidateService.IsTrashed();
            }
        }

        public async Task HandleAsync(ContentDeletedNotification notification, CancellationToken cancellationToken)
        {
            if (!_config.Enabled) return;

            if (notification.DeletedEntities.Any(x => _allowedContentContentType.Contains(x.ContentType.Alias)))
            {
                _logger.LogInformation("Next.js revalidation triggered for deleted content.");
                await _revalidateService.IsDeleted();
            }
        }
    }
}
