// tests/playwright/auth.spec.js
const { test, expect } = require('@playwright/test');

// Helper function to login
async function loginUser(page, email, password = 'password123456') {
  await page.goto('http://localhost:3000/users/sign_in');
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('input[type="submit"]');
}

test.describe('Authentication Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Ensure we start from a clean state
    await page.goto('http://localhost:3000');
  });

  test('User can login with valid credentials and reach dashboard', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Wait for redirect to dashboard
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Take screenshot for verification
    await page.screenshot({ path: 'screenshots/successful-login.png', fullPage: true });
    
    // Verify we're on the dashboard
    await expect(page.locator('text=Dashboard')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=Welcome back')).toBeVisible();
  });

  test('User cannot login with invalid credentials', async ({ page }) => {
    await page.goto('http://localhost:3000/users/sign_in');
    await page.fill('input[name="user[email]"]', 'invalid@example.com');
    await page.fill('input[name="user[password]"]', 'wrongpassword');
    await page.click('input[type="submit"]');
    
    // Should stay on login page with error
    await expect(page).toHaveURL(/.*sign_in/);
    await expect(page.locator('text=Invalid Email or password')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/failed-login.png', fullPage: true });
  });

  test('User can logout successfully', async ({ page }) => {
    // Login first
    await loginUser(page, 'brokers+02@boughtspot.com');
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Logout
    await page.click('text=Logout');
    await expect(page).toHaveURL(/.*sign_in/);
    
    await page.screenshot({ path: 'screenshots/successful-logout.png', fullPage: true });
  });

  test('Different user roles can access appropriate areas', async ({ page }) => {
    // Test Insurance Agent access
    await loginUser(page, 'brokers+01@boughtspot.com');
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Agent should see client management
    await expect(page.locator('text=Clients')).toBeVisible();
    await expect(page.locator('text=Applications')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/agent-dashboard.png', fullPage: true });
    
    // Logout and test Insurance Company user
    await page.click('text=Logout');
    await loginUser(page, 'insurance+company1@boughtspot.com');
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Insurance company should see different navigation
    await expect(page.locator('text=Applications')).toBeVisible();
    await expect(page.locator('text=Quotes')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/insurance-company-dashboard.png', fullPage: true });
  });

  test('Brokerage admin can access admin features', async ({ page }) => {
    await loginUser(page, 'brokersync+admin1@boughtspot.com');
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Admin should have additional navigation options
    await expect(page.locator('text=Reports')).toBeVisible();
    await expect(page.locator('text=Settings')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/admin-dashboard.png', fullPage: true });
  });

  test('Session security works correctly', async ({ page }) => {
    await loginUser(page, 'brokers+03@boughtspot.com');
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Navigate to session management
    await page.goto('http://localhost:3000/sessions/manage');
    await expect(page.locator('text=Active Sessions')).toBeVisible();
    await expect(page.locator('text=Current Session')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/session-management.png', fullPage: true });
  });

  test('Password reset functionality', async ({ page }) => {
    await page.goto('http://localhost:3000/users/sign_in');
    await page.click('text=Forgot your password?');
    
    await expect(page).toHaveURL(/.*password.*new/);
    await page.fill('input[name="user[email]"]', 'brokers+01@boughtspot.com');
    await page.click('input[type="submit"]');
    
    await expect(page.locator('text=You will receive an email')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/password-reset.png', fullPage: true });
  });

  test('Navigation menu is accessible and functional', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Test main navigation items
    const navItems = ['Clients', 'Applications', 'Quotes', 'Documents'];
    
    for (const item of navItems) {
      await expect(page.locator(`text=${item}`)).toBeVisible();
    }
    
    // Test clicking on Clients
    await page.click('text=Clients');
    await expect(page).toHaveURL(/.*clients/);
    await expect(page.locator('text=All Clients')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/clients-page.png', fullPage: true });
  });

  test('User profile and settings access', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    await page.waitForURL(/.*\/$/, { timeout: 10000 });
    
    // Access user profile/settings
    await page.click('text=Profile');
    await expect(page.locator('text=Profile')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/user-profile.png', fullPage: true });
  });
});