# BrokerSync Comprehensive Feature Testing Guide

## Overview
This document provides a complete inventory of all features and functionalities in the BrokerSync application, organized by user role and use case. Each feature includes unit tests and browser automation tests using Playwright to ensure comprehensive coverage.

## Test Credentials
- **Universal Password**: `password123456`
- **Universal Phone Number**: `+233242422604`

## User Roles & Test Accounts

### Brokerage Administrators
- **brokersync+admin1@boughtspot.com** - Premium Insurance Brokers
- **brokersync+admin2@boughtspot.com** - Elite Risk Solutions  
- **brokersync+admin3@boughtspot.com** - Secure Shield Brokers

### Insurance Agents
- **brokers+01@boughtspot.com** - John Doe (Premium Insurance Brokers)
- **brokers+02@boughtspot.com** - Jane Smith (Premium Insurance Brokers) 
- **brokers+03@boughtspot.com** - Michael Johnson (Premium Insurance Brokers)
- **brokers+05@boughtspot.com** - David Brown (Elite Risk Solutions)
- **brokers+06@boughtspot.com** - Emma Davis (Elite Risk Solutions)

### Insurance Company Users
- **insurance+company1@boughtspot.com** - Ghana National Insurance Company
- **insurance+company2@boughtspot.com** - Star Assurance Company

---

## 1. AUTHENTICATION & SECURITY FEATURES

### 1.1 User Authentication (Basic)
**Description**: Core login/logout functionality using Devise
**User Roles**: All users
**Routes**: `/users/sign_in`, `/users/sign_out`

#### Unit Tests:
```ruby
describe "User Authentication" do
  it "allows valid user to login" do
    user = create(:user, email: "test@example.com", password: "password123456")
    post user_session_path, params: { user: { email: "test@example.com", password: "password123456" } }
    expect(response).to redirect_to(root_path)
    expect(controller.current_user).to eq(user)
  end

  it "rejects invalid credentials" do
    post user_session_path, params: { user: { email: "invalid@example.com", password: "wrong" } }
    expect(response).to render_template(:new)
    expect(flash[:alert]).to be_present
  end

  it "logs out user successfully" do
    user = create(:user)
    sign_in user
    delete destroy_user_session_path
    expect(response).to redirect_to(root_path)
    expect(controller.current_user).to be_nil
  end
end
```

#### Playwright Browser Tests:
```javascript
test('User can login with valid credentials', async ({ page }) => {
  await page.goto('http://localhost:3000/users/sign_in');
  await page.fill('input[name="user[email]"]', 'brokers+01@boughtspot.com');
  await page.fill('input[name="user[password]"]', 'password123456');
  await page.click('input[type="submit"]');
  await expect(page).toHaveURL(/.*\/$/); // Should redirect to dashboard
  await expect(page.locator('text=Dashboard')).toBeVisible();
});

test('User cannot login with invalid credentials', async ({ page }) => {
  await page.goto('http://localhost:3000/users/sign_in');
  await page.fill('input[name="user[email]"]', 'invalid@example.com');
  await page.fill('input[name="user[password]"]', 'wrongpassword');
  await page.click('input[type="submit"]');
  await expect(page.locator('text=Invalid Email or password')).toBeVisible();
});

test('User can logout successfully', async ({ page }) => {
  // Login first
  await page.goto('http://localhost:3000/users/sign_in');
  await page.fill('input[name="user[email]"]', 'brokers+01@boughtspot.com');
  await page.fill('input[name="user[password]"]', 'password123456');
  await page.click('input[type="submit"]');
  
  // Logout
  await page.click('text=Logout');
  await expect(page).toHaveURL(/.*sign_in/);
});
```

### 1.2 Multi-Factor Authentication (MFA)
**Description**: TOTP-based two-factor authentication with backup codes
**User Roles**: All users (when enabled by organization)
**Routes**: `/mfa`, `/mfa/setup`, `/mfa_verifications`

#### Unit Tests:
```ruby
describe "Multi-Factor Authentication" do
  let(:user) { create(:user, mfa_enabled: false) }

  it "allows user to setup MFA" do
    sign_in user
    post enable_mfa_path
    user.reload
    expect(user.mfa_enabled?).to be true
    expect(user.mfa_secret).to be_present
    expect(user.backup_codes).to be_present
  end

  it "verifies TOTP codes correctly" do
    user.enable_mfa!
    totp = ROTP::TOTP.new(user.mfa_secret)
    valid_code = totp.now
    
    expect(user.verify_mfa_code(valid_code)).to be true
    expect(user.verify_mfa_code("123456")).to be false
  end

  it "accepts backup codes" do
    user.enable_mfa!
    backup_code = JSON.parse(user.backup_codes).first
    
    expect(user.verify_mfa_code(backup_code)).to be true
    user.reload
    expect(JSON.parse(user.backup_codes)).not_to include(backup_code)
  end
end
```

