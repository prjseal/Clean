using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;

namespace Clean.Core.Middleware;

/// <summary>
/// Middleware to add security headers to HTTP responses.
/// Addresses OWASP ZAP findings for missing Content-Security-Policy and X-Frame-Options headers.
/// </summary>
public class SecurityHeadersMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IConfiguration _configuration;

    public SecurityHeadersMiddleware(RequestDelegate next, IConfiguration configuration)
    {
        _next = next;
        _configuration = configuration;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Get configuration values
        var xFrameOptions = _configuration["SecurityHeaders:XFrameOptions"] ?? "SAMEORIGIN";
        var frameAncestors = _configuration["SecurityHeaders:FrameAncestors"] ?? "'self'";

        // X-Frame-Options header to prevent clickjacking (Issue #387)
        if (!context.Response.Headers.ContainsKey("X-Frame-Options"))
        {
            context.Response.Headers.Append("X-Frame-Options", xFrameOptions);
        }

        // Content Security Policy with frame-ancestors directive (Issues #386 and #387)
        if (!context.Response.Headers.ContainsKey("Content-Security-Policy"))
        {
            var cspPolicy = _configuration["SecurityHeaders:ContentSecurityPolicy"];

            if (string.IsNullOrEmpty(cspPolicy))
            {
                // Default CSP policy suitable for Umbraco CMS
                cspPolicy = $"default-src 'self'; " +
                           $"script-src 'self' 'unsafe-inline' 'unsafe-eval'; " +
                           $"style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
                           $"font-src 'self' data: https://fonts.gstatic.com; " +
                           $"img-src 'self' data: https:; " +
                           $"connect-src 'self'; " +
                           $"frame-ancestors {frameAncestors}; " +
                           $"base-uri 'self'; " +
                           $"form-action 'self'";
            }

            context.Response.Headers.Append("Content-Security-Policy", cspPolicy);
        }

        // Additional security headers
        if (!context.Response.Headers.ContainsKey("X-Content-Type-Options"))
        {
            context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
        }

        if (!context.Response.Headers.ContainsKey("X-XSS-Protection"))
        {
            context.Response.Headers.Append("X-XSS-Protection", "1; mode=block");
        }

        if (!context.Response.Headers.ContainsKey("Referrer-Policy"))
        {
            context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
        }

        if (!context.Response.Headers.ContainsKey("Permissions-Policy"))
        {
            context.Response.Headers.Append("Permissions-Policy", "geolocation=(), microphone=(), camera=()");
        }

        await _next(context);
    }
}
