# Clean Starter Kit

## Regenerate Models Builder models after schema or package changes

`template/Clean.Models/*.generated.cs` is committed to source control. Clean.Blog runs
Models Builder in `SourceCodeManual` mode (`ModelsDirectory: ~/../Clean.Models`), so the models
only change when they are regenerated explicitly.

**Always regenerate the models and commit them** after either of these:

- a schema change: adding, removing or editing a document type, element type, media type,
  member type, composition or property (whether in the backoffice or through uSync files)
- a package version update: any change to the `Umbraco.Cms.*` package versions (major, minor or
  patch), so that the `Umbraco.ModelsBuilder.Embedded` version stamps match the shipped version

### How to regenerate

The same steps are documented for human contributors in
`.github/general-contributing.md` (section "Regenerating Models Builder Models"); keep the two in
sync.

1. Run Clean.Blog (`dotnet run` in `template/Clean.Blog`, https://localhost:44340). Wait for the
   site to finish starting and any unattended upgrade to complete.
2. Get a bearer token with the API client that `appsettings.Development.json` provisions
   (`uSync:Command:ClientId` / `uSync:Command:Secret`, created on startup by
   `Composing/ApiClientSetup.cs`):
   `POST https://localhost:44340/umbraco/management/api/v1/security/back-office/token`
   with form body `grant_type=client_credentials&client_id=<ClientId>&client_secret=<Secret>`.
3. Trigger generation:
   `POST https://localhost:44340/umbraco/management/api/v1/models-builder/build`
   with `Authorization: Bearer <token>`. Expect `200`.
   (Alternatively, use **Settings > Models Builder > Generate models** in the backoffice.)
4. Check `GET /umbraco/management/api/v1/models-builder/dashboard` reports `"lastError": null`.
5. Build `template/Clean.Models/Clean.Models.csproj`, review the diff in `template/Clean.Models`,
   and commit it. After a package-only update the diff should be just the version stamps; any
   other change means the schema and the committed models had drifted, so call it out.