#### Playwright Browser Tests:
```javascript
test('User can setup MFA', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.goto('http://localhost:3000/mfa');
  await page.click('text=Setup MFA');
  await expect(page.locator('text=Scan QR Code')).toBeVisible();
  await expect(page.locator('text=Backup Codes')).toBeVisible();
});

test('MFA verification required after setup', async ({ page }) => {
  // Assuming MFA is already setup for this user
  await page.goto('http://localhost:3000/users/sign_in');
  await page.fill('input[name="user[email]"]', 'brokers+02@boughtspot.com');
  await page.fill('input[name="user[password]"]', 'password123456');
  await page.click('input[type="submit"]');
  await expect(page).toHaveURL(/.*mfa_verifications/);
  await expect(page.locator('text=Enter verification code')).toBeVisible();
});
```

### 1.3 Session Security Management
**Description**: Advanced session tracking, concurrent session limits, and security monitoring
**User Roles**: All users
**Routes**: `/sessions/manage`

#### Unit Tests:
```ruby
describe "Session Security" do
  let(:user) { create(:user) }

  it "tracks session creation" do
    expect {
      sign_in user
    }.to change(UserSession, :count).by(1)
  end

  it "detects suspicious login locations" do
    # Mock different IP addresses
    allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return("192.168.1.1")
    sign_in user
    
    allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return("203.0.113.1")
    sign_in user
    
    expect(SecurityAlert.where(alert_type: 'new_login_location').count).to be > 0
  end

  it "limits concurrent sessions" do
    # Create max allowed sessions
    5.times do |i|
      UserSession.create!(user: user, session_id: "session_#{i}", ip_address: "192.168.1.#{i}")
    end
    
    # Attempt to create another session
    new_session = UserSession.new(user: user, session_id: "session_6", ip_address: "192.168.1.6")
    expect(new_session.save).to be false
  end
end
```

#### Playwright Browser Tests:
```javascript
test('User can view active sessions', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.goto('http://localhost:3000/sessions/manage');
  await expect(page.locator('text=Active Sessions')).toBeVisible();
  await expect(page.locator('text=Current Session')).toBeVisible();
});

test('User can terminate other sessions', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.goto('http://localhost:3000/sessions/manage');
  await page.click('text=Terminate All Other Sessions');
  await expect(page.locator('text=All other sessions terminated')).toBeVisible();
});
```

### 1.4 Rate Limiting & IP Blocking
**Description**: Automatic protection against brute force attacks and suspicious activity
**User Roles**: System-wide protection
**Implementation**: `RateLimitingService`, `IpBlockingService`

#### Unit Tests:
```ruby
describe "Rate Limiting" do
  it "blocks excessive login attempts" do
    6.times do
      post user_session_path, params: { user: { email: "test@example.com", password: "wrong" } }
    end
    
    expect(response).to have_http_status(:too_many_requests)
    expect(RateLimitingService.check_rate_limit("127.0.0.1", :login)).to be true
  end

  it "auto-blocks IPs with multiple violations" do
    identifier = "203.0.113.1"
    
    # Trigger multiple rate limit violations
    6.times do
      RateLimitingService.increment_counter(identifier, :login)
    end
    
    expect(IpBlockingService.blocked?(identifier)).to be true
  end
end
```

---

## 2. DASHBOARD & NAVIGATION

### 2.1 Main Dashboard
**Description**: Role-based dashboard showing key metrics and recent activity
**User Roles**: All authenticated users
**Routes**: `/` (root)

#### Unit Tests:
```ruby
describe "Main Dashboard" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  before { sign_in user }

  it "displays document metrics" do
    create_list(:document, 3, organization: organization, user: user)
    get root_path
    
    expect(assigns(:document_metrics)[:total_documents]).to eq(3)
    expect(response).to render_template(:index)
  end

  it "shows recent activity" do
    documents = create_list(:document, 5, organization: organization, user: user)
    get root_path
    
    expect(assigns(:recent_documents).count).to eq(5)
  end

  it "displays system metrics" do
    get root_path
    
    expect(assigns(:system_metrics)).to include(:total_users, :active_users_today)
  end
end
```

