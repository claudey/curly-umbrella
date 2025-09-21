const { test, expect } = require('@playwright/test');

test.describe('Dashboard Styling Debug', () => {
  test('Login and check dashboard styling', async ({ page }) => {
    // Login first
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for redirect after login
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    // Check if CSS is loaded
    const stylesheets = await page.locator('link[rel="stylesheet"]').count();
    console.log(`Found ${stylesheets} stylesheets`);
    
    // Check specific CSS files
    const applicationCSS = await page.locator('link[href*="application"]').isVisible();
    const tailwindCSS = await page.locator('link[href*="tailwind"]').isVisible();
    
    console.log(`Application CSS loaded: ${applicationCSS}`);
    console.log(`Tailwind CSS loaded: ${tailwindCSS}`);
    
    // Take screenshot of actual dashboard
    await page.screenshot({ path: 'test-results/actual-dashboard.png', fullPage: true });
    
    // Check if body has background styling
    const bodyClass = await page.locator('body').getAttribute('class');
    console.log(`Body classes: ${bodyClass}`);
    
    // Print page URL and title
    console.log(`Current URL: ${page.url()}`);
    console.log(`Page title: ${await page.title()}`);
  });
});