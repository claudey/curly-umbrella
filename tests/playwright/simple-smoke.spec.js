const { test, expect } = require('@playwright/test');

test.describe('Simple Smoke Tests', () => {
  test('Can access login page', async ({ page }) => {
    await page.goto('/users/sign_in');
    await expect(page).toHaveURL(/.*sign_in/);
    
    // Check if page has basic login elements - be more flexible
    const pageContent = await page.textContent('body');
    console.log('Page content preview:', pageContent?.substring(0, 500));
    
    // Look for email input field which should exist on login page
    await expect(page.locator('input[type="email"], input[name*="email"]')).toBeVisible();
  });

  test('Can access home page redirects to login', async ({ page }) => {
    await page.goto('/');
    // Should redirect to login for unauthenticated users
    await expect(page).toHaveURL(/.*sign_in/);
  });
});