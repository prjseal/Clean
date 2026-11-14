# Dictionary items imported by a package migration can't be looked up by key until the site restarts

- **Status:** Not filed
- **Repository:** umbraco/Umbraco-CMS
- **Found:** 2026-11-14, Umbraco 19.0.0-rc1, Clean 19.0.0-rc02 (the NuGet package)
- **Clean workaround:** Yes, `template/Clean/Migrations/PostMigrationNotification.cs` (background in `plans/package-install-dictionary-cache-workaround.md`)
- **Background:** found while testing the published Clean 19.0.0-rc02 package on a fresh
  `dotnet new umbraco` site. The Clean template install isn't affected, because it imports with
  uSync instead of a package migration

The minimal repro below was run on 2026-11-14 with no Clean code. Its site was a fresh
`dotnet new umbraco` 19.0.0-rc1 site on SQLite. SQL Server hasn't been tried.

Everything below the line is the issue text, ready to paste.

---

## Title

Dictionary items imported by a package migration can't be looked up by key until the site restarts

## Which Umbraco version are you using?

19.0.0-rc1

## Bug summary

When a package migration imports dictionary items (`ImportPackage.FromEmbeddedResource(...)` with
a package.xml that has `<DictionaryItems>`), the items are saved to the database, but looking one
up by key returns nothing until the application restarts:

- `IDictionaryItemService.GetAsync("<key>")` returns `null`
- `ICultureDictionary["<key>"]`, and so `@Umbraco.GetDictionaryValue("<key>")` in views, returns
  an empty string

Listing the items still works: `IDictionaryItemService.GetDescendantsAsync(null)` returns them,
and the backoffice Translation section lists them. After a restart, the lookups by key return the
right values.

For a starter kit installed from NuGet, this means every dictionary-driven label on the site
renders blank on first boot: form labels, button text, paging links and the site name in page
titles. It stays that way until someone restarts the site.

## Specifics

- Umbraco 19.0.0-rc1, .NET 11, SQLite, unattended install
  (`dotnet new umbraco --development-database-type SQLite` with the unattended user options)
- The package migration runs during the unattended upgrade on first boot

### What's proven

- The rows are in `cmsDictionary` and `cmsLanguageText` with the right language (`en-US`, the
  site's only language) straight after the import.
- Lookups by key return nothing after the import, with no time limit: on one fresh install they
  were still empty 16 minutes after boot. Opening the dictionary in the backoffice doesn't change
  this.
- Restarting the application fixes it.
- Clearing the isolated cache for dictionary items once the application has started fixes it,
  without a restart:
  `AppCaches.IsolatedCaches.ClearCache<IDictionaryItem>()` in an
  `UmbracoApplicationStartedNotification` handler. Clearing `AppCaches.RuntimeCache` alone doesn't.
- `DistributedCache.RefreshAll(DictionaryCacheRefresher.UniqueId)` **doesn't** fix it, either in
  a `MigrationPlansExecutedNotification` handler or in an `UmbracoApplicationStartedNotification`
  handler.

### What's likely, but not proven

- The import looks each item up by key before creating it, and the miss is cached in the
  `IDictionaryItem` isolated cache. Saving the new item doesn't replace or clear that cached miss.
- It's unclear why `DictionaryCacheRefresher.RefreshAll` leaves that entry in place, when clearing
  the isolated cache directly removes it.

## Steps to reproduce

1. Create a site:
   `dotnet new umbraco -n ReproSite --friendly-name Administrator --email admin@example.com --password 1234567890 --development-database-type SQLite`
2. Add `Migrations/package.xml` and embed it
   (`<EmbeddedResource Include="Migrations/package.xml" />` in the `.csproj`):

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <umbPackage>
     <info>
       <package>
         <name>DictRepro</name>
       </package>
     </info>
     <DictionaryItems>
       <DictionaryItem Key="5f0c7a1e-2b3d-4c5e-8f90-a1b2c3d4e5f6" Name="Repro.Hello">
         <Value LanguageCultureAlias="en-US"><![CDATA[Hello from the package]]></Value>
       </DictionaryItem>
     </DictionaryItems>
   </umbPackage>
   ```

3. Add a package migration that imports it:

   ```csharp
   public class ReproPackageMigrationPlan : PackageMigrationPlan
   {
       public ReproPackageMigrationPlan() : base("DictRepro") { }

       protected override void DefinePlan() =>
           To<ImportReproPackage>(new Guid("0d6b1f8e-6a43-4c1f-9d1e-3b7a2c9e5f11"));
   }

   public class ImportReproPackage : AsyncPackageMigrationBase
   {
       public ImportReproPackage(IPackagingService packagingService, IMediaService mediaService,
           MediaFileManager mediaFileManager, MediaUrlGeneratorCollection mediaUrlGenerators,
           IShortStringHelper shortStringHelper, IContentTypeBaseServiceProvider contentTypeBaseServiceProvider,
           IMigrationContext context, IOptions<PackageMigrationSettings> packageMigrationSettings)
           : base(packagingService, mediaService, mediaFileManager, mediaUrlGenerators,
               shortStringHelper, contentTypeBaseServiceProvider, context, packageMigrationSettings)
       {
       }

       protected override Task MigrateAsync()
       {
           ImportPackage.FromEmbeddedResource(GetType()).Do();
           return Task.CompletedTask;
       }
   }
   ```

4. Add an endpoint that reads the item:

   ```csharp
   public class ReproController(ICultureDictionaryFactory cultureDictionaryFactory, IDictionaryItemService dictionaryItemService) : Controller
   {
       [HttpGet("/repro")]
       public async Task<IActionResult> Get()
       {
           var cultureDictionaryValue = cultureDictionaryFactory.CreateDictionary(CultureInfo.GetCultureInfo("en-US"))["Repro.Hello"];
           var item = await dictionaryItemService.GetAsync("Repro.Hello");
           var all = await dictionaryItemService.GetDescendantsAsync(null);
           return Content($"cultureDictionary=[{cultureDictionaryValue}]\n" +
               $"GetAsync=[{(item is null ? "null" : item.Translations.FirstOrDefault()?.Value)}]\n" +
               $"GetDescendantsAsync count={all.Count()}\n", "text/plain");
       }
   }
   ```

5. Run the site so the unattended install and the package migration run, wait for
   "Unattended upgrade completed successfully" in the log, and request `/repro`.
6. Restart the site and request `/repro` again.

## Expected result

On the first boot, straight after the package migration:

```text
cultureDictionary=[Hello from the package]
GetAsync=[Hello from the package]
GetDescendantsAsync count=1
```

## Actual result

On the first boot:

```text
cultureDictionary=[]
GetAsync=[null]
GetDescendantsAsync count=1
```

After a restart, the expected result.

## Suggestions (not verified)

- Clear (or update) the `IDictionaryItem` isolated cache when the package import saves dictionary
  items, or once the package migrations have run.
- Check whether `DictionaryCacheRefresher.RefreshAll` should clear the cached by-key entries too,
  since today it doesn't remove this one.
