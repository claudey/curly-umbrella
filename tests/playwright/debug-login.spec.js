const { test, expect } = require('@playwright/test');

test.describe('Debug Login Process', () => {
  test('Step by step login debug', async ({ page }) => {
    console.log('1. Going to login page...');
    await page.goto('/users/sign_in');
    console.log(`✅ Login page loaded: ${page.url()}`);
    
    // Take screenshot of login page
    await page.screenshot({ path: 'test-results/debug-login-page.png' });
    
    console.log('2. Filling email...');
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    
    console.log('3. Filling password...');
    await page.fill('input[name="user[password]"]', 'password123456');
    
    console.log('4. Clicking submit...');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait a bit and see what happens
    await page.waitForTimeout(3000);
    
    console.log(`5. After submit - URL: ${page.url()}`);
    
    // Take screenshot of result
    await page.screenshot({ path: 'test-results/debug-after-submit.png' });
    
    // Check if we're still on login page or moved somewhere else
    if (page.url().includes('sign_in')) {
      console.log('❌ Still on login page - login failed');
      
      // Look for error messages
      const errorText = await page.textContent('body');
      console.log('Page content preview:', errorText.substring(0, 200));
    } else {
      console.log('✅ Redirected away from login page - login succeeded');
    }
  });
});