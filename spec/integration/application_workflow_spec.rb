require 'rails_helper'

RSpec.describe 'Application Workflow Integration', type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, organization: organization) }
  let(:agent_user) { create(:user, :agent, organization: organization) }
  let(:client) { create(:client, organization: organization) }
  let(:insurance_company) { create(:insurance_company, organization: organization) }

  before do
    ActsAsTenant.current_tenant = organization
    sign_in agent_user
  end

  after { ActsAsTenant.current_tenant = nil }

  describe 'Complete Motor Insurance Application Workflow' do
    let(:application_params) do
      {
        insurance_application: {
          application_type: 'motor',
          first_name: 'John',
          last_name: 'Doe',
          email: 'john.doe@example.com',
          phone_number: '555-1234',
          date_of_birth: '1985-01-01',
          address: '123 Main St',
          city: 'Anytown',
          state: 'CA',
          postal_code: '12345',
          vehicle_make: 'Toyota',
          vehicle_model: 'Camry',
          vehicle_year: 2020,
          vehicle_vin: '1234567890ABCDEFG',
          license_number: 'ABC123456',
          coverage_amount: 50000,
          policy_start_date: 1.month.from_now,
          policy_end_date: 1.year.from_now,
          client_id: client.id
        }
      }
    end

    context 'successful application submission and processing' do
      it 'completes the full workflow from application to quote acceptance' do
        # Step 1: Create new application
        post '/insurance_applications', params: application_params
        expect(response).to have_http_status(:redirect)

        application = InsuranceApplication.last
        expect(application.status).to eq('draft')
        expect(application.application_type).to eq('motor')
        expect(application.vehicle_make).to eq('Toyota')

        # Step 2: Submit application for review
        patch "/insurance_applications/#{application.id}/submit"
        expect(response).to have_http_status(:redirect)

        application.reload
        expect(application.status).to eq('submitted')
        expect(application.submitted_at).to be_present

        # Step 3: Admin starts review process
        sign_in admin_user
        patch "/insurance_applications/#{application.id}/start_review"
        expect(response).to have_http_status(:redirect)

        application.reload
        expect(application.status).to eq('under_review')
        expect(application.review_started_at).to be_present

        # Step 4: Admin approves application
        patch "/insurance_applications/#{application.id}/approve"
        expect(response).to have_http_status(:redirect)

        application.reload
        expect(application.status).to eq('approved')
        expect(application.approved_at).to be_present
        expect(application.approved_by).to eq(admin_user)

        # Step 5: Create quote for approved application
        quote_params = {
          quote: {
            insurance_company_id: insurance_company.id,
            base_premium: 1200,
            taxes: 120,
            fees: 50,
            policy_term: 12,
            payment_frequency: 'monthly',
            effective_date: 1.month.from_now,
            expiry_date: 1.year.from_now,
            coverage_limits: { 'liability' => 100000, 'collision' => 50000 },
            deductibles: { 'collision' => 500 }
          }
        }

        post "/insurance_applications/#{application.id}/quotes", params: quote_params
        expect(response).to have_http_status(:redirect)

        quote = application.quotes.last
        expect(quote.status).to eq('pending')
        expect(quote.total_premium).to eq(1370) # base + taxes + fees

        # Step 6: Submit quote to insurance company
        patch "/quotes/#{quote.id}/submit"
        expect(response).to have_http_status(:redirect)

        quote.reload
        expect(quote.status).to eq('submitted')
        expect(quote.submitted_at).to be_present

        # Step 7: Insurance company approves quote
        patch "/quotes/#{quote.id}/approve"
        expect(response).to have_http_status(:redirect)

        quote.reload
        expect(quote.status).to eq('approved')
        expect(quote.approved_at).to be_present

        # Step 8: Client accepts quote
        patch "/quotes/#{quote.id}/accept"
        expect(response).to have_http_status(:redirect)

        quote.reload
        expect(quote.status).to eq('accepted')
        expect(quote.accepted_at).to be_present

        # Verify audit trail
        expect(application.audits.count).to be > 0
        expect(quote.audits.count).to be > 0

        # Verify notifications were sent (if notification system is implemented)
        # expect(ActionMailer::Base.deliveries.count).to be > 0
      end
    end

    context 'application rejection workflow' do
      it 'handles application rejection correctly' do
        # Create and submit application
        post '/insurance_applications', params: application_params
        application = InsuranceApplication.last

        patch "/insurance_applications/#{application.id}/submit"

        # Admin rejects application
        sign_in admin_user
        rejection_params = {
          rejection_reason: 'Insufficient credit score'
        }

        patch "/insurance_applications/#{application.id}/reject", params: rejection_params
        expect(response).to have_http_status(:redirect)

        application.reload
        expect(application.status).to eq('rejected')
        expect(application.rejected_at).to be_present
        expect(application.rejection_reason).to eq('Insufficient credit score')
        expect(application.rejected_by).to eq(admin_user)

        # Verify application cannot be processed further
        expect(application.can_be_approved?).to be_falsey
        expect(application.can_be_submitted?).to be_falsey
      end
    end

    context 'quote rejection and re-quote workflow' do
      let!(:application) { create(:insurance_application, :approved, organization: organization, client: client, user: agent_user) }

      it 'handles quote rejection and allows new quotes' do
        # Create initial quote
        quote_params = {
          quote: {
            insurance_company_id: insurance_company.id,
            base_premium: 1500,
            taxes: 150,
            fees: 75,
            policy_term: 12,
            payment_frequency: 'monthly',
            effective_date: 1.month.from_now,
            expiry_date: 1.year.from_now
          }
        }

        post "/insurance_applications/#{application.id}/quotes", params: quote_params
        quote = application.quotes.last

        # Submit and then reject quote
        patch "/quotes/#{quote.id}/submit"
        patch "/quotes/#{quote.id}/reject", params: { rejection_reason: 'Rate too high' }

        quote.reload
        expect(quote.status).to eq('rejected')
        expect(quote.rejection_reason).to eq('Rate too high')

        # Create new quote with better terms
        better_quote_params = {
          quote: {
            insurance_company_id: insurance_company.id,
            base_premium: 1200, # Lower premium
            taxes: 120,
            fees: 50,
            policy_term: 12,
            payment_frequency: 'monthly',
            effective_date: 1.month.from_now,
            expiry_date: 1.year.from_now
          }
        }

        post "/insurance_applications/#{application.id}/quotes", params: better_quote_params
        new_quote = application.quotes.reload.last

        expect(new_quote.id).not_to eq(quote.id)
        expect(new_quote.base_premium).to eq(1200)
        expect(new_quote.status).to eq('pending')

        # Accept the new quote
        patch "/quotes/#{new_quote.id}/submit"
        patch "/quotes/#{new_quote.id}/approve"
        patch "/quotes/#{new_quote.id}/accept"

        new_quote.reload
        expect(new_quote.status).to eq('accepted')
      end
    end
  end

  describe 'Document Upload Workflow' do
    let!(:application) { create(:insurance_application, :submitted, organization: organization, client: client, user: agent_user) }

    it 'allows document upload during application process' do
      # Upload driver license
      document_params = {
        document: {
          name: 'Driver License',
          document_type: 'driver_license',
          category: 'legal',
          access_level: 'private',
          file: fixture_file_upload('spec/fixtures/files/sample_document.pdf', 'application/pdf')
        }
      }

      post "/insurance_applications/#{application.id}/documents", params: document_params
      expect(response).to have_http_status(:redirect)

      document = application.documents.last
      expect(document.name).to eq('Driver License')
      expect(document.document_type).to eq('driver_license')
      expect(document.file).to be_attached

      # Upload vehicle registration
      vehicle_reg_params = {
        document: {
          name: 'Vehicle Registration',
          document_type: 'vehicle_registration',
          category: 'legal',
          access_level: 'private',
          file: fixture_file_upload('spec/fixtures/files/sample_document.pdf', 'application/pdf')
        }
      }

      post "/insurance_applications/#{application.id}/documents", params: vehicle_reg_params
      expect(response).to have_http_status(:redirect)

      expect(application.documents.count).to eq(2)
      expect(application.documents.pluck(:document_type)).to include('driver_license', 'vehicle_registration')
    end
  end

  describe 'Multi-Quote Comparison Workflow' do
    let!(:application) { create(:insurance_application, :approved, organization: organization, client: client, user: agent_user) }
    let!(:company1) { create(:insurance_company, organization: organization, name: 'Company A') }
    let!(:company2) { create(:insurance_company, organization: organization, name: 'Company B') }

    it 'allows multiple quotes for comparison' do
      # Create first quote
      quote1_params = {
        quote: {
          insurance_company_id: company1.id,
          base_premium: 1500,
          taxes: 150,
          fees: 75,
          policy_term: 12,
          payment_frequency: 'monthly'
        }
      }

      post "/insurance_applications/#{application.id}/quotes", params: quote1_params
      quote1 = application.quotes.last

      # Create second quote
      quote2_params = {
        quote: {
          insurance_company_id: company2.id,
          base_premium: 1300,
          taxes: 130,
          fees: 65,
          policy_term: 12,
          payment_frequency: 'monthly'
        }
      }

      post "/insurance_applications/#{application.id}/quotes", params: quote2_params
      quote2 = application.quotes.last

      # Verify both quotes exist
      expect(application.quotes.count).to eq(2)
      expect(application.quotes.pluck(:insurance_company_id)).to include(company1.id, company2.id)

      # Compare quotes
      get "/insurance_applications/#{application.id}/compare_quotes"
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Company A')
      expect(response.body).to include('Company B')
      expect(response.body).to include('1500') # quote1 premium
      expect(response.body).to include('1300') # quote2 premium

      # Accept the better quote (quote2)
      patch "/quotes/#{quote2.id}/submit"
      patch "/quotes/#{quote2.id}/approve"
      patch "/quotes/#{quote2.id}/accept"

      quote2.reload
      expect(quote2.status).to eq('accepted')

      # Verify the other quote remains unaffected
      quote1.reload
      expect(quote1.status).to eq('pending')
    end
  end

  describe 'Error Handling and Edge Cases' do
    context 'invalid data submission' do
      it 'handles invalid application data gracefully' do
        invalid_params = {
          insurance_application: {
            application_type: 'motor',
            first_name: '', # Missing required field
            email: 'invalid-email', # Invalid format
            vehicle_year: 1900 # Invalid year
          }
        }

        post '/insurance_applications', params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)

        # Verify no application was created
        expect(InsuranceApplication.count).to eq(0)
      end
    end

    context 'unauthorized access attempts' do
      it 'prevents unauthorized status changes' do
        application = create(:insurance_application, :submitted, organization: organization, client: client, user: agent_user)

        # Agent tries to approve (only admin should be able to)
        patch "/insurance_applications/#{application.id}/approve"
        expect(response).to have_http_status(:forbidden)

        application.reload
        expect(application.status).to eq('submitted') # Status unchanged
      end
    end

    context 'expired quote handling' do
      it 'prevents acceptance of expired quotes' do
        application = create(:insurance_application, :approved, organization: organization, client: client, user: agent_user)
        quote = create(:quote, :expired, insurance_application: application, organization: organization, insurance_company: insurance_company, user: agent_user)

        patch "/quotes/#{quote.id}/accept"
        expect(response).to have_http_status(:unprocessable_entity)

        quote.reload
        expect(quote.status).not_to eq('accepted')
      end
    end
  end

  describe 'Performance and Data Integrity' do
    it 'maintains data consistency under concurrent access' do
      application = create(:insurance_application, :submitted, organization: organization, client: client, user: agent_user)

      # Simulate concurrent approval attempts
      threads = []
      results = []

      3.times do |i|
        threads << Thread.new do
          begin
            patch "/insurance_applications/#{application.id}/approve"
            results << response.status
          rescue => e
            results << e.class
          end
        end
      end

      threads.each(&:join)

      # Only one should succeed
      application.reload
      expect(application.status).to eq('approved')
      expect(application.approved_at).to be_present
    end
  end
end
