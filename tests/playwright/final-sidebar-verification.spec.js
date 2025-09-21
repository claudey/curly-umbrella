const { test, expect } = require('@playwright/test');

test('Login and verify sidebar positioning', async ({ page }) => {
  // Navigate to the login page
  await page.goto('http://localhost:3000');
  
  // Fill in login credentials (using test user credentials)
  await page.fill('input[placeholder="Email address"]', 'admin@test.com');
  await page.fill('input[placeholder="Password"]', 'password');
  
  // Click sign in
  await page.click('input[type="submit"], button[type="submit"]');
  
  // Wait for redirect to dashboard
  await page.waitForLoadState('networkidle');
  
  // Take a screenshot of the dashboard
  await page.screenshot({ 
    path: 'test-results/final-dashboard-with-sidebar.png', 
    fullPage: true 
  });
  
  // Check if the drawer structure exists
  const drawer = await page.locator('.drawer');
  const drawerExists = await drawer.count();
  console.log('Drawer elements found:', drawerExists);
  
  // Check if the drawer-side (sidebar) exists
  const drawerSide = await page.locator('.drawer-side');
  const drawerSideExists = await drawerSide.count();
  console.log('Drawer-side elements found:', drawerSideExists);
  
  // Check for navigation menu
  const menuItems = await page.locator('.menu');
  const menuExists = await menuItems.count();
  console.log('Menu elements found:', menuExists);
  
  // Check specific navigation links
  const dashboardLink = await page.locator('text=Dashboard').count();
  const clientsLink = await page.locator('text=Clients').count();
  const applicationsLink = await page.locator('text=Applications').count();
  const quotesLink = await page.locator('text=Quotes').count();
  const documentsLink = await page.locator('text=Documents').count();
  
  console.log('Navigation links found:');
  console.log('- Dashboard:', dashboardLink);
  console.log('- Clients:', clientsLink);
  console.log('- Applications:', applicationsLink);
  console.log('- Quotes:', quotesLink);
  console.log('- Documents:', documentsLink);
  
  // Check page title
  const pageTitle = await page.title();
  console.log('Page title:', pageTitle);
});