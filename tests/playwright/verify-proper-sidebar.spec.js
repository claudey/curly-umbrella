const { test, expect } = require('@playwright/test');

test.describe('Verify Proper Sidebar Layout', () => {
  test('Navigation items should be positioned on the left side', async ({ page }) => {
    // Login
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for dashboard
    await page.waitForURL(url => !url.pathname.includes('sign_in'));
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/proper-sidebar-layout.png', fullPage: true });
    
    // Check that drawer layout is properly structured
    await expect(page.locator('.drawer')).toBeVisible();
    await expect(page.locator('.drawer-content')).toBeVisible();
    await expect(page.locator('.drawer-side')).toBeVisible();
    
    // Verify sidebar contains navigation items
    const sidebarMenu = page.locator('.drawer-side .menu');
    await expect(sidebarMenu).toBeVisible();
    
    // Check that specific navigation items are visible in sidebar
    await expect(page.locator('.drawer-side .menu li:has-text("Dashboard")')).toBeVisible();
    await expect(page.locator('.drawer-side .menu li:has-text("Clients")')).toBeVisible();
    await expect(page.locator('.drawer-side .menu li:has-text("Applications")')).toBeVisible();
    await expect(page.locator('.drawer-side .menu li:has-text("Quotes")')).toBeVisible();
    await expect(page.locator('.drawer-side .menu li:has-text("Documents")')).toBeVisible();
    
    // Check positioning - sidebar should be on the left
    const sidebarBox = await page.locator('.drawer-side').boundingBox();
    const contentBox = await page.locator('.drawer-content').boundingBox();
    
    console.log(`Sidebar bounding box: x=${sidebarBox.x}, y=${sidebarBox.y}, width=${sidebarBox.width}, height=${sidebarBox.height}`);
    console.log(`Content bounding box: x=${contentBox.x}, y=${contentBox.y}, width=${contentBox.width}, height=${contentBox.height}`);
    
    // On large screens, sidebar should be visible and positioned to the left
    if (page.viewportSize().width >= 1024) {
      // Sidebar should start at x=0 (left edge)
      expect(sidebarBox.x).toBe(0);
      // Content should start after the sidebar
      expect(contentBox.x).toBeGreaterThanOrEqual(sidebarBox.width - 50); // Allow some margin
    }
    
    console.log('✅ Sidebar layout is correctly positioned');
  });
});