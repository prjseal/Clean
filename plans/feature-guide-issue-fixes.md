# Fix the issues found while writing the feature guide

## Context

Writing the feature guide (`.github/clean-features*.md`) against a running Clean.Blog site turned up
six things to look at. Issue 1 turned out to be intended behaviour and stays as it is; the other
five are problems. The guide currently documents them as they are. This plan fixes them on the
`feature/v19-native-rebuild` branch, so they ship in 19.0.0-rc02, and then updates the guide.

| # | Issue | Evidence |
|---|-------|----------|
| 1 | Every sample page renders `<meta name="robots" content="NOFOLLOW,NOINDEX" />`. **Intended, no change** (see Decisions) | Every `uSync/v19/Content/*.config` (except `xmlsitemap.config`, which has no SEO fields) and every page in `package.zip` stores `0` for both `isIndexable` and `isFollowable` |
| 2 | `og:image` and `twitter:image` point to `/socialimage.png`, which does not exist (404) | `Views/Partials/metaData.cshtml`; there is no `socialimage*` file anywhere under `template/` |
| 3 | The Error page is not used for 404s; a missing URL shows Umbraco's built-in "Page Not Found" | No `Error404Collection` config and no last chance finder. The package install cannot rely on config the site does not have |
| 4 | "Hide From Search" (`umbracoNaviHide`) does not keep a page out of search results | `SiteSearchService.GetFilters()` only filters out the `error`, `search` and `xMLSitemap` content types |
| 5 | Three dictionary items are not used by any view: `ArticleList.ViewAll`, `Paging.Page`, `Paging.Of` | `grep` over `Clean.Blog/Views` and `Clean.Core` |
| 6 | `.github/clean-documentation.md` links to `#technical-references`, which does not exist | Its table of contents |

### Decisions

- **Same branch.** The user asked for this work on `feature/v19-native-rebuild`, not a new branch
  from `develop` (the repo has no `develop`; `dev/v19` is the v19 integration branch). This is a
  deliberate exception to the usual "branch from a freshly pulled `develop`" rule.
- **Robots defaults (issue 1): no change.** The sample content stays `NOFOLLOW,NOINDEX` on purpose,
  so a test site that gets deployed is not indexed. New pages must default to `FOLLOW,INDEX`, and
  they already do. This was checked against the code:
  - `isIndexable` and `isFollowable` use the **Toggle (default on)** Data Type
    (`fccec1e1-0057-48ca-b9bf-184e00758a58`), configured `"default": true` in both
    `uSync/v19/DataTypes/ToggleDefaultOn.config` and `package.zip`.
  - The Umbraco 19.0.0-rc1 backoffice applies that setting to new documents:
    `UmbTrueFalsePropertyValuePreset` returns the `default` config value when the property has no
    value yet. So a page created in the backoffice opens with both toggles on and renders
    `FOLLOW,INDEX` once published.
  - The sample pages store an explicit `0`, so the preset does not touch them.
  - `metaData.cshtml` reads the page's own toggles, or the nearest ancestor's for a page without
    SEO controls (XML Sitemap inherits from Home).
  - Known gap, left as is (see Out of scope): the preset is a backoffice feature. A page created in
    code (`IContentService`) or through the Management API without these values has no value,
    `Value<bool>` returns `false`, and the page renders `NOFOLLOW,NOINDEX`.
- **Social image (issue 2).** Do not ship a `socialimage.png`. Use the page's own **Main Image**,
  falling back to the Home page's Main Image, cropped to 1200 × 630. If neither has an image, leave
  the image tags out rather than point at a missing file.
- **404 page (issue 3).** Add a last chance content finder in `Clean.Core`, so it works for template
  sites and package installs alike. It honours `Umbraco:CMS:Content:Error404Collection` first, so a
  site that configures its own 404 page keeps it.
- **Hide From Search (issue 4).** Filter in the search query, not after it, so the total count and
  paging stay correct for both the search page and `GET /api/v1/search/getSearchResults`. The
  toggle applies to the page itself only, matching `IsVisible()`; pages below it are unaffected.
