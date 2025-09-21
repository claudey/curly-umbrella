require 'rails_helper'

RSpec.describe "Role-Based Access Control", type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  let(:admin_user) { create(:user, role: :brokerage_admin, organization: organization) }
  let(:agent_user) { create(:user, role: :agent, organization: organization) }
  let(:insurance_company_user) { create(:user, role: :insurance_company) }
  let(:other_org_user) { create(:user, role: :agent, organization: other_organization) }

  describe "Agent Role Permissions" do
    before { sign_in agent_user }

    it "allows access to client management" do
      get clients_path
      expect(response).to have_http_status(:success)
    end

    it "allows access to applications" do
      get insurance_applications_path
      expect(response).to have_http_status(:success)
    end

    it "allows access to quotes (view only)" do
      get quotes_path
      expect(response).to have_http_status(:success)
    end

    it "allows access to documents" do
      get documents_path
      expect(response).to have_http_status(:success)
    end

    it "denies access to admin features" do
      get admin_organizations_path
      expect(response).to have_http_status(:forbidden)
    end

    it "denies access to user management" do
      get admin_users_path
      expect(response).to have_http_status(:forbidden)
    end

    it "denies access to system reports" do
      get admin_reports_path
      expect(response).to have_http_status(:forbidden)
    end

    it "can create clients" do
      client_params = {
        first_name: "Test",
        last_name: "Client",
        email: "test@example.com",
        phone: "+233244123456"
      }

      expect {
        post clients_path, params: { client: client_params }
      }.to change(Client, :count).by(1)

      expect(response).to redirect_to(client_path(Client.last))
    end

    it "can create applications" do
      client = create(:client, organization: organization)
      application_params = {
        client_id: client.id,
        insurance_type: 'motor',
        application_data: {
          vehicle_make: 'Toyota',
          vehicle_model: 'Camry'
        }
      }

      expect {
        post insurance_applications_path, params: { insurance_application: application_params }
      }.to change(InsuranceApplication, :count).by(1)
    end

    it "cannot create quotes (only insurance companies can)" do
      application = create(:insurance_application, organization: organization)
      quote_params = {
        insurance_application_id: application.id,
        premium_amount: 1000,
        coverage_amount: 50000
      }

      post quotes_path, params: { quote: quote_params }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "Brokerage Admin Role Permissions" do
    before { sign_in admin_user }

    it "allows access to all agent features" do
      [ clients_path, insurance_applications_path, quotes_path, documents_path ].each do |path|
        get path
        expect(response).to have_http_status(:success)
      end
    end

    it "allows access to user management" do
      get admin_users_path
      expect(response).to have_http_status(:success)
    end

    it "allows access to organization settings" do
      get admin_organizations_path
      expect(response).to have_http_status(:success)
    end

    it "allows access to reports" do
      get admin_reports_path
      expect(response).to have_http_status(:success)
    end

    it "can manage users within organization" do
      user_params = {
        email: "newuser@example.com",
        first_name: "New",
        last_name: "User",
        role: "agent",
        password: "password123456"
      }

      expect {
        post admin_users_path, params: { user: user_params }
      }.to change(User, :count).by(1)

      new_user = User.last
      expect(new_user.organization).to eq(organization)
    end

    it "can update organization settings" do
      org_params = {
        name: "Updated Organization Name",
        phone: "+233244999999"
      }

      patch admin_organization_path(organization), params: { organization: org_params }
      expect(response).to redirect_to(admin_organization_path(organization))

      organization.reload
      expect(organization.name).to eq("Updated Organization Name")
    end

    it "denies access to super admin features" do
      get admin_system_path
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot manage other organizations" do
      patch admin_organization_path(other_organization), params: {
        organization: { name: "Hacked Name" }
      }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "Insurance Company Role Permissions" do
    before { sign_in insurance_company_user }

    it "allows access to applications (view submitted only)" do
      get insurance_applications_path
      expect(response).to have_http_status(:success)
    end

    it "allows access to quotes management" do
      get quotes_path
      expect(response).to have_http_status(:success)
    end

    it "can create quotes for submitted applications" do
      application = create(:insurance_application, status: 'submitted')
      quote_params = {
        insurance_application_id: application.id,
        premium_amount: 1500,
        coverage_amount: 75000,
        commission_rate: 15.0
      }

      expect {
        post quotes_path, params: { quote: quote_params }
      }.to change(Quote, :count).by(1)
    end

    it "denies access to client management" do
      get clients_path
      expect(response).to have_http_status(:forbidden)
    end

    it "denies access to creating applications" do
      application_params = {
        insurance_type: 'motor',
        application_data: { vehicle_make: 'Toyota' }
      }

      post insurance_applications_path, params: { insurance_application: application_params }
      expect(response).to have_http_status(:forbidden)
    end

    it "denies access to admin features" do
      [ admin_users_path, admin_organizations_path, admin_reports_path ].each do |path|
        get path
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "can only see applications in reviewable status" do
      draft_app = create(:insurance_application, status: 'draft')
      submitted_app = create(:insurance_application, status: 'submitted')
      under_review_app = create(:insurance_application, status: 'under_review')

      get insurance_applications_path

      # Parse response to check which applications are visible
      expect(response.body).to include(submitted_app.application_number)
      expect(response.body).to include(under_review_app.application_number)
      expect(response.body).not_to include(draft_app.application_number)
    end
  end

  describe "Cross-Organization Access Control" do
    before { sign_in agent_user }

    it "prevents access to other organization's clients" do
      other_client = create(:client, organization: other_organization)

      get client_path(other_client)
      expect(response).to have_http_status(:not_found)
    end

    it "prevents access to other organization's applications" do
      other_application = create(:insurance_application, organization: other_organization)

      get insurance_application_path(other_application)
      expect(response).to have_http_status(:not_found)
    end

    it "prevents access to other organization's documents" do
      other_document = create(:document, organization: other_organization)

      get document_path(other_document)
      expect(response).to have_http_status(:not_found)
    end

    it "only shows organization's data in index pages" do
      # Create data for both organizations
      create_list(:client, 3, organization: organization)
      create_list(:client, 2, organization: other_organization)

      get clients_path

      expect(assigns(:clients).count).to eq(3)
      expect(assigns(:clients).map(&:organization).uniq).to eq([ organization ])
    end

    it "scopes API endpoints to organization" do
      create_list(:client, 2, organization: organization)
      create_list(:client, 3, organization: other_organization)

      get api_v1_clients_path, headers: { 'Accept' => 'application/json' }

      json_response = JSON.parse(response.body)
      expect(json_response['clients'].count).to eq(2)
    end
  end

  describe "Permission Helper Methods" do
    it "correctly identifies user permissions" do
      expect(agent_user.can?(:manage, :clients)).to be true
      expect(agent_user.can?(:manage, :users)).to be false
      expect(agent_user.can?(:create, :quotes)).to be false

      expect(admin_user.can?(:manage, :clients)).to be true
      expect(admin_user.can?(:manage, :users)).to be true
      expect(admin_user.can?(:manage, :organization)).to be true

      expect(insurance_company_user.can?(:create, :quotes)).to be true
      expect(insurance_company_user.can?(:manage, :clients)).to be false
    end

    it "correctly scopes resources by organization" do
      create_list(:client, 3, organization: organization)
      create_list(:client, 2, organization: other_organization)

      scoped_clients = agent_user.accessible_clients
      expect(scoped_clients.count).to eq(3)
      expect(scoped_clients.map(&:organization).uniq).to eq([ organization ])
    end
  end

  describe "Feature Flag Access Control" do
    it "respects feature flags for role-based features" do
      # Assuming you have feature flags
      allow(organization).to receive(:feature_enabled?).with('advanced_analytics').and_return(false)

      sign_in admin_user
      get admin_analytics_path

      expect(response).to have_http_status(:forbidden)
    end

    it "allows access when feature is enabled" do
      allow(organization).to receive(:feature_enabled?).with('advanced_analytics').and_return(true)

      sign_in admin_user
      get admin_analytics_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "Dynamic Permissions" do
    it "handles temporary permission elevation" do
      # If your system supports temporary permissions
      permission = create(:temporary_permission, user: agent_user, permission: 'view_reports', expires_at: 1.hour.from_now)

      sign_in agent_user
      get admin_reports_path

      expect(response).to have_http_status(:success)
    end

    it "expires temporary permissions" do
      permission = create(:temporary_permission, user: agent_user, permission: 'view_reports', expires_at: 1.hour.ago)

      sign_in agent_user
      get admin_reports_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "Audit Trail for Permissions" do
    it "logs permission checks" do
      sign_in agent_user

      expect {
        get admin_users_path
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('permission_denied')
      expect(audit_log.details).to include('admin_users')
    end

    it "logs successful access" do
      sign_in agent_user

      expect {
        get clients_path
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('resource_accessed')
    end
  end

  describe "Security Edge Cases" do
    it "prevents parameter tampering for organization_id" do
      sign_in agent_user

      client_params = {
        first_name: "Test",
        last_name: "Client",
        email: "test@example.com",
        organization_id: other_organization.id # Attempt to tamper
      }

      post clients_path, params: { client: client_params }

      new_client = Client.last
      expect(new_client.organization).to eq(organization) # Should use current user's org
    end

    it "handles mass assignment attacks" do
      sign_in agent_user

      user_params = {
        first_name: "Test",
        last_name: "User",
        role: "brokerage_admin", # Attempt to escalate privileges
        organization_id: other_organization.id
      }

      patch user_path(agent_user), params: { user: user_params }

      agent_user.reload
      expect(agent_user.role).to eq('agent') # Role should not change
      expect(agent_user.organization).to eq(organization) # Org should not change
    end

    it "prevents session fixation attacks" do
      old_session_id = nil

      # Capture session before login
      get new_user_session_path
      old_session_id = session[:session_id] if session[:session_id]

      # Login
      post user_session_path, params: {
        user: { email: agent_user.email, password: "password123456" }
      }

      # Session should be regenerated
      new_session_id = session[:session_id]
      expect(new_session_id).not_to eq(old_session_id) if old_session_id
    end

    it "handles concurrent role changes" do
      # Simulate concurrent modification
      original_role = agent_user.role

      # Thread 1: Try to change role
      thread1 = Thread.new do
        sign_in admin_user
        patch admin_user_path(agent_user), params: {
          user: { role: 'brokerage_admin' }
        }
      end

      # Thread 2: User tries to access admin features
      thread2 = Thread.new do
        sign_in agent_user
        get admin_users_path
      end

      thread1.join
      thread2.join

      # Should handle gracefully without security issues
      expect(response).to have_http_status(:forbidden)
    end
  end
end
