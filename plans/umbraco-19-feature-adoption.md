# Umbraco 19 feature adoption tracker

Every new feature in Umbraco 19 (19.0.0-beta1 and 19.0.0-rc1), whether Clean uses it yet, and
the work items for the ones it should. Update the **Status** column as items land, and link the PR.

Sources: Umbraco's
[Umbraco 19 upgrade notes](https://docs.umbraco.com/umbraco-cms/19.latest/get-started/upgrading-and-migrating/version-specific),
the [19.0.0-beta1 release](https://github.com/umbraco/Umbraco-CMS/releases/tag/release-19.0.0-beta1),
the [Umbraco CMS releases](https://github.com/umbraco/umbraco-cms/releases) (19.0.0-rc1) and
the [19.0.0 release notes](https://releases.umbraco.com/release/umbraco/Umbraco-CMS/19.0.0).
Last checked: 2026-11-13, against Umbraco 19.0.0-rc1 and Clean 19.0.0-rc02.

## Status key

- **Done**: Clean already uses it.
- **Automatic**: comes with Umbraco 19. Clean gets it without changes.
- **Not started**: Clean should use it. There is a work item below.
- **Optional**: Clean could use it, but it is not needed for a starter kit. Decide before starting.
- **Not applicable**: does not fit Clean as it is (single language, no segments, no backoffice
  extensions). The reason is in the table.

## Tracker

### Platform

| Feature | Umbraco PR | Status | Notes |
|---|---|---|---|
| .NET 11 | #23955, #24571 | Done | Clean 19.0.0-beta01 |
| Runtime async (Umbraco is compiled with it; projects opt in) | #24109 | Not started | Work item C |
| ImageSharp 4 as the default imaging package | #23334 | Automatic | Clean has no direct ImageSharp references |
| In-memory image cache on by default (`Imaging:Memory:Enabled`) | | Automatic | In the rc02 upgrade notes |
| Scheduled publishing aligned to the clock by default (`ScheduledPublishing:AlignToClock`) | | Automatic | In the rc02 upgrade notes |
| Entra ID SQL authentication (`Microsoft.Data.SqlClient.Extensions.Azure` shipped) | #24453 | Automatic | Clean uses SQLite for development |
| Kestrel profile first in `launchSettings.json` | #22427 | Done | Clean 19.0.0-rc02 |

### Search

| Feature | Umbraco PR | Status | Notes |
|---|---|---|---|
| Umbraco Search in core (`ISearcher`, Examine as default provider) | #23321 | Done | `ISiteSearchService` in `Clean.Core`, Clean 19.0.0-rc02 |
| Settings > Search dashboard with index health | #23321 | Done | Headless guide points to it |
| Deferred index build | | Automatic | |
| Block elements and reusable blocks indexed | | Automatic, to check | Work item D |
| Merged values from content indexers, file-to-text extension point | | Not applicable | No custom indexers or file indexing in Clean |
| External members indexed | | Not applicable | Clean has no members |

### Content editing

| Feature | Umbraco PR | Status | Notes |
|---|---|---|---|
| Library Elements (shared elements picked by an Element Picker) | | Done | Article categories, `Category Picker (multiple)` |
| Reusable content of blocks: a block in Block List, Block Grid, Single Block or the Rich Text Editor references a Library Element | #22448, #23195 | Not started | Work item A, Clean's headline Umbraco 19 feature |
| Transfer a block to the Library; Library action in the block Create bar | #22448 | Not started | Part of work item A |
| Document Blueprints in the Library, with folders | #23905, #23907 | Not started | Work item B |
| Blueprints limited to the document types that allow them | #23908 | Not started | Part of work item B |
| Blueprint access per user group and user | #23906 | Optional | Clean ships no user groups beyond the defaults |
| Single Block editor, interchangeable with Block List | #24144 | Optional | Work item E. Clean has no single-block property today |
| Blocks in the Rich Text Editor | #23195 | Optional | Work item E. `Rich Text (Standard)` has no blocks today |
| Min item count as a floor | #23693 | Automatic | Clean's Block Lists set no minimum |
| Default picker Data Types named after their editors | #24568 | Done | Clean 19.0.0-rc02, under `Umbraco Defaults` |
| Folders can be moved in the Document Type, Media Type, Member Type, Data Type and Blueprint trees | #23637 | Automatic | |
| Reference warnings on trash, delete and publish | #23625 | Automatic | Deleting a category used by an article now warns. Check during work item A |

### Multilingual and personalisation

| Feature | Umbraco PR | Status | Notes |
|---|---|---|---|
| "Allow editing shared content" permission per user group | #24022 | Not applicable | Clean has one language (`en-us`). The old setting was removed in rc02 |
| Scheduled publishing for all selected languages at once | #23375 | Not applicable | One language |
| Segment content travels with its language version and is validated on publish | #23060 | Not applicable | Clean has no segments |
| Segment variance for Elements | #24104 | Not applicable | Clean has no segments |

### Backoffice and security

| Feature | Umbraco PR | Status | Notes |
|---|---|---|---|
| Cookie-based backoffice login, session refresh on activity | #23484, #23791 | Automatic | The client-credentials API client in `ApiClientSetup.cs` still uses OpenID Connect and still works |
| Preview and trashed media use the backoffice cookie | #23698, #23616 | Automatic | |
| Environment permissions: deny schema changes through the Management API | #24372 | Optional | A production hardening tip for the docs, not a starter kit feature |
| Log Viewer copy button, user group picker paging, blueprint access in the users overview | #24209, #24136, #24140 | Automatic | |
| Action groups, read-only workspaces, `isReference` modals, entity action separators | #24421, #24353, #24389, #23998 | Not applicable | Backoffice extension APIs. Clean has no backoffice extensions |
| New login photo | #24544 | Automatic | |

### Headless

| Feature | Umbraco PR | Status | Notes |
|---|---|---|---|
| Delivery API OpenAPI operation IDs use an underscore (`GetContent2_0`) | | To check | Work item F. Clean's code does not use them; the Next.js example might |
| Delivery API output for reusable blocks | | To check | Work item F. Umbraco's notes do not say whether it changes |

## Work items

All work items are made on `feature/v19-native-rebuild`, the Clean 19.0.0-rc02 branch, alongside
the native rebuild. Do not create a branch per item.

```
git checkout feature/v19-native-rebuild
```

Commit each step separately so each work item can be reviewed on its own in the PR.

After any schema change, regenerate the Models Builder models and commit them (see `CLAUDE.md`).
After any change to the Library, sample content or Data Types, re-export uSync and regenerate the
embedded `package.zip` (step 10 of `plans/umbraco-19-native-rebuild.md`).

Suggested order: D, then A, B, F, C. E only if A shows a need for it.

### A. Reusable blocks in the main content

**Status:** Not started.

Goal: show Umbraco 19's main new feature in the sample site. An editor can save a Main Content
block to the Library and place the same block on several pages; editing it once updates every page.

1. In a running Clean.Blog, find how a Block List Data Type allows Library blocks. Umbraco's notes
   name the feature but no configuration key. Record the key or setting in this file.
2. Turn it on for `Main Content Block List` (key `b5922818-d8d8-43df-88ed-4582a24c0fa6`). Decide
   which block types may be reusable. A likely sample: a "newsletter sign-up" or "about the
   author" Rich Text block, or a Code Snippet reused on two articles.
3. Add the sample: one Library block in a new `Reusable Blocks` Library folder, placed on at least
   two pages in the sample content.
4. Check the Razor rendering in `Views/Partials/blocklist/Components/*.cshtml` and the block list
   default view renders a Library block the same as an inline block, including its settings
   (`hide`, spacing) and the `[HIDDEN]` label.
5. Check the reference warning: deleting the Library block or a category used by an article warns.
6. Search: a page that uses the Library block is found by text inside it (see D).
7. Package path: the exported `package.xml` carries the Library block and the sample pages that
   use it, and a fresh install of the `Clean` package keeps the link (the pages still reference the
   Library block, not a copy). Check `PostMigrationNotification.cs` publishes the new Library
   folder's elements, as it does the categories.
8. Docs: a "Reusable blocks" section in `.github/clean-features-blocks.md` with screenshots, and
   a line in `clean-features-backoffice.md` (Library section).

Open questions: is the opt-in per Data Type or per block type; can settings differ per page when
the content is shared; does uSync 19 export a Library block and its references cleanly.

Done when: the sample shows one Library block on two pages, editing it updates both, the
template and package install paths both keep it, and the docs describe it.

### B. Document Blueprints for articles

**Status:** Not started.

Goal: give editors a ready-made starting point for a new article, using Umbraco 19's Library
Blueprints.

1. Allow Blueprints on `article` (Umbraco 19 only lets you create Blueprints for document types
   that allow them). Decide whether `content` pages get one too.
2. Create a `Blueprints` folder in the Library and an "Article" Blueprint with the usual Main
   Content rows (intro Rich Text, Image, Rich Text), a placeholder summary and no categories.
3. Check uSync 19 exports and imports Blueprints in their new Library location, and record the
   folder it writes under `uSync/v19`.
4. Check whether Umbraco's package format carries Blueprints. If it does not, either create the
   Blueprint in the package migration or document that it is template-only.
5. Docs: how to create an article from the Blueprint, in `.github/clean-features-pages.md`.

Open questions: whether the package export supports Blueprints at all; whether a Blueprint should
reference the Library block from A.

Done when: "Create > Article from Blueprint" works on the template site and, if supported, on a
package install.

### C. Opt the projects into runtime async

**Status:** Not started.

Umbraco 19 is compiled with .NET 11 runtime async. Projects opt in with
`<Features>$(Features);runtime-async=on</Features>`.

1. Check whether a fresh `dotnet new umbraco` 19 project opts in. The native rebuild plan said to
   follow the baseline, and the baseline did not at rc1. If Umbraco's final 19.0.0 template adds
   it, follow that.
2. If adopting: add the property to `Clean.Core`, `Clean.Headless`, `Clean` and `Clean.Blog`
   (and the template's copy of `Clean.Blog`).
3. Build with zero warnings, run the template and package install tests, and check the site, the
   search and the headless endpoints.

Done when: the decision is recorded here, and if adopted, all projects build and every test path
passes.

### D. Check search finds text inside blocks

**Status:** Not started.

Umbraco 19 indexes block elements and reusable blocks. Clean's article text lives in Main Content
Rich Text blocks.

1. On a fresh template site, search for a word that only appears inside a Rich Text block of one
   article. Check it is found by the search page and by `GET /api/v1/search/getSearchResults`.
2. If it is not found, find which field in the published content index holds block text, and add
   it to the query in `Clean.Core/Services/SiteSearchService.cs`.
3. Record the result here. If it already works, mark D Done with no PR.

### E. Single Block and blocks in the Rich Text Editor (optional)

**Status:** Optional, not decided.

Clean has no property that holds exactly one block, and `Rich Text (Standard)` has no blocks.
Only take this on if A shows a reusable block is more natural inside rich text (for example a
call-out inside an article body), or if a page needs a single configurable block such as a page
header. Write a separate plan if it goes ahead.

### F. Headless checks for Umbraco 19

**Status:** Not started.

1. With the Delivery API on, fetch an article that uses the Library block from A, and record how
   the block appears in the JSON compared with an inline block.
2. Check the Next.js example linked from `.github/clean-headless-api.md` against the renamed
   Delivery API operation IDs (`GetContent2.0` is now `GetContent2_0`), if it uses a generated
   client. Tell its maintainer if it breaks; it is not in this repo.
3. Update `.github/clean-headless-api.md` with anything a frontend needs to know.
