require 'rails_helper'

RSpec.describe Api::V1::SearchController, type: :controller do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:api_key) { create(:api_key, user: user, organization: organization) }

  before do
    request.headers['Authorization'] = "Bearer #{api_key.key}"
    allow(ApiAuthenticationService).to receive(:authenticate_request!).and_return(api_key)
    allow(controller).to receive(:current_api_key).and_return(api_key)
    allow(controller).to receive(:current_api_user).and_return(user)
    allow(controller).to receive(:current_organization).and_return(organization)
  end

  describe 'GET #global' do
    let!(:client) { create(:client, organization: organization, first_name: 'John', last_name: 'Doe') }
    let!(:application) { create(:insurance_application, organization: organization, client: client, insurance_type: 'motor') }

    context 'with valid search query' do
      it 'returns search results successfully' do
        get :global, params: { query: 'John', scope: 'all' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('clients')
        expect(json_response['data']).to have_key('applications')
        expect(json_response['data']).to have_key('total_count')
        expect(json_response['data']).to have_key('search_time')
      end

      it 'respects scope parameter' do
        get :global, params: { query: 'John', scope: 'clients' }

        json_response = JSON.parse(response.body)
        
        expect(json_response['data']['clients']['count']).to be > 0
        expect(json_response['data']['applications']['count']).to eq(0)
        expect(json_response['data']['quotes']['count']).to eq(0)
        expect(json_response['data']['documents']['count']).to eq(0)
      end

      it 'includes search metadata' do
        get :global, params: { query: 'motor insurance' }

        json_response = JSON.parse(response.body)
        
        expect(json_response['data']['query']).to eq('motor insurance')
        expect(json_response['data']['scope']).to eq('all')
        expect(json_response['data']['search_time']).to be_a(Float)
      end

      it 'supports pagination' do
        get :global, params: { query: 'John', page: 1, per_page: 5 }

        json_response = JSON.parse(response.body)
        
        expect(json_response['data']).to have_key('pagination')
        pagination = json_response['data']['pagination']
        expect(pagination['current_page']).to eq(1)
        expect(pagination['per_page']).to eq(5)
      end

      it 'tracks search analytics' do
        expect(SearchAnalyticsService).to receive(:track_search).with(
          hash_including(
            user: user,
            query: 'John',
            scope: 'all'
          )
        )

        get :global, params: { query: 'John', scope: 'all' }
      end
    end

    context 'with empty query' do
      it 'returns empty results' do
        get :global, params: { query: '' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['data']['total_count']).to eq(0)
      end
    end

    context 'with invalid scope' do
      it 'returns error for invalid scope' do
        get :global, params: { query: 'test', scope: 'invalid_scope' }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be false
        expect(json_response['error']['message']).to include('Invalid scope')
      end
    end

    context 'without authentication' do
      before do
        request.headers['Authorization'] = nil
        allow(controller).to receive(:current_api_user).and_return(nil)
      end

      it 'returns unauthorized' do
        get :global, params: { query: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with rate limiting' do
      before do
        allow(RateLimitingService).to receive(:check_request_rate_limit).and_return(false)
      end

      it 'returns rate limit error' do
        get :global, params: { query: 'test' }

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'GET #suggestions' do
    let!(:client1) { create(:client, organization: organization, first_name: 'John', last_name: 'Doe') }
    let!(:client2) { create(:client, organization: organization, first_name: 'Jane', last_name: 'Doe') }

    it 'returns search suggestions' do
      get :suggestions, params: { query: 'joh' }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['success']).to be true
      expect(json_response['data']['suggestions']).to be_an(Array)
      
      if json_response['data']['suggestions'].any?
        suggestion = json_response['data']['suggestions'].first
        expect(suggestion).to have_key('type')
        expect(suggestion).to have_key('value')
        expect(suggestion).to have_key('label')
        expect(suggestion).to have_key('category')
      end
    end

    it 'limits number of suggestions' do
      get :suggestions, params: { query: 'doe' }

      json_response = JSON.parse(response.body)
      expect(json_response['data']['suggestions'].size).to be <= 10
    end

    it 'returns empty suggestions for short queries' do
      get :suggestions, params: { query: 'a' }

      json_response = JSON.parse(response.body)
      expect(json_response['data']['suggestions']).to be_empty
    end
  end

  describe 'GET #filters' do
    before do
      create(:insurance_application, organization: organization, status: 'draft')
      create(:insurance_application, organization: organization, status: 'submitted')
    end

    it 'returns available filters with counts' do
      get :filters, params: { query: 'insurance' }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['success']).to be true
      expect(json_response['data']['filters']).to have_key('applications')
      
      app_filters = json_response['data']['filters']['applications']
      expect(app_filters).to have_key('statuses')
      expect(app_filters['statuses']).to be_an(Array)
    end

    it 'includes filter counts' do
      get :filters, params: { query: 'application' }

      json_response = JSON.parse(response.body)
      app_statuses = json_response['data']['filters']['applications']['statuses']
      
      if app_statuses.any?
        status_filter = app_statuses.first
        expect(status_filter).to have_key('value')
        expect(status_filter).to have_key('label')
        expect(status_filter).to have_key('count')
        expect(status_filter['count']).to be >= 0
      end
    end
  end

  describe 'GET #history' do
    before do
      create(:search_history, user: user, query: 'motor insurance', results_count: 10)
      create(:search_history, user: user, query: 'fire policy', results_count: 5)
    end

    it 'returns user search history' do
      get :history

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['success']).to be true
      expect(json_response['data']['recent_searches']).to be_an(Array)
      expect(json_response['data']['recent_searches'].size).to eq(2)
      
      search = json_response['data']['recent_searches'].first
      expect(search).to have_key('query')
      expect(search).to have_key('results_count')
      expect(search).to have_key('searched_at')
    end

    it 'orders history by most recent first' do
      get :history

      json_response = JSON.parse(response.body)
      searches = json_response['data']['recent_searches']
      
      # Assuming motor insurance was created after fire policy
      expect(searches.first['query']).to eq('motor insurance')
    end

    it 'limits history to recent searches' do
      # Create many old searches
      create_list(:search_history, 20, user: user, created_at: 1.week.ago)
      
      get :history

      json_response = JSON.parse(response.body)
      expect(json_response['data']['recent_searches'].size).to be <= 10
    end
  end

  describe 'GET #analytics' do
    context 'as admin user' do
      before do
        user.update!(role: 'brokerage_admin')
        create(:search_history, user: user, query: 'test', results_count: 5, created_at: 1.day.ago)
      end

      it 'returns search analytics for organization' do
        get :analytics, params: { period: '7d' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be true
        expect(json_response['data']['analytics']).to have_key('total_searches')
        expect(json_response['data']['analytics']).to have_key('unique_users')
        expect(json_response['data']['analytics']).to have_key('popular_queries')
      end

      it 'supports different time periods' do
        get :analytics, params: { period: '30d' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['data']['period']).to eq('30d')
      end
    end

    context 'as regular user' do
      it 'returns forbidden for non-admin users' do
        get :analytics

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE #clear_history' do
    before do
      create_list(:search_history, 5, user: user)
    end

    it 'clears user search history' do
      expect {
        delete :clear_history
      }.to change { user.search_histories.count }.from(5).to(0)

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
    end

    it 'only clears current user history' do
      other_user = create(:user, organization: organization)
      create(:search_history, user: other_user)

      delete :clear_history

      expect(other_user.search_histories.count).to eq(1)
    end
  end

  describe 'error handling' do
    context 'when search service raises error' do
      before do
        allow(GlobalSearchService).to receive(:new).and_raise(StandardError.new('Search error'))
      end

      it 'returns internal server error' do
        get :global, params: { query: 'test' }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be false
        expect(json_response['error']['message']).to include('Search temporarily unavailable')
      end
    end

    context 'with malformed parameters' do
      it 'handles missing query parameter' do
        get :global

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be false
        expect(json_response['error']['message']).to include('Query parameter is required')
      end

      it 'handles invalid pagination parameters' do
        get :global, params: { query: 'test', page: -1, per_page: 1000 }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'performance' do
    before do
      # Create test data for performance testing
      create_list(:client, 100, organization: organization)
      create_list(:insurance_application, 50, organization: organization)
    end

    it 'completes search within reasonable time' do
      start_time = Time.current
      get :global, params: { query: 'test', scope: 'all' }
      end_time = Time.current
      
      expect(end_time - start_time).to be < 3.0 # Should complete within 3 seconds
      expect(response).to have_http_status(:ok)
    end

    it 'includes performance metrics in response' do
      get :global, params: { query: 'test' }

      json_response = JSON.parse(response.body)
      expect(json_response['data']['search_time']).to be_a(Float)
      expect(json_response['data']['search_time']).to be > 0
    end
  end

  describe 'caching' do
    it 'caches identical search requests' do
      expect(GlobalSearchService).to receive(:new).once.and_call_original
      
      # Make the same request twice
      get :global, params: { query: 'motor insurance', scope: 'all' }
      get :global, params: { query: 'motor insurance', scope: 'all' }
      
      expect(response).to have_http_status(:ok)
    end

    it 'includes cache headers in response' do
      get :global, params: { query: 'test' }

      expect(response.headers['Cache-Control']).to be_present
      expect(response.headers['ETag']).to be_present
    end
  end
end