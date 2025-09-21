require 'rails_helper'

RSpec.describe 'API V1 Applications', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:client) { create(:client, organization: organization) }
  let(:api_key) { create(:api_key, organization: organization, user: user) }

  let(:valid_headers) do
    {
      'Authorization' => "Bearer #{api_key.key}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  let(:invalid_headers) do
    {
      'Authorization' => 'Bearer invalid_key',
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe 'GET /api/v1/applications' do
    let!(:applications) do
      [
        create(:insurance_application, :motor, organization: organization, user: user, client: client),
        create(:insurance_application, :life, organization: organization, user: user, client: client),
        create(:insurance_application, :property, organization: organization, user: user, client: client)
      ]
    end

    context 'with valid authentication' do
      it 'returns all applications for the organization' do
        get '/api/v1/applications', headers: valid_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['applications']).to be_an(Array)
        expect(json_response['data']['applications'].length).to eq(3)
        expect(json_response['meta']['total']).to eq(3)
        expect(json_response['meta']['page']).to eq(1)
      end

      it 'supports pagination' do
        # Create more applications
        create_list(:insurance_application, 10, organization: organization, user: user, client: client)

        get '/api/v1/applications', params: { page: 1, per_page: 5 }, headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['applications'].length).to eq(5)
        expect(json_response['meta']['total']).to eq(13)
        expect(json_response['meta']['page']).to eq(1)
        expect(json_response['meta']['per_page']).to eq(5)
      end

      it 'supports filtering by status' do
        applications[0].update!(status: 'submitted')
        applications[1].update!(status: 'approved')

        get '/api/v1/applications', params: { status: 'submitted' }, headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['applications'].length).to eq(1)
        expect(json_response['data']['applications'][0]['status']).to eq('submitted')
      end

      it 'supports filtering by application type' do
        get '/api/v1/applications', params: { application_type: 'motor' }, headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['applications'].length).to eq(1)
        expect(json_response['data']['applications'][0]['application_type']).to eq('motor')
      end

      it 'includes related data when requested' do
        get '/api/v1/applications', params: { include: 'quotes,documents' }, headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        application_data = json_response['data']['applications'][0]
        expect(application_data).to have_key('quotes')
        expect(application_data).to have_key('documents')
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        get '/api/v1/applications', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']['code']).to eq('UNAUTHORIZED')
      end

      it 'returns 401 without authorization header' do
        get '/api/v1/applications', headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']['message']).to include('Authorization header missing')
      end
    end

    context 'with rate limiting' do
      it 'enforces rate limits' do
        # Make requests up to the limit
        50.times do
          get '/api/v1/applications', headers: valid_headers
        end

        # The 51st request should be rate limited
        get '/api/v1/applications', headers: valid_headers
        expect(response).to have_http_status(:too_many_requests)

        json_response = JSON.parse(response.body)
        expect(json_response['error']['code']).to eq('RATE_LIMIT_EXCEEDED')
      end
    end
  end

  describe 'GET /api/v1/applications/:id' do
    let!(:application) { create(:insurance_application, :motor, organization: organization, user: user, client: client) }
    let!(:quote) { create(:quote, insurance_application: application, organization: organization, user: user) }

    context 'with valid authentication' do
      it 'returns the specific application' do
        get "/api/v1/applications/#{application.id}", headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['application']['id']).to eq(application.id)
        expect(json_response['data']['application']['application_number']).to eq(application.application_number)
      end

      it 'includes quotes and documents in response' do
        get "/api/v1/applications/#{application.id}", headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        application_data = json_response['data']['application']
        expect(application_data['quotes']).to be_an(Array)
        expect(application_data['quotes'].length).to eq(1)
        expect(application_data['documents']).to be_an(Array)
      end

      it 'returns 404 for non-existent application' do
        get '/api/v1/applications/99999', headers: valid_headers

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']['code']).to eq('NOT_FOUND')
      end
    end

    context 'cross-tenant access prevention' do
      let(:other_organization) { create(:organization) }
      let(:other_application) { create(:insurance_application, organization: other_organization) }

      it 'prevents access to applications from other organizations' do
        get "/api/v1/applications/#{other_application.id}", headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/applications' do
    let(:valid_application_params) do
      {
        application: {
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
          client_id: client.id
        }
      }
    end

    context 'with valid authentication and data' do
      it 'creates a new application' do
        expect {
          post '/api/v1/applications', params: valid_application_params.to_json, headers: valid_headers
        }.to change(InsuranceApplication, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['application']['application_type']).to eq('motor')
        expect(json_response['data']['application']['first_name']).to eq('John')
      end

      it 'automatically generates application number' do
        post '/api/v1/applications', params: valid_application_params.to_json, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['data']['application']['application_number']).to match(/^APP\d{6}$/)
      end

      it 'sets correct organization and user' do
        post '/api/v1/applications', params: valid_application_params.to_json, headers: valid_headers

        application = InsuranceApplication.last
        expect(application.organization).to eq(organization)
        expect(application.user).to eq(user)
      end
    end

    context 'with invalid data' do
      it 'returns validation errors for missing required fields' do
        invalid_params = { application: { application_type: 'motor' } }

        post '/api/v1/applications', params: invalid_params.to_json, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']['code']).to eq('VALIDATION_ERROR')
        expect(json_response['error']['details']).to be_present
      end

      it 'validates motor-specific fields' do
        invalid_motor_params = valid_application_params.deep_dup
        invalid_motor_params[:application][:vehicle_make] = nil

        post '/api/v1/applications', params: invalid_motor_params.to_json, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']['details']).to include('vehicle_make')
      end
    end
  end

  describe 'PUT /api/v1/applications/:id' do
    let!(:application) { create(:insurance_application, :motor, organization: organization, user: user, client: client) }

    context 'with valid authentication and data' do
      it 'updates the application' do
        update_params = {
          application: {
            first_name: 'Jane',
            vehicle_make: 'Honda'
          }
        }

        put "/api/v1/applications/#{application.id}", params: update_params.to_json, headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['application']['first_name']).to eq('Jane')
        expect(json_response['data']['application']['vehicle_make']).to eq('Honda')

        application.reload
        expect(application.first_name).to eq('Jane')
        expect(application.vehicle_make).to eq('Honda')
      end

      it 'prevents updating after submission' do
        application.update!(status: 'submitted')

        update_params = { application: { first_name: 'Jane' } }

        put "/api/v1/applications/#{application.id}", params: update_params.to_json, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']['message']).to include('cannot be updated')
      end
    end
  end

  describe 'POST /api/v1/applications/:id/submit' do
    let!(:application) { create(:insurance_application, :motor, organization: organization, user: user, client: client) }

    context 'with valid authentication' do
      it 'submits the application for review' do
        post "/api/v1/applications/#{application.id}/submit", headers: valid_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['application']['status']).to eq('submitted')

        application.reload
        expect(application.status).to eq('submitted')
        expect(application.submitted_at).to be_present
      end

      it 'prevents duplicate submission' do
        application.update!(status: 'submitted')

        post "/api/v1/applications/#{application.id}/submit", headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']['message']).to include('already submitted')
      end
    end
  end

  describe 'GET /api/v1/applications/:id/documents' do
    let!(:application) { create(:insurance_application, organization: organization, user: user, client: client) }
    let!(:documents) do
      [
        create(:document, documentable: application, organization: organization, user: user),
        create(:document, documentable: application, organization: organization, user: user)
      ]
    end

    it 'returns documents for the application' do
      get "/api/v1/applications/#{application.id}/documents", headers: valid_headers

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['documents']).to be_an(Array)
      expect(json_response['data']['documents'].length).to eq(2)
    end
  end

  describe 'GET /api/v1/applications/:id/quotes' do
    let!(:application) { create(:insurance_application, organization: organization, user: user, client: client) }
    let!(:quotes) do
      [
        create(:quote, insurance_application: application, organization: organization, user: user),
        create(:quote, insurance_application: application, organization: organization, user: user)
      ]
    end

    it 'returns quotes for the application' do
      get "/api/v1/applications/#{application.id}/quotes", headers: valid_headers

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['quotes']).to be_an(Array)
      expect(json_response['data']['quotes'].length).to eq(2)
    end

    it 'includes quote details and status' do
      get "/api/v1/applications/#{application.id}/quotes", headers: valid_headers

      json_response = JSON.parse(response.body)
      quote_data = json_response['data']['quotes'][0]
      expect(quote_data).to have_key('quote_number')
      expect(quote_data).to have_key('status')
      expect(quote_data).to have_key('total_premium')
      expect(quote_data).to have_key('insurance_company')
    end
  end

  describe 'Performance and Error Handling' do
    context 'large datasets' do
      it 'handles large numbers of applications efficiently' do
        create_list(:insurance_application, 100, organization: organization, user: user, client: client)

        start_time = Time.current
        get '/api/v1/applications', params: { per_page: 50 }, headers: valid_headers
        response_time = Time.current - start_time

        expect(response).to have_http_status(:ok)
        expect(response_time).to be < 2.seconds
      end
    end

    context 'malformed requests' do
      it 'handles invalid JSON gracefully' do
        post '/api/v1/applications',
             params: '{ invalid json }',
             headers: valid_headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']['code']).to eq('INVALID_JSON')
      end

      it 'handles missing content-type header' do
        headers_without_content_type = valid_headers.except('Content-Type')

        post '/api/v1/applications',
             params: valid_application_params.to_json,
             headers: headers_without_content_type

        expect(response).to have_http_status(:unsupported_media_type)
      end
    end

    context 'API versioning' do
      it 'returns proper version information in headers' do
        get '/api/v1/applications', headers: valid_headers

        expect(response.headers['API-Version']).to eq('1.0')
        expect(response.headers['X-RateLimit-Limit']).to be_present
        expect(response.headers['X-RateLimit-Remaining']).to be_present
      end
    end
  end
end
