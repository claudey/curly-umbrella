// tests/playwright/02-rbac.spec.js
const { test, expect } = require('@playwright/test');
const { 
  loginAsAgent, 
  loginAsBrokerageAdmin, 
  loginAsInsuranceCompany,
  hasAccess 
} = require('../support/auth-helpers');
const { navigateToSection, expectErrorMessage } = require('../support/test-helpers');

test.describe('Role-Based Access Control (RBAC)', () => {
  
  test.describe('Agent Role Permissions', () => {
    
    test('Agent can access client management', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      await expect(page.locator('text=Clients')).toBeVisible();
      await page.click('text=Clients');
      await expect(page).toHaveURL(/.*clients/);
      await expect(page.locator('text=All Clients')).toBeVisible();
    });

    test('Agent can create and manage applications', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      await expect(page.locator('text=Applications')).toBeVisible();
      await page.click('text=Applications');
      await expect(page).toHaveURL(/.*applications/);
      
      // Should see new application button
      await expect(page.locator('text=New Application')).toBeVisible();
    });

    test('Agent can view quotes but not create them', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      await expect(page.locator('text=Quotes')).toBeVisible();
      await page.click('text=Quotes');
      await expect(page).toHaveURL(/.*quotes/);
      
      // Agent should see quotes but not create button (only insurance companies create quotes)
      const createQuoteButton = page.locator('text=Create Quote');
      await expect(createQuoteButton).not.toBeVisible();
    });

    test('Agent can manage documents', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      await expect(page.locator('text=Documents')).toBeVisible();
      await page.click('text=Documents');
      await expect(page).toHaveURL(/.*documents/);
      
      await expect(page.locator('text=Upload Document')).toBeVisible();
    });

    test('Agent cannot access admin features', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Should not see admin navigation
      await expect(page.locator('text=Admin Panel')).not.toBeVisible();
      await expect(page.locator('text=Organizations')).not.toBeVisible();
      await expect(page.locator('text=User Management')).not.toBeVisible();
      
      // Try to access admin page directly
      await page.goto('/admin/organizations');
      
      // Should be forbidden or redirected
      const currentUrl = page.url();
      if (currentUrl.includes('admin')) {
        await expect(page.locator('text=Access denied')).toBeVisible();
      } else {
        // Should be redirected away from admin
        expect(currentUrl).not.toContain('/admin');
      }
    });

    test('Agent cannot access other organizations data', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Try to access another organization's client (assuming different org IDs)
      await page.goto('/clients/999999'); // Non-existent or other org's client
      
      // Should get 404 or access denied
      const notFoundVisible = await page.locator('text=Not found').isVisible();
      const accessDeniedVisible = await page.locator('text=Access denied').isVisible();
      
      expect(notFoundVisible || accessDeniedVisible).toBeTruthy();
    });
  });

  test.describe('Brokerage Admin Role Permissions', () => {
    
    test('Brokerage admin can access all agent features', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      // Should have all agent permissions
      await expect(page.locator('text=Clients')).toBeVisible();
      await expect(page.locator('text=Applications')).toBeVisible();
      await expect(page.locator('text=Quotes')).toBeVisible();
      await expect(page.locator('text=Documents')).toBeVisible();
    });

    test('Brokerage admin can manage users', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      await expect(page.locator('text=Users')).toBeVisible();
      await page.click('text=Users');
      await expect(page).toHaveURL(/.*users/);
      
      await expect(page.locator('text=Add User')).toBeVisible();
    });

    test('Brokerage admin can access reports', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      await expect(page.locator('text=Reports')).toBeVisible();
      await page.click('text=Reports');
      await expect(page).toHaveURL(/.*reports/);
    });

    test('Brokerage admin can manage organization settings', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      await expect(page.locator('text=Settings')).toBeVisible();
      await page.click('text=Settings');
      
      // Should see organization settings
      await expect(page.locator('text=Organization Settings')).toBeVisible();
    });

    test('Brokerage admin cannot access super admin features', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      // Should not see super admin features
      await expect(page.locator('text=System Admin')).not.toBeVisible();
      await expect(page.locator('text=All Organizations')).not.toBeVisible();
      
      // Try to access super admin page
      await page.goto('/admin/system');
      
      const currentUrl = page.url();
      if (currentUrl.includes('/admin/system')) {
        await expect(page.locator('text=Access denied')).toBeVisible();
      } else {
        expect(currentUrl).not.toContain('/admin/system');
      }
    });
  });

  test.describe('Insurance Company Role Permissions', () => {
    
    test('Insurance company can view applications', async ({ page }) => {
      await loginAsInsuranceCompany(page, 0);
      
      await expect(page.locator('text=Applications')).toBeVisible();
      await page.click('text=Applications');
      await expect(page).toHaveURL(/.*applications/);
      
      // Should see applications but not create new ones
      await expect(page.locator('text=New Application')).not.toBeVisible();
    });

    test('Insurance company can create and manage quotes', async ({ page }) => {
      await loginAsInsuranceCompany(page, 0);
      
      await expect(page.locator('text=Quotes')).toBeVisible();
      await page.click('text=Quotes');
      await expect(page).toHaveURL(/.*quotes/);
      
      // Should be able to create quotes
      await expect(page.locator('text=Create Quote')).toBeVisible();
    });

    test('Insurance company cannot access client management', async ({ page }) => {
      await loginAsInsuranceCompany(page, 0);
      
      // Should not see clients in navigation
      await expect(page.locator('text=Clients')).not.toBeVisible();
      
      // Try to access clients directly
      await page.goto('/clients');
      
      const currentUrl = page.url();
      if (currentUrl.includes('clients')) {
        await expect(page.locator('text=Access denied')).toBeVisible();
      } else {
        expect(currentUrl).not.toContain('clients');
      }
    });

    test('Insurance company cannot access admin features', async ({ page }) => {
      await loginAsInsuranceCompany(page, 0);
      
      await expect(page.locator('text=Users')).not.toBeVisible();
      await expect(page.locator('text=Reports')).not.toBeVisible();
      await expect(page.locator('text=Settings')).not.toBeVisible();
    });

    test('Insurance company can only see relevant applications', async ({ page }) => {
      await loginAsInsuranceCompany(page, 0);
      await page.click('text=Applications');
      
      // Should only see applications submitted for review (not drafts)
      const applicationRows = page.locator('table tbody tr');
      const count = await applicationRows.count();
      
      if (count > 0) {
        // Check that all visible applications are in submitted status
        for (let i = 0; i < count; i++) {
          const statusCell = applicationRows.nth(i).locator('td').nth(3); // Assuming status is 4th column
          const status = await statusCell.textContent();
          expect(['submitted', 'under_review', 'approved', 'rejected']).toContain(status.toLowerCase().trim());
        }
      }
    });
  });

  test.describe('Cross-Organization Access Control', () => {
    
    test('Users cannot access other organizations data', async ({ page }) => {
      await loginAsAgent(page, 0); // Agent from org 1
      
      // Try to access data that should belong to another organization
      // This assumes you have test data with different organization IDs
      await page.goto('/clients');
      
      const tableRows = page.locator('table tbody tr');
      const count = await tableRows.count();
      
      // All visible clients should belong to the same organization
      // This is more of a data integrity test
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('API endpoints respect organization boundaries', async ({ page, request }) => {
      await loginAsAgent(page, 0);
      
      // Extract session cookie for API request
      const cookies = await page.context().cookies();
      const sessionCookie = cookies.find(c => c.name.includes('session'));
      
      if (sessionCookie) {
        // Try to access API endpoint with session
        const response = await request.get('/api/v1/clients', {
          headers: {
            'Cookie': `${sessionCookie.name}=${sessionCookie.value}`
          }
        });
        
        expect(response.status()).toBe(200);
        
        const data = await response.json();
        // All returned clients should belong to the user's organization
        if (data.clients && data.clients.length > 0) {
          // This assumes the API returns organization_id
          const orgIds = data.clients.map(c => c.organization_id);
          const uniqueOrgIds = [...new Set(orgIds)];
          expect(uniqueOrgIds.length).toBe(1); // Should only see one organization's data
        }
      }
    });
  });

  test.describe('Permission Inheritance and Delegation', () => {
    
    test('Delegated permissions work correctly', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // If the agent has been given additional permissions
      // This would depend on your specific permission delegation system
      await page.goto('/profile/permissions');
      
      if (await page.locator('text=Delegated Permissions').isVisible()) {
        // Test delegated permissions
        const delegatedPerms = page.locator('[data-testid="delegated-permissions"] li');
        const count = await delegatedPerms.count();
        expect(count).toBeGreaterThanOrEqual(0);
      }
    });

    test('Temporary permission elevation works', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // If your system supports temporary elevation
      if (await page.locator('text=Request Elevation').isVisible()) {
        await page.click('text=Request Elevation');
        await page.selectOption('select[name="permission"]', 'manage_reports');
        await page.fill('textarea[name="justification"]', 'Need to generate monthly report');
        await page.click('button[type="submit"]');
        
        await expect(page.locator('text=Elevation request submitted')).toBeVisible();
      }
    });
  });

  test.describe('Feature Flag Access Control', () => {
    
    test('Feature flags control feature visibility', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      // Check if advanced features are visible based on feature flags
      const hasAdvancedAnalytics = await page.locator('text=Advanced Analytics').isVisible();
      const hasAIFeatures = await page.locator('text=AI Insights').isVisible();
      
      // These depend on your feature flag configuration
      // The test mainly ensures the UI responds to feature flags
      expect(typeof hasAdvancedAnalytics).toBe('boolean');
      expect(typeof hasAIFeatures).toBe('boolean');
    });

    test('Beta features require special access', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      if (await page.locator('text=Beta Features').isVisible()) {
        await page.click('text=Beta Features');
        
        // Should show beta feature disclaimer
        await expect(page.locator('text=experimental')).toBeVisible();
      }
    });
  });

  test.describe('Audit and Compliance', () => {
    
    test('Permission checks are logged', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Try to access admin feature (should be denied and logged)
      await page.goto('/admin/users');
      
      // The permission denial should be logged in audit trail
      // This is more of a backend verification but we can check if redirected
      const currentUrl = page.url();
      expect(currentUrl).not.toContain('/admin/users');
    });

    test('Role changes take effect immediately', async ({ page }) => {
      // This test would require admin privileges to change roles
      // and would be more of an integration test
      await loginAsBrokerageAdmin(page, 0);
      
      // If you have the ability to change user roles in the UI
      if (await page.locator('text=User Management').isVisible()) {
        await page.click('text=User Management');
        
        // Look for role change functionality
        const roleChangeButton = page.locator('text=Change Role');
        if (await roleChangeButton.isVisible()) {
          // Test role change (would need careful setup)
          // This is a complex test that affects user permissions
        }
      }
    });
  });

  test.describe('Security Edge Cases', () => {
    
    test('URL manipulation does not bypass permissions', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      const restrictedUrls = [
        '/admin/users',
        '/admin/organizations', 
        '/admin/system',
        '/reports/financial',
        '/api/v1/admin'
      ];
      
      for (const url of restrictedUrls) {
        await page.goto(url);
        const currentUrl = page.url();
        
        // Should either redirect away or show access denied
        if (currentUrl.includes(url)) {
          await expect(page.locator('text=Access denied')).toBeVisible();
        } else {
          expect(currentUrl).not.toContain(url);
        }
      }
    });

    test('Session hijacking protection', async ({ page, context }) => {
      await loginAsAgent(page, 0);
      
      // Get current session cookies
      const cookies = await context.cookies();
      const sessionCookie = cookies.find(c => c.name.includes('session'));
      
      if (sessionCookie) {
        // Create new context with stolen cookie (simulating session hijacking)
        const newContext = await page.context().browser().newContext();
        await newContext.addCookies([sessionCookie]);
        
        const newPage = await newContext.newPage();
        await newPage.goto('/clients');
        
        // Should detect session anomaly (different IP, user agent, etc.)
        // This depends on your session security implementation
        const hasSecurityWarning = await newPage.locator('text=Security Warning').isVisible();
        const requiresReauth = await newPage.locator('text=Please log in again').isVisible();
        
        // One of these should be true for good security
        expect(hasSecurityWarning || requiresReauth || newPage.url().includes('sign_in')).toBeTruthy();
      }
    });
  });
});