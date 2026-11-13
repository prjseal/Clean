#!/usr/bin/env bash
# Installs the Clean package on a fresh SQLite database again and again, with disk load during each
# boot, and reports whether each first boot succeeded. Run it from the work dir setup.sh created
# (setup.sh copies this script there).
#
# Usage (Git Bash): ./install-loop.sh <max runs> [nostop]
#   Without "nostop" it stops at the first run that is not ok. Logs are kept in runs/.
#
# Each run: deletes ReproSite/umbraco/Data and Logs, starts copying a large folder in the
# background (the disk load), starts the site, and waits until the log shows either
# "Unattended upgrade failed" or the Home page published and "Now listening".
#
# Outcomes:
#   ok      booted, no Error level log entries
#   FAILED  "Unattended upgrade failed" (the boot failed)
#   ERROR   booted, but the log has Error level entries
#   timeout neither within 4 minutes
# Each outcome is followed by the number of pages the package published (17 for Clean 19).
R="$(cd "$(dirname "$0")" && pwd)"
cd "$R"
max="${1:-10}"
nostop="${2:-}"

if [ ! -d ReproSite ]; then
  echo "No ReproSite here. Run tools/package-install-repro/setup.sh <this dir> first." >&2
  exit 1
fi

# The disk load: copy the newest Umbraco static assets package (a large folder) three times
STRESS_SRC="${STRESS_SRC:-$(ls -td ~/.nuget/packages/umbraco.cms.staticassets/*/ 2>/dev/null | head -1)}"
if [ -z "$STRESS_SRC" ] || [ ! -d "$STRESS_SRC" ]; then
  echo "Set STRESS_SRC to a large folder to copy for disk load." >&2
  exit 1
fi

mkdir -p runs
rm -f runs/run*
fails=0
for i in $(seq 1 "$max"); do
  taskkill //F //IM ReproSite.exe >/dev/null 2>&1
  sleep 2
  rm -rf ReproSite/umbraco/Data ReproSite/umbraco/Logs
  ( for k in 1 2 3; do cp -r "$STRESS_SRC" "$R/stress$k" && rm -rf "$R/stress$k"; done ) &
  dotnet run --no-build --project ReproSite > "runs/run$i.out" 2>&1 &
  outcome="timeout"
  log=""
  for t in $(seq 1 120); do
    log=$(ls ReproSite/umbraco/Logs/UmbracoTraceLog*.json 2>/dev/null | head -1)
    if [ -n "$log" ]; then
      if grep -q 'Unattended upgrade failed' "$log"; then outcome="FAILED"; break; fi
      if grep -q '"nodeName":"Home"' "$log" && grep -q 'Now listening' "runs/run$i.out"; then
        sleep 10
        if grep -q 'Unattended upgrade failed' "$log"; then outcome="FAILED"
        elif grep -q '"@l":"Error"' "$log"; then outcome="ERROR"
        else outcome="ok"; fi
        break
      fi
    fi
    sleep 2
  done
  if [ -n "$log" ]; then
    cp "$log" "runs/run$i.json"
    outcome="$outcome (pages published: $(grep -c 'SuccessPublish' "$log"))"
  fi
  echo "run $i: $outcome"
  taskkill //F //IM ReproSite.exe >/dev/null 2>&1
  wait
  case "$outcome" in
    ok*) ;;
    *) fails=$((fails + 1)); [ -z "$nostop" ] && break ;;
  esac
done
echo "done: $fails not ok of $i"