- **Unused dictionary items (issue 5).** Keep any item the reference headless front end
  (`hifi-phil/clean-headless`) uses; delete the rest.
- **CHANGELOG.** `19.0.0-rc02` is not tagged yet (the latest tag is `v19.0.0-rc01`), so add the
  fixes to the existing `## [19.0.0-rc02]` entry. No version bump.

## Implementation

One commit per numbered step, as `Paul Seal <prjseal@gmail.com>`. No assistant attribution in
commit messages.

### 0. Branch

```bash
git checkout feature/v19-native-rebuild
git pull
```

### 1. Commit the feature guide as it stands

The guide and its screenshots are uncommitted in the working tree:

- `.github/clean-features.md`, `clean-features-pages.md`, `clean-features-blocks.md`,
  `clean-features-seo-and-navigation.md`, `clean-features-backoffice.md`
- `.github/images/frontend/**`
- the edits to `README.md` and `.github/clean-documentation.md`

Commit them on their own ("Add the feature guide with website screenshots"), before any fix, so
the later doc changes show up as a clear diff.

### 2. Robots defaults (issue 1): check only, no commit

Do not change the sample content's `isIndexable`/`isFollowable` values. Confirm the behaviour on
the running site instead:

1. Delete `template/Clean.Blog/umbraco/Data`, run Clean.Blog, and let the first-boot uSync import
   finish with no errors.
2. The sample pages render `NOFOLLOW,NOINDEX`: `/`, `/about/`, `/blog/`, `/blog/codegarden-2026/`,
   `/authors/paul-seal/`, `/contact/`, `/error/`, `/search/`. (`/xmlsitemap/` writes XML, so it has
   no tag.)
3. In the backoffice, create a new Content page under Home. Its SEO tab opens with Is Indexable and
   Is Followable both on. Publish it and check it renders `FOLLOW,INDEX`.
4. Delete the test page (and empty it from the recycle bin), and check `git status` shows no
   `uSync/v19/Content` change.

If step 3 does not show both toggles on, stop and report it: the decision rests on that preset.

### 3. Social sharing image (issue 2)

In `template/Clean.Blog/Views/Partials/metaData.cshtml`:

- Pick the image: the page's Main Image if the page is `IMainImageControls` and has one, otherwise
  the Home page's Main Image.
- Build an absolute URL from `GetCropUrl(width: 1200, height: 630)` and the existing
  `domainAddress`. Check that the image it returns really is 1200 × 630 (a crop, not a resize that
  keeps the aspect ratio). If it is not, pass the crop mode explicitly.
- Write `og:image`, `og:image:width` (`1200`), `og:image:height` (`630`) and `twitter:image` from
  it. Drop `og:image:type`: the crop URL's format is not always PNG.
- If there is no image, write none of these tags.

Remove every reference to `socialimage.png` under `template/` (`git grep socialimage`).

The `Clean` package carries this view in its embedded `package.zip`, so step 8 picks it up.

### 4. Error page for 404s (issue 3)

Read `Umbraco.Core.xml`, `Umbraco.Infrastructure.xml` and `Umbraco.Web.Website.xml` in
`~/.nuget/packages/umbraco.cms.*/19.0.0-rc1/lib/net11.0/` for the exact signatures first. What is
known:

- `IContentLastChanceFinder` (`Umbraco.Cms.Core.Routing`) with `TryFindContent(IPublishedRequestBuilder)`.
- `ContentFinderByConfigured404` (`Umbraco.Cms.Core.Routing`, in Umbraco.Infrastructure) is the
  default last chance finder. Its constructor takes `ILogger<>`, `IEntityService`,
  `IOptionsMonitor<ContentSettings>`, `IVariationContextAccessor`, `IUmbracoContextAccessor`,
  `IDocumentUrlService`, `IPublishedContentCache`, `IDocumentNavigationQueryService` and
  `IMediaNavigationQueryService`.
