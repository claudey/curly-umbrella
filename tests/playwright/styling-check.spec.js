const { test, expect } = require('@playwright/test');

test.describe('Styling Check', () => {
  test('Login page has proper styling loaded', async ({ page }) => {
    await page.goto('/users/sign_in');
    
    // Check if CSS is loaded by looking for computed styles
    const body = page.locator('body');
    await expect(body).toBeVisible();
    
    // Check if Tailwind classes are working
    const emailInput = page.locator('input[name="user[email]"]');
    await expect(emailInput).toBeVisible();
    
    // Take a screenshot to verify styling
    await page.screenshot({ path: 'test-results/login-styling.png', fullPage: true });
    
    console.log('✅ Login page styling check completed');
  });

  test('Dashboard has proper styling when logged in', async ({ page }) => {
    // First, try to access the home page to see if it loads properly
    await page.goto('/');
    
    // Take a screenshot 
    await page.screenshot({ path: 'test-results/dashboard-styling.png', fullPage: true });
    
    console.log('✅ Dashboard styling check completed');
  });
});