// tests/support/auth-helpers.js
// Authentication helper functions for Playwright tests

const TEST_CREDENTIALS = {
  universalPassword: 'password123456',
  universalPhone: '+233242422604',
  
  brokerageAdmins: [
    'brokersync+admin1@boughtspot.com',
    'brokersync+admin2@boughtspot.com', 
    'brokersync+admin3@boughtspot.com'
  ],
  
  agents: [
    'brokers+01@boughtspot.com',
    'brokers+02@boughtspot.com',
    'brokers+03@boughtspot.com',
    'brokers+05@boughtspot.com',
    'brokers+06@boughtspot.com'
  ],
  
  insuranceCompanies: [
    'insurance+company1@boughtspot.com',
    'insurance+company2@boughtspot.com'
  ]
};

/**
 * Login as a specific user type
 * @param {import('@playwright/test').Page} page 
 * @param {string} email 
 * @param {string} password 
 */
async function loginAsUser(page, email, password = TEST_CREDENTIALS.universalPassword) {
  await page.goto('/users/sign_in');
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('input[type="submit"]');
  
  // Wait for redirect to dashboard
  await page.waitForURL(/.*\/$/, { timeout: 10000 });
  await page.waitForSelector('text=Dashboard', { timeout: 10000 });
}

/**
 * Login as a broker/agent
 * @param {import('@playwright/test').Page} page 
 * @param {number} agentIndex 
 */
async function loginAsAgent(page, agentIndex = 0) {
  const email = TEST_CREDENTIALS.agents[agentIndex];
  await loginAsUser(page, email);
}

/**
 * Login as a brokerage admin
 * @param {import('@playwright/test').Page} page 
 * @param {number} adminIndex 
 */
async function loginAsBrokerageAdmin(page, adminIndex = 0) {
  const email = TEST_CREDENTIALS.brokerageAdmins[adminIndex];
  await loginAsUser(page, email);
}

/**
 * Login as an insurance company user
 * @param {import('@playwright/test').Page} page 
 * @param {number} companyIndex 
 */
async function loginAsInsuranceCompany(page, companyIndex = 0) {
  const email = TEST_CREDENTIALS.insuranceCompanies[companyIndex];
  await loginAsUser(page, email);
}

/**
 * Logout current user
 * @param {import('@playwright/test').Page} page 
 */
async function logout(page) {
  await page.click('text=Logout');
  await page.waitForURL(/.*sign_in/, { timeout: 5000 });
}

/**
 * Setup MFA for testing
 * @param {import('@playwright/test').Page} page 
 */
async function setupMFA(page) {
  await page.goto('/mfa');
  await page.click('text=Setup MFA');
  
  // Wait for QR code and backup codes to appear
  await page.waitForSelector('text=Scan QR Code');
  await page.waitForSelector('text=Backup Codes');
  
  // Get backup codes for testing
  const backupCodes = await page.textContent('[data-testid="backup-codes"]');
  return backupCodes;
}

/**
 * Handle MFA verification during login
 * @param {import('@playwright/test').Page} page 
 * @param {string} code - TOTP code or backup code
 */
async function verifyMFA(page, code) {
  await page.waitForSelector('text=Enter verification code');
  await page.fill('input[name="mfa_code"]', code);
  await page.click('input[type="submit"]');
}

/**
 * Check if user has required permissions
 * @param {import('@playwright/test').Page} page 
 * @param {string} feature - Feature to check access for
 */
async function hasAccess(page, feature) {
  const selectors = {
    'admin_panel': 'text=Admin Panel',
    'organizations': 'text=Organizations',
    'users': 'text=Users',
    'clients': 'text=Clients',
    'applications': 'text=Applications',
    'quotes': 'text=Quotes',
    'documents': 'text=Documents',
    'reports': 'text=Reports'
  };
  
  try {
    await page.waitForSelector(selectors[feature], { timeout: 2000 });
    return true;
  } catch {
    return false;
  }
}

module.exports = {
  TEST_CREDENTIALS,
  loginAsUser,
  loginAsAgent,
  loginAsBrokerageAdmin,
  loginAsInsuranceCompany,
  logout,
  setupMFA,
  verifyMFA,
  hasAccess
};