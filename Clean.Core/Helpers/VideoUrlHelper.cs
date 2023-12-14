using System;
using System.Linq;

namespace Clean.Core.Helpers;

public static class VideoUrlHelper
{
    public static string GetVideoId(string youtubeUrl)
    {
        if (Uri.TryCreate(youtubeUrl, UriKind.Absolute, out Uri uri))
        {
            if (uri.Host.Equals("www.youtube.com", StringComparison.OrdinalIgnoreCase)
                || uri.Host.Equals("youtube.com", StringComparison.OrdinalIgnoreCase))
            {
                var query = Microsoft.AspNetCore.WebUtilities.QueryHelpers.ParseQuery(uri.Query);
                if (query.ContainsKey("v"))
                {
                    return query["v"].ToString();
                }
            }
            else if (uri.Host.Equals("youtu.be", StringComparison.OrdinalIgnoreCase))
            {
                return uri.Segments.LastOrDefault();
            }
        }

        return null; // If the URL is not a valid YouTube video URL or doesn't contain the video ID.
    }
}
