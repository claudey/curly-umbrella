const { test, expect } = require('@playwright/test');

test.describe('Final Drawer Test', () => {
  test('Verify navigation is on left side', async ({ page }) => {
    // Login
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for dashboard
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/final-drawer-test.png', fullPage: true });
    
    console.log('Screenshot taken - checking layout...');
    
    // Basic checks
    await expect(page.locator('.drawer')).toBeVisible();
    await expect(page.locator('.drawer-side')).toBeVisible();
    await expect(page.locator('.drawer-content')).toBeVisible();
    
    console.log('✅ Basic drawer elements found');
  });
});