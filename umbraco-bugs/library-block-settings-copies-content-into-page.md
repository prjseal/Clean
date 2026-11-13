# Opening a Library block's settings and saving the page copies the element's content into the page

- **Status:** Not filed
- **Repository:** umbraco/Umbraco-CMS
- **Found:** 2026-11-13, Umbraco 19.0.0-rc1, Clean 19.0.0-rc02
- **Clean workaround:** none. Recorded in the `[19.0.0-rc02]` CHANGELOG known issues
- **Background:** `plans/umbraco-19-feature-adoption.md`, work item A (reusable blocks), "Findings"

The steps to reproduce below are written from the findings in work item A, with a made-up word
("pineapple") to search for. Run them once on a fresh site before filing, and fill in the two
"Not checked" points if they are quick to answer.

Everything below the line is the issue text, ready to paste.

---

## Title

Block List: opening a reusable (Library) block's Settings in the page editor and saving the page stores a copy of the element's content in the page

## Which Umbraco version are you using?

19.0.0-rc1

## Bug summary

A reusable block (a block placed from the Library) is stored in the page's Block List value as a
layout entry that points at the Library element, with no `contentData` entry of its own:

```json
{ "contentKey": "<element key>", "isExternalContent": true, "key": "<new key>", "settingsKey": "<settings key>" }
```

The block's settings are the page's own `settingsData` entry, so each page can have different
settings for the same Library block.

If an editor opens that block's **Settings** dialog in the page editor and then saves the page,
the saved value also gets a `contentData` entry under the element's key, holding a copy of the
element's content, plus an `expose` entry for it. Saving the page without opening the Settings
dialog does not add the copy.

The page still renders the Library element, so the visible page is right. But the copy is
indexed with the page: after the Library element's text is changed and published, the page can
still be found in search by the old text, which is no longer on the page.

## Specifics

- Umbraco 19.0.0-rc1, .NET 11, SQLite
- Umbraco Search with the Examine provider, with
  `Umbraco:CMS:Indexing:IndexExternalBlockElements` set to `true` (so the Library element's text
  is indexed on the pages that use it)
- A Block List whose block type's element type has **Allow in Library** turned on
- Real example: the [Clean starter kit](https://github.com/prjseal/Clean) 19.0.0-rc02. Its
  `Rich Text Row` element type is allowed in the Library, and the `Join the Umbraco Community`
  Library element is placed on two articles

### What was observed

- The stored value before and after: no `contentData` entry for the Library block before; after
  opening its Settings dialog and saving, a `contentData` entry under the element's key with the
  element's content, and an `expose` entry.
- Saving the same page without opening the Settings dialog leaves the value as it was.
- The page keeps rendering the Library element's current content.
- The published content index picks up the copied text, so the page is still found by text that
  was later removed from the Library element.

### Not checked

- Whether the copy is ever updated (for example, by opening the Settings dialog again after the
  element changes), or whether it stays as the text at the time of the save.
- Whether the same happens in a Block Grid, a Single Block or a Rich Text Editor block.
- Which part of the backoffice adds the entry.
- Whether the copy needs a change in the Settings dialog, or whether opening and closing it is
  enough.

## Steps to reproduce

1. On a site with Umbraco Search, set `Umbraco:CMS:Indexing:IndexExternalBlockElements` to `true`.
2. Turn on **Allow in Library** for an element type used as a Block List block type.
3. Create a Library element of that type containing a distinctive word, for example "pineapple",
   and publish it.
4. On a page, add the block from the Library tab of the block picker. Save and publish the page.
5. Check the page's stored Block List value (Management API, or the database): the layout entry
   has `isExternalContent: true` and there is no `contentData` entry for it.
6. Open the block's **Settings** dialog in the page editor and close it, then save and publish the
   page.
7. Check the stored value again: there is now a `contentData` entry under the element's key with a
   copy of the element's content, and an `expose` entry.
8. Change the Library element's text from "pineapple" to "banana" and publish it.
9. Search for "pineapple". The page is still found, although it now renders "banana".

## Expected result / actual result

Expected: the page keeps only the reference to the Library element and its own settings. Editing
a reusable block's settings never stores the element's content in the page.

Actual: opening the Settings dialog and saving the page stores a copy of the element's content,
which search then indexes as part of the page.

## Suggestions

These are only suggestions.

- When the block's content is external (`isExternalContent: true`), do not write a `contentData`
  or `expose` entry for it when the Settings dialog is submitted, or strip them on save.
- Ignore `contentData` entries for external blocks when indexing a page, so a stray copy cannot
  be found.
