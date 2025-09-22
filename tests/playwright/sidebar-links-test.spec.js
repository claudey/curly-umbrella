const { test, expect } = require('@playwright/test');

test.describe('Sidebar Navigation Links', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the application and log in
    await page.goto('http://localhost:3000');
    
    // Check if we're redirected to login
    if (page.url().includes('/users/sign_in')) {
      console.log('Logging in with test credentials...');
      
      // Fill in login form
      await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
      await page.fill('input[name="user[password]"]', 'password123456');
      
      // Submit the form
      await page.click('input[type="submit"], button[type="submit"]');
      
      // Wait for redirect after login
      await page.waitForURL('http://localhost:3000/', { timeout: 5000 });
      console.log('Successfully logged in');
    }
  });

  test('should access Dashboard link', async ({ page }) => {
    console.log('Testing Dashboard link...');
    
    // Try to access dashboard directly
    await page.goto('http://localhost:3000/');
    
    // Check if page loads successfully
    const title = await page.title();
    console.log('Dashboard page title:', title);
    
    // Check for common error indicators
    const hasError = await page.locator('text=error').count() > 0;
    const hasException = await page.locator('text=exception').count() > 0;
    const hasMissingTemplate = await page.locator('text=template').count() > 0;
    
    console.log('Dashboard - Has error:', hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
    
    if (hasError || hasException || hasMissingTemplate) {
      const errorText = await page.textContent('body');
      console.log('Dashboard error details:', errorText.substring(0, 500));
    }
  });

  test('should access Global Search link', async ({ page }) => {
    console.log('Testing Global Search link...');
    
    await page.goto('http://localhost:3000/search');
    await page.waitForTimeout(1000);
    
    const url = page.url();
    console.log('Global Search URL:', url);
    
    const hasError = await page.locator('text=error').count() > 0;
    const hasException = await page.locator('text=exception').count() > 0;
    const hasMissingTemplate = await page.locator('text=template').count() > 0;
    
    console.log('Global Search - Has error:', hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
    
    if (hasError || hasException || hasMissingTemplate) {
      const errorText = await page.textContent('body');
      console.log('Global Search error details:', errorText.substring(0, 500));
    }
  });

  test('should access Clients section links', async ({ page }) => {
    console.log('Testing Clients section links...');
    
    // Test All Clients
    console.log('Testing /clients...');
    await page.goto('http://localhost:3000/clients');
    await page.waitForTimeout(1000);
    
    let hasError = await page.locator('text=error').count() > 0;
    let hasException = await page.locator('text=exception').count() > 0;
    let hasMissingTemplate = await page.locator('text=template').count() > 0;
    
    console.log('All Clients - Has error:', hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
    
    if (hasError || hasException || hasMissingTemplate) {
      const errorText = await page.textContent('body');
      console.log('All Clients error details:', errorText.substring(0, 500));
    }
    
    // Test Add Client
    console.log('Testing /clients/new...');
    await page.goto('http://localhost:3000/clients/new');
    await page.waitForTimeout(1000);
    
    hasError = await page.locator('text=error').count() > 0;
    hasException = await page.locator('text=exception').count() > 0;
    hasMissingTemplate = await page.locator('text=template').count() > 0;
    
    console.log('Add Client - Has error:', hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
    
    if (hasError || hasException || hasMissingTemplate) {
      const errorText = await page.textContent('body');
      console.log('Add Client error details:', errorText.substring(0, 500));
    }
  });

  test('should access Applications section links', async ({ page }) => {
    console.log('Testing Applications section links...');
    
    const applications = [
      { name: 'Motor Insurance', path: '/motor_applications' },
      { name: 'Life Insurance', path: '/life_applications' },
      { name: 'Fire Insurance', path: '/fire_applications' },
      { name: 'Residential Insurance', path: '/residential_applications' }
    ];
    
    for (const app of applications) {
      console.log(`Testing ${app.name} at ${app.path}...`);
      await page.goto(`http://localhost:3000${app.path}`);
      await page.waitForTimeout(1000);
      
      const hasError = await page.locator('text=error').count() > 0;
      const hasException = await page.locator('text=exception').count() > 0;
      const hasMissingTemplate = await page.locator('text=template').count() > 0;
      
      console.log(`${app.name} - Has error:`, hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
      
      if (hasError || hasException || hasMissingTemplate) {
        const errorText = await page.textContent('body');
        console.log(`${app.name} error details:`, errorText.substring(0, 500));
      }
    }
  });

  test('should access Quotes section links', async ({ page }) => {
    console.log('Testing Quotes section links...');
    
    const quotes = [
      { name: 'All Quotes', path: '/quotes' },
      { name: 'Pending Reviews', path: '/quotes/pending' },
      { name: 'Expiring Soon', path: '/quotes/expiring_soon' }
    ];
    
    for (const quote of quotes) {
      console.log(`Testing ${quote.name} at ${quote.path}...`);
      await page.goto(`http://localhost:3000${quote.path}`);
      await page.waitForTimeout(1000);
      
      const hasError = await page.locator('text=error').count() > 0;
      const hasException = await page.locator('text=exception').count() > 0;
      const hasMissingTemplate = await page.locator('text=template').count() > 0;
      
      console.log(`${quote.name} - Has error:`, hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
      
      if (hasError || hasException || hasMissingTemplate) {
        const errorText = await page.textContent('body');
        console.log(`${quote.name} error details:`, errorText.substring(0, 500));
      }
    }
  });

  test('should access Documents section links', async ({ page }) => {
    console.log('Testing Documents section links...');
    
    const documents = [
      { name: 'All Documents', path: '/documents' },
      { name: 'Upload Document', path: '/documents/new' },
      { name: 'Archived', path: '/documents/archived' },
      { name: 'Expiring Soon', path: '/documents/expiring' }
    ];
    
    for (const doc of documents) {
      console.log(`Testing ${doc.name} at ${doc.path}...`);
      await page.goto(`http://localhost:3000${doc.path}`);
      await page.waitForTimeout(1000);
      
      const hasError = await page.locator('text=error').count() > 0;
      const hasException = await page.locator('text=exception').count() > 0;
      const hasMissingTemplate = await page.locator('text=template').count() > 0;
      
      console.log(`${doc.name} - Has error:`, hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
      
      if (hasError || hasException || hasMissingTemplate) {
        const errorText = await page.textContent('body');
        console.log(`${doc.name} error details:`, errorText.substring(0, 500));
      }
    }
  });

  test('should access Insurance Companies section links', async ({ page }) => {
    console.log('Testing Insurance Companies section links...');
    
    const companies = [
      { name: 'All Companies', path: '/insurance_companies_admin' },
      { name: 'Pending Approval', path: '/insurance_companies_admin/pending' }
    ];
    
    for (const company of companies) {
      console.log(`Testing ${company.name} at ${company.path}...`);
      await page.goto(`http://localhost:3000${company.path}`);
      await page.waitForTimeout(1000);
      
      const hasError = await page.locator('text=error').count() > 0;
      const hasException = await page.locator('text=exception').count() > 0;
      const hasMissingTemplate = await page.locator('text=template').count() > 0;
      
      console.log(`${company.name} - Has error:`, hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
      
      if (hasError || hasException || hasMissingTemplate) {
        const errorText = await page.textContent('body');
        console.log(`${company.name} error details:`, errorText.substring(0, 500));
      }
    }
  });

  test('should access Reports section links', async ({ page }) => {
    console.log('Testing Reports section links...');
    
    const reports = [
      { name: 'Performance', path: '/executive/performance' },
      { name: 'Analytics', path: '/executive/analytics' }
    ];
    
    for (const report of reports) {
      console.log(`Testing ${report.name} at ${report.path}...`);
      await page.goto(`http://localhost:3000${report.path}`);
      await page.waitForTimeout(1000);
      
      const hasError = await page.locator('text=error').count() > 0;
      const hasException = await page.locator('text=exception').count() > 0;
      const hasMissingTemplate = await page.locator('text=template').count() > 0;
      
      console.log(`${report.name} - Has error:`, hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
      
      if (hasError || hasException || hasMissingTemplate) {
        const errorText = await page.textContent('body');
        console.log(`${report.name} error details:`, errorText.substring(0, 500));
      }
    }
  });

  test('should access Settings section links', async ({ page }) => {
    console.log('Testing Settings section links...');
    
    const settings = [
      { name: 'Organization', path: '/settings/organization' },
      { name: 'Users', path: '/settings/users' },
      { name: 'Preferences', path: '/settings/preferences' }
    ];
    
    for (const setting of settings) {
      console.log(`Testing ${setting.name} at ${setting.path}...`);
      await page.goto(`http://localhost:3000${setting.path}`);
      await page.waitForTimeout(1000);
      
      const hasError = await page.locator('text=error').count() > 0;
      const hasException = await page.locator('text=exception').count() > 0;
      const hasMissingTemplate = await page.locator('text=template').count() > 0;
      
      console.log(`${setting.name} - Has error:`, hasError, 'Has exception:', hasException, 'Has missing template:', hasMissingTemplate);
      
      if (hasError || hasException || hasMissingTemplate) {
        const errorText = await page.textContent('body');
        console.log(`${setting.name} error details:`, errorText.substring(0, 500));
      }
    }
  });
});