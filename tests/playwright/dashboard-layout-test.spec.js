const { test, expect } = require('@playwright/test');

test('Dashboard layout with proper sidebar positioning', async ({ page }) => {
  // Navigate to the dashboard
  await page.goto('http://localhost:3000');
  
  // Wait for the page to load completely
  await page.waitForLoadState('networkidle');
  
  // Take a full page screenshot
  await page.screenshot({ 
    path: 'test-results/dashboard-layout-final.png', 
    fullPage: true 
  });
  
  // Check if the drawer structure exists
  const drawer = await page.locator('.drawer');
  await expect(drawer).toBeVisible();
  
  // Check if the drawer-side (sidebar) exists
  const drawerSide = await page.locator('.drawer-side');
  await expect(drawerSide).toBeVisible();
  
  // Check if navigation items are present in the sidebar
  const navItems = await page.locator('.drawer-side .menu');
  await expect(navItems).toBeVisible();
  
  // Check specific navigation links
  await expect(page.locator('text=Dashboard')).toBeVisible();
  await expect(page.locator('text=Clients')).toBeVisible();
  await expect(page.locator('text=Applications')).toBeVisible();
  await expect(page.locator('text=Quotes')).toBeVisible();
  await expect(page.locator('text=Documents')).toBeVisible();
  
  console.log('Dashboard layout test completed successfully');
});