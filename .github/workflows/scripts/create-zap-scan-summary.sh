#!/bin/bash

###############################################################################
# create-zap-scan-summary.sh
#
# Creates a comprehensive GitHub Actions workflow summary for OWASP ZAP
# security scan results. The summary includes scan details, security findings,
# and downloadable artifacts.
#
# The script generates markdown output suitable for GITHUB_STEP_SUMMARY,
# including scan metadata, full ZAP results (if available), and contextual
# notes based on the template source used.
#
# Usage:
#   ./create-zap-scan-summary.sh <branch_name> <template_source> <template_version> <site_url> [umbraco_cms_version] [issues_created]
#
# Arguments:
#   branch_name          - Branch where scan was performed
#   template_source      - Template source (code/nuget/github-packages)
#   template_version     - Clean template version tested
#   site_url             - Target URL that was scanned
#   umbraco_cms_version  - (Optional) Umbraco CMS version
#   issues_created       - (Optional) Number of issues created from scan
#
# Outputs:
#   Appends formatted markdown to $GITHUB_STEP_SUMMARY
#
# Examples:
#   ./create-zap-scan-summary.sh "main" "nuget" "7.0.1" "https://localhost:5001"
#   ./create-zap-scan-summary.sh "feature/new" "code" "7.0.2" "https://localhost:5001" "15.0.0" "3"
###############################################################################

set -e

# Check required arguments
if [ $# -lt 4 ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 <branch_name> <template_source> <template_version> <site_url> [umbraco_cms_version] [issues_created]"
  exit 1
fi

BRANCH_NAME="$1"
TEMPLATE_SOURCE="$2"
TEMPLATE_VERSION="$3"
SITE_URL="$4"
UMBRACO_CMS_VERSION="${5:-}"
ISSUES_CREATED="${6:-}"

# Check if GITHUB_STEP_SUMMARY is set
if [ -z "$GITHUB_STEP_SUMMARY" ]; then
  echo "Error: GITHUB_STEP_SUMMARY environment variable is not set"
  echo "This script should be run in a GitHub Actions environment"
  exit 1
fi

echo "Generating ZAP scan summary..."
echo "Branch: $BRANCH_NAME"
echo "Template Source: $TEMPLATE_SOURCE"
echo "Template Version: $TEMPLATE_VERSION"
echo "Site URL: $SITE_URL"

# Start building the summary
{
  echo "## OWASP ZAP Security Scan Complete"
  echo ""
  echo "### Scan Details"
  echo "- **Branch:** \`$BRANCH_NAME\`"
  echo "- **Template Source:** $TEMPLATE_SOURCE"
  echo "- **Clean Template Version:** $TEMPLATE_VERSION"

  if [ -n "$UMBRACO_CMS_VERSION" ]; then
    echo "- **Umbraco CMS Version:** $UMBRACO_CMS_VERSION"
  fi

  echo "- **Target URL:** $SITE_URL"
  echo "- **Project Type:** Clean Blog (from Umbraco.Community.Templates.Clean)"
  echo ""
  echo "---"
  echo ""
} >> "$GITHUB_STEP_SUMMARY"

# Include the full ZAP scan results in the summary
if [ -f "report_md.md" ]; then
  {
    echo "### Security Scan Results"
    echo ""
    cat report_md.md
    echo ""
  } >> "$GITHUB_STEP_SUMMARY"
else
  {
    echo "⚠️ **Warning:** Scan report not found. Please check the artifacts for detailed results."
    echo ""
  } >> "$GITHUB_STEP_SUMMARY"
fi

# Add downloadable reports section
{
  echo "---"
  echo ""
  echo "### Downloadable Reports"
  echo "Full scan reports have been uploaded as artifacts:"
  echo "- 📄 HTML Report (detailed with styling)"
  echo "- 📝 Markdown Report (text-based)"
  echo "- 📋 JSON Report (machine-readable)"
  echo "- 📋 Site Logs (for debugging)"
  echo ""
} >> "$GITHUB_STEP_SUMMARY"

# Add contextual notes based on template source
if [ "$TEMPLATE_SOURCE" = "code" ]; then
  {
    echo "⚠️ **Note:** When testing local repository code, this workflow will fail if new security issues are found."
    echo ""

    if [ -n "$ISSUES_CREATED" ] && [ "$ISSUES_CREATED" != "0" ]; then
      echo "### ❌ Security Check Failed"
      echo ""
      echo "The security scan found **$ISSUES_CREATED** new security issue(s) when testing the local repository code."
      echo ""
      echo "Please review and fix these issues before merging."
      echo ""
    fi
  } >> "$GITHUB_STEP_SUMMARY"
else
  {
    echo "ℹ️ **Note:** This workflow does not fail on security findings when testing published templates. Please review the results above and in the artifacts."
    echo ""
  } >> "$GITHUB_STEP_SUMMARY"
fi

echo "✓ ZAP scan summary created successfully"
