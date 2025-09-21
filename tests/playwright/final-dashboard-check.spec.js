const { test, expect } = require('@playwright/test');

test.describe('Final Dashboard Layout Check', () => {
  test('Capture final dashboard with DaisyUI layout', async ({ page }) => {
    // Login
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for dashboard
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    // Take full screenshot
    await page.screenshot({ path: 'test-results/final-dashboard-layout.png', fullPage: true });
    
    // Check if DaisyUI components are present
    const hasDaisyUICards = await page.locator('.card').count();
    const hasDaisyUIButtons = await page.locator('.btn').count();
    const hasProperGrid = await page.locator('.grid').count();
    
    console.log(`Found ${hasDaisyUICards} DaisyUI cards`);
    console.log(`Found ${hasDaisyUIButtons} DaisyUI buttons`);
    console.log(`Found ${hasProperGrid} grid layouts`);
    
    // Verify layout structure
    await expect(page.locator('.drawer')).toBeVisible(); // Main layout
    await expect(page.locator('.drawer-side')).toBeVisible(); // Sidebar
    await expect(page.locator('.drawer-content')).toBeVisible(); // Main content
  });
});