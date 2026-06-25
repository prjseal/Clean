using System;
using System.Linq;
using System.Threading.Tasks;
using System.Xml.Linq;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.Migrations;

namespace Clean.Migrations;

public class CreateElementLibraryMigration : AsyncMigrationBase
{
    private readonly IElementContainerService _elementContainerService;
    private readonly IElementService _elementService;
    private readonly IContentTypeService _contentTypeService;

    public CreateElementLibraryMigration(
        IElementContainerService elementContainerService,
        IElementService elementService,
        IContentTypeService contentTypeService,
        IMigrationContext context)
        : base(context)
    {
        _elementContainerService = elementContainerService;
        _elementService = elementService;
        _contentTypeService = contentTypeService;
    }

    protected override async Task MigrateAsync()
    {
        var assembly = GetType().Assembly;

        var configs = assembly.GetManifestResourceNames()
            .Where(n => n.Contains(".ElementLibrary.") && n.EndsWith(".config"))
            .Select(name =>
            {
                using var stream = assembly.GetManifestResourceStream(name)!;
                return XDocument.Load(stream);
            })
            .ToList();

        // Create containers first
        foreach (var doc in configs.Where(d => d.Root?.Name.LocalName == "ElementContainer")
                                   .OrderBy(d => (int?)d.Root?.Element("SortOrder") ?? 0))
        {
            var key = Guid.Parse(doc.Root!.Attribute("Key")!.Value);
            var name = doc.Root.Attribute("Alias")!.Value;

            var existing = await _elementContainerService.GetAsync(key);
            if (existing != null)
                continue;

            await _elementContainerService.CreateAsync(key, name, null, Constants.Security.SuperUserKey);
        }

        // Create elements under their containers
        foreach (var doc in configs.Where(d => d.Root?.Name.LocalName == "Element")
                                   .OrderBy(d => (int?)d.Root?.Element("Info")?.Element("SortOrder") ?? 0))
        {
            var key = Guid.Parse(doc.Root!.Attribute("Key")!.Value);
            var info = doc.Root.Element("Info")!;
            var name = info.Element("NodeName")!.Attribute("Default")!.Value;
            var contentTypeAlias = info.Element("ContentType")!.Value;
            var parentKey = Guid.Parse(info.Element("Parent")!.Attribute("Key")!.Value);
            var sortOrder = int.Parse(info.Element("SortOrder")!.Value);

            if (_elementService.GetById(key) != null)
                continue;

            var contentType = _contentTypeService.Get(contentTypeAlias);
            if (contentType == null)
                continue;

            var container = await _elementContainerService.GetAsync(parentKey);
            if (container == null)
                continue;

            var element = new Element(name, container.Id, contentType)
            {
                Key = key,
                SortOrder = sortOrder
            };

            _elementService.Save(element);
            _elementService.Publish(element, Array.Empty<string>());
        }
    }
}
