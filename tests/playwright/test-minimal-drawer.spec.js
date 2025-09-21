const { test, expect } = require('@playwright/test');

test.describe('Test Minimal Drawer', () => {
  test('Check if basic DaisyUI drawer works', async ({ page }) => {
    // Go directly to test page
    await page.goto('/test_drawer');
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/minimal-drawer-test.png', fullPage: true });
    
    // Check if drawer elements exist
    await expect(page.locator('.drawer')).toBeVisible();
    await expect(page.locator('.drawer-side')).toBeVisible();
    await expect(page.locator('.drawer-content')).toBeVisible();
    
    // Check if sidebar menu is visible
    await expect(page.locator('.drawer-side .menu')).toBeVisible();
    await expect(page.locator('.drawer-side .menu li:has-text("Dashboard")')).toBeVisible();
    
    console.log('✅ Minimal drawer test completed');
  });
});