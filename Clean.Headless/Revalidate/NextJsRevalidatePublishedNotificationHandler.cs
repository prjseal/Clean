using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Umbraco.Cms.Core.Events;
using Umbraco.Cms.Core.Notifications;
using Umbraco.Cms.Core.Web;
using Umbraco.Extensions;
using  Umbraco.Cms.Web.Common.PublishedModels;

namespace Clean.Headless.Revalidate
{
    public class NextJsRevalidatePublishedNotificationHandler : INotificationAsyncHandler<ContentPublishedNotification>
    {
        private readonly NextJsRevalidateService _revalidateService;
        private readonly ILogger<NextJsRevalidatePublishedNotificationHandler> _logger;
        private readonly NextJsRevalidateOptions _config;
        private readonly IUmbracoContextAccessor _umbracoContextAccessor;

        public NextJsRevalidatePublishedNotificationHandler(NextJsRevalidateService revalidateService,
            IOptions<NextJsRevalidateOptions> options, ILogger<NextJsRevalidatePublishedNotificationHandler> logger, 
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
            if (_config.Enabled)
            {
                if (notification.PublishedEntities.Any(x => x.Level is 1 or 2 && !x.GetValue<bool>("hideFromTopNavigation")))
                {
                    _logger.LogInformation("Navigation next js revalidation triggered");
                    await _revalidateService.ForNavigation();
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
        }
    }
}
