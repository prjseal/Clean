#!/bin/bash

###############################################################################
# sanitize-version-numbers.sh
#
# Sanitizes version numbers for use in GitHub Actions artifact names by
# replacing dots with dashes.
#
# GitHub Actions artifact names cannot contain certain characters including
# dots. This script transforms version strings like "7.0.1" into "7-0-1"
# for safe use in artifact naming.
#
# Usage:
#   ./sanitize-version-numbers.sh <version>
#
# Arguments:
#   version - The version string to sanitize (e.g., "7.0.1")
#
# Outputs:
#   Sets GITHUB_OUTPUT with:
#     template_version_safe - Sanitized version string with dashes
#
# Examples:
#   ./sanitize-version-numbers.sh "7.0.1"
#   # Output: template_version_safe=7-0-1
#
#   ./sanitize-version-numbers.sh "7.0.1-ci.42"
#   # Output: template_version_safe=7-0-1-ci-42
###############################################################################

set -e

# Check if version argument is provided
if [ -z "$1" ]; then
  echo "Error: Version argument is required"
  echo "Usage: $0 <version>"
  exit 1
fi

TEMPLATE_VERSION="$1"

# Replace dots with dashes for artifact naming (GitHub Actions requirement)
TEMPLATE_VERSION_SAFE="${TEMPLATE_VERSION//./-}"

echo "Original version: $TEMPLATE_VERSION"
echo "Sanitized version: $TEMPLATE_VERSION_SAFE"

# Output to GITHUB_OUTPUT if in GitHub Actions environment
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "template_version_safe=${TEMPLATE_VERSION_SAFE}" >> "$GITHUB_OUTPUT"
  echo "✓ Wrote template_version_safe to GITHUB_OUTPUT"
else
  echo "⚠ GITHUB_OUTPUT not set, skipping output file write"
fi