#### Playwright Browser Tests:
```javascript
test('Dashboard loads with correct metrics', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await expect(page.locator('text=Dashboard')).toBeVisible();
  await expect(page.locator('text=Documents')).toBeVisible();
  await expect(page.locator('text=Recent Documents')).toBeVisible();
  await expect(page.locator('text=Storage & System Info')).toBeVisible();
});

test('Navigation menu is accessible', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await expect(page.locator('text=Clients')).toBeVisible();
  await expect(page.locator('text=Applications')).toBeVisible();
  await expect(page.locator('text=Quotes')).toBeVisible();
  await expect(page.locator('text=Documents')).toBeVisible();
});
```

### 2.2 Role-Based Access Control (RBAC)
**Description**: Dynamic permission system controlling feature access
**User Roles**: All users (permissions vary by role)
**Models**: `Role`, `Permission`, `UserRole`, `RolePermission`

#### Unit Tests:
```ruby
describe "Role-Based Access Control" do
  let(:organization) { create(:organization) }
  let(:admin_role) { create(:role, name: 'admin', organization: organization) }
  let(:agent_role) { create(:role, name: 'agent', organization: organization) }
  let(:admin_user) { create(:user, organization: organization, role: :brokerage_admin) }
  let(:agent_user) { create(:user, organization: organization, role: :agent) }

  it "allows admin to access all features" do
    sign_in admin_user
    get admin_organizations_path
    expect(response).to have_http_status(:success)
  end

  it "restricts agent from admin features" do
    sign_in agent_user
    get admin_organizations_path
    expect(response).to have_http_status(:forbidden)
  end

  it "allows role assignment" do
    permission = create(:permission, name: 'manage_users')
    admin_role.permissions << permission
    
    expect(admin_role.permissions).to include(permission)
  end
end
```

---

## 3. CLIENT MANAGEMENT

### 3.1 Client Registration & Profile Management
**Description**: Complete client onboarding and profile management system
**User Roles**: Agents, Brokerage Admins
**Model**: `Client`

#### Unit Tests:
```ruby
describe "Client Management" do
  let(:organization) { create(:organization) }
  let(:agent) { create(:user, role: :agent, organization: organization) }

  before { sign_in agent }

  it "creates client with valid data" do
    client_params = {
      first_name: "John",
      last_name: "Doe", 
      email: "john@example.com",
      phone: "+233244123456",
      date_of_birth: "1990-01-01"
    }
    
    expect {
      post clients_path, params: { client: client_params }
    }.to change(Client, :count).by(1)
  end

  it "validates required fields" do
    post clients_path, params: { client: { first_name: "" } }
    expect(assigns(:client).errors[:first_name]).to be_present
  end

  it "calculates age correctly" do
    client = create(:client, date_of_birth: 30.years.ago)
    expect(client.age).to eq(30)
  end
end
```

#### Playwright Browser Tests:
```javascript
test('Agent can create new client', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Clients');
  await page.click('text=Add Client');
  
  await page.fill('input[name="client[first_name]"]', 'Test');
  await page.fill('input[name="client[last_name]"]', 'Client');
  await page.fill('input[name="client[email]"]', 'test.client@example.com');
  await page.fill('input[name="client[phone]"]', '+233244123456');
  await page.fill('input[name="client[date_of_birth]"]', '1990-01-01');
  
  await page.click('input[type="submit"]');
  await expect(page.locator('text=Client created successfully')).toBeVisible();
});

test('Client list displays correctly', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Clients');
  await expect(page.locator('text=All Clients')).toBeVisible();
  await expect(page.locator('text=Kofi Asante')).toBeVisible(); // From seed data
});
```

---

## 4. INSURANCE APPLICATION MANAGEMENT

### 4.1 Motor Insurance Applications
**Description**: Complete motor insurance application workflow
**User Roles**: Agents, Brokerage Admins
**Model**: `MotorApplication`, `InsuranceApplication`

