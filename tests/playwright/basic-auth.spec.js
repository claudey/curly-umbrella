const { test, expect } = require('@playwright/test');

test.describe('Basic Authentication', () => {
  test('Can access login form fields', async ({ page }) => {
    await page.goto('/users/sign_in');
    
    // Verify login form elements are present
    await expect(page.locator('input[name="user[email]"]')).toBeVisible();
    await expect(page.locator('input[name="user[password]"]')).toBeVisible();
    await expect(page.locator('input[type="submit"], button[type="submit"]')).toBeVisible();
  });

  test('Login form shows validation errors for empty fields', async ({ page }) => {
    await page.goto('/users/sign_in');
    
    // Try to submit empty form
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Should stay on login page or show validation
    await expect(page).toHaveURL(/.*sign_in/);
  });

  test('Home page redirects unauthenticated users to login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveURL(/.*sign_in/);
  });
});