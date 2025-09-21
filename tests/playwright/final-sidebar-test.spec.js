const { test, expect } = require('@playwright/test');

test.describe('Final Sidebar Test', () => {
  test('Verify sidebar is positioned correctly', async ({ page }) => {
    // Login
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for dashboard
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/final-sidebar-test.png', fullPage: true });
    
    // Check basic layout elements
    await expect(page.locator('.drawer')).toBeVisible();
    await expect(page.locator('.drawer-side')).toBeVisible();
    await expect(page.locator('.drawer-content').first()).toBeVisible();
    
    console.log('✅ Layout elements are visible');
    
    // Check if navigation items are visible in sidebar
    await expect(page.locator('.drawer-side .menu')).toBeVisible();
    await expect(page.locator('.drawer-side .menu li')).toHaveCount(8); // Should have multiple nav items
    
    console.log('✅ Navigation menu is visible in sidebar');
  });
});