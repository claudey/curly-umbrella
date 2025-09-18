const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ 
    headless: false,
    executablePath: '/opt/homebrew/bin/chromium',
    slowMo: 1000 // Slow down actions to see what's happening
  });
  const page = await browser.newPage();
  
  console.log('🚀 Testing complete login flow with brokers+02@boughtspot.com');
  
  // Monitor network responses
  page.on('response', response => {
    const status = response.status();
    const url = response.url();
    console.log(`📡 ${status} ${url}`);
    
    if (status >= 400) {
      console.error(`❌ HTTP Error: ${status} ${url}`);
    }
  });
  
  // Monitor console logs
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error') {
      console.error('❌ Console Error:', text);
    }
  });
  
  try {
    // Step 1: Navigate to root and verify redirect to login
    console.log('\n📍 Step 1: Navigate to application root');
    await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
    
    const currentUrl1 = page.url();
    console.log(`🔗 Current URL: ${currentUrl1}`);
    
    await page.screenshot({ path: '01_redirect_to_login.png', fullPage: true });
    console.log('📸 Screenshot saved: 01_redirect_to_login.png');
    
    // Verify we're on login page
    if (!currentUrl1.includes('/users/sign_in')) {
      throw new Error('Expected to be redirected to login page');
    }
    
    // Step 2: Verify login form elements are present
    console.log('\n📍 Step 2: Verify login form elements');
    const emailField = await page.locator('input[type="email"]');
    const passwordField = await page.locator('input[type="password"]');
    const submitButton = await page.locator('input[type="submit"], button[type="submit"]');
    
    if (!(await emailField.isVisible())) {
      throw new Error('Email field not found');
    }
    if (!(await passwordField.isVisible())) {
      throw new Error('Password field not found');
    }
    if (!(await submitButton.isVisible())) {
      throw new Error('Submit button not found');
    }
    
    console.log('✅ All form elements are present');
    
    // Step 3: Fill in login credentials
    console.log('\n📍 Step 3: Fill in credentials');
    await emailField.fill('brokers+02@boughtspot.com');
    await passwordField.fill('password123456');
    
    await page.screenshot({ path: '02_form_filled.png', fullPage: true });
    console.log('📸 Screenshot saved: 02_form_filled.png');
    
    // Step 4: Submit the form and wait for navigation
    console.log('\n📍 Step 4: Submit login form');
    
    // Wait for navigation after clicking submit
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
      submitButton.click()
    ]);
    
    const currentUrl2 = page.url();
    console.log(`🔗 URL after login attempt: ${currentUrl2}`);
    
    await page.screenshot({ path: '03_after_login_submit.png', fullPage: true });
    console.log('📸 Screenshot saved: 03_after_login_submit.png');
    
    // Step 5: Check if login was successful
    console.log('\n📍 Step 5: Verify login success');
    
    if (currentUrl2.includes('/users/sign_in')) {
      console.log('❌ Still on login page - checking for error messages');
      
      // Look for error messages
      const errorSelectors = ['.alert', '.error', '.notice', '.flash', '[data-flash]'];
      for (const selector of errorSelectors) {
        const elements = await page.locator(selector).all();
        for (const element of elements) {
          const text = await element.textContent();
          if (text && text.trim()) {
            console.log(`📋 Found message: ${text.trim()}`);
          }
        }
      }
      
      throw new Error('Login failed - still on sign-in page');
    } else {
      console.log('✅ Successfully redirected from login page!');
      console.log(`🎉 Current URL: ${currentUrl2}`);
      
      // Check for user-specific content or dashboard elements
      const bodyText = await page.textContent('body');
      if (bodyText.toLowerCase().includes('dashboard') || 
          bodyText.toLowerCase().includes('welcome') ||
          currentUrl2.includes('/dashboard') ||
          currentUrl2.includes('/home')) {
        console.log('✅ Dashboard/welcome content detected');
      }
      
      await page.screenshot({ path: '04_successful_login_dashboard.png', fullPage: true });
      console.log('📸 Screenshot saved: 04_successful_login_dashboard.png');
    }
    
    // Step 6: Final verification
    console.log('\n📍 Step 6: Final verification');
    await page.waitForTimeout(2000); // Wait a bit more to ensure page is fully loaded
    
    const finalUrl = page.url();
    const pageTitle = await page.title();
    console.log(`🔗 Final URL: ${finalUrl}`);
    console.log(`📄 Page title: ${pageTitle}`);
    
    await page.screenshot({ path: '05_final_state.png', fullPage: true });
    console.log('📸 Screenshot saved: 05_final_state.png');
    
    if (finalUrl.includes('/users/sign_in')) {
      console.log('❌ LOGIN TEST FAILED - User is still on login page');
      return;
    }
    
    console.log('🎉 LOGIN TEST PASSED - User successfully logged in and redirected to dashboard!');
    
    // Keep browser open for observation
    console.log('\n⏳ Keeping browser open for 10 seconds for observation...');
    await page.waitForTimeout(10000);
    
  } catch (error) {
    console.error('💥 Test Error:', error.message);
    
    await page.screenshot({ path: '99_error_state.png', fullPage: true });
    console.log('📸 Error screenshot saved: 99_error_state.png');
    
    console.log('\n🔍 Debug info:');
    console.log('Current URL:', page.url());
    console.log('Page title:', await page.title());
  } finally {
    await browser.close();
  }
})();