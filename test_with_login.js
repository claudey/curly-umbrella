const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  try {
    console.log('Testing life applications page with login...');
    
    // Navigate to the application
    await page.goto('http://localhost:3000/life_applications');
    
    // Should be redirected to login
    await page.waitForURL('**/users/sign_in');
    console.log('✅ Redirected to login as expected');
    
    // Fill in login form
    await page.fill('input[name="user[email]"]', 'brokersync+admin1@boughtspot.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    
    // Submit the form
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for redirect and page load
    await page.waitForURL('**/life_applications', { timeout: 10000 });
    console.log('✅ Successfully redirected to life applications page');
    
    // Check for errors on the page
    const hasError = await page.locator('text=RuntimeError').count() > 0;
    const hasEnumError = await page.locator('text=Undeclared attribute type for enum').count() > 0;
    const hasException = await page.locator('text=Exception').count() > 0;
    
    if (hasError || hasEnumError || hasException) {
      console.log('❌ Page has errors');
      const errorText = await page.textContent('body');
      console.log('Error details:', errorText.substring(0, 500));
    } else {
      console.log('✅ Life applications page loads successfully without errors');
      
      // Check if we can see the expected content
      const hasTitle = await page.locator('text=Life Insurance Applications').count() > 0;
      if (hasTitle) {
        console.log('✅ Page content loads correctly');
      } else {
        console.log('⚠️  Page loads but content may be missing');
      }
    }
    
  } catch (error) {
    console.log('❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
})();