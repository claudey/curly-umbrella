const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ 
    headless: false,
    executablePath: '/opt/homebrew/bin/chromium'
  });
  const page = await browser.newPage();
  
  console.log('🚀 Testing login with brokers+02@boughtspot.com');
  
  // Monitor console logs and errors
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error') {
      console.error('❌ Console Error:', text);
    } else if (type === 'warning') {
      console.warn('⚠️  Console Warning:', text);
    }
  });
  
  page.on('pageerror', err => {
    console.error('💥 Page Error:', err.message);
  });
  
  page.on('response', response => {
    if (response.status() >= 400) {
      console.error(`🌐 HTTP Error: ${response.status()} ${response.url()}`);
    }
  });
  
  try {
    // Navigate to the sign-in page
    console.log('📍 Navigating to sign-in page...');
    await page.goto('http://localhost:3000/users/sign_in', { waitUntil: 'networkidle' });
    
    // Check if we're on the right page
    const title = await page.title();
    console.log(`📄 Page title: ${title}`);
    
    // Take a screenshot of the login page
    await page.screenshot({ path: 'login_page.png' });
    console.log('📸 Login page screenshot saved as login_page.png');
    
    // Fill in the email field
    console.log('📧 Filling email field...');
    await page.fill('input[type="email"]', 'brokers+02@boughtspot.com');
    
    // Fill in the password field
    console.log('🔐 Filling password field...');
    await page.fill('input[type="password"]', 'password123456');
    
    // Take a screenshot with filled form
    await page.screenshot({ path: 'login_form_filled.png' });
    console.log('📸 Filled form screenshot saved as login_form_filled.png');
    
    // Submit the form
    console.log('🚀 Submitting login form...');
    await page.click('input[type="submit"], button[type="submit"]');
    
    // Wait for navigation or response
    await page.waitForLoadState('networkidle');
    
    // Check the current URL and page content
    const currentUrl = page.url();
    console.log(`🌐 Current URL after login: ${currentUrl}`);
    
    // Take a screenshot of the result
    await page.screenshot({ path: 'after_login.png' });
    console.log('📸 After login screenshot saved as after_login.png');
    
    // Check if login was successful
    const pageContent = await page.textContent('body');
    
    if (currentUrl.includes('/users/sign_in')) {
      console.log('❌ Login failed - still on sign-in page');
      
      // Check for error messages
      const errorMessages = await page.locator('.alert, .error, .notice').allTextContents();
      if (errorMessages.length > 0) {
        console.log('📋 Error messages found:');
        errorMessages.forEach(msg => console.log(`   - ${msg}`));
      }
    } else {
      console.log('✅ Login successful - redirected to:', currentUrl);
      
      // Check if we can see user-specific content
      const userInfo = await page.locator('[data-user], .user-name, .current-user').first().textContent().catch(() => null);
      if (userInfo) {
        console.log(`👤 Logged in as: ${userInfo}`);
      }
    }
    
    // Check for any flash messages or notifications
    const flashMessages = await page.locator('.flash, .alert, .notice, .success').allTextContents();
    if (flashMessages.length > 0) {
      console.log('💬 Flash messages:');
      flashMessages.forEach(msg => console.log(`   - ${msg}`));
    }
    
    console.log('✅ Login test completed');
    
    // Keep browser open for 10 seconds to observe
    console.log('⏳ Keeping browser open for 10 seconds...');
    await page.waitForTimeout(10000);
    
  } catch (error) {
    console.error('🔥 Test Error:', error.message);
    
    // Take error screenshot
    await page.screenshot({ path: 'login_error.png' });
    console.log('📸 Error screenshot saved as login_error.png');
  } finally {
    await browser.close();
  }
})();