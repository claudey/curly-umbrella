require 'rails_helper'

RSpec.describe "Search Requests", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  before do
    sign_in user
  end

  describe "GET /search" do
    let!(:client) { create(:client, organization: organization, first_name: 'John', last_name: 'Doe') }
    let!(:application) { create(:insurance_application, organization: organization, client: client) }

    context 'with valid search parameters' do
      it 'renders the search results page' do
        get search_path, params: { query: 'John', scope: 'all' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Search Results')
        expect(response.body).to include('John')
      end

      it 'displays search results in the correct format' do
        get search_path, params: { query: 'John' }

        expect(response.body).to include('data-controller="search"')
        expect(response.body).to include('search-results')
      end

      it 'includes search metadata in the page' do
        get search_path, params: { query: 'motor insurance', scope: 'applications' }

        expect(response.body).to include('motor insurance')
        expect(response.body).to include('applications')
      end
    end

    context 'with AJAX request' do
      it 'returns JSON response for AJAX requests' do
        get search_path, params: { query: 'John' }, xhr: true

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('html')
        expect(json_response).to have_key('total_count')
        expect(json_response).to have_key('search_time')
      end

      it 'renders partial for AJAX requests' do
        get search_path, params: { query: 'John' }, xhr: true

        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('search-result-item')
      end
    end

    context 'with filters' do
      let!(:motor_app) { create(:insurance_application, organization: organization, application_type: 'motor') }
      let!(:fire_app) { create(:insurance_application, organization: organization, application_type: 'fire') }

      it 'applies status filters correctly' do
        get search_path, params: {
          query: 'insurance',
          scope: 'applications',
          filters: { status: 'draft' }
        }

        expect(response).to have_http_status(:ok)
        # Results should be filtered by status
      end

      it 'applies multiple filters' do
        get search_path, params: {
          query: 'insurance',
          scope: 'applications',
          filters: {
            status: 'draft',
            application_type: 'motor'
          }
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with pagination' do
      before do
        create_list(:client, 30, organization: organization)
      end

      it 'paginates results correctly' do
        get search_path, params: { query: 'client', page: 1, per_page: 10 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('pagination')
        expect(response.body).to include('page-1')
      end

      it 'handles invalid page numbers' do
        get search_path, params: { query: 'client', page: 999 }

        expect(response).to have_http_status(:ok)
        # Should default to first page or show appropriate message
      end
    end

    context 'without authentication' do
      before do
        sign_out user
      end

      it 'redirects to login page' do
        get search_path, params: { query: 'test' }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'with organization isolation' do
      let(:other_organization) { create(:organization) }
      let!(:external_client) { create(:client, organization: other_organization, first_name: 'External', last_name: 'User') }

      it 'does not return results from other organizations' do
        get search_path, params: { query: 'External' }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('External User')
      end
    end
  end

  describe "GET /search/suggestions" do
    let!(:client1) { create(:client, organization: organization, first_name: 'John', last_name: 'Doe') }
    let!(:client2) { create(:client, organization: organization, first_name: 'Jane', last_name: 'Smith') }

    it 'returns search suggestions as JSON' do
      get suggestions_search_path, params: { query: 'joh' }, xhr: true

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('suggestions')
      expect(json_response['suggestions']).to be_an(Array)
    end

    it 'limits suggestions appropriately' do
      get suggestions_search_path, params: { query: 'j' }, xhr: true

      json_response = JSON.parse(response.body)
      expect(json_response['suggestions'].size).to be <= 10
    end

    it 'returns empty suggestions for very short queries' do
      get suggestions_search_path, params: { query: 'a' }, xhr: true

      json_response = JSON.parse(response.body)
      expect(json_response['suggestions']).to be_empty
    end
  end

  describe "POST /search/save" do
    it 'saves search to user history' do
      expect {
        post save_search_path, params: {
          query: 'motor insurance',
          results_count: 15,
          search_time: 0.25
        }, xhr: true
      }.to change(SearchHistory, :count).by(1)

      expect(response).to have_http_status(:ok)

      history = SearchHistory.last
      expect(history.user).to eq(user)
      expect(history.query).to eq('motor insurance')
      expect(history.results_count).to eq(15)
    end

    it 'does not save empty queries' do
      expect {
        post save_search_path, params: {
          query: '',
          results_count: 0
        }, xhr: true
      }.not_to change(SearchHistory, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /search/history" do
    before do
      create(:search_history, user: user, query: 'motor insurance', results_count: 10)
      create(:search_history, user: user, query: 'fire policy', results_count: 5)
    end

    it 'returns user search history' do
      get history_search_path, xhr: true

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('history')
      expect(json_response['history']).to be_an(Array)
      expect(json_response['history'].size).to eq(2)
    end

    it 'orders history by most recent first' do
      get history_search_path, xhr: true

      json_response = JSON.parse(response.body)
      first_search = json_response['history'].first
      expect(first_search['query']).to eq('fire policy') # Assuming it was created last
    end
  end

  describe "DELETE /search/history" do
    before do
      create_list(:search_history, 5, user: user)
    end

    it 'clears user search history' do
      expect {
        delete clear_history_search_path, xhr: true
      }.to change { user.search_histories.count }.from(5).to(0)

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
    end
  end

  describe "performance and caching" do
    before do
      create_list(:client, 100, organization: organization)
      create_list(:insurance_application, 50, organization: organization)
    end

    it 'caches search results appropriately' do
      # First request
      get search_path, params: { query: 'insurance' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to be_present
    end

    it 'varies cache by user and organization' do
      get search_path, params: { query: 'test' }

      expect(response.headers['Vary']).to include('User')
    end

    it 'completes search within reasonable time' do
      start_time = Time.current
      get search_path, params: { query: 'client', scope: 'all' }
      end_time = Time.current

      expect(end_time - start_time).to be < 3.0
      expect(response).to have_http_status(:ok)
    end
  end

  describe "error handling" do
    context 'when search service fails' do
      before do
        allow(GlobalSearchService).to receive(:new).and_raise(StandardError.new('Service error'))
      end

      it 'handles service errors gracefully' do
        get search_path, params: { query: 'test' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Search temporarily unavailable')
      end
    end

    context 'with malformed parameters' do
      it 'handles invalid scope parameters' do
        get search_path, params: { query: 'test', scope: 'invalid' }

        expect(response).to have_http_status(:ok)
        # Should default to 'all' scope or show error message
      end

      it 'handles very long search queries' do
        long_query = 'a' * 1000
        get search_path, params: { query: long_query }

        expect(response).to have_http_status(:ok)
        # Should truncate or show appropriate message
      end
    end
  end

  describe "accessibility and usability" do
    it 'includes proper ARIA labels and roles' do
      get search_path, params: { query: 'test' }

      expect(response.body).to include('role="search"')
      expect(response.body).to include('aria-label')
    end

    it 'provides proper form labels' do
      get search_path

      expect(response.body).to include('<label')
      expect(response.body).to include('for="search_query"')
    end

    it 'includes search result count for screen readers' do
      get search_path, params: { query: 'insurance' }

      expect(response.body).to include('results found')
      expect(response.body).to include('sr-only') # Screen reader only text
    end
  end
end
