using System.ComponentModel.DataAnnotations;

namespace Clean.Headless.Revalidate
{
    public class NextJsRevalidateOptions
    {
        [Required]
        public bool Enabled { get; set; }
        
        public string? WebHookUrls { get; set; } = null;

        public string WebHookSecret { get; set; } = string.Empty;

    }
}