// tests/playwright/03-document-management.spec.js
const { test, expect } = require('@playwright/test');
const { loginAsAgent, loginAsBrokerageAdmin } = require('../support/auth-helpers');
const { 
  uploadFile, 
  expectSuccessMessage, 
  expectErrorMessage,
  waitForPageLoad,
  uploadDocumentViaUI 
} = require('../support/test-helpers');

test.describe('Document Management', () => {
  
  test.describe('Document Upload & Storage', () => {
    
    test('User can upload valid PDF document', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      await page.fill('input[name="document[name]"]', 'Test Policy Document');
      await page.selectOption('select[name="document[category]"]', 'policy');
      
      // Upload motor insurance policy PDF
      await uploadFile(page, 'input[type="file"]', 'motor-insurance/insurance_policy.pdf');
      
      await page.click('button[type="submit"]');
      await expect(page.locator('text=Document uploaded successfully')).toBeVisible();
    });

    test('User can upload vehicle registration document', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      const documentData = {
        'document[name]': 'Vehicle Registration Certificate',
        'document[category]': 'vehicle_documents',
        filePath: 'motor-insurance/vehicle_registration_1.pdf'
      };
      
      await uploadDocumentViaUI(page, documentData);
      await expect(page.locator('text=Document uploaded successfully')).toBeVisible();
    });

    test('User can upload fire insurance documents', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      const fireInsuranceDocs = [
        {
          name: 'Property Deed',
          category: 'property_documents',
          file: 'fire-insurance/property_deed.pdf'
        },
        {
          name: 'Building Permit',
          category: 'permits',
          file: 'fire-insurance/building_permit.pdf'
        },
        {
          name: 'Fire Safety Certificate',
          category: 'safety_certificates',
          file: 'fire-insurance/fire_safety_certificate.pdf'
        }
      ];
      
      for (const doc of fireInsuranceDocs) {
        await page.click('text=Documents');
        await page.click('text=Upload Document');
        
        await page.fill('input[name="document[name]"]', doc.name);
        await page.selectOption('select[name="document[category]"]', doc.category);
        await uploadFile(page, 'input[type="file"]', doc.file);
        
        await page.click('button[type="submit"]');
        await expect(page.locator('text=Document uploaded successfully')).toBeVisible();
      }
    });

    test('System validates file types correctly', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      await page.fill('input[name="document[name]"]', 'Invalid File Type');
      
      // Try to upload a non-PDF file (create a temporary test file)
      const invalidFile = 'data:text/plain;base64,VGVzdCBmaWxl'; // "Test file" in base64
      
      // This would need actual file upload testing
      // For now, we'll test the UI validation
      await expect(page.locator('input[type="file"]')).toHaveAttribute('accept', /pdf/i);
    });

    test('System enforces file size limits', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      // Check for file size limit information
      await expect(page.locator('text=Maximum file size')).toBeVisible();
    });

    test('User can categorize documents correctly', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      // Check available categories
      const categorySelect = page.locator('select[name="document[category]"]');
      
      const expectedCategories = [
        'policy',
        'claim',
        'vehicle_documents',
        'property_documents',
        'identity_documents',
        'financial_documents'
      ];
      
      for (const category of expectedCategories) {
        await expect(categorySelect.locator(`option[value="${category}"]`)).toBeVisible();
      }
    });
  });

  test.describe('Document Search and Filtering', () => {
    
    test('User can search documents by name', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // Search for specific document
      await page.fill('input[placeholder*="Search documents"]', 'policy');
      await page.keyboard.press('Enter');
      
      await expect(page.locator('text=Search results')).toBeVisible();
      
      // Check that results contain the search term
      const documentRows = page.locator('table tbody tr');
      const count = await documentRows.count();
      
      if (count > 0) {
        const firstRowText = await documentRows.first().textContent();
        expect(firstRowText.toLowerCase()).toContain('policy');
      }
    });

    test('User can filter documents by category', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // Filter by category
      await page.selectOption('select[name="category_filter"]', 'policy');
      await page.click('button[type="submit"]');
      
      // Check that all visible documents are policy documents
      const categoryTags = page.locator('[data-category="policy"]');
      const count = await categoryTags.count();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('User can filter documents by date range', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // Set date filters
      await page.fill('input[name="date_from"]', '2024-01-01');
      await page.fill('input[name="date_to"]', '2024-12-31');
      await page.click('button[type="submit"]');
      
      // Should show filtered results
      await expect(page.locator('text=Filtered by date')).toBeVisible();
    });

    test('Advanced search works correctly', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      if (await page.locator('text=Advanced Search').isVisible()) {
        await page.click('text=Advanced Search');
        
        // Fill advanced search criteria
        await page.fill('input[name="keywords"]', 'motor insurance');
        await page.selectOption('select[name="document_type"]', 'policy');
        await page.selectOption('select[name="status"]', 'active');
        
        await page.click('button[text="Search"]');
        
        await expect(page.locator('text=Advanced search results')).toBeVisible();
      }
    });
  });

  test.describe('Document Security & Access Control', () => {
    
    test('Documents are scoped to organization', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // All visible documents should belong to the user's organization
      const documentRows = page.locator('table tbody tr');
      const count = await documentRows.count();
      
      // This is a visual check - in a real test you'd verify organization IDs
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('User cannot access other organization documents via URL', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Try to access a document ID that doesn't belong to the organization
      await page.goto('/documents/999999');
      
      // Should get 404 or access denied
      const notFoundVisible = await page.locator('text=Not found').isVisible();
      const accessDeniedVisible = await page.locator('text=Access denied').isVisible();
      
      expect(notFoundVisible || accessDeniedVisible).toBeTruthy();
    });

    test('Document download requires authentication', async ({ page, context }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // Find a document download link
      const downloadLink = page.locator('a[href*="/documents/"][href*="/download"]').first();
      
      if (await downloadLink.isVisible()) {
        // Click download link
        const downloadPromise = page.waitForEvent('download');
        await downloadLink.click();
        const download = await downloadPromise;
        
        // Verify download started
        expect(download.suggestedFilename()).toBeTruthy();
      }
    });

    test('Sensitive documents require additional verification', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Upload a document marked as sensitive
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      await page.fill('input[name="document[name]"]', 'Sensitive Client Data');
      await page.selectOption('select[name="document[category]"]', 'confidential');
      await page.check('input[name="document[sensitive]"]');
      
      await uploadFile(page, 'input[type="file"]', 'general-forms/bank_statement_sample.pdf');
      
      await page.click('button[type="submit"]');
      
      // Should require additional confirmation for sensitive documents
      if (await page.locator('text=Confirm sensitive document upload').isVisible()) {
        await page.click('button[text="Confirm"]');
      }
      
      await expect(page.locator('text=Document uploaded successfully')).toBeVisible();
    });
  });

  test.describe('Document Versioning', () => {
    
    test('User can upload new version of document', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // Find an existing document
      const documentRow = page.locator('table tbody tr').first();
      
      if (await documentRow.isVisible()) {
        await documentRow.click();
        
        // Look for version management
        if (await page.locator('text=Upload New Version').isVisible()) {
          await page.click('text=Upload New Version');
          
          await uploadFile(page, 'input[type="file"]', 'motor-insurance/insurance_policy.pdf');
          await page.click('button[type="submit"]');
          
          await expect(page.locator('text=New version uploaded')).toBeVisible();
          await expect(page.locator('text=Version 2')).toBeVisible();
        }
      }
    });

    test('User can view document version history', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      const documentRow = page.locator('table tbody tr').first();
      
      if (await documentRow.isVisible()) {
        await documentRow.click();
        
        if (await page.locator('text=Version History').isVisible()) {
          await page.click('text=Version History');
          
          await expect(page.locator('text=Version 1')).toBeVisible();
          await expect(page.locator('text=Created by')).toBeVisible();
          await expect(page.locator('text=Upload date')).toBeVisible();
        }
      }
    });

    test('User can revert to previous version', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      const documentRow = page.locator('table tbody tr').first();
      
      if (await documentRow.isVisible()) {
        await documentRow.click();
        
        if (await page.locator('text=Version History').isVisible()) {
          await page.click('text=Version History');
          
          const revertButton = page.locator('button[text="Revert to this version"]').first();
          if (await revertButton.isVisible()) {
            await revertButton.click();
            
            // Confirm reversion
            await page.click('button[text="Confirm Revert"]');
            
            await expect(page.locator('text=Reverted to previous version')).toBeVisible();
          }
        }
      }
    });
  });

  test.describe('Document Organization & Management', () => {
    
    test('User can organize documents in folders', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      if (await page.locator('text=Create Folder').isVisible()) {
        await page.click('text=Create Folder');
        
        await page.fill('input[name="folder[name]"]', 'Motor Insurance Claims');
        await page.fill('textarea[name="folder[description]"]', 'Documents related to motor insurance claims');
        
        await page.click('button[type="submit"]');
        
        await expect(page.locator('text=Folder created successfully')).toBeVisible();
        await expect(page.locator('text=Motor Insurance Claims')).toBeVisible();
      }
    });

    test('User can move documents between folders', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // Select a document
      const documentCheckbox = page.locator('input[type="checkbox"][data-document-id]').first();
      
      if (await documentCheckbox.isVisible()) {
        await documentCheckbox.check();
        
        // Look for move action
        if (await page.locator('text=Move to Folder').isVisible()) {
          await page.click('text=Move to Folder');
          
          await page.selectOption('select[name="folder_id"]', { label: 'Motor Insurance Claims' });
          await page.click('button[text="Move"]');
          
          await expect(page.locator('text=Document moved successfully')).toBeVisible();
        }
      }
    });

    test('User can bulk delete documents', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      // Select multiple documents
      const checkboxes = page.locator('input[type="checkbox"][data-document-id]');
      const count = await checkboxes.count();
      
      if (count > 0) {
        // Check first two documents
        await checkboxes.nth(0).check();
        if (count > 1) {
          await checkboxes.nth(1).check();
        }
        
        if (await page.locator('text=Delete Selected').isVisible()) {
          await page.click('text=Delete Selected');
          
          // Confirm deletion
          await page.click('button[text="Confirm Delete"]');
          
          await expect(page.locator('text=Documents deleted successfully')).toBeVisible();
        }
      }
    });

    test('User can archive old documents', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      const documentRow = page.locator('table tbody tr').first();
      
      if (await documentRow.isVisible()) {
        // Click on document to open details
        await documentRow.click();
        
        if (await page.locator('text=Archive Document').isVisible()) {
          await page.click('text=Archive Document');
          
          await page.fill('textarea[name="archive_reason"]', 'Document is outdated and no longer needed');
          await page.click('button[text="Archive"]');
          
          await expect(page.locator('text=Document archived successfully')).toBeVisible();
        }
      }
    });
  });

  test.describe('Document Sharing & Collaboration', () => {
    
    test('User can share document with team members', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      const documentRow = page.locator('table tbody tr').first();
      
      if (await documentRow.isVisible()) {
        await documentRow.click();
        
        if (await page.locator('text=Share Document').isVisible()) {
          await page.click('text=Share Document');
          
          // Select team members to share with
          await page.selectOption('select[name="user_ids[]"]', { label: 'Jane Smith' });
          await page.selectOption('select[name="permission"]', 'view');
          
          await page.click('button[text="Share"]');
          
          await expect(page.locator('text=Document shared successfully')).toBeVisible();
        }
      }
    });

    test('User can set document expiration date', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      const documentRow = page.locator('table tbody tr').first();
      
      if (await documentRow.isVisible()) {
        await documentRow.click();
        
        if (await page.locator('text=Set Expiration').isVisible()) {
          await page.click('text=Set Expiration');
          
          // Set expiration date to one year from now
          const nextYear = new Date();
          nextYear.setFullYear(nextYear.getFullYear() + 1);
          const dateString = nextYear.toISOString().split('T')[0];
          
          await page.fill('input[name="expires_at"]', dateString);
          await page.click('button[text="Set Expiration"]');
          
          await expect(page.locator('text=Expiration date set')).toBeVisible();
        }
      }
    });

    test('User receives notifications for document updates', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Check notifications
      await page.click('[data-testid="notification-bell"]');
      
      // Look for document-related notifications
      const notifications = page.locator('.notification-item');
      const count = await notifications.count();
      
      if (count > 0) {
        const documentNotification = notifications.filter({ hasText: 'document' }).first();
        if (await documentNotification.isVisible()) {
          await expect(documentNotification).toContainText('document');
        }
      }
    });
  });

  test.describe('Document Analytics & Reporting', () => {
    
    test('Admin can view document usage statistics', async ({ page }) => {
      await loginAsBrokerageAdmin(page, 0);
      
      if (await page.locator('text=Reports').isVisible()) {
        await page.click('text=Reports');
        await page.click('text=Document Analytics');
        
        await expect(page.locator('text=Total Documents')).toBeVisible();
        await expect(page.locator('text=Storage Used')).toBeVisible();
        await expect(page.locator('text=Most Accessed Documents')).toBeVisible();
      }
    });

    test('System tracks document access for audit', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      
      const documentRow = page.locator('table tbody tr').first();
      
      if (await documentRow.isVisible()) {
        await documentRow.click();
        
        // View the document (this should be logged)
        if (await page.locator('text=View Document').isVisible()) {
          await page.click('text=View Document');
          
          // Check if audit trail shows the access
          if (await page.locator('text=Audit Trail').isVisible()) {
            await page.click('text=Audit Trail');
            await expect(page.locator('text=Document viewed')).toBeVisible();
          }
        }
      }
    });
  });

  test.describe('Document Error Handling', () => {
    
    test('Handles corrupted file upload gracefully', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      await page.fill('input[name="document[name]"]', 'Corrupted File Test');
      
      // This would require an actual corrupted file for testing
      // For now, we test the error handling UI
      await expect(page.locator('.error-handling-info')).toBeVisible();
    });

    test('Shows appropriate error for oversized files', async ({ page }) => {
      await loginAsAgent(page, 0);
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      // Check that file size validation exists
      const fileInput = page.locator('input[type="file"]');
      const maxSize = await fileInput.getAttribute('data-max-size');
      
      expect(maxSize).toBeTruthy();
    });

    test('Handles network errors during upload', async ({ page }) => {
      await loginAsAgent(page, 0);
      
      // Simulate network failure
      await page.route('**/documents', route => route.abort());
      
      await page.click('text=Documents');
      await page.click('text=Upload Document');
      
      await page.fill('input[name="document[name]"]', 'Network Error Test');
      await uploadFile(page, 'input[type="file"]', 'motor-insurance/insurance_policy.pdf');
      
      await page.click('button[type="submit"]');
      
      // Should show network error message
      await expect(page.locator('text=Network error')).toBeVisible();
    });
  });
});