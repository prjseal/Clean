using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;

namespace Clean.Blog.Middleware;

/// <summary>
/// Middleware to add security headers to HTTP responses following OWASP best practices.
/// Addresses OWASP ZAP findings for missing Content-Security-Policy and X-Frame-Options headers.
/// </summary>
public class SecurityHeadersMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IConfiguration _configuration;

    // Default CSP policy suitable for Umbraco CMS
    private const string DefaultCspPolicy =
        "default-src 'self'; " +
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " +
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
        "font-src 'self' data: https://fonts.gstatic.com; " +
        "img-src 'self' data: https:; " +
        "connect-src 'self'; " +
        "frame-ancestors 'self'; " +
        "base-uri 'self'; " +
        "form-action 'self'";

    public SecurityHeadersMiddleware(RequestDelegate next, IConfiguration configuration)
    {
        _next = next;
        _configuration = configuration;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // X-Frame-Options: Prevents clickjacking attacks (Issue #387)
        // Hardcoded to SAMEORIGIN as this should always be set for CMS applications
        if (!context.Response.Headers.ContainsKey("X-Frame-Options"))
        {
            context.Response.Headers.Append("X-Frame-Options", "SAMEORIGIN");
        }

        // Content-Security-Policy: Configurable to allow environment-specific adjustments (Issues #386 and #387)
        if (!context.Response.Headers.ContainsKey("Content-Security-Policy"))
        {
            var cspPolicy = _configuration["SecurityHeaders:ContentSecurityPolicy"];
            if (string.IsNullOrWhiteSpace(cspPolicy))
            {
                cspPolicy = DefaultCspPolicy;
            }
            context.Response.Headers.Append("Content-Security-Policy", cspPolicy);
        }

        // X-Content-Type-Options: Prevents MIME-sniffing attacks
        if (!context.Response.Headers.ContainsKey("X-Content-Type-Options"))
        {
            context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
        }

        // X-XSS-Protection: Legacy XSS protection (deprecated but still recommended for older browsers)
        if (!context.Response.Headers.ContainsKey("X-XSS-Protection"))
        {
            context.Response.Headers.Append("X-XSS-Protection", "1; mode=block");
        }

        // Referrer-Policy: Controls how much referrer information is shared
        if (!context.Response.Headers.ContainsKey("Referrer-Policy"))
        {
            context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
        }

        // Permissions-Policy: Controls browser features and APIs
        if (!context.Response.Headers.ContainsKey("Permissions-Policy"))
        {
            context.Response.Headers.Append("Permissions-Policy", "geolocation=(), microphone=(), camera=()");
        }

        // Strict-Transport-Security (HSTS): Forces HTTPS (only applied on HTTPS connections)
        if (context.Request.IsHttps && !context.Response.Headers.ContainsKey("Strict-Transport-Security"))
        {
            // max-age=31536000 (1 year), includeSubDomains for all subdomains
            context.Response.Headers.Append("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
        }

        await _next(context);
    }
}
