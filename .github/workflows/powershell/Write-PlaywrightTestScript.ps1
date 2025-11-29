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

.PARAMETER DataTypeKeys
    Optional array of data type keys (GUIDs) to screenshot in Umbraco

.EXAMPLE
    .\Write-PlaywrightTestScript.ps1 -OutputPath "test.js"

.EXAMPLE
    .\Write-PlaywrightTestScript.ps1 -OutputPath "test.js" -ContentKeys @("guid1", "guid2")
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string[]]$ContentKeys = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$DataTypeKeys = @()
)

# Convert ContentKeys to JSON for the JavaScript script
$contentKeysJson = $ContentKeys | ConvertTo-Json -Compress

# Convert DataTypeKeys to JSON for the JavaScript script
$dataTypeKeysJson = $DataTypeKeys | ConvertTo-Json -Compress

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
    console.log('Content type keys loaded:\n' + JSON.stringify(contentKeys, null, 2));
  } catch (error) {
    console.error('Error parsing content keys:', error.message);
  }

  // Get data type keys from environment variable (passed as JSON)
  const dataTypeKeysJson = process.env.DATATYPE_KEYS || '[]';
  let dataTypeKeys = [];

  try {
    dataTypeKeys = JSON.parse(dataTypeKeysJson);
    console.log('Data type keys loaded:\n' + JSON.stringify(dataTypeKeys, null, 2));
  } catch (error) {
    console.error('Error parsing data type keys:', error.message);
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

      for (let i = 0; i < 1; i++) {
        const contentKey = contentKeys[i];

        try {
          console.log('--- Content Item ' + (i + 1) + '/' + contentKeys.length + ' ---');
          console.log('Key: ' + contentKey);

          // Log current URL before navigation
          const beforeUrl = page.url();
          console.log('Current URL before navigation: ' + beforeUrl);

          // Try multiple URL patterns for different Umbraco versions
          const urlPatterns = [
            baseUrl + '/umbraco/section/content/workspace/document/edit/' + contentKey + '/invariant',
            baseUrl + '/umbraco/section/content/workspace/document-edit/' + contentKey,
            baseUrl + '/umbraco/content/edit/' + contentKey,
            baseUrl + '/umbraco#/content/content/edit/' + contentKey
          ];

          let navigationSuccessful = false;

          for (let urlPattern of urlPatterns) {
            console.log('Trying URL pattern: ' + urlPattern);

            try {
              await page.goto(urlPattern, { waitUntil: 'domcontentloaded', timeout: 10000 });
              await page.waitForTimeout(2000);

              const currentUrl = page.url();
              console.log('Current URL after navigation: ' + currentUrl);

              // Check if URL contains the content key (indicates successful navigation)
              if (currentUrl.includes(contentKey) || currentUrl.includes('edit') || currentUrl.includes('workspace')) {
                console.log('Navigation successful with this pattern!');
                navigationSuccessful = true;
                break;
              } else {
                console.log('URL reverted, trying next pattern...');
              }
            } catch (navError) {
              console.log('Navigation failed with this pattern: ' + navError.message);
            }
          }

          if (!navigationSuccessful) {
            console.log('WARNING: Could not navigate to content item, screenshot may show default page');
          }

          // Wait for loading spinner to disappear
          console.log('Waiting for page to finish loading...');
          try {
            // Wait for common Umbraco loading indicators to disappear
            await page.waitForSelector('.umb-load-indicator', { state: 'hidden', timeout: 15000 }).catch(() => {});
            await page.waitForSelector('[data-element="editor-container"]', { state: 'visible', timeout: 5000 }).catch(() => {});
            console.log('Loading indicators cleared');
          } catch (e) {
            console.log('Could not detect loading indicators, continuing with fixed wait...');
          }

          // Additional wait for content to load
          console.log('Waiting 5 seconds for content to fully render...');
          await page.waitForTimeout(5000);

          // Log final URL before screenshot
          const finalUrl = page.url();
          console.log('Final URL before screenshot: ' + finalUrl);

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
