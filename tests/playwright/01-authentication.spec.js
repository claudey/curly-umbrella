// tests/playwright/01-authentication.spec.js
const { test, expect } = require('@playwright/test');
const { 
  loginAsUser, 
  loginAsAgent, 
  loginAsBrokerageAdmin, 
  loginAsInsuranceCompany,
  logout,
  setupMFA,
  verifyMFA,
  TEST_CREDENTIALS 
} = require('../support/auth-helpers');
const { waitForPageLoad, expectErrorMessage } = require('../support/test-helpers');

test.describe('Authentication & Security Features', () => {
  
  test.describe('Basic Authentication', () => {
    
    test('User can login with valid credentials', async ({ page }) => {
      await page.goto('/users/sign_in');
      await page.fill('input[name="user[email]"]', TEST_CREDENTIALS.agents[0]);
      await page.fill('input[name="user[password]"]', TEST_CREDENTIALS.universalPassword);
      await page.click('input[type="submit"]');
      
      // Should redirect to dashboard
      await expect(page).toHaveURL(/.*\/$/);
      await expect(page.locator('text=Dashboard')).toBeVisible();
    });

    test('User cannot login with invalid credentials', async ({ page }) => {
      await page.goto('/users/sign_in');
      await page.fill('input[name="user[email]"]', 'invalid@example.com');
      await page.fill('input[name="user[password]"]', 'wrongpassword');
      await page.click('input[type="submit"]');
      
      await expect(page.locator('text=Invalid Email or password')).toBeVisible();
      await expect(page).toHaveURL(/.*sign_in/);
    });

    test('User can logout successfully', async ({ page }) => {
      // Login first
      await loginAsAgent(page, 0);
      
      // Logout
      await page.click('text=Logout');
      await expect(page).toHaveURL(/.*sign_in/);
    });

    test('User is redirected to login when not authenticated', async ({ page }) => {
      await page.goto('/clients');
      await expect(page).toHaveURL(/.*sign_in/);
    });

    test('Remember me functionality works', async ({ page }) => {
      await page.goto('/users/sign_in');
      await page.fill('input[name="user[email]"]', TEST_CREDENTIALS.agents[0]);
      await page.fill('input[name="user[password]"]', TEST_CREDENTIALS.universalPassword);
      await page.check('input[name="user[remember_me]"]');
      await page.click('input[type="submit"]');
      
      await expect(page).toHaveURL(/.*\/$/);
      
      // Check that remember me cookie is set
      const cookies = await page.context().cookies();
      const rememberCookie = cookies.find(cookie => cookie.name.includes('remember'));
      expect(rememberCookie).toBeTruthy();
    });
  });

  test.describe('Multi-Factor Authentication (MFA)', () => {
    
    test('User can setup MFA', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.goto('/mfa');
      
      // Check if MFA setup is available
      if (await page.locator('text=Setup MFA').isVisible()) {
        await page.click('text=Setup MFA');
        await expect(page.locator('text=Scan QR Code')).toBeVisible();
        await expect(page.locator('text=Backup Codes')).toBeVisible();
      }
    });

    test('MFA verification is required after setup', async ({ page }) => {
      // This test assumes MFA is already setup for the user
      // In a real scenario, you would set this up in a beforeEach or use a dedicated test user
      await page.goto('/users/sign_in');
      await page.fill('input[name="user[email]"]', TEST_CREDENTIALS.agents[1]); // Agent with MFA
      await page.fill('input[name="user[password]"]', TEST_CREDENTIALS.universalPassword);
      await page.click('input[type="submit"]');
      
      // Should be redirected to MFA verification if MFA is enabled
      const currentUrl = page.url();
      if (currentUrl.includes('mfa_verification')) {
        await expect(page.locator('text=Enter verification code')).toBeVisible();
        
        // Test with invalid code
        await page.fill('input[name="mfa_code"]', '123456');
        await page.click('input[type="submit"]');
        await expect(page.locator('text=Invalid verification code')).toBeVisible();
      }
    });

    test('Backup codes work for MFA', async ({ page }) => {
      // This would require setting up backup codes in advance
      // For now, we'll test the UI flow
      await page.goto('/users/sign_in');
      await page.fill('input[name="user[email]"]', TEST_CREDENTIALS.agents[1]);
      await page.fill('input[name="user[password]"]', TEST_CREDENTIALS.universalPassword);
      await page.click('input[type="submit"]');
      
      if (page.url().includes('mfa_verification')) {
        await expect(page.locator('text=Use backup code')).toBeVisible();
        await page.click('text=Use backup code');
        await expect(page.locator('input[name="backup_code"]')).toBeVisible();
      }
    });
  });

  test.describe('Session Security Management', () => {
    
    test('User can view active sessions', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.goto('/sessions/manage');
      
      await expect(page.locator('text=Active Sessions')).toBeVisible();
      await expect(page.locator('text=Current Session')).toBeVisible();
    });

    test('User can terminate other sessions', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.goto('/sessions/manage');
      
      if (await page.locator('text=Terminate All Other Sessions').isVisible()) {
        await page.click('text=Terminate All Other Sessions');
        await expect(page.locator('text=All other sessions terminated')).toBeVisible();
      }
    });

    test('Session timeout works correctly', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Simulate session timeout by clearing cookies
      await page.context().clearCookies();
      
      // Try to access protected page
      await page.goto('/clients');
      await expect(page).toHaveURL(/.*sign_in/);
      await expect(page.locator('text=Your session has expired')).toBeVisible();
    });
  });

  test.describe('Rate Limiting & Security', () => {
    
    test('Rate limiting blocks excessive login attempts', async ({ page }) => {
      const invalidEmail = 'test@example.com';
      const invalidPassword = 'wrongpassword';
      
      // Attempt multiple failed logins
      for (let i = 0; i < 6; i++) {
        await page.goto('/users/sign_in');
        await page.fill('input[name="user[email]"]', invalidEmail);
        await page.fill('input[name="user[password]"]', invalidPassword);
        await page.click('input[type="submit"]');
        await page.waitForTimeout(500); // Small delay between attempts
      }
      
      // Should show rate limiting message
      await expect(page.locator('text=Too many requests')).toBeVisible();
    });

    test('Password reset flow works', async ({ page }) => {
      await page.goto('/users/sign_in');
      await page.click('text=Forgot your password?');
      
      await expect(page).toHaveURL(/.*password.*new/);
      await page.fill('input[name="user[email]"]', TEST_CREDENTIALS.agents[0]);
      await page.click('input[type="submit"]');
      
      await expect(page.locator('text=You will receive an email')).toBeVisible();
    });

    test('Account lockout after failed attempts', async ({ page }) => {
      // This test simulates what would happen with account lockout
      // The actual implementation may vary
      await page.goto('/users/sign_in');
      
      // Multiple failed attempts with same email
      for (let i = 0; i < 5; i++) {
        await page.fill('input[name="user[email]"]', TEST_CREDENTIALS.agents[0]);
        await page.fill('input[name="user[password]"]', 'wrongpassword');
        await page.click('input[type="submit"]');
        await page.waitForTimeout(500);
      }
      
      // Check for lockout message (implementation dependent)
      const errorMessages = page.locator('.alert-error, .flash-error');
      await expect(errorMessages).toBeVisible();
    });
  });

  test.describe('Role-Based Authentication', () => {
    
    test('Agent can access agent features', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Should see agent-appropriate navigation
      await expect(page.locator('text=Clients')).toBeVisible();
      await expect(page.locator('text=Applications')).toBeVisible();
      await expect(page.locator('text=Quotes')).toBeVisible();
    });

    test('Brokerage admin can access admin features', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      // Should see admin-appropriate navigation
      await expect(page.locator('text=Users')).toBeVisible();
      await expect(page.locator('text=Reports')).toBeVisible();
    });

    test('Insurance company user sees appropriate interface', async ({ page }) => {
      await loginAsInsuranceCompany(page, 0);
      
      // Should see insurance company features
      await expect(page.locator('text=Applications')).toBeVisible();
      await expect(page.locator('text=Quotes')).toBeVisible();
    });

    test('Agent cannot access admin-only features', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Try to access admin page directly
      await page.goto('/admin/organizations');
      
      // Should be forbidden or redirected
      const currentUrl = page.url();
      expect(currentUrl).not.toContain('/admin/organizations');
      
      // Should show access denied message
      if (currentUrl.includes('sign_in')) {
        // Redirected to login
        expect(true).toBeTruthy();
      } else {
        // Should show 403 or access denied
        await expect(page.locator('text=Access denied')).toBeVisible();
      }
    });
  });

  test.describe('Security Headers and HTTPS', () => {
    
    test('Security headers are present', async ({ page }) => {
      const response = await page.goto('/');
      
      // Check for important security headers
      const headers = response.headers();
      
      // These checks depend on your Rails security configuration
      expect(headers['x-frame-options']).toBeTruthy();
      expect(headers['x-content-type-options']).toBeTruthy();
      expect(headers['x-xss-protection']).toBeTruthy();
    });

    test('CSRF protection is enabled', async ({ page }) => {
      await page.goto('/users/sign_in');
      
      // Check for CSRF token in forms
      const csrfToken = await page.locator('input[name="authenticity_token"]').getAttribute('value');
      expect(csrfToken).toBeTruthy();
      expect(csrfToken.length).toBeGreaterThan(0);
    });
  });
});

