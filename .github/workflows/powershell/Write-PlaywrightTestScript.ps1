<#
.SYNOPSIS
    Writes a Playwright test script to a file.

.DESCRIPTION
    This script creates a Playwright JavaScript test file that tests an Umbraco site
    by navigating pages, taking screenshots, and testing the Umbraco login page.

.PARAMETER OutputPath
    The path where the test script should be written

.PARAMETER ContentKeys
    Optional array of content keys (GUIDs) to screenshot in Umbraco

.EXAMPLE
    .\Write-PlaywrightTestScript.ps1 -OutputPath "test.js"

.EXAMPLE
    .\Write-PlaywrightTestScript.ps1 -OutputPath "test.js" -ContentKeys @("guid1", "guid2")
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string[]]$ContentKeys = @()
)

# Convert ContentKeys to JSON for the JavaScript script
$contentKeysJson = $ContentKeys | ConvertTo-Json -Compress

$testScript = @"
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  const screenshotsDir = path.join(__dirname, 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const baseUrl = process.env.SITE_URL;
  console.log('Testing site at:', baseUrl);

  // Get content keys from environment variable (passed as JSON)
  const contentKeysJson = process.env.CONTENT_KEYS || '[]';
  let contentKeys = [];

  try {
    contentKeys = JSON.parse(contentKeysJson);
    console.log('Content keys loaded:', contentKeys.length);
  } catch (error) {
    console.error('Error parsing content keys:', error.message);
  }

  try {
    // Test Umbraco login page
    console.log('Navigating to Umbraco login...');
    await page.goto(baseUrl + '/umbraco', { waitUntil: 'domcontentloaded', timeout: 30000 });

    let counter = 1;
    await page.screenshot({
      path: path.join(screenshotsDir, counter.toString().padStart(2, '0') + '-umbraco-login.png'),
      fullPage: true
    });
    console.log('Screenshot saved: ' + counter.toString().padStart(2, '0') + '-umbraco-login.png');
    counter++;

    // Log into Umbraco
    console.log('Logging into Umbraco...');
    await page.fill('input[name="username"]', 'admin@example.com');
    await page.fill('input[name="password"]', '1234567890');
    await page.click('button[type="submit"]');

    // Wait for navigation after login (just wait for DOM, not full network idle)
    console.log('Waiting for Umbraco to load after login...');
    await page.waitForTimeout(5000);

    // Take screenshot after login
    await page.screenshot({
      path: path.join(screenshotsDir, counter.toString().padStart(2, '0') + '-umbraco-logged-in.png'),
      fullPage: true
    });
    console.log('Screenshot saved: ' + counter.toString().padStart(2, '0') + '-umbraco-logged-in.png');
    counter++;

    // Process each content key
    if (contentKeys.length > 0) {
      console.log('\n================================================');
      console.log('Processing ' + contentKeys.length + ' content items');
      console.log('================================================\n');

      for (let i = 0; i < contentKeys.length; i++) {
        const contentKey = contentKeys[i];

        try {
          console.log('--- Content Item ' + (i + 1) + '/' + contentKeys.length + ' ---');
          console.log('Key: ' + contentKey);

          // Navigate to content item by changing the hash (SPA navigation)
          const hashPath = '/content/content/edit/' + contentKey;
          console.log('Navigating to: ' + baseUrl + '/umbraco#' + hashPath);

          // Change the window location hash to trigger SPA navigation
          await page.evaluate((hash) => {
            window.location.hash = hash;
          }, hashPath);

          // Wait 5 seconds for content to fully load
          console.log('Waiting 5 seconds for content to load...');
          await page.waitForTimeout(5000);

          // Take screenshot
          const screenshotName = counter.toString().padStart(2, '0') + '-content-' + contentKey + '.png';
          await page.screenshot({
            path: path.join(screenshotsDir, screenshotName),
            fullPage: true
          });

          console.log('Screenshot saved: ' + screenshotName);
          console.log('');
          counter++;

        } catch (error) {
          console.error('Error processing content key ' + contentKey + ':', error.message);
          console.log('');
        }
      }

      console.log('================================================');
      console.log('Completed processing all content items');
      console.log('================================================\n');
    } else {
      console.log('\nNo content keys provided, skipping content item screenshots');
    }

  } catch (error) {
    console.error('Error during testing:', error);
    process.exit(1);
  }

  await browser.close();
  console.log('Testing complete!');
})();
"@

$testScript | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "Playwright test script written to: $OutputPath" -ForegroundColor Green
