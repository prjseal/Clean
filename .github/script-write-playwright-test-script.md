# Write-PlaywrightTestScript.ps1 Documentation

PowerShell script that generates a Playwright JavaScript test file for automated browser testing of Umbraco sites.

## Synopsis

```powershell
Write-PlaywrightTestScript.ps1 -OutputPath <String>
```

## Description

This script creates a ready-to-run Playwright test file (`test.js`) that performs comprehensive browser automation testing of an Umbraco website. The generated test navigates through site pages, discovers internal links, captures full-page screenshots, and validates the Umbraco admin interface.

The script is designed to be called by other automation scripts (like `Test-LatestNuGetPackages.ps1`) to generate consistent, repeatable browser tests.

## Location

`.github/workflows/powershell/Write-PlaywrightTestScript.ps1`

## Parameters

### -OutputPath

**Type**: String
**Required**: Yes
**Description**: File path where the generated Playwright test script should be written.

**Examples**:
```powershell
-OutputPath "test.js"
-OutputPath "C:\workspace\test-latest\test.js"
-OutputPath "$testDir\test.js"
```

## Environment Variables

The **generated test script** uses the following environment variable (not the PowerShell script itself):

### SITE_URL

**Required**: Yes (at test runtime)
**Description**: Base URL of the Umbraco site to test.

**Example**:
```powershell
$env:SITE_URL = "https://localhost:44359"
node test.js
```

## Examples

### Example 1: Basic Usage

```powershell
.\Write-PlaywrightTestScript.ps1 -OutputPath "test.js"
```

**Output**: Creates `test.js` in current directory

### Example 2: Specify Full Path

```powershell
$testDir = "C:\workspace\test-latest"
.\Write-PlaywrightTestScript.ps1 -OutputPath "$testDir\test.js"
```

**Output**: Creates test.js in specified directory

### Example 3: In Testing Pipeline

```powershell
# Create test script
.\Write-PlaywrightTestScript.ps1 -OutputPath "$testDir\test.js"

# Set site URL
$env:SITE_URL = "https://localhost:44359"

# Run generated test
node "$testDir\test.js"
```

## Generated Test Script

The script generates a complete Playwright test with the following structure:

### JavaScript Test Structure

```javascript
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  // 1. Setup browser and context
  // 2. Create screenshots directory
  // 3. Navigate home page
  // 4. Discover internal links
  // 5. Visit up to 10 pages
  // 6. Test Umbraco login
  // 7. Close browser
})();
```

### Test Flow

```mermaid
flowchart TD
    Start([Test Execution<br/>node test.js]) --> Launch[Launch Chromium Browser<br/>Headless mode]

    Launch --> Context[Create Browser Context<br/>ignoreHTTPSErrors: true]

    Context --> CreateDir[Create Screenshots Directory<br/>screenshots/]

    CreateDir --> GetURL[Read SITE_URL<br/>from environment]

    GetURL --> Home[Navigate to Home Page<br/>baseUrl + '/'<br/>Wait for networkidle<br/>30s timeout]

    Home --> Screenshot1[Capture Full-Page Screenshot<br/>01-home.png]

    Screenshot1 --> Discover[Discover Internal Links<br/>- Query all 'a href' elements<br/>- Filter same hostname<br/>- Exclude /umbraco, #, javascript:<br/>- Remove duplicates]

    Discover --> LogCount[Log Link Count<br/>console.log]

    LogCount --> Loop{More Links<br/>Up to 10?}

    Loop -->|Yes| Navigate[Navigate to Link<br/>Wait for networkidle<br/>30s timeout]

    Navigate --> CreateName[Generate Screenshot Name<br/>##-{sanitized-url}.png]

    CreateName --> Screenshot2[Capture Full-Page Screenshot]

    Screenshot2 --> LogScreenshot[Log Screenshot Saved]

    LogScreenshot --> HandleError{Navigation<br/>Error?}

    HandleError -->|Yes| LogError[Log Error Message<br/>Continue to next]
    HandleError -->|No| Loop

    LogError --> Loop

    Loop -->|No| UmbracoLogin[Navigate to /umbraco<br/>Wait for networkidle<br/>30s timeout]

    UmbracoLogin --> Screenshot3[Capture Login Screenshot<br/>##-umbraco-login.png]

    Screenshot3 --> Close[Close Browser]

    Close --> Success[Log: Testing complete!<br/>Exit 0]

    Home -.->|Error| CatchError[Catch Block<br/>Log error details]
    Navigate -.->|Error| CatchError
    UmbracoLogin -.->|Error| CatchError

    CatchError --> Fail[Exit Code 1]

    style Success fill:#ccffcc
    style Fail fill:#ffcccc
```

