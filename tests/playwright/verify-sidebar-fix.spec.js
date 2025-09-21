const { test, expect } = require('@playwright/test');

test.describe('Verify Sidebar Fix', () => {
  test('Check if sidebar is positioned correctly on the left', async ({ page }) => {
    // Login
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for dashboard
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    // Take screenshot to verify layout
    await page.screenshot({ path: 'test-results/sidebar-fix-verification.png', fullPage: true });
    
    // Verify drawer layout structure
    await expect(page.locator('.drawer')).toBeVisible();
    await expect(page.locator('.drawer-side')).toBeVisible();
    await expect(page.locator('.drawer-content')).toBeVisible();
    
    // Check sidebar positioning - should be on the left
    const sidebarBox = await page.locator('.drawer-side').boundingBox();
    const contentBox = await page.locator('.drawer-content').boundingBox();
    
    console.log(`Sidebar position: x=${sidebarBox.x}, y=${sidebarBox.y}`);
    console.log(`Content position: x=${contentBox.x}, y=${contentBox.y}`);
    
    // Sidebar should be positioned to the left of content
    expect(sidebarBox.x).toBeLessThan(contentBox.x);
    
    // Check that navigation menu is visible in sidebar
    await expect(page.locator('.drawer-side .menu')).toBeVisible();
    
    console.log('✅ Sidebar is correctly positioned on the left side');
  });
});