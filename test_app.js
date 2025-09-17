const { chromium } = require('playwright');

async function testBrokerSyncApp() {
  console.log('🚀 Starting BrokerSync Application Test with Playwright');
  
  const browser = await chromium.launch({ 
    headless: false,  // Show the browser so we can see what's happening
    slowMo: 1000     // Slow down interactions for visibility
  });
  
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 }
  });
  
  const page = await context.newPage();
  
  // Set up console message monitoring
  const consoleMessages = [];
  page.on('console', msg => {
    const messageType = msg.type();
    const messageText = msg.text();
    
    consoleMessages.push({
      type: messageType,
      text: messageText,
      timestamp: new Date().toISOString()
    });
    
    console.log(`📝 Console [${messageType.toUpperCase()}]: ${messageText}`);
  });
  
  // Set up error monitoring
  const pageErrors = [];
  page.on('pageerror', error => {
    pageErrors.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
    
    console.log(`❌ Page Error: ${error.message}`);
    console.log(`   Stack: ${error.stack}`);
  });
  
  // Set up network monitoring for failed requests
  const failedRequests = [];
  page.on('response', response => {
    if (!response.ok()) {
      failedRequests.push({
        url: response.url(),
        status: response.status(),
        statusText: response.statusText(),
        timestamp: new Date().toISOString()
      });
      
      console.log(`🌐 Failed Request: ${response.status()} ${response.statusText()} - ${response.url()}`);
    }
  });
  
  try {
    console.log('🔗 Navigating to http://localhost:3000');
    
    // Navigate to the application
    const response = await page.goto('http://localhost:3000', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    console.log(`✅ Page loaded with status: ${response.status()}`);
    
    // Wait for the page to fully load
    await page.waitForLoadState('networkidle', { timeout: 10000 });
    
    // Get page title
    const title = await page.title();
    console.log(`📄 Page title: "${title}"`);
    
    // Check for any immediate JavaScript errors
    await page.waitForTimeout(2000);
    
    // Try to find common elements that should be present
    console.log('🔍 Checking for common page elements...');
    
    try {
      const bodyContent = await page.textContent('body');
      console.log(`📝 Page has content (${bodyContent.length} characters)`);
      
      if (bodyContent.toLowerCase().includes('error') || 
          bodyContent.toLowerCase().includes('exception') ||
          bodyContent.toLowerCase().includes('500') ||
          bodyContent.toLowerCase().includes('404')) {
        console.log('⚠️  Page appears to contain error content');
        console.log('   First 500 characters:', bodyContent.substring(0, 500));
      }
    } catch (e) {
      console.log(`❌ Could not read body content: ${e.message}`);
    }
    
    // Check for navigation elements
    try {
      const navElements = await page.$$('nav, .navbar, .navigation');
      console.log(`🧭 Found ${navElements.length} navigation elements`);
    } catch (e) {
      console.log(`⚠️  Could not check navigation elements: ${e.message}`);
    }
    
    // Check for forms
    try {
      const forms = await page.$$('form');
      console.log(`📋 Found ${forms.length} forms on the page`);
    } catch (e) {
      console.log(`⚠️  Could not check forms: ${e.message}`);
    }
    
    // Check for buttons
    try {
      const buttons = await page.$$('button, input[type="button"], input[type="submit"]');
      console.log(`🔘 Found ${buttons.length} buttons on the page`);
    } catch (e) {
      console.log(`⚠️  Could not check buttons: ${e.message}`);
    }
    
    // Take a screenshot
    console.log('📸 Taking screenshot...');
    await page.screenshot({ 
      path: '/Users/ayitey/Projects/brokersync/brokersync-screenshot.png',
      fullPage: true 
    });
    console.log('✅ Screenshot saved as brokersync-screenshot.png');
    
    // Wait a bit more to catch any delayed errors
    await page.waitForTimeout(3000);
    
  } catch (error) {
    console.log(`❌ Test failed with error: ${error.message}`);
    console.log(`   Stack: ${error.stack}`);
  }
  
  // Report summary
  console.log('\n📊 Test Summary:');
  console.log(`   Console messages: ${consoleMessages.length}`);
  console.log(`   Page errors: ${pageErrors.length}`);
  console.log(`   Failed requests: ${failedRequests.length}`);
  
  if (consoleMessages.length > 0) {
    console.log('\n📝 Console Messages:');
    consoleMessages.forEach((msg, index) => {
      console.log(`   ${index + 1}. [${msg.type}] ${msg.text}`);
    });
  }
  
  if (pageErrors.length > 0) {
    console.log('\n❌ Page Errors:');
    pageErrors.forEach((error, index) => {
      console.log(`   ${index + 1}. ${error.message}`);
    });
  }
  
  if (failedRequests.length > 0) {
    console.log('\n🌐 Failed Requests:');
    failedRequests.forEach((req, index) => {
      console.log(`   ${index + 1}. ${req.status} ${req.statusText} - ${req.url}`);
    });
  }
  
  // Keep browser open for manual inspection
  console.log('\n⏳ Keeping browser open for 30 seconds for manual inspection...');
  await page.waitForTimeout(30000);
  
  await browser.close();
  console.log('✅ Test completed');
  
  // Return results
  return {
    consoleMessages,
    pageErrors,
    failedRequests,
    success: pageErrors.length === 0 && failedRequests.length === 0
  };
}

// Run the test
testBrokerSyncApp().catch(console.error);