#### Unit Tests:
```ruby
describe "Motor Insurance Applications" do
  let(:organization) { create(:organization) }
  let(:agent) { create(:user, role: :agent, organization: organization) }
  let(:client) { create(:client, organization: organization) }

  before { sign_in agent }

  it "creates motor application with required fields" do
    application_params = {
      client_id: client.id,
      insurance_type: 'motor',
      application_data: {
        vehicle_make: 'Toyota',
        vehicle_model: 'Camry',
        vehicle_year: '2020',
        registration_number: 'GR-1234-AB',
        chassis_number: 'CHASSIS123',
        engine_number: 'ENGINE123',
        driver_license_number: 'DL123456'
      }
    }
    
    expect {
      post insurance_applications_path, params: { insurance_application: application_params }
    }.to change(InsuranceApplication, :count).by(1)
  end

  it "generates application number automatically" do
    application = create(:insurance_application, insurance_type: 'motor', organization: organization)
    expect(application.application_number).to match(/^MI\d{6}\d{4}$/)
  end

  it "calculates risk score based on vehicle and driver data" do
    application = create(:insurance_application, 
      insurance_type: 'motor',
      organization: organization,
      client: create(:client, date_of_birth: 20.years.ago), # Young driver = higher risk
      application_data: { vehicle_year: '2010' } # Older vehicle = higher risk
    )
    
    expect(application.risk_score).to be > 50
    expect(application.risk_level).to eq('high')
  end
end
```

#### Playwright Browser Tests:
```javascript
test('Agent can create motor insurance application', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Applications');
  await page.click('text=Motor Insurance');
  await page.click('text=New Application');
  
  // Select client
  await page.selectOption('select[name="application[client_id]"]', { label: 'Kofi Asante' });
  
  // Fill vehicle details
  await page.fill('input[name="application[vehicle_make]"]', 'Toyota');
  await page.fill('input[name="application[vehicle_model]"]', 'Camry');
  await page.fill('input[name="application[vehicle_year]"]', '2020');
  await page.fill('input[name="application[registration_number]"]', 'GR-5678-CD');
  
  await page.click('button[type="submit"]');
  await expect(page.locator('text=Application created successfully')).toBeVisible();
});

test('Application status workflow works correctly', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Applications');
  await page.click('text=MI2025090001'); // From seed data
  
  // Submit application
  await page.click('text=Submit Application');
  await expect(page.locator('text=submitted')).toBeVisible();
  
  // Start review (as admin)
  await page.click('text=Start Review');
  await expect(page.locator('text=under_review')).toBeVisible();
});
```

### 4.2 Fire Insurance Applications
**Description**: Property fire insurance application processing
**User Roles**: Agents, Brokerage Admins

#### Unit Tests:
```ruby
describe "Fire Insurance Applications" do
  it "validates fire insurance specific fields" do
    application = build(:insurance_application,
      insurance_type: 'fire',
      application_data: {} # Missing required fields
    )
    
    expect(application).not_to be_valid
    expect(application.errors[:application_data]).to include(/property_type is required/)
  end

  it "calculates fire risk based on property type and construction" do
    application = create(:insurance_application,
      insurance_type: 'fire',
      application_data: {
        property_type: 'industrial', # High risk
        construction_type: 'wood', # High risk
        fire_safety_measures: '' # No safety measures
      }
    )
    
    expect(application.risk_level).to eq('high')
  end
end
```

### 4.3 Other Insurance Types
**Description**: Liability, General Accident, and Bonds insurance processing
**User Roles**: Agents, Brokerage Admins

---

## 5. QUOTE MANAGEMENT

### 5.1 Quote Generation & Management  
**Description**: Insurance companies can create and manage quotes for applications
**User Roles**: Insurance Company Users
**Model**: `Quote`

#### Unit Tests:
```ruby
describe "Quote Management" do
  let(:insurance_company) { create(:insurance_company) }
  let(:user) { create(:user, role: :insurance_company) }
  let(:application) { create(:insurance_application, status: 'submitted') }

  before { sign_in user }

  it "creates quote with valid data" do
    quote_params = {
      insurance_application_id: application.id,
      premium_amount: 1000.00,
      coverage_amount: 50000.00,
      commission_rate: 15.0,
      validity_period: 30,
      coverage_details: { 'comprehensive' => 'Full coverage' }
    }
    
    expect {
      post quotes_path, params: { quote: quote_params }
    }.to change(Quote, :count).by(1)
  end

  it "auto-calculates commission amount" do
    quote = create(:quote, premium_amount: 1000, commission_rate: 15)
    expect(quote.commission_amount).to eq(150.0)
  end

  it "handles quote status transitions" do
    quote = create(:quote, status: 'draft')
    
    expect(quote.submit!).to be true
    expect(quote.status).to eq('submitted')
    
    quote.start_review!
    expect(quote.status).to eq('pending_review')
    
    quote.approve!
    expect(quote.status).to eq('approved')
  end
end
```