## Generated Test Features

### 1. Browser Configuration

```javascript
const browser = await chromium.launch();
const context = await browser.newContext({
  ignoreHTTPSErrors: true  // Ignore self-signed certificate errors
});
```

**Purpose**: Allows testing of local development sites with self-signed SSL certificates.

### 2. Screenshot Directory Creation

```javascript
const screenshotsDir = path.join(__dirname, 'screenshots');
if (!fs.existsSync(screenshotsDir)) {
  fs.mkdirSync(screenshotsDir, { recursive: true });
}
```

**Purpose**: Ensures screenshots directory exists before capturing images.

### 3. Link Discovery

```javascript
const links = await page.evaluate((baseUrl) => {
  const anchors = Array.from(document.querySelectorAll('a[href]'));
  return anchors
    .map(a => a.href)
    .filter(href => {
      const url = new URL(href);
      const baseUrlObj = new URL(baseUrl);
      return url.hostname === baseUrlObj.hostname &&
             !href.includes('/umbraco') &&
             !href.includes('#') &&
             !href.includes('javascript:');
    })
    .filter((value, index, self) => self.indexOf(value) === index);
}, baseUrl);
```

**Filters**:
- ✅ Same hostname only (internal links)
- ❌ Excludes `/umbraco` admin pages
- ❌ Excludes anchor links (`#`)
- ❌ Excludes JavaScript pseudo-links
- ❌ Removes duplicates

### 4. Screenshot Naming

```javascript
const screenshotName = counter.toString().padStart(2, '0') + '-' +
  link.replace(baseUrl, '').replace(/[^a-z0-9]/gi, '-').substring(0, 50) + '.png';
```

**Format**: `##-{sanitized-url}.png`

**Examples**:
- `01-home.png` - Home page
- `02-about.png` - /about page
- `03-contact-us.png` - /contact-us page
- `12-umbraco-login.png` - Umbraco login

### 5. Error Handling

```javascript
try {
  await page.goto(link, { waitUntil: 'networkidle', timeout: 30000 });
  // ... take screenshot ...
} catch (error) {
  console.error('Error visiting', link, ':', error.message);
  // Continue to next page instead of failing entire test
}
```

**Behavior**: Logs errors but continues testing remaining pages.

## Output

### PowerShell Script Output

```
Playwright test script written to: C:\workspace\test-latest\test.js
```

### Generated Test Output (when executed)

```
Testing site at: https://localhost:44359
Navigating to home page...
Screenshot saved: 01-home.png
Found 8 internal links to test
Navigating to: https://localhost:44359/about
Screenshot saved: 02-about.png
Navigating to: https://localhost:44359/products
Screenshot saved: 03-products.png
...
Navigating to Umbraco login...
Screenshot saved: 12-umbraco-login.png
Testing complete!
```

## Screenshots Generated

The generated test creates screenshots in the `screenshots/` subdirectory:

| File | Description |
|------|-------------|
| `01-home.png` | Home page (always first) |
| `02-{page}.png` | Second discovered page |
| `03-{page}.png` | Third discovered page |
| ... | Up to 10 discovered pages |
| `##-umbraco-login.png` | Umbraco admin login (always last) |

**Screenshot Properties**:
- Full-page capture (entire scrollable content)
- PNG format
- Timestamped by capture order
- URL-based naming for identification

## Configuration Options in Generated Test

The generated test includes the following configurable options:

### Timeout Settings

```javascript
await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
```

- **Wait strategy**: `networkidle` - Waits for network activity to settle
- **Timeout**: 30 seconds per page

### Page Limit

```javascript
for (const link of links.slice(0, 10)) {
  // Test only first 10 discovered links
}
```

