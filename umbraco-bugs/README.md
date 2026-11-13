# Umbraco bugs

Bugs found in Umbraco (or its packages) while working on Clean, written up ready to raise on
GitHub. One file per bug, named after the bug in kebab-case. Each file starts with its status,
then the issue text to paste.

When a bug is filed, set its status to "Filed" with the issue link. When Umbraco fixes it, set it
to "Fixed in <version>" and remove Clean's workaround, if it has one.

| Bug | Umbraco version | Status | Clean workaround |
|---|---|---|---|
| [SQLite lock race between the URL rebuild and Umbraco Search indexing](sqlite-url-rebuild-lock-race.md) | 19.0.0-rc1 | Not filed | Yes |