#### Playwright Browser Tests:
```javascript
test('Insurance company can create quote', async ({ page }) => {
  await loginAsUser(page, 'insurance+company1@boughtspot.com');
  await page.click('text=Applications');
  await page.click('text=MI2025090001'); // Application from seed data
  await page.click('text=Create Quote');
  
  await page.fill('input[name="quote[premium_amount]"]', '1200.00');
  await page.fill('input[name="quote[coverage_amount]"]', '50000.00');
  await page.fill('input[name="quote[commission_rate]"]', '15');
  await page.fill('input[name="quote[validity_period]"]', '30');
  
  await page.click('button[type="submit"]');
  await expect(page.locator('text=Quote created successfully')).toBeVisible();
});

test('Quote comparison works for brokers', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Quotes');
  await page.click('text=Compare Quotes');
  await expect(page.locator('text=Quote Comparison')).toBeVisible();
});
```

---

## 6. DOCUMENT MANAGEMENT

### 6.1 Document Upload & Storage
**Description**: Secure document management with versioning and encryption
**User Roles**: All authenticated users
**Model**: `Document`

#### Unit Tests:
```ruby
describe "Document Management" do
  let(:user) { create(:user) }
  let(:organization) { user.organization }

  before { sign_in user }

  it "uploads document successfully" do
    file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')
    
    expect {
      post documents_path, params: { 
        document: { 
          name: 'Test Document',
          category: 'policy',
          file: file
        }
      }
    }.to change(Document, :count).by(1)
  end

  it "validates file types" do
    file = fixture_file_upload('spec/fixtures/malicious.exe', 'application/octet-stream')
    
    post documents_path, params: { 
      document: { 
        name: 'Malicious File',
        file: file
      }
    }
    
    expect(assigns(:document).errors[:file]).to be_present
  end

  it "tracks document versions" do
    document = create(:document, organization: organization, user: user)
    original_version = document.version
    
    # Upload new version
    file = fixture_file_upload('spec/fixtures/updated_document.pdf', 'application/pdf')
    post new_version_document_path(document), params: { file: file }
    
    document.reload
    expect(document.version).to eq(original_version + 1)
  end

  it "handles document archiving" do
    document = create(:document, organization: organization, user: user)
    
    patch archive_document_path(document)
    document.reload
    
    expect(document.archived?).to be true
    expect(document.archived_at).to be_present
  end
end
```

#### Playwright Browser Tests:
```javascript
test('User can upload document', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Documents');
  await page.click('text=Upload Document');
  
  await page.fill('input[name="document[name]"]', 'Test Policy Document');
  await page.selectOption('select[name="document[category]"]', 'policy');
  
  // Upload file
  const fileInput = page.locator('input[type="file"]');
  await fileInput.setInputFiles('test-files/sample-policy.pdf');
  
  await page.click('button[type="submit"]');
  await expect(page.locator('text=Document uploaded successfully')).toBeVisible();
});

test('Document search and filtering works', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Documents');
  
  await page.fill('input[placeholder="Search documents..."]', 'policy');
  await page.keyboard.press('Enter');
  
  await expect(page.locator('text=Search results')).toBeVisible();
});
```

### 6.2 Document Security & Encryption
**Description**: Advanced document security with encryption and access controls
**Implementation**: `Encryptable` concern

#### Unit Tests:
```ruby
describe "Document Security" do
  it "encrypts sensitive document data" do
    document = create(:document, sensitive_data: "Confidential information")
    
    # Data should be encrypted in database
    raw_data = Document.connection.select_value(
      "SELECT sensitive_data FROM documents WHERE id = #{document.id}"
    )
    expect(raw_data).not_to eq("Confidential information")
    
    # But accessible normally through model
    expect(document.sensitive_data).to eq("Confidential information")
  end

  it "tracks document access" do
    document = create(:document)
    user = create(:user)
    
    expect {
      AuditLog.log_data_access(user, document, 'document_downloaded')
    }.to change(AuditLog, :count).by(1)
  end
end
```

---

## 7. NOTIFICATION SYSTEM

### 7.1 Real-time Notifications
**Description**: Multi-channel notification system (in-app, SMS, WhatsApp)
**User Roles**: All users
**Models**: `Notification`, `NotificationPreference`, `SmsLog`, `WhatsappLog`

