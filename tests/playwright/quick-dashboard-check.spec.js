const { test, expect } = require('@playwright/test');

test('Quick dashboard check', async ({ page }) => {
  // Navigate to the home page
  await page.goto('http://localhost:3000');
  
  // Wait for the page to load
  await page.waitForLoadState('domcontentloaded');
  
  // Take a screenshot to see what's actually displayed
  await page.screenshot({ 
    path: 'test-results/quick-dashboard-check.png', 
    fullPage: true 
  });
  
  // Check if page loaded without errors
  const pageTitle = await page.title();
  console.log('Page title:', pageTitle);
  
  // Check for any error messages
  const errorElements = await page.locator('.error, .alert-error').count();
  console.log('Error elements found:', errorElements);
});