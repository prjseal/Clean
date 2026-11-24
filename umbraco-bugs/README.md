# Umbraco bugs

Bugs found in Umbraco (or its packages) while working on Clean, written up ready to raise on
GitHub. One file per bug, named after the bug in kebab-case. Each file starts with its status,
then the issue text to paste.

When a bug is filed, set its status to "Filed" with the issue link. When Umbraco fixes it, set it
to "Fixed in <version>" and remove Clean's workaround, if it has one.

| Bug | Umbraco version | Status | Clean workaround |
|---|---|---|---|
| [SQLite lock race between the URL rebuild and Umbraco Search indexing](sqlite-url-rebuild-lock-race.md) | 19.0.0-rc1 | Fixed in 19.0.0-rc2 | Removed |
| [Opening a Library block's settings and saving the page copies the element's content into the page](library-block-settings-copies-content-into-page.md) | 19.0.0-rc1 | Not filed (rc2 may fix it, unverified) | No |
| [Dictionary items imported by a package migration can't be looked up by key until the site restarts](package-migration-dictionary-items-stale-cache.md) | 19.0.0-rc1 | Not filed | Yes |
