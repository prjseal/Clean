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

  // Navigate to home page first to discover links
  try {
    console.log('Navigating to home page...');
    await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 30000 });

    // Take screenshot of home page
    await page.screenshot({
      path: path.join(screenshotsDir, '01-home.png'),
      fullPage: true
    });
    console.log('Screenshot saved: 01-home.png');

    // Find all internal links on the page
    const links = await page.evaluate((baseUrl) => {
      const anchors = Array.from(document.querySelectorAll('a[href]'));
      return anchors
        .map(a => a.href)
        .filter(href => {
          try {
            const url = new URL(href);
            const baseUrlObj = new URL(baseUrl);
            return url.hostname === baseUrlObj.hostname &&
                   !href.includes('/umbraco') &&
                   !href.includes('#') &&
                   !href.includes('javascript:');
          } catch {
            return false;
          }
        })
        .filter((value, index, self) => self.indexOf(value) === index);
    }, baseUrl);

    console.log('Found ' + links.length + ' internal links to test');

    // Visit each discovered link
    let counter = 2;
    for (const link of links.slice(0, 10)) {
      try {
        console.log('Navigating to:', link);
        await page.goto(link, { waitUntil: 'networkidle', timeout: 30000 });

        const screenshotName = counter.toString().padStart(2, '0') + '-' +
          link.replace(baseUrl, '').replace(/[^a-z0-9]/gi, '-').substring(0, 50) + '.png';

        await page.screenshot({
          path: path.join(screenshotsDir, screenshotName),
          fullPage: true
        });
        console.log('Screenshot saved:', screenshotName);
        counter++;
      } catch (error) {
        console.error('Error visiting', link, ':', error.message);
      }
    }

    // Test Umbraco login page
    console.log('Navigating to Umbraco login...');
    await page.goto(baseUrl + '/umbraco', { waitUntil: 'networkidle', timeout: 30000 });
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

    // Function to click on a tree item and take screenshot
    async function clickTreeItemAndScreenshot(itemName, screenshotCounter) {
      try {
        console.log(`Clicking on tree item: ${itemName}...`);

        // Primary selector using Umbraco's data-element attribute
        const primarySelector = `[data-element="tree-item-${itemName}"]`;

        let clicked = false;

        // Try primary selector first
        try {
          await page.click(primarySelector, { timeout: 5000 });
          clicked = true;
          console.log(`Clicked on ${itemName} using data-element selector`);
        } catch (e) {
          console.log(`Primary selector failed, trying fallback selectors...`);

          // Fallback selectors
          const fallbackSelectors = [
            `[data-element="tree-item-${itemName}"] a`,
            `a[title="${itemName}"]`,
            `.umb-tree-item:has-text("${itemName}")`,
            `text=${itemName}`
          ];

          for (const selector of fallbackSelectors) {
            try {
              await page.click(selector, { timeout: 3000 });
              clicked = true;
              console.log(`Clicked on ${itemName} using fallback selector`);
              break;
            } catch (e) {
              continue;
            }
          }
        }

        if (!clicked) {
          console.log(`Warning: Could not click on ${itemName}`);
          return screenshotCounter;
        }

        // Wait 5 seconds before taking screenshot
        console.log(`Waiting 5 seconds before taking screenshot...`);
        await page.waitForTimeout(5000);

        // Take screenshot
        const screenshotName = screenshotCounter.toString().padStart(2, '0') +
          `-content-${itemName.replace(/[^a-z0-9]/gi, '-').toLowerCase()}.png`;
        await page.screenshot({
          path: path.join(screenshotsDir, screenshotName),
          fullPage: true
        });
        console.log(`Screenshot saved: ${screenshotName}`);
        return screenshotCounter + 1;
      } catch (error) {
        console.error(`Error processing ${itemName}:`, error.message);
        return screenshotCounter;
      }
    }

    // Click on Home page first
    counter = await clickTreeItemAndScreenshot('Home', counter);

    // Try to expand the Home node to see child pages
    console.log('Attempting to expand Home node...');
    try {
      // Click on the uui-symbol-expand element within the Home tree item
      // Based on Umbraco's data-element attributes for tree navigation
      const expandSelector = '[data-element="tree-item-Home"] [data-element="tree-item-expand"]';

      try {
        await page.click(expandSelector, { timeout: 5000 });
        console.log('Home node expanded using uui-symbol-expand');
        await page.waitForTimeout(1000);
      } catch (e) {
        console.log('Could not find expand element, trying alternative selectors...');

        // Fallback selectors
        const fallbackSelectors = [
          '[data-element="tree-item-Home"] uui-symbol-expand',
          '[data-element="tree-item-Home"] button[aria-label*="expand"]',
          '[data-element="tree-item-Home"] .umb-tree-item__expand'
        ];

        let expanded = false;
        for (const selector of fallbackSelectors) {
          try {
            await page.click(selector, { timeout: 3000 });
            expanded = true;
            console.log('Home node expanded using fallback selector');
            await page.waitForTimeout(1000);
            break;
          } catch (e) {
            continue;
          }
        }

        if (!expanded) {
          console.log('Could not expand Home node automatically');
        }
      }

      // Get all visible tree items that are children of Home
      console.log('Looking for child pages under Home...');
      const childPages = await page.evaluate(() => {
        const items = [];

        // Look for elements with data-element attribute starting with "tree-item-"
        const treeItems = document.querySelectorAll('[data-element^="tree-item-"]');

        treeItems.forEach(item => {
          const dataElement = item.getAttribute('data-element');
          if (dataElement && dataElement !== 'tree-item-Home') {
            // Extract the page name from data-element attribute
            const pageName = dataElement.replace('tree-item-', '');

            // Also check if this item is visible (has non-zero dimensions)
            const rect = item.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0 && pageName.length > 0) {
              items.push(pageName);
            }
          }
        });

        // Remove duplicates
        return [...new Set(items)];
      });

      console.log(`Found ${childPages.length} potential child pages`);

      // Click on each child page
      for (const pageName of childPages) {
        if (pageName && pageName.trim()) {
          counter = await clickTreeItemAndScreenshot(pageName.trim(), counter);
        }
      }

    } catch (error) {
      console.error('Error expanding or processing child pages:', error.message);
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
