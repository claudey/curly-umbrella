const { test, expect } = require('@playwright/test');

// From SEED_DATA_SUMMARY.md
const SEED_CREDENTIALS = {
  universalPassword: 'password123456',
  admin: 'brokersync+admin1@boughtspot.com',
  agent: 'brokers+01@boughtspot.com', // John Doe - Premium Insurance Brokers
  teamLead: 'brokers+02@boughtspot.com' // Jane Smith - Premium Insurance Brokers
};

test.describe('Real Login Tests with Seed Data', () => {
  test('Can login as admin and see dashboard', async ({ page }) => {
    await page.goto('/users/sign_in');
    
    // Fill in the actual login form
    await page.fill('input[name="user[email]"]', SEED_CREDENTIALS.admin);
    await page.fill('input[name="user[password]"]', SEED_CREDENTIALS.universalPassword);
    
    // Click the Sign in button
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Should be redirected away from login page
    await expect(page).not.toHaveURL(/sign_in/);
    
    // Should see dashboard content
    await expect(page.locator('body')).toContainText(/dashboard|welcome/i);
    
    console.log('✅ Admin login successful');
  });

  test('Can login as agent and see appropriate content', async ({ page }) => {
    await page.goto('/users/sign_in');
    
    // Fill login form with agent credentials
    await page.fill('input[name="user[email]"]', SEED_CREDENTIALS.agent);
    await page.fill('input[name="user[password]"]', SEED_CREDENTIALS.universalPassword);
    
    // Submit form
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Should be redirected to dashboard
    await expect(page).not.toHaveURL(/sign_in/);
    
    // Should see user name or welcome message
    await expect(page.locator('body')).toContainText(/John|welcome|dashboard/i);
    
    console.log('✅ Agent login successful');
  });

  test('Can logout successfully', async ({ page }) => {
    // First login
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', SEED_CREDENTIALS.agent);
    await page.fill('input[name="user[password]"]', SEED_CREDENTIALS.universalPassword);
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for login to complete
    await expect(page).not.toHaveURL(/sign_in/);
    
    // Look for logout link/button and click it
    const logoutButton = page.locator('a:has-text("Logout"), a:has-text("Sign out"), button:has-text("Logout")').first();
    await expect(logoutButton).toBeVisible();
    await logoutButton.click();
    
    // Should be redirected back to login
    await expect(page).toHaveURL(/sign_in/);
    
    console.log('✅ Logout successful');
  });

  test('Invalid credentials show error', async ({ page }) => {
    await page.goto('/users/sign_in');
    
    // Try invalid credentials
    await page.fill('input[name="user[email]"]', 'invalid@example.com');
    await page.fill('input[name="user[password]"]', 'wrongpassword');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Should stay on login page
    await expect(page).toHaveURL(/sign_in/);
    
    // Should show some kind of error message
    await expect(page.locator('body')).toContainText(/invalid|error|incorrect/i);
    
    console.log('✅ Invalid login properly rejected');
  });
});