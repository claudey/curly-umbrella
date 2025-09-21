// tests/support/test-helpers.js
// General testing helper functions

/**
 * Wait for page to load completely
 * @param {import('@playwright/test').Page} page 
 */
async function waitForPageLoad(page) {
  await page.waitForLoadState('networkidle');
  await page.waitForLoadState('domcontentloaded');
}

/**
 * Fill form fields from an object
 * @param {import('@playwright/test').Page} page 
 * @param {Object} formData - Key-value pairs of field names and values
 */
async function fillForm(page, formData) {
  for (const [fieldName, value] of Object.entries(formData)) {
    const selector = `input[name="${fieldName}"], select[name="${fieldName}"], textarea[name="${fieldName}"]`;
    
    const element = await page.locator(selector).first();
    const tagName = await element.evaluate(el => el.tagName.toLowerCase());
    
    if (tagName === 'select') {
      await element.selectOption(value);
    } else {
      await element.fill(value.toString());
    }
  }
}

/**
 * Upload a file to a file input
 * @param {import('@playwright/test').Page} page 
 * @param {string} fileSelector - CSS selector for file input
 * @param {string} filePath - Path to file relative to test-documents/
 */
async function uploadFile(page, fileSelector, filePath) {
  const fullPath = `public/test-documents/${filePath}`;
  await page.setInputFiles(fileSelector, fullPath);
}

/**
 * Check for success message
 * @param {import('@playwright/test').Page} page 
 * @param {string} message - Expected success message
 */
async function expectSuccessMessage(page, message) {
  await page.waitForSelector('.alert-success, .flash-success, [data-testid="success-message"]', { timeout: 5000 });
  const successElement = await page.locator('.alert-success, .flash-success, [data-testid="success-message"]').first();
  const text = await successElement.textContent();
  return text.includes(message);
}

/**
 * Check for error message
 * @param {import('@playwright/test').Page} page 
 * @param {string} message - Expected error message
 */
async function expectErrorMessage(page, message) {
  await page.waitForSelector('.alert-error, .flash-error, [data-testid="error-message"]', { timeout: 5000 });
  const errorElement = await page.locator('.alert-error, .flash-error, [data-testid="error-message"]').first();
  const text = await errorElement.textContent();
  return text.includes(message);
}

/**
 * Wait for and click element safely
 * @param {import('@playwright/test').Page} page 
 * @param {string} selector 
 */
async function safeClick(page, selector) {
  await page.waitForSelector(selector, { timeout: 10000 });
  await page.click(selector);
}

/**
 * Create a new client via UI
 * @param {import('@playwright/test').Page} page 
 * @param {Object} clientData 
 */
async function createClientViaUI(page, clientData = {}) {
  const defaultData = {
    'client[first_name]': 'Test',
    'client[last_name]': 'Client',
    'client[email]': `test.client.${Date.now()}@example.com`,
    'client[phone]': '+233244123456',
    'client[date_of_birth]': '1990-01-01'
  };
  
  const formData = { ...defaultData, ...clientData };
  
  await page.click('text=Clients');
  await page.click('text=Add Client');
  await fillForm(page, formData);
  await page.click('input[type="submit"], button[type="submit"]');
  
  return formData;
}

/**
 * Create a motor insurance application via UI
 * @param {import('@playwright/test').Page} page 
 * @param {Object} applicationData 
 */
async function createMotorApplicationViaUI(page, applicationData = {}) {
  const defaultData = {
    'application[vehicle_make]': 'Toyota',
    'application[vehicle_model]': 'Camry',
    'application[vehicle_year]': '2020',
    'application[registration_number]': `GR-${Date.now()}-AB`,
    'application[chassis_number]': `CHASSIS${Date.now()}`,
    'application[engine_number]': `ENGINE${Date.now()}`,
    'application[driver_license_number]': `DL${Date.now()}`
  };
  
  const formData = { ...defaultData, ...applicationData };
  
  await page.click('text=Applications');
  await page.click('text=Motor Insurance');
  await page.click('text=New Application');
  
  // Select first client if client_id not specified
  if (!applicationData['application[client_id]']) {
    await page.selectOption('select[name="application[client_id]"]', { index: 1 });
  }
  
  await fillForm(page, formData);
  await page.click('button[type="submit"]');
  
  return formData;
}

/**
 * Create a quote via UI
 * @param {import('@playwright/test').Page} page 
 * @param {string} applicationId 
 * @param {Object} quoteData 
 */
async function createQuoteViaUI(page, applicationId, quoteData = {}) {
  const defaultData = {
    'quote[premium_amount]': '1200.00',
    'quote[coverage_amount]': '50000.00',
    'quote[commission_rate]': '15',
    'quote[validity_period]': '30'
  };
  
  const formData = { ...defaultData, ...quoteData };
  
  await page.goto(`/insurance_applications/${applicationId}`);
  await page.click('text=Create Quote');
  await fillForm(page, formData);
  await page.click('button[type="submit"]');
  
  return formData;
}

/**
 * Upload document via UI
 * @param {import('@playwright/test').Page} page 
 * @param {Object} documentData 
 */
async function uploadDocumentViaUI(page, documentData = {}) {
  const defaultData = {
    'document[name]': `Test Document ${Date.now()}`,
    'document[category]': 'policy'
  };
  
  const formData = { ...defaultData, ...documentData };
  
  await page.click('text=Documents');
  await page.click('text=Upload Document');
  await fillForm(page, formData);
  
  if (documentData.filePath) {
    await uploadFile(page, 'input[type="file"]', documentData.filePath);
  }
  
  await page.click('button[type="submit"]');
  
  return formData;
}

/**
 * Navigate to specific section
 * @param {import('@playwright/test').Page} page 
 * @param {string} section 
 */
async function navigateToSection(page, section) {
  const sectionMap = {
    'dashboard': '/',
    'clients': '/clients',
    'applications': '/insurance_applications',
    'quotes': '/quotes',
    'documents': '/documents',
    'notifications': '/notifications',
    'admin': '/admin',
    'profile': '/profile'
  };
  
  const path = sectionMap[section] || section;
  await page.goto(path);
  await waitForPageLoad(page);
}

/**
 * Check if element exists without waiting
 * @param {import('@playwright/test').Page} page 
 * @param {string} selector 
 */
async function elementExists(page, selector) {
  try {
    await page.waitForSelector(selector, { timeout: 1000 });
    return true;
  } catch {
    return false;
  }
}

/**
 * Get table data
 * @param {import('@playwright/test').Page} page 
 * @param {string} tableSelector 
 */
async function getTableData(page, tableSelector = 'table') {
  const table = page.locator(tableSelector).first();
  const headers = await table.locator('thead th').allTextContents();
  const rows = await table.locator('tbody tr').count();
  
  const data = [];
  for (let i = 0; i < rows; i++) {
    const row = {};
    const cells = await table.locator(`tbody tr:nth-child(${i + 1}) td`).allTextContents();
    
    headers.forEach((header, index) => {
      if (cells[index]) {
        row[header.trim()] = cells[index].trim();
      }
    });
    
    data.push(row);
  }
  
  return { headers, data };
}

module.exports = {
  waitForPageLoad,
  fillForm,
  uploadFile,
  expectSuccessMessage,
  expectErrorMessage,
  safeClick,
  createClientViaUI,
  createMotorApplicationViaUI,
  createQuoteViaUI,
  uploadDocumentViaUI,
  navigateToSection,
  elementExists,
  getTableData
};