- **Maximum pages**: 10 (plus home + login = 12 total)
- **Purpose**: Keep test duration reasonable

### Browser Options

```javascript
ignoreHTTPSErrors: true
```

- **HTTPS validation**: Disabled (for local dev certificates)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - All pages tested successfully |
| 1 | Error - Navigation failed or exception thrown |

## Error Scenarios

### Missing SITE_URL

**Error**: `process.env.SITE_URL is undefined`

**Cause**: Environment variable not set

**Solution**:
```powershell
$env:SITE_URL = "https://localhost:44359"
node test.js
```

### Navigation Timeout

**Error**: `Timeout 30000ms exceeded`

**Cause**: Page took longer than 30 seconds to load

**Solution**:
- Check site performance
- Verify site is actually running
- Check for JavaScript errors blocking page load

### Screenshot Directory Error

**Error**: `ENOENT: no such file or directory`

**Cause**: Cannot create screenshots directory (permissions)

**Solution**: Ensure write permissions in test directory

### Page Not Found (404)

**Behavior**: Logged as error, test continues

**Output**: `Error visiting https://localhost:44359/missing : ...`

## Dependencies

The generated test requires:

- **Node.js**: To execute JavaScript
- **Playwright**: npm package must be installed
- **Chromium**: Playwright browser (installed via `npx playwright install chromium`)

**Installation**:
```bash
npm init -y
npm install --save-dev playwright
npx playwright install chromium
```

## Limitations

- **No assertions**: Test doesn't validate page content, only captures screenshots
- **No authentication**: Doesn't log into Umbraco admin
- **No form interaction**: Doesn't fill forms or click buttons
- **Fixed page limit**: Always tests max 10 pages (hard-coded)
- **No mobile testing**: Only tests desktop viewport
- **Chromium only**: Doesn't test Firefox or WebKit

## Use Cases

### 1. Visual Regression Testing

Capture screenshots to compare before/after changes:
```powershell
# Before changes
.\Write-PlaywrightTestScript.ps1 -OutputPath "test.js"
node test.js  # Creates screenshots/

# After changes
node test.js  # Compare new screenshots with old
```

### 2. Smoke Testing

Quick validation that site pages load:
```powershell
# In CI/CD pipeline
.\Write-PlaywrightTestScript.ps1 -OutputPath "test.js"
$env:SITE_URL = "https://staging.example.com"
node test.js  # Exit code 0 = all pages loaded
```

### 3. Documentation

Generate screenshots for documentation:
```powershell
# Generate current site screenshots
.\Write-PlaywrightTestScript.ps1 -OutputPath "test.js"
$env:SITE_URL = "https://demo.example.com"
node test.js
# Use screenshots/ for user guides
```

## Related Documentation

- [workflow-test-umbraco-latest.md](workflow-test-umbraco-latest.md) - Workflow that uses this script
- [script-test-latest-nuget-packages.md](script-test-latest-nuget-packages.md) - Parent script that calls this
- [Playwright Documentation](https://playwright.dev/)
- [Playwright API](https://playwright.dev/docs/api/class-playwright)

## Best Practices

1. **Set SITE_URL before running**: Always set environment variable first
2. **Verify site is running**: Ensure site is accessible before testing
3. **Check screenshots**: Review captured images for rendering issues
4. **Monitor test duration**: 10 pages × 30s timeout = up to 5 minutes
5. **Clean old screenshots**: Remove previous screenshots before new runs
6. **Use for CI/CD**: Automate screenshot capture in pipelines

## Future Enhancements

Potential improvements for future versions:

- **Configurable page limit**: Parameter to control number of pages tested
- **Custom selectors**: Test specific page elements
- **Assertions**: Validate page content and structure
- **Authentication testing**: Log into Umbraco and test admin UI
- **Mobile viewports**: Test responsive design
- **Multiple browsers**: Test across Chromium, Firefox, WebKit
- **Performance metrics**: Capture page load times
- **Accessibility testing**: Run Axe accessibility checks
- **Link checking**: Validate all links return 200 status

## Version History

- **v1.0**: Initial version with basic page navigation and screenshot capture