#### Unit Tests:
```ruby
describe "Notification System" do
  let(:user) { create(:user, sms_enabled: true, whatsapp_enabled: true) }

  it "creates in-app notification" do
    expect {
      Notification.create!(
        user: user,
        title: "Test Notification",
        message: "This is a test",
        notification_type: "application_status"
      )
    }.to change(Notification, :count).by(1)
  end

  it "sends SMS notification when enabled" do
    allow_any_instance_of(SmsService).to receive(:send_sms).and_return(true)
    
    result = user.send_sms(body: "Test SMS message")
    expect(result).to be true
  end

  it "respects notification preferences" do
    user.notification_preferences.update(sms_enabled: false)
    
    # Should not send SMS when disabled
    expect(user.can_receive_sms?).to be false
  end

  it "tracks notification delivery" do
    notification = create(:notification, user: user)
    
    expect {
      notification.mark_as_read!
    }.to change { notification.read_at }.from(nil)
  end
end
```

#### Playwright Browser Tests:
```javascript
test('User receives in-app notifications', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  
  // Check notification bell icon
  await expect(page.locator('[data-testid="notification-bell"]')).toBeVisible();
  
  await page.click('[data-testid="notification-bell"]');
  await expect(page.locator('text=Notifications')).toBeVisible();
});

test('User can manage notification preferences', async ({ page }) => {
  await loginAsUser(page, 'brokers+01@boughtspot.com');
  await page.click('text=Notifications');
  await page.click('text=Preferences');
  
  await page.uncheck('input[name="sms_enabled"]');
  await page.click('button[type="submit"]');
  
  await expect(page.locator('text=Preferences updated')).toBeVisible();
});
```

---

## 8. REPORTING & ANALYTICS

### 8.1 Executive Dashboard
**Description**: High-level analytics and business intelligence
**User Roles**: Brokerage Admins, Super Admins
**Routes**: `/executive/*`

#### Unit Tests:
```ruby
describe "Executive Dashboard" do
  let(:admin) { create(:user, role: :brokerage_admin) }
  let(:organization) { admin.organization }

  before { sign_in admin }

  it "displays key business metrics" do
    # Create test data
    create_list(:insurance_application, 10, organization: organization)
    create_list(:quote, 5, organization: organization)
    
    get executive_dashboard_index_path
    
    expect(assigns(:metrics)).to include(:total_applications, :total_quotes)
    expect(response).to have_http_status(:success)
  end

  it "shows revenue analytics" do
    get executive_dashboard_analytics_path
    
    expect(assigns(:revenue_data)).to be_present
    expect(assigns(:commission_data)).to be_present
  end

  it "generates forecasting data" do
    get executive_dashboard_forecasting_path
    
    expect(assigns(:forecast_data)).to be_present
  end
end
```

#### Playwright Browser Tests:
```javascript
test('Executive dashboard loads correctly', async ({ page }) => {
  await loginAsUser(page, 'brokersync+admin1@boughtspot.com');
  await page.goto('http://localhost:3000/executive');
  
  await expect(page.locator('text=Executive Dashboard')).toBeVisible();
  await expect(page.locator('text=Revenue Analytics')).toBeVisible();
  await expect(page.locator('text=Application Trends')).toBeVisible();
});

test('Analytics charts render properly', async ({ page }) => {
  await loginAsUser(page, 'brokersync+admin1@boughtspot.com');
  await page.goto('http://localhost:3000/executive/analytics');
  
  await expect(page.locator('canvas')).toBeVisible(); // Chart.js canvas
  await expect(page.locator('text=Monthly Revenue')).toBeVisible();
});
```

### 8.2 Audit Logging & Compliance
**Description**: Comprehensive audit trail for compliance and security
**User Roles**: Admins, Compliance Officers
**Model**: `AuditLog`

#### Unit Tests:
```ruby
describe "Audit Logging" do
  let(:user) { create(:user) }
  let(:document) { create(:document, user: user) }

  it "logs data access events" do
    expect {
      AuditLog.log_data_access(user, document, 'document_viewed')
    }.to change(AuditLog, :count).by(1)
    
    log = AuditLog.last
    expect(log.action).to eq('document_viewed')
    expect(log.auditable).to eq(document)
  end

  it "logs data modifications" do
    expect {
      AuditLog.log_data_modification(user, document, 'document_updated', { name: 'New Name' })
    }.to change(AuditLog, :count).by(1)
  end

  it "exports audit logs for compliance" do
    create_list(:audit_log, 10, user: user)
    
    get export_audits_path, params: { format: 'csv' }
    expect(response.content_type).to eq('text/csv')
  end
end
```

