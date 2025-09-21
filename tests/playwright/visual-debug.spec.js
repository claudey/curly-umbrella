const { test, expect } = require('@playwright/test');

test('Visual debug - see what is actually displayed', async ({ page }) => {
  // Navigate to the home page
  await page.goto('http://localhost:3000');
  
  // Wait for the page to load
  await page.waitForLoadState('networkidle');
  
  // Take a screenshot to see what's actually displayed
  await page.screenshot({ 
    path: 'test-results/visual-debug-current-state.png', 
    fullPage: true 
  });
  
  // Get the actual HTML content
  const htmlContent = await page.content();
  console.log('Page HTML length:', htmlContent.length);
  
  // Check for any error text
  const bodyText = await page.textContent('body');
  console.log('Body text preview:', bodyText.substring(0, 200));
  
  // Check the page title
  const title = await page.title();
  console.log('Page title:', title);
});