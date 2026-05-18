#!/bin/bash
# Installs the .NET 10 SDK so dotnet build/restore/test work in this session.
# Idempotent: re-running is cheap once the SDK is already on disk.
set -euo pipefail

# Only run in the Claude Code on the web remote container.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"
INSTALL_SCRIPT="$HOME/.dotnet-install.sh"
CHANNEL="10.0"

mkdir -p "$DOTNET_ROOT"

if [ ! -x "$DOTNET_ROOT/dotnet" ]; then
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$INSTALL_SCRIPT"
        chmod +x "$INSTALL_SCRIPT"
    fi
    "$INSTALL_SCRIPT" --channel "$CHANNEL" --install-dir "$DOTNET_ROOT" --no-path
fi

# Persist DOTNET_ROOT and PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    {
        echo "export DOTNET_ROOT=\"$DOTNET_ROOT\""
        echo "export PATH=\"$DOTNET_ROOT:\$PATH\""
        echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1"
        echo "export DOTNET_NOLOGO=1"
    } >> "$CLAUDE_ENV_FILE"
fi

"$DOTNET_ROOT/dotnet" --version >&2
