const { test, expect } = require('@playwright/test');

test.describe('Browser Debug - Headed Mode', () => {
  test('Login and check dashboard styling in real browser', async ({ page }) => {
    // Login first
    await page.goto('/users/sign_in');
    
    console.log('✅ Login page loaded');
    
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for redirect after login
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    console.log(`Current URL: ${page.url()}`);
    
    // Take screenshot and pause for inspection
    await page.screenshot({ path: 'test-results/dashboard-debug.png', fullPage: true });
    
    // Check what CSS files are actually loaded
    const stylesheetUrls = await page.evaluate(() => {
      const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
      return links.map(link => link.href);
    });
    
    console.log('Loaded stylesheets:', stylesheetUrls);
    
    // Check computed styles on body
    const bodyStyles = await page.evaluate(() => {
      const body = document.body;
      const computedStyle = window.getComputedStyle(body);
      return {
        backgroundColor: computedStyle.backgroundColor,
        fontFamily: computedStyle.fontFamily,
        margin: computedStyle.margin,
        padding: computedStyle.padding
      };
    });
    
    console.log('Body styles:', bodyStyles);
    
    // Look for specific Bootstrap/Tailwind classes
    const hasBootstrapClasses = await page.locator('.container-fluid').isVisible();
    const hasTailwindClasses = await page.locator('.bg-gray-50').isVisible();
    
    console.log(`Bootstrap classes found: ${hasBootstrapClasses}`);
    console.log(`Tailwind classes found: ${hasTailwindClasses}`);
    
    // Pause for manual inspection
    await page.pause();
  });
});