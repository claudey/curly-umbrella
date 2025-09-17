const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ 
    headless: false,
    executablePath: '/opt/homebrew/bin/chromium'
  });
  const page = await browser.newPage();
  
  console.log('🚀 Starting browser monitoring for localhost:3000');
  
  // Monitor console logs
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error') {
      console.error('❌ Console Error:', text);
    } else if (type === 'warning') {
      console.warn('⚠️  Console Warning:', text);
    } else {
      console.log(`📝 Console ${type}:`, text);
    }
  });
  
  // Monitor page errors
  page.on('pageerror', err => {
    console.error('💥 Page Error:', err.message);
    console.error('Stack:', err.stack);
  });
  
  // Monitor network failures
  page.on('response', response => {
    if (response.status() >= 400) {
      console.error(`🌐 HTTP Error: ${response.status()} ${response.url()}`);
    }
  });
  
  // Monitor request failures
  page.on('requestfailed', request => {
    console.error(`🚫 Request Failed: ${request.url()} - ${request.failure().errorText}`);
  });
  
  try {
    // Test authentication pages
    const authPages = [
      { url: 'http://localhost:3000/users/sign_in', name: 'Sign In' },
      { url: 'http://localhost:3000/users/sign_up', name: 'Sign Up' },
      { url: 'http://localhost:3000/users/password/new', name: 'Password Reset' }
    ];

    for (const authPage of authPages) {
      console.log(`📍 Testing ${authPage.name} page: ${authPage.url}...`);
      
      try {
        await page.goto(authPage.url, { waitUntil: 'networkidle' });
        
        // Check if Tailwind classes are present
        const hasModernStyling = await page.evaluate(() => {
          const form = document.querySelector('form');
          const inputs = document.querySelectorAll('input[type="email"], input[type="password"]');
          const buttons = document.querySelectorAll('button, input[type="submit"]');
          
          // Check for Tailwind classes that indicate modern styling
          let hasTailwindClasses = false;
          
          if (form) {
            const classes = form.className;
            hasTailwindClasses = classes.includes('bg-white') || classes.includes('shadow') || classes.includes('rounded');
          }
          
          // Check input styling
          for (const input of inputs) {
            const classes = input.className;
            if (classes.includes('border') && classes.includes('rounded')) {
              hasTailwindClasses = true;
              break;
            }
          }
          
          return {
            hasForm: !!form,
            inputCount: inputs.length,
            buttonCount: buttons.length,
            hasTailwindClasses,
            bodyClasses: document.body.className,
            formClasses: form ? form.className : 'No form found'
          };
        });
        
        console.log(`✅ ${authPage.name} page loaded`);
        console.log(`📋 Form present: ${hasModernStyling.hasForm}`);
        console.log(`📝 Inputs found: ${hasModernStyling.inputCount}`);
        console.log(`🎨 Tailwind styling: ${hasModernStyling.hasTailwindClasses}`);
        console.log(`🏷️  Body classes: ${hasModernStyling.bodyClasses}`);
        
        if (!hasModernStyling.hasTailwindClasses) {
          console.log(`⚠️  ${authPage.name} may not have proper styling`);
          console.log(`📄 Form classes: ${hasModernStyling.formClasses}`);
        }
        
      } catch (error) {
        console.log(`❌ Error loading ${authPage.name}: ${error.message}`);
      }
      
      console.log('---');
    }
    
    console.log('📊 Authentication pages test complete');
    
  } catch (error) {
    console.error('🔥 Critical Error:', error.message);
  } finally {
    await browser.close();
  }
})();