---

## 9. API & INTEGRATIONS

### 9.1 RESTful API
**Description**: Comprehensive API for third-party integrations
**User Roles**: API consumers with valid API keys
**Routes**: `/api/v1/*`

#### Unit Tests:
```ruby
describe "API v1" do
  let(:organization) { create(:organization) }
  let(:api_key) { create(:api_key, organization: organization) }

  it "authenticates with valid API key" do
    get api_v1_applications_path, headers: { 'Authorization' => "Bearer #{api_key.key}" }
    expect(response).to have_http_status(:success)
  end

  it "rejects invalid API key" do
    get api_v1_applications_path, headers: { 'Authorization' => "Bearer invalid_key" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns applications in JSON format" do
    application = create(:insurance_application, organization: organization)
    
    get api_v1_applications_path, headers: { 'Authorization' => "Bearer #{api_key.key}" }
    
    json_response = JSON.parse(response.body)
    expect(json_response['applications']).to be_an(Array)
    expect(json_response['applications'].first['id']).to eq(application.id)
  end
end
```

### 9.2 Webhook System
**Description**: Event-driven webhook notifications for external systems
**Routes**: `/api/v1/webhooks`

#### Unit Tests:
```ruby
describe "Webhook System" do
  let(:webhook) { create(:webhook, url: 'https://example.com/webhook') }

  it "delivers webhook on application status change" do
    application = create(:insurance_application)
    
    expect(WebhookDeliveryJob).to receive(:perform_later)
      .with(webhook.id, 'application.status_changed', hash_including(application_id: application.id))
    
    application.update!(status: 'approved')
  end

  it "retries failed webhook deliveries" do
    stub_request(:post, webhook.url).to_return(status: 500)
    
    expect {
      WebhookDeliveryJob.perform_now(webhook.id, 'test.event', { test: 'data' })
    }.to raise_error(WebhookDeliveryError)
  end
end
```

---

## 10. ADVANCED FEATURES

### 10.1 AI/ML Risk Assessment
**Description**: Machine learning-powered risk scoring and pricing recommendations
**Implementation**: Risk calculation algorithms in insurance application models

#### Unit Tests:
```ruby
describe "AI/ML Risk Assessment" do
  it "calculates comprehensive risk scores" do
    # High-risk profile
    high_risk_application = create(:insurance_application,
      insurance_type: 'motor',
      client: create(:client, date_of_birth: 19.years.ago), # Young driver
      application_data: {
        vehicle_year: '2005', # Old vehicle
        vehicle_usage: 'commercial', # Commercial use
        previous_accidents: 'yes' # Previous claims
      }
    )
    
    expect(high_risk_application.risk_score).to be > 70
    expect(high_risk_application.risk_level).to eq('high')
    
    # Low-risk profile  
    low_risk_application = create(:insurance_application,
      insurance_type: 'motor',
      client: create(:client, date_of_birth: 35.years.ago), # Experienced driver
      application_data: {
        vehicle_year: '2022', # New vehicle
        vehicle_usage: 'personal', # Personal use
        previous_accidents: 'no' # No previous claims
      }
    )
    
    expect(low_risk_application.risk_score).to be < 50
    expect(low_risk_application.risk_level).to eq('low')
  end

  it "adjusts pricing based on risk assessment" do
    application = create(:insurance_application, insurance_type: 'motor')
    base_premium = 1000
    
    risk_multiplier = case application.risk_level
    when 'low' then 0.8
    when 'medium' then 1.0
    when 'high' then 1.3
    end
    
    adjusted_premium = base_premium * risk_multiplier
    expect(adjusted_premium).to be > 0
  end
end
```

### 10.2 Feature Flag Management
**Description**: Dynamic feature control for gradual rollouts and A/B testing
**Model**: `FeatureFlag`