- `SetContentLastChanceFinder<T>()` and a factory overload are in `WebsiteUmbracoBuilderExtensions`.
- `SetIs404()` is an extension on `IPublishedRequestBuilder`.

Build:

1. `template/Clean.Core/Routing/ErrorPageLastChanceFinder.cs` implementing `IContentLastChanceFinder`
   (file-scoped namespace, primary constructor):
   1. Call a `ContentFinderByConfigured404` instance first. If it finds content, return its result.
   2. Otherwise find the site root for the request: the root of the matched domain if there is one,
      else the first published root node of type `home`. Use `IDocumentNavigationQueryService` and
      `IPublishedContentCache`, not obsolete APIs.
   3. Take the first published child of that root whose content type alias is `error`.
   4. If there is one, set it as the request's published content, call `SetIs404()`, and return
      `true`. Otherwise return `false`.
2. Register it in `CleanCoreComposer` with `builder.SetContentLastChanceFinder(...)`, using the
   factory overload to create the inner `ContentFinderByConfigured404` with
   `ActivatorUtilities.CreateInstance`.
3. Check:
   - `curl -sk -o /dev/null -w "%{http_code}" https://localhost:44340/does-not-exist/` gives `404`,
     and the body is the Clean Error page ("Page not found").
   - Existing pages still give `200`.
   - Setting `Error404Collection` in `appsettings.Local.json` to another page makes that page the
     404 page. Remove the setting afterwards; do not commit it.
   - The Delivery API and the headless endpoints still respond.

### 5. Hide From Search in search results (issue 4)

In `template/Clean.Core/Services/SiteSearchService.cs`:

1. Find out how Umbraco Search indexes a True/false property: its field name (expected to be the
   property alias, `umbracoNaviHide`) and its value type (expected to be an integer, `0`/`1`).
   Read the `IPropertyValueHandler` docs in `Umbraco.Core.xml`, and look at an indexed document in
   **Settings > Search** in the backoffice.
2. Add a negated filter for hidden pages to `GetFilters()`, next to the content type filter. For an
   integer field: `new IntegerExactFilter("umbracoNaviHide", [1], Negate: true)`. Use the filter
   type that matches what step 1 found.
3. A negated filter must keep documents that do not have the field at all (Home has no Visibility
   Controls). Confirm the Home page ("Clean Starter Kit") still appears when searching for
   `umbraco`.
4. If the property cannot be filtered on, fall back to a negated `KeywordFilter` on
   `Constants.Search.FieldNames.Id` with the keys of the published pages that have
   `umbracoNaviHide` on. Do **not** filter the results after the query: it breaks `Total` and
   paging.
5. Check on the running site, then put the content back and do not commit the change:
   - Turn on Hide From Search on the **Meetups** article and publish.
   - `/search/?q=umbraco` no longer lists Meetups, and the count drops from 11 to 10.
   - `GET /api/v1/search/getSearchResults?searchQuery=umbraco` gives the same.
   - Turn it off again and publish, and check `git status` shows no `uSync/v19/Content` change.

### 6. Unused dictionary items (issue 5)

1. Search `hifi-phil/clean-headless` for each key, read-only, for example
   `gh search code --repo hifi-phil/clean-headless "ArticleList.ViewAll"` (repeat for
   `Paging.Page` and `Paging.Of`).
2. Keep any key the headless front end uses. Delete the uSync file for each one it does not
   (`uSync/v19/Dictionary/articlelist.viewall.config`, `paging.page.config`, `paging.of.config`),
   and delete the item on the running site so step 8's export matches.
3. Record which keys were kept and why in the commit message.

### 7. Broken anchor in the documentation index (issue 6)

In `.github/clean-documentation.md`, remove the `- [Technical References](#technical-references)`
line from the table of contents. There is no such section.

### 8. Regenerate the embedded package

Run `.github/workflows/powershell/CreateNuGetPackages.ps1` locally with version `19.0.0-rc02`, as
for the previous rc02 regeneration. Commit the new `template/Clean/Migrations/package.zip`. Check its
`package.xml`:

