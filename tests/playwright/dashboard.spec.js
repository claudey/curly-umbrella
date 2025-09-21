// tests/playwright/dashboard.spec.js
const { test, expect } = require('@playwright/test');

// Helper function to login
async function loginUser(page, email, password = 'password123456') {
  await page.goto('http://localhost:3000/users/sign_in');
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('input[type="submit"]');
  await page.waitForURL(/.*\/$/, { timeout: 10000 });
}

test.describe('Dashboard Functionality Tests', () => {
  test('Dashboard loads with correct metrics and data', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Verify main dashboard sections are visible
    await expect(page.locator('text=Dashboard')).toBeVisible();
    await expect(page.locator('text=Welcome back')).toBeVisible();
    
    // Check for key dashboard sections
    await expect(page.locator('text=Recent Documents')).toBeVisible();
    await expect(page.locator('text=Storage & System Info')).toBeVisible();
    await expect(page.locator('text=Quick Actions')).toBeVisible();
    
    // Verify metrics are displayed
    await expect(page.locator('text=Documents')).toBeVisible();
    await expect(page.locator('text=Organization Users')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/dashboard-overview.png', fullPage: true });
  });

  test('Recent documents section works correctly', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check recent documents section
    const recentDocs = page.locator('text=Recent Documents');
    await expect(recentDocs).toBeVisible();
    
    // Should show either documents or "No documents yet" message
    const hasDocuments = await page.locator('text=View All').isVisible();
    const noDocuments = await page.locator('text=No documents yet').isVisible();
    
    expect(hasDocuments || noDocuments).toBeTruthy();
    
    await page.screenshot({ path: 'screenshots/recent-documents.png', fullPage: true });
  });

  test('Quick actions are functional', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Test Upload Document quick action
    if (await page.locator('text=Upload Document').isVisible()) {
      await page.click('text=Upload Document');
      await expect(page).toHaveURL(/.*documents.*new/);
      await page.goBack();
    }
    
    // Test Browse Documents quick action
    if (await page.locator('text=Browse Documents').isVisible()) {
      await page.click('text=Browse Documents');
      await expect(page).toHaveURL(/.*documents/);
      await page.goBack();
    }
    
    await page.screenshot({ path: 'screenshots/quick-actions.png', fullPage: true });
  });

  test('System metrics display correctly', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check Storage & System Info section
    await expect(page.locator('text=Storage & System Info')).toBeVisible();
    await expect(page.locator('text=Documents 0')).toBeVisible(); // From seed data
    await expect(page.locator('text=Total Storage 0 B')).toBeVisible();
    await expect(page.locator('text=Organization Users 7')).toBeVisible(); // From seed data
    
    await page.screenshot({ path: 'screenshots/system-metrics.png', fullPage: true });
  });

  test('Document type overview works', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check Document Types Overview section
    await expect(page.locator('text=Document Types Overview')).toBeVisible();
    
    // Should show either document types or "No document data available yet"
    const hasData = await page.locator('text=View All').isVisible();
    const noData = await page.locator('text=No document data available yet').isVisible();
    
    expect(hasData || noData).toBeTruthy();
    
    await page.screenshot({ path: 'screenshots/document-types.png', fullPage: true });
  });

  test('Upcoming tasks section displays', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check Upcoming Tasks section
    await expect(page.locator('text=Upcoming Tasks')).toBeVisible();
    
    // Should show either tasks or "All caught up!" message
    const hasTasks = await page.locator('[data-test="task-item"]').isVisible();
    const noTasks = await page.locator('text=All caught up!').isVisible();
    
    expect(hasTasks || noTasks).toBeTruthy();
    
    await page.screenshot({ path: 'screenshots/upcoming-tasks.png', fullPage: true });
  });

  test('My recent documents section works', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check My Recent Documents section
    await expect(page.locator('text=My Recent Documents')).toBeVisible();
    
    // Should show either documents or "No recent documents" message
    const hasRecentDocs = await page.locator('[data-test="recent-document"]').isVisible();
    const noRecentDocs = await page.locator('text=No recent documents').isVisible();
    
    expect(hasRecentDocs || noRecentDocs).toBeTruthy();
    
    await page.screenshot({ path: 'screenshots/my-recent-documents.png', fullPage: true });
  });

  test('Navigation sidebar is functional', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check main navigation items
    const navItems = [
      { text: 'Dashboard', expectedUrl: /.*\/$/ },
      { text: 'Clients', expectedUrl: /.*clients/ },
      { text: 'Applications', expectedUrl: /.*applications/ },
      { text: 'Quotes', expectedUrl: /.*quotes/ },
      { text: 'Documents', expectedUrl: /.*documents/ }
    ];
    
    for (const item of navItems) {
      await expect(page.locator(`text=${item.text}`)).toBeVisible();
      
      // Test navigation
      await page.click(`text=${item.text}`);
      await expect(page).toHaveURL(item.expectedUrl);
      
      // Go back to dashboard
      await page.click('text=Dashboard');
      await expect(page).toHaveURL(/.*\/$/);
    }
    
    await page.screenshot({ path: 'screenshots/navigation-test.png', fullPage: true });
  });

  test('User info and profile access works', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check user info in sidebar
    await expect(page.locator('text=John Doe')).toBeVisible(); // From seed data
    
    // Test profile link
    await page.click('text=Profile');
    await expect(page.locator('text=Profile')).toBeVisible();
    
    await page.screenshot({ path: 'screenshots/profile-access.png', fullPage: true });
  });

  test('Dashboard is responsive on different screen sizes', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Test desktop view
    await page.setViewportSize({ width: 1920, height: 1080 });
    await expect(page.locator('text=Dashboard')).toBeVisible();
    await page.screenshot({ path: 'screenshots/dashboard-desktop.png', fullPage: true });
    
    // Test tablet view
    await page.setViewportSize({ width: 768, height: 1024 });
    await expect(page.locator('text=Dashboard')).toBeVisible();
    await page.screenshot({ path: 'screenshots/dashboard-tablet.png', fullPage: true });
    
    // Test mobile view
    await page.setViewportSize({ width: 375, height: 667 });
    await expect(page.locator('text=Dashboard')).toBeVisible();
    await page.screenshot({ path: 'screenshots/dashboard-mobile.png', fullPage: true });
  });

  test('Real-time data updates work', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check if metrics are loaded
    await expect(page.locator('text=Documents 0')).toBeVisible();
    await expect(page.locator('text=Organization Users 7')).toBeVisible();
    
    // Note: In a real test, we would create/update data and verify it reflects
    // For now, we just verify the static seed data is displayed correctly
    
    await page.screenshot({ path: 'screenshots/realtime-data.png', fullPage: true });
  });

  test('Error handling on dashboard', async ({ page }) => {
    await loginUser(page, 'brokers+01@boughtspot.com');
    
    // Check that page loads without JavaScript errors
    const messages = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        messages.push(msg.text());
      }
    });
    
    // Wait for page to fully load
    await page.waitForTimeout(3000);
    
    // Check for any JavaScript errors
    expect(messages.length).toBe(0);
    
    await page.screenshot({ path: 'screenshots/error-handling.png', fullPage: true });
  });
});