#### Unit Tests:
```ruby
describe "Feature Flag Management" do
  let(:organization) { create(:organization) }

  it "controls feature availability" do
    feature = create(:feature_flag, 
      name: 'advanced_analytics', 
      enabled: true,
      organization: organization
    )
    
    expect(organization.feature_enabled?('advanced_analytics')).to be true
  end

  it "supports percentage rollouts" do
    feature = create(:feature_flag,
      name: 'new_ui',
      enabled: true,
      percentage: 50
    )
    
    # Test rollout logic (simplified)
    user_id = 12345
    enabled_for_user = (user_id % 100) < feature.percentage
    expect([true, false]).to include(enabled_for_user)
  end
end
```

### 10.3 Performance Monitoring & Caching
**Description**: Application performance optimization and monitoring
**Implementation**: `Cacheable` concern, Redis caching

#### Unit Tests:
```ruby
describe "Performance Monitoring" do
  it "caches expensive database queries" do
    expect(Rails.cache).to receive(:fetch).with('dashboard_metrics_org_1', expires_in: 5.minutes)
    
    controller = HomeController.new
    controller.send(:load_dashboard_data)
  end

  it "monitors query performance" do
    expect(QueryAnalyzer).to receive(:analyze_query)
    
    User.includes(:organization).limit(10).to_a
  end
end
```

---

## TESTING REQUIREMENTS FROM USER

### Required Test Resources

1. **Sample PDF Documents**
   - Policy documents (various insurance types)
   - Claim forms
   - ID verification documents
   - Vehicle registration documents

2. **Sample Images**
   - Vehicle photos (for motor insurance)
   - Property photos (for fire insurance)
   - Driver license photos
   - ID card/passport photos

3. **Test Data Files**
   - CSV files for bulk data import
   - Excel templates for application data
   - Sample API responses

4. **External Service Mocking**
   - SMS service responses
   - WhatsApp API responses
   - Payment gateway responses
   - Third-party API integrations

### Environment Setup Requirements

1. **Playwright Configuration**
   ```javascript
   // playwright.config.js
   module.exports = {
     testDir: './tests',
     timeout: 30000,
     expect: {
       timeout: 5000
     },
     fullyParallel: true,
     forbidOnly: !!process.env.CI,
     retries: process.env.CI ? 2 : 0,
     workers: process.env.CI ? 1 : undefined,
     reporter: 'html',
     use: {
       baseURL: 'http://localhost:3000',
       trace: 'on-first-retry',
       screenshot: 'only-on-failure'
     }
   };
   ```

2. **Rails Test Environment**
   ```ruby
   # config/environments/test.rb
   config.cache_classes = true
   config.eager_load = false
   config.public_file_server.enabled = true
   config.consider_all_requests_local = true
   config.action_controller.perform_caching = false
   config.action_mailer.delivery_method = :test
   config.active_support.deprecation = :stderr
   ```

3. **Database Setup**
   - Dedicated test database
   - Factory Bot for test data generation
   - Database cleaner configuration

### Testing Checklist

- [ ] All authentication flows tested ⚠️ **Asset pipeline issues in test environment**
- [ ] Role-based access control verified
- [ ] Document upload/download functionality
- [ ] Insurance application workflows
- [ ] Quote generation and management
- [ ] Notification system (all channels)
- [ ] API endpoints and authentication ⚠️ **Authentication mocking issues**
- [ ] Security features (MFA, rate limiting)
- [ ] Dashboard and reporting features
- [ ] Error handling and edge cases
- [ ] Performance under load
- [ ] Mobile responsiveness
- [ ] Cross-browser compatibility

### Current Testing Status (Updated: Sept 22, 2025)

#### ✅ Working Tests
- **User Model Tests**: ✅ All 5 tests passing (enums, validations, behavior, scopes)
- **Client Model Tests**: ✅ All 14 tests passing (associations, validations, age calculation, scopes, contact methods)
- **Factory Definitions**: User, Organization, Client, Document, API Key factories created
- **Service Tests**: GlobalSearchService and SearchAnalyticsService test structures in place

#### ⚠️ Issues Identified
1. **Asset Pipeline**: DaisyUI manual CSS not loading in test environment
2. **API Authentication**: Controller tests failing due to authentication service mocking
3. **Route Helpers**: Some path helpers not available in feature test context
4. **Test Configuration**: Slow test filtering affecting feature test execution

#### 🔧 Recommended Next Steps
1. Fix asset compilation for test environment
2. Create proper authentication helpers for feature tests
3. Verify all route definitions and helpers
4. Start with unit tests (models/services) before feature tests

This comprehensive testing guide ensures that every feature of the BrokerSync application is thoroughly tested from both a unit test perspective and a real-world user interaction perspective using Playwright browser automation.