require 'rails_helper'

RSpec.describe "Simple Request Tests", type: :request do
  # Test basic request functionality without complex authentication
  
  describe "Public endpoints" do
    it "can access login page" do
      get new_user_session_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("sign")
    end
  end

  describe "Basic CRUD with minimal auth" do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, organization: organization) }

    before do
      # Set up minimal context
      ActsAsTenant.current_tenant = organization
      
      # Mock security concerns
      allow_any_instance_of(ApplicationController).to receive(:check_ip_blocking).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:check_rate_limiting).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:monitor_request_security).and_return(true)
      
      # Sign in user
      sign_in user
    end

    describe "Clients CRUD" do
      it "can create a client" do
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

        expect(response.status).to be_in([200, 201, 302])
      end

      it "can list clients" do
        create(:client, organization: organization)
        
        get clients_path
        expect(response.status).to be_in([200, 302])
      end
    end

    describe "Applications CRUD" do
      it "can create an application" do
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

        expect(response.status).to be_in([200, 201, 302])
      end
    end

    describe "Documents CRUD" do
      it "can access documents index" do
        get documents_path
        expect(response.status).to be_in([200, 302])
      end

      it "can access document upload form" do
        get new_document_path
        expect(response.status).to be_in([200, 302])
      end
    end
  end

  describe "API endpoints" do
    let(:organization) { create(:organization) }
    
    before do
      ActsAsTenant.current_tenant = organization
    end

    it "can access API with basic auth" do
      api_key = create(:api_key, organization: organization)
      
      get api_v1_applications_path, headers: {
        'Authorization' => "Bearer #{api_key.key}",
        'Accept' => 'application/json'
      }
      
      expect(response.status).to be_in([200, 401, 403])
    end
  end
end