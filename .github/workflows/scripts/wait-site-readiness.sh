#!/bin/bash

###############################################################################
# wait-site-readiness.sh
#
# Waits for an Umbraco site to be fully ready for OWASP ZAP security scanning
# by polling the site URL and verifying it responds with a successful HTTP
# status code.
#
# This script ensures the site is not only started but fully initialized and
# responding to requests before ZAP begins its security scan.
#
# Usage:
#   ./wait-site-readiness.sh <site_url>
#
# Arguments:
#   site_url - The URL of the site to check (e.g., "https://localhost:5001")
#
# Behavior:
#   - Waits additional 5 seconds after site reports ready
#   - Attempts HTTP/HTTPS connectivity
#   - Polls site URL up to 10 times with 3-second intervals
#   - Validates HTTP 200 or 302 response codes
#   - Confirms site is responding before exiting
#
# Exit Codes:
#   0 - Site is ready and responding
#   1 - Site failed to respond after maximum attempts
#
# Examples:
#   ./wait-site-readiness.sh "https://localhost:5001"
#   ./wait-site-readiness.sh "http://localhost:5000"
###############################################################################

set -e

# Check if site URL argument is provided
if [ -z "$1" ]; then
  echo "Error: Site URL argument is required"
  echo "Usage: $0 <site_url>"
  exit 1
fi

SITE_URL="$1"

echo "Waiting additional time to ensure site is fully ready for ZAP scan..."
sleep 5

echo "Site URL: $SITE_URL"
echo "Testing site connectivity..."

# Convert HTTPS to HTTP if needed (ZAP works better with HTTP for local testing)
if [[ $SITE_URL == https://* ]]; then
  HTTP_URL="${SITE_URL/https/http}"
  echo "Attempting to connect to: $HTTP_URL"

  # Try a simple curl to verify the site is responding
  for i in {1..10}; do
    if curl -k -s -o /dev/null -w "%{http_code}" "$SITE_URL" | grep -q "200\|302"; then
      echo "✓ Site is responding!"
      exit 0
    fi
    echo "Waiting for site to respond (attempt $i/10)..."
    sleep 3
  done

  echo "✗ Site failed to respond after 10 attempts"
  exit 1
else
  echo "Site is using HTTP, attempting to connect to: $SITE_URL"

  # Try a simple curl to verify the site is responding
  for i in {1..10}; do
    if curl -s -o /dev/null -w "%{http_code}" "$SITE_URL" | grep -q "200\|302"; then
      echo "✓ Site is responding!"
      exit 0
    fi
    echo "Waiting for site to respond (attempt $i/10)..."
    sleep 3
  done

  echo "✗ Site failed to respond after 10 attempts"
  exit 1
fi