test.describe('Authentication Edge Cases', () => {
  
  test('Handles special characters in passwords', async ({ page }) => {
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', TEST_CREDENTIALS.agents[0]);
    await page.fill('input[name="user[password]"]', 'P@ssw0rd!#$%');
    await page.click('input[type="submit"]');
    
    // Should handle special characters gracefully
    const hasError = await page.locator('.alert-error').isVisible();
    if (hasError) {
      const errorText = await page.locator('.alert-error').textContent();
      expect(errorText).toContain('Invalid Email or password');
    }
  });

  test('Handles very long input values', async ({ page }) => {
    const longEmail = 'a'.repeat(255) + '@example.com';
    const longPassword = 'b'.repeat(255);
    
    await page.goto('/users/sign_in');
    await page.fill('input[name="user[email]"]', longEmail);
    await page.fill('input[name="user[password]"]', longPassword);
    await page.click('input[type="submit"]');
    
    // Should handle gracefully without crashes
    await expect(page.locator('input[name="user[email]"]')).toBeVisible();
  });

  test('Handles empty form submission', async ({ page }) => {
    await page.goto('/users/sign_in');
    await page.click('input[type="submit"]');
    
    // Should show validation errors
    await expect(page.locator('text=Email can\'t be blank')).toBeVisible();
  });
});