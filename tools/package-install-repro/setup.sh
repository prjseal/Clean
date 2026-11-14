#!/usr/bin/env bash
# Creates a fresh Umbraco site with the Clean package from .artifacts/nuget, with Debug logging on
# the locking, scoping and Umbraco Search loggers, ready for install-loop.sh.
#
# Usage (Git Bash): tools/package-install-repro/setup.sh <work dir> [Clean version]
#   <work dir>       a folder outside the repo, e.g. the session scratchpad. ReproSite is created in it.
#   [Clean version]  defaults to 19.0.0-rc02. Build it first with CreateNuGetPackages.ps1.
#
# Needs the Umbraco.Templates version that matches Clean (dotnet new install Umbraco.Templates@<v>).
set -euo pipefail

WORK="${1:?Usage: setup.sh <work dir> [Clean version]}"
VERSION="${2:-19.0.0-rc02}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FEED="$REPO/.artifacts/nuget"

if [ ! -f "$FEED/Clean.$VERSION.nupkg" ]; then
  echo "No $FEED/Clean.$VERSION.nupkg. Run .github/workflows/powershell/CreateNuGetPackages.ps1 -Version $VERSION first." >&2
  exit 1
fi

# NuGet uses the global packages cache before the local feed, so drop any earlier build of this version
NUGET_PACKAGES_DIR="${NUGET_PACKAGES:-$HOME/.nuget/packages}"
for p in clean clean.core clean.headless; do
  rm -rf "${NUGET_PACKAGES_DIR:?}/$p/${VERSION:?}"
done

mkdir -p "$WORK"
cd "$WORK"
cp "$REPO/tools/package-install-repro/install-loop.sh" "$REPO/tools/package-install-repro/timeline.mjs" .
chmod +x install-loop.sh

dotnet new umbraco --force -n ReproSite --friendly-name "Administrator" --email "admin@example.com" \
  --password "1234567890" --development-database-type SQLite
dotnet add ReproSite package Clean --version "$VERSION" --source "$FEED"

# Debug logging for the loggers that show the lock overlap
node -e '
const fs = require("fs");
const p = "ReproSite/appsettings.Development.json";
const j = JSON.parse(fs.readFileSync(p, "utf8"));
j.Serilog.MinimumLevel.Override = {
  "Umbraco.Cms.Core.Scoping": "Debug",
  "Umbraco.Cms.Infrastructure.Scoping": "Debug",
  "Umbraco.Cms.Persistence.Sqlite": "Debug",
  "Umbraco.Cms.Core.DistributedLocking": "Debug",
  "Umbraco.Cms.Search": "Debug",
  "Umbraco.Cms.Core.Search": "Debug",
  "Umbraco.Cms.Search.Provider.Examine": "Debug"
};
fs.writeFileSync(p, JSON.stringify(j, null, 2));
'

dotnet build ReproSite

echo
echo "Ready. Run: cd \"$WORK\" && ./install-loop.sh 30 nostop"
