const { test, expect } = require('@playwright/test');

test.describe('Quick Dashboard Test', () => {
  test('Check if dashboard styling is fixed', async ({ page }) => {
    // Login
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for dashboard
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/dashboard-after-tailwind-fix.png', fullPage: true });
    
    // Check if we have proper Tailwind styling
    const hasTailwindBackground = await page.locator('.bg-gray-50').isVisible();
    const hasTailwindButton = await page.locator('.bg-blue-600').isVisible();
    
    console.log(`Tailwind background: ${hasTailwindBackground}`);
    console.log(`Tailwind button: ${hasTailwindButton}`);
    
    // Check if page title exists
    const dashboardTitle = await page.locator('h1').textContent();
    console.log(`Dashboard title: ${dashboardTitle}`);
  });
});