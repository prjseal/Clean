# Package install repro

Scripts that install the `Clean` package on a fresh SQLite database again and again, with disk
load during each boot, to catch first-boot failures that only happen some of the time. They were
written for the lock race in `plans/package-install-boot-lock-race.md`
(`umbraco-bugs/sqlite-url-rebuild-lock-race.md`): before the fix, about 1 boot in 5 to 10 failed
under load.

Needs Git Bash, Node.js, the .NET SDK, and the `Umbraco.Templates` version that matches Clean.

| Script | What it does |
|---|---|
| `setup.sh <work dir> [version]` | Clears the NuGet cache for the version, creates `ReproSite` in the work dir with the `Clean` package from `.artifacts/nuget`, turns on Debug logging for locking, scoping and Umbraco Search, builds it, and copies the other two scripts into the work dir |
| `install-loop.sh <max runs> [nostop]` | Run from the work dir. Each run deletes the database, boots the site while copying a large folder in the background, and reports `ok`, `FAILED`, `ERROR` or `timeout` with the number of pages published. Keeps each run's log in `runs/`. Stops at the first failure unless `nostop` is given |
| `timeline.mjs <log> [from] [to]` | Prints an Umbraco JSON log as a timeline (time, thread, level, logger, message) |

```bash
# From the repo root, after CreateNuGetPackages.ps1 -Version 19.0.0-rc02
tools/package-install-repro/setup.sh /path/outside/the/repo/repro 19.0.0-rc02
cd /path/outside/the/repo/repro
./install-loop.sh 30 nostop
node timeline.mjs runs/run1.json | grep -E "Rebuilding all|will be published|Unattended upgrade"
```

`install-loop.sh` uses the newest `umbraco.cms.staticassets` folder in the NuGet cache for the disk
load. Set `STRESS_SRC` to use another large folder. Use a work folder outside the repo: each
`ReproSite` is a full Umbraco site.
