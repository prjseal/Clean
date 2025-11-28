<#
.SYNOPSIS
    Writes a Playwright test script to a file.

.DESCRIPTION
    This script creates a Playwright JavaScript test file that tests an Umbraco site
    by navigating pages, taking screenshots, and testing the Umbraco login page.

.PARAMETER OutputPath
    The path where the test script should be written

.EXAMPLE
    .\Write-PlaywrightTestScript.ps1 -OutputPath "test.js"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$testScript = @'
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { parseStringPromise } = require('xml2js');

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

  try {
    // Test Umbraco login page
    console.log('Navigating to Umbraco login...');
    await page.goto(baseUrl + '/umbraco', { waitUntil: 'networkidle', timeout: 30000 });

    let counter = 1;
    await page.screenshot({
      path: path.join(screenshotsDir, counter.toString().padStart(2, '0') + '-umbraco-login.png'),
      fullPage: true
    });
    console.log('Screenshot saved: umbraco-login.png');
    counter++;

    // Log into Umbraco
    console.log('Logging into Umbraco...');
    await page.fill('input[name="username"]', 'admin@example.com');
    await page.fill('input[name="password"]', '1234567890');
    await page.click('button[type="submit"]');

    // Wait for navigation after login
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    await page.waitForTimeout(3000);

    // Take screenshot after login
    await page.screenshot({
      path: path.join(screenshotsDir, counter.toString().padStart(2, '0') + '-umbraco-logged-in.png'),
      fullPage: true
    });
    console.log('Screenshot saved: umbraco-logged-in.png');
    counter++;

    // Navigate to Content section
    console.log('Navigating to Content section...');

    // Wait for and click on Content section
    const contentSelector = 'a[href="#/content"], [data-element="section-content"], a[title="Content"]';
    await page.waitForSelector(contentSelector, { timeout: 10000 });
    await page.click(contentSelector);
    await page.waitForTimeout(2000);

    // Find element with text "Home" and click it
    console.log('Looking for element with text "Home"...');

    // Try multiple selectors to find Home element
    const homeSelectors = [
      'text=Home',
      '[title="Home"]',
      '[data-element="tree-item-Home"]',
      'a:has-text("Home")',
      '*:has-text("Home")'
    ];

    let homeClicked = false;
    for (const selector of homeSelectors) {
      try {
        await page.click(selector, { timeout: 3000 });
        homeClicked = true;
        console.log(`Found and clicked Home using selector: ${selector}`);
        break;
      } catch (e) {
        continue;
      }
    }

    if (!homeClicked) {
      throw new Error('Could not find Home element');
    }

    // Wait for URL to update
    await page.waitForTimeout(2000);

    // Get the current URL
    const currentUrl = page.url();
    console.log('Current URL after clicking Home:', currentUrl);

    // Extract the key from the URL - typical Umbraco URL pattern: /umbraco#/content/content/edit/{key}
    const urlMatch = currentUrl.match(/\/content\/edit\/([a-f0-9-]{36})/i);
    let baseContentKey = null;

    if (urlMatch) {
      baseContentKey = urlMatch[1];
      console.log('Extracted key from URL:', baseContentKey);
    } else {
      console.log('Warning: Could not extract key from URL, will try to construct URL pattern');
    }

    // Read and parse usync content files to get published content keys
    console.log('Reading usync content files...');
    const usyncContentPath = path.join(__dirname, 'template', 'Clean.Blog', 'uSync', 'v17', 'Content');

    let contentFiles = [];
    try {
      contentFiles = fs.readdirSync(usyncContentPath).filter(f => f.endsWith('.config'));
      console.log(`Found ${contentFiles.length} content config files`);
    } catch (error) {
      console.error('Error reading usync content directory:', error.message);
      throw error;
    }

    const publishedContent = [];

    // Parse each content file
    for (const file of contentFiles) {
      try {
        const filePath = path.join(usyncContentPath, file);
        const xmlContent = fs.readFileSync(filePath, 'utf8');

        // Parse XML
        const result = await parseStringPromise(xmlContent);

        if (result && result.Content) {
          const key = result.Content.$.Key;
          const alias = result.Content.$.Alias;
          const published = result.Content.Info &&
                          result.Content.Info[0] &&
                          result.Content.Info[0].Published &&
                          result.Content.Info[0].Published[0] &&
                          result.Content.Info[0].Published[0].$.Default === 'true';

          if (published) {
            console.log(`\n=== Published Content Item ===`);
            console.log(`File: ${file}`);
            console.log(`Alias: ${alias}`);
            console.log(`Key: ${key}`);
            console.log(`XML Preview: ${xmlContent.substring(0, 200)}...`);

            publishedContent.push({
              key: key,
              alias: alias,
              file: file
            });
          }
        }
      } catch (error) {
        console.error(`Error parsing ${file}:`, error.message);
      }
    }

    console.log(`\n\nFound ${publishedContent.length} published content items`);
    console.log('Published content keys:', publishedContent.map(c => `${c.alias}: ${c.key}`).join('\n'));

    // Now visit each content item by replacing the key in the URL
    if (baseContentKey || currentUrl.includes('/content/')) {
      for (const content of publishedContent) {
        try {
          console.log(`\n--- Processing: ${content.alias} (${content.key}) ---`);

          // Construct the URL
          let contentUrl;
          if (baseContentKey) {
            // Replace the key in the original URL
            contentUrl = currentUrl.replace(baseContentKey, content.key);
          } else {
            // Try to construct URL from pattern
            contentUrl = `${baseUrl}/umbraco#/content/content/edit/${content.key}`;
          }

          console.log(`Navigating to: ${contentUrl}`);
          await page.goto(contentUrl, { waitUntil: 'networkidle', timeout: 30000 });

          // Wait 5 seconds
          console.log('Waiting 5 seconds before screenshot...');
          await page.waitForTimeout(5000);

          // Take screenshot
          const screenshotName = counter.toString().padStart(2, '0') +
            `-content-${content.alias.replace(/[^a-z0-9]/gi, '-').toLowerCase()}.png`;

          await page.screenshot({
            path: path.join(screenshotsDir, screenshotName),
            fullPage: true
          });

          console.log(`Screenshot saved: ${screenshotName}`);
          counter++;

        } catch (error) {
          console.error(`Error processing ${content.alias}:`, error.message);
        }
      }
    } else {
      console.error('Could not determine URL pattern for content items');
    }

  } catch (error) {
    console.error('Error during testing:', error);
    process.exit(1);
  }

  await browser.close();
  console.log('Testing complete!');
})();
'@

$testScript | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "Playwright test script written to: $OutputPath" -ForegroundColor Green
