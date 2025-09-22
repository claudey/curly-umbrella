require 'rails_helper'

RSpec.describe GlobalSearchService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:other_organization) { create(:organization) }
  
  # Create test data
  let!(:client1) { create(:client, organization: organization, first_name: 'John', last_name: 'Doe', email: 'john.doe@example.com') }
  let!(:client2) { create(:client, organization: organization, first_name: 'Jane', last_name: 'Smith', email: 'jane.smith@company.com') }
  let!(:external_client) { create(:client, organization: other_organization, first_name: 'John', last_name: 'External') }
  
  let!(:application1) { create(:insurance_application, organization: organization, client: client1, application_type: 'motor', status: 'submitted') }
  let!(:application2) { create(:insurance_application, organization: organization, client: client2, application_type: 'fire', status: 'approved') }
  
  let!(:quote1) { create(:quote, organization: organization, application: application1, total_premium: 1200.00, status: 'pending') }
  let!(:quote2) { create(:quote, organization: organization, application: application2, total_premium: 850.00, status: 'accepted') }
  
  let!(:document1) { create(:document, organization: organization, user: user, name: 'Motor Insurance Policy', document_type: 'policy_document') }
  let!(:document2) { create(:document, organization: organization, user: user, name: 'Fire Safety Certificate', document_type: 'certificate') }

  describe '#initialize' do
    it 'sets the current user and search parameters' do
      params = { query: 'test', scope: 'all' }
      service = GlobalSearchService.new(user, params)
      
      expect(service.current_user).to eq(user)
      expect(service.params).to eq(params)
    end
  end

  describe '#search' do
    let(:service) { GlobalSearchService.new(user, params) }

    context 'with global search query' do
      let(:params) { { query: 'John', scope: 'all' } }

      it 'returns results from multiple entity types' do
        results = service.search

        expect(results).to have_key(:clients)
        expect(results).to have_key(:applications)
        expect(results).to have_key(:quotes)
        expect(results).to have_key(:documents)
        expect(results).to have_key(:total_count)
        expect(results).to have_key(:search_time)
      end

      it 'finds clients by name' do
        results = service.search
        
        expect(results[:clients][:results]).to include(client1)
        expect(results[:clients][:results]).not_to include(external_client)
        expect(results[:clients][:count]).to eq(1)
      end

      it 'respects organization boundaries' do
        results = service.search
        
        # Should not find clients from other organizations
        all_results = results.values.flat_map { |v| v.is_a?(Hash) ? v[:results] || [] : [] }
        expect(all_results).not_to include(external_client)
      end

      it 'includes search metadata' do
        results = service.search
        
        expect(results[:total_count]).to be > 0
        expect(results[:search_time]).to be_a(Float)
        expect(results[:query]).to eq('John')
        expect(results[:scope]).to eq('all')
      end
    end

    context 'with specific scope search' do
      let(:params) { { query: 'motor', scope: 'applications' } }

      it 'searches only in specified scope' do
        results = service.search

        expect(results[:applications][:count]).to eq(1)
        expect(results[:applications][:results]).to include(application1)
        expect(results[:clients][:count]).to eq(0)
        expect(results[:quotes][:count]).to eq(0)
        expect(results[:documents][:count]).to eq(0)
      end
    end

    context 'with email search' do
      let(:params) { { query: 'jane.smith@company.com', scope: 'all' } }

      it 'finds clients by email' do
        results = service.search
        
        expect(results[:clients][:results]).to include(client2)
        expect(results[:clients][:count]).to eq(1)
      end
    end

    context 'with numeric search (premium amounts)' do
      let(:params) { { query: '1200', scope: 'quotes' } }

      it 'finds quotes by premium amount' do
        results = service.search
        
        expect(results[:quotes][:results]).to include(quote1)
        expect(results[:quotes][:count]).to eq(1)
      end
    end

    context 'with empty query' do
      let(:params) { { query: '', scope: 'all' } }

      it 'returns empty results' do
        results = service.search
        
        expect(results[:total_count]).to eq(0)
        expect(results[:clients][:count]).to eq(0)
        expect(results[:applications][:count]).to eq(0)
        expect(results[:quotes][:count]).to eq(0)
        expect(results[:documents][:count]).to eq(0)
      end
    end

    context 'with pagination' do
      let(:params) { { query: 'insurance', scope: 'all', page: 1, per_page: 2 } }

      it 'paginates results correctly' do
        results = service.search
        
        expect(results).to have_key(:pagination)
        expect(results[:pagination]).to include(:current_page, :per_page, :total_pages)
      end

      it 'limits results per page' do
        results = service.search
        
        total_results = results[:clients][:results].size + 
                       results[:applications][:results].size + 
                       results[:quotes][:results].size + 
                       results[:documents][:results].size
        
        expect(total_results).to be <= 2
      end
    end
  end

  describe '#suggestions' do
    let(:service) { GlobalSearchService.new(user, { query: 'joh' }) }

    it 'returns search suggestions' do
      suggestions = service.suggestions
      
      expect(suggestions).to be_an(Array)
      expect(suggestions.first).to have_key(:type)
      expect(suggestions.first).to have_key(:value)
      expect(suggestions.first).to have_key(:label)
      expect(suggestions.first).to have_key(:category)
    end

    it 'includes different types of suggestions' do
      suggestions = service.suggestions
      
      suggestion_types = suggestions.map { |s| s[:type] }.uniq
      expect(suggestion_types).to include('client')
    end

    it 'limits number of suggestions' do
      suggestions = service.suggestions
      
      expect(suggestions.size).to be <= 10
    end
  end

  describe '#filters' do
    let(:service) { GlobalSearchService.new(user, { query: 'insurance' }) }

    it 'returns available filters for each scope' do
      filters = service.filters
      
      expect(filters).to have_key(:clients)
      expect(filters).to have_key(:applications)
      expect(filters).to have_key(:quotes)
      expect(filters).to have_key(:documents)
    end

    it 'includes filter counts' do
      filters = service.filters
      
      expect(filters[:applications]).to have_key(:statuses)
      expect(filters[:applications][:statuses]).to be_an(Array)
      
      if filters[:applications][:statuses].any?
        filter = filters[:applications][:statuses].first
        expect(filter).to have_key(:value)
        expect(filter).to have_key(:label)
        expect(filter).to have_key(:count)
      end
    end
  end

  describe '#recent_searches' do
    let(:service) { GlobalSearchService.new(user, {}) }

    before do
      # Simulate some search history
      create(:search_history, user: user, query: 'john doe', results_count: 5, created_at: 1.hour.ago)
      create(:search_history, user: user, query: 'motor insurance', results_count: 12, created_at: 2.hours.ago)
      create(:search_history, user: user, query: 'fire policy', results_count: 3, created_at: 1.day.ago)
    end

    it 'returns recent search queries for the user' do
      recent = service.recent_searches
      
      expect(recent).to be_an(Array)
      expect(recent.size).to be <= 5
      expect(recent.first).to have_key(:query)
      expect(recent.first).to have_key(:results_count)
      expect(recent.first).to have_key(:searched_at)
    end

    it 'orders by most recent first' do
      recent = service.recent_searches
      
      expect(recent.first[:query]).to eq('john doe')
    end
  end

  describe '#save_search' do
    let(:service) { GlobalSearchService.new(user, { query: 'test search' }) }

    it 'saves the search to history' do
      expect {
        service.save_search(15)
      }.to change(SearchHistory, :count).by(1)
      
      history = SearchHistory.last
      expect(history.user).to eq(user)
      expect(history.query).to eq('test search')
      expect(history.results_count).to eq(15)
    end

    it 'does not save empty queries' do
      service = GlobalSearchService.new(user, { query: '' })
      
      expect {
        service.save_search(0)
      }.not_to change(SearchHistory, :count)
    end
  end

  describe 'performance' do
    let(:service) { GlobalSearchService.new(user, { query: 'test', scope: 'all' }) }

    before do
      # Create more test data for performance testing
      create_list(:client, 50, organization: organization)
      create_list(:insurance_application, 30, organization: organization)
      create_list(:quote, 25, organization: organization)
      create_list(:document, 40, organization: organization, user: user)
    end

    it 'completes search within reasonable time' do
      start_time = Time.current
      results = service.search
      end_time = Time.current
      
      search_duration = end_time - start_time
      expect(search_duration).to be < 2.0 # Should complete within 2 seconds
      expect(results[:search_time]).to be < 2.0
    end

    it 'uses database indexes efficiently' do
      # This test ensures we're using proper indexes
      expect {
        service.search
      }.not_to exceed_query_limit(10) # Should not require too many queries
    end
  end

  describe 'error handling' do
    let(:service) { GlobalSearchService.new(user, { query: 'test' }) }

    it 'handles invalid scope gracefully' do
      service = GlobalSearchService.new(user, { query: 'test', scope: 'invalid_scope' })
      
      expect { service.search }.not_to raise_error
      results = service.search
      expect(results[:total_count]).to eq(0)
    end

    it 'handles SQL injection attempts' do
      malicious_query = "'; DROP TABLE users; --"
      service = GlobalSearchService.new(user, { query: malicious_query })
      
      expect { service.search }.not_to raise_error
    end

    it 'handles very long search queries' do
      long_query = 'a' * 1000
      service = GlobalSearchService.new(user, { query: long_query })
      
      expect { service.search }.not_to raise_error
    end
  end

  describe 'access control' do
    let(:restricted_document) { create(:document, organization: organization, user: user, access_level: 'private') }
    let(:other_user) { create(:user, organization: organization) }
    let(:service) { GlobalSearchService.new(other_user, { query: restricted_document.name }) }

    it 'respects document access permissions' do
      results = service.search
      
      # Other user should not see private documents they don't own
      expect(results[:documents][:results]).not_to include(restricted_document)
    end

    it 'allows users to see their own private documents' do
      owner_service = GlobalSearchService.new(user, { query: restricted_document.name })
      results = owner_service.search
      
      expect(results[:documents][:results]).to include(restricted_document)
    end
  end

  describe 'search analytics' do
    let(:service) { GlobalSearchService.new(user, { query: 'analytics test' }) }

    it 'tracks search metrics' do
      expect(SearchAnalyticsService).to receive(:track_search).with(
        user: user,
        query: 'analytics test',
        scope: anything,
        results_count: anything,
        search_time: anything
      )
      
      service.search
    end
  end
end