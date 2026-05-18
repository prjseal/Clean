using Clean.Blog.Composing;
using Clean.Blog.Middleware;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

builder.CreateUmbracoBuilder()
    .AddBackOffice()
    .AddWebsite()
    .AddComposers()
    .Build();

WebApplication app = builder.Build();

await app.BootUmbracoAsync();

// Run package migrations and provision the backoffice API client before the
// Kestrel listener accepts requests, so CreateNuGetPackages.ps1's first /token
// call doesn't race against Umbraco's still-upgrading state.
await ApiClientSetup.RunPackageMigrationsAsync(app.Services, "Clean.Blog");
await ApiClientSetup.EnsureAsync(app.Services);

// Add security headers middleware
app.UseMiddleware<SecurityHeadersMiddleware>();

app.UseUmbraco()
    .WithMiddleware(u =>
    {
        u.UseBackOffice();
        u.UseWebsite();
    })
    .WithEndpoints(u =>
    {
        u.UseBackOfficeEndpoints();
        u.UseWebsiteEndpoints();
    });

await app.RunAsync();