- the sample pages still store `0` for `isIndexable` and `isFollowable`, and the
  `Toggle (default on)` Data Type still has `"default":true`
- the `metaData` partial view has the step 3 markup and no `socialimage.png`
- the dictionary items match step 6

### 9. Regenerate Models Builder models

Steps 3 to 6 change no schema, so the models should not change. Follow `CLAUDE.md` ("How to
regenerate") only if a step did change a document type; otherwise skip this step and say so.

### 10. Update the feature guide

- `.github/clean-features-seo-and-navigation.md`
  - Keep the "Robots settings in the sample content" warning: it already says the sample pages are
    off on purpose and new pages default to on. Add one sentence: the default comes from the
    backoffice, so a page created in code or through the Management API without these values
    renders `NOFOLLOW,NOINDEX` until they are set.
  - Replace the "Social sharing image" note with how the image is chosen (Main Image, then Home's
    Main Image, cropped to 1200 × 630, left out if there is none). Update the example `<head>`
    block to match.
  - In Visibility, say Hide From Search now also keeps the page out of search results, and remove
    the sentence saying it does not.
  - Update the dictionary table for step 6: remove deleted rows, or keep them as "used by the
    headless front end".
- `.github/clean-features-pages.md`
  - Error: say a missing URL now shows the Error page with a 404 status, found automatically as
    the first Error page under Home, and that `Error404Collection` still takes precedence. Keep the
    config example, reframed as the way to choose a different page.
  - Search: add that pages with Hide From Search turned on are left out.
- `.github/clean-features.md`: add "a 404 page" to the visitor features list.
- **Screenshots.** No changes. The SEO tab screenshots in
  `.github/images/backoffice/content/*/seo.png` show both toggles off, which is correct for the
  sample content.

### 11. CHANGELOG

In the existing `## [19.0.0-rc02]` entry, under `### Fixed`:

- Missing pages show the Clean Error page with a 404 status, unless `Error404Collection` sets another page
- Pages with Hide From Search turned on are left out of the search page and the search API
- The social sharing image tags use the page's Main Image instead of a `/socialimage.png` that did not exist

Under `### Removed`, list any dictionary items deleted in step 6.

## Out of scope

- An `og:title` fallback when Meta Name is empty (today it renders an empty `og:title`)
- Using `Paging.Page`/`Paging.Of` in the pagination view
- A `robots.txt` (the guide already shows how to add one)
- Changing what `IsVisible()` or the Visibility toggles mean
- Changing the sample content's robots values (they stay `NOFOLLOW,NOINDEX` on purpose)
- Defaulting `INDEX`/`FOLLOW` for pages created outside the backoffice. It would mean treating "no
  value" as on in `metaData.cshtml`, which needs care: the sample pages store `0`, and the change
  must not make them indexable. Revisit if pages are commonly created through the API

## Verification

1. `dotnet build template/Clean.sln` and `template-pack.sln`: zero warnings, zero errors.
2. Fresh template path: delete `umbraco/Data`, run Clean.Blog, first-boot import clean, every page
   in the Home tree renders `NOFOLLOW,NOINDEX`, and a new page created in the backoffice renders
   `FOLLOW,INDEX` (step 2).
3. `curl` checks:
   - `/does-not-exist/`: status `404`, Clean's Error page
   - `/`: `og:image` is an absolute crop URL to Home's Main Image, and that URL returns `200`
   - `/blog/codegarden-2026/`: `og:image` uses the article's own Main Image
4. Search: the step 5 checks pass, and Home still appears in results.
5. `git grep socialimage -- template` finds nothing.
6. Package path: run `Test-PackageInstallation.ps1` with the local `Clean` 19.0.0-rc02 package. The
   installed site renders, a missing URL shows the Error page with a 404, and the sample
   pages render `NOFOLLOW,NOINDEX`.
7. The link checker used for the feature guide (every relative link, anchor and image in
   `.github/clean-features*.md` and `clean-documentation.md` resolves) reports no problems.
8. Commits as described above. Do not push or open a PR.
