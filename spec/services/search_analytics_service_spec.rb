require 'rails_helper'

RSpec.describe SearchAnalyticsService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe '.track_search' do
    let(:search_params) do
      {
        user: user,
        query: 'motor insurance',
        scope: 'all',
        results_count: 15,
        search_time: 0.25
      }
    end

    it 'creates a search history record' do
      expect {
        SearchAnalyticsService.track_search(search_params)
      }.to change(SearchHistory, :count).by(1)

      history = SearchHistory.last
      expect(history.user).to eq(user)
      expect(history.query).to eq('motor insurance')
      expect(history.results_count).to eq(15)
    end

    it 'stores search metadata' do
      SearchAnalyticsService.track_search(search_params.merge(
        filters: { status: 'active' },
        user_agent: 'Mozilla/5.0...'
      ))

      history = SearchHistory.last
      expect(history.metadata['scope']).to eq('all')
      expect(history.metadata['search_time']).to eq(0.25)
      expect(history.metadata['filters']).to eq({ 'status' => 'active' })
    end

    it 'does not track empty or invalid queries' do
      expect {
        SearchAnalyticsService.track_search(search_params.merge(query: ''))
      }.not_to change(SearchHistory, :count)

      expect {
        SearchAnalyticsService.track_search(search_params.merge(query: nil))
      }.not_to change(SearchHistory, :count)
    end

    it 'handles tracking errors gracefully' do
      allow(SearchHistory).to receive(:create!).and_raise(StandardError.new('Database error'))

      expect {
        SearchAnalyticsService.track_search(search_params)
      }.not_to raise_error
    end
  end

  describe '.organization_search_stats' do
    let(:other_user) { create(:user, organization: organization) }
    let(:external_user) { create(:user) }

    before do
      create(:search_history, user: user, query: 'motor insurance', results_count: 10, created_at: 1.day.ago)
      create(:search_history, user: user, query: 'fire policy', results_count: 5, created_at: 2.days.ago)
      create(:search_history, user: other_user, query: 'motor insurance', results_count: 8, created_at: 12.hours.ago)
      create(:search_history, user: external_user, query: 'external search', results_count: 3, created_at: 1.day.ago)
    end

    it 'returns search statistics for organization users only' do
      stats = SearchAnalyticsService.organization_search_stats(organization, 7.days.ago, Time.current)

      expect(stats[:total_searches]).to eq(3) # Excludes external user
      expect(stats[:unique_users]).to eq(2)
      expect(stats[:average_results]).to be_within(0.1).of(7.67) # (10+5+8)/3
    end

    it 'includes popular queries for the organization' do
      stats = SearchAnalyticsService.organization_search_stats(organization, 7.days.ago, Time.current)

      expect(stats[:popular_queries]).to be_an(Array)
      expect(stats[:popular_queries].first[:query]).to eq('motor insurance')
      expect(stats[:popular_queries].first[:count]).to eq(2)
    end

    it 'calculates search trends' do
      stats = SearchAnalyticsService.organization_search_stats(organization, 7.days.ago, Time.current)

      expect(stats).to have_key(:daily_breakdown)
      expect(stats[:daily_breakdown]).to be_an(Array)
    end
  end

  describe '.search_performance_metrics' do
    before do
      create(:search_history, user: user, query: 'fast query', results_count: 10,
             metadata: { search_time: 0.1 }, created_at: 1.hour.ago)
      create(:search_history, user: user, query: 'slow query', results_count: 5,
             metadata: { search_time: 2.5 }, created_at: 2.hours.ago)
      create(:search_history, user: user, query: 'medium query', results_count: 8,
             metadata: { search_time: 0.8 }, created_at: 3.hours.ago)
    end

    it 'calculates search performance statistics' do
      metrics = SearchAnalyticsService.search_performance_metrics(1.day.ago, Time.current)

      expect(metrics).to have_key(:average_search_time)
      expect(metrics).to have_key(:median_search_time)
      expect(metrics).to have_key(:percentile_95_time)
      expect(metrics).to have_key(:slow_searches_count)

      expect(metrics[:average_search_time]).to be_within(0.1).of(1.13) # (0.1+2.5+0.8)/3
      expect(metrics[:slow_searches_count]).to eq(1) # Queries > 2 seconds
    end

    it 'identifies slowest search patterns' do
      metrics = SearchAnalyticsService.search_performance_metrics(1.day.ago, Time.current)

      expect(metrics).to have_key(:slowest_queries)
      expect(metrics[:slowest_queries]).to be_an(Array)
      expect(metrics[:slowest_queries].first[:query]).to eq('slow query')
      expect(metrics[:slowest_queries].first[:avg_time]).to eq(2.5)
    end
  end

  describe '.search_success_analysis' do
    before do
      create(:search_history, user: user, query: 'successful query', results_count: 10)
      create(:search_history, user: user, query: 'partially successful', results_count: 1)
      create(:search_history, user: user, query: 'failed query', results_count: 0)
      create(:search_history, user: user, query: 'failed query', results_count: 0)
    end

    it 'calculates search success rates' do
      analysis = SearchAnalyticsService.search_success_analysis(1.day.ago, Time.current)

      expect(analysis[:total_searches]).to eq(4)
      expect(analysis[:successful_searches]).to eq(2) # results_count > 0
      expect(analysis[:success_rate]).to eq(50.0)
      expect(analysis[:zero_result_queries]).to be_an(Array)
    end

    it 'identifies queries with zero results' do
      analysis = SearchAnalyticsService.search_success_analysis(1.day.ago, Time.current)

      zero_result = analysis[:zero_result_queries].first
      expect(zero_result[:query]).to eq('failed query')
      expect(zero_result[:count]).to eq(2)
    end

    it 'suggests query improvements' do
      analysis = SearchAnalyticsService.search_success_analysis(1.day.ago, Time.current)

      expect(analysis).to have_key(:improvement_suggestions)
      expect(analysis[:improvement_suggestions]).to be_an(Array)
    end
  end

  describe '.user_search_behavior' do
    before do
      # Create diverse search patterns
      create(:search_history, user: user, query: 'motor', created_at: 9.hours.ago)
      create(:search_history, user: user, query: 'fire', created_at: 8.hours.ago)
      create(:search_history, user: user, query: 'motor insurance', created_at: 7.hours.ago)
      create(:search_history, user: user, query: 'life policy', created_at: 6.hours.ago)
    end

    it 'analyzes user search patterns' do
      behavior = SearchAnalyticsService.user_search_behavior(user, 1.day.ago, Time.current)

      expect(behavior).to have_key(:total_searches)
      expect(behavior).to have_key(:unique_queries)
      expect(behavior).to have_key(:search_frequency)
      expect(behavior).to have_key(:preferred_search_times)
      expect(behavior).to have_key(:query_refinement_patterns)

      expect(behavior[:total_searches]).to eq(4)
      expect(behavior[:unique_queries]).to eq(4)
    end

    it 'identifies search refinement patterns' do
      behavior = SearchAnalyticsService.user_search_behavior(user, 1.day.ago, Time.current)

      refinements = behavior[:query_refinement_patterns]
      expect(refinements).to be_an(Array)

      # Should detect that "motor insurance" is a refinement of "motor"
      motor_refinement = refinements.find { |r| r[:original] == 'motor' && r[:refined] == 'motor insurance' }
      expect(motor_refinement).to be_present
    end

    it 'calculates search session patterns' do
      behavior = SearchAnalyticsService.user_search_behavior(user, 1.day.ago, Time.current)

      expect(behavior).to have_key(:average_session_length)
      expect(behavior).to have_key(:searches_per_session)
    end
  end

  describe '.export_analytics' do
    before do
      create_list(:search_history, 5, user: user, created_at: 1.day.ago)
    end

    it 'exports search analytics to CSV format' do
      csv_data = SearchAnalyticsService.export_analytics(organization, 7.days.ago, Time.current, 'csv')

      expect(csv_data).to be_a(String)
      expect(csv_data).to include('Query,User,Results Count,Search Time,Created At')
    end

    it 'exports search analytics to JSON format' do
      json_data = SearchAnalyticsService.export_analytics(organization, 7.days.ago, Time.current, 'json')
      parsed_data = JSON.parse(json_data)

      expect(parsed_data).to have_key('searches')
      expect(parsed_data).to have_key('summary')
      expect(parsed_data['searches']).to be_an(Array)
    end

    it 'handles invalid export formats gracefully' do
      result = SearchAnalyticsService.export_analytics(organization, 7.days.ago, Time.current, 'invalid')

      expect(result).to be_nil
    end
  end

  describe '.real_time_search_metrics' do
    before do
      # Create recent searches
      create(:search_history, user: user, created_at: 5.minutes.ago, results_count: 10)
      create(:search_history, user: user, created_at: 3.minutes.ago, results_count: 5)
      create(:search_history, user: user, created_at: 1.minute.ago, results_count: 0)
    end

    it 'returns real-time search metrics' do
      metrics = SearchAnalyticsService.real_time_search_metrics(organization)

      expect(metrics).to have_key(:searches_last_hour)
      expect(metrics).to have_key(:searches_last_5_minutes)
      expect(metrics).to have_key(:active_users)
      expect(metrics).to have_key(:success_rate_last_hour)

      expect(metrics[:searches_last_5_minutes]).to eq(2)
    end

    it 'includes trending queries' do
      metrics = SearchAnalyticsService.real_time_search_metrics(organization)

      expect(metrics).to have_key(:trending_queries)
      expect(metrics[:trending_queries]).to be_an(Array)
    end
  end

  describe 'error handling and edge cases' do
    it 'handles nil parameters gracefully' do
      expect {
        SearchAnalyticsService.track_search(nil)
      }.not_to raise_error

      expect {
        SearchAnalyticsService.organization_search_stats(nil, 1.day.ago, Time.current)
      }.not_to raise_error
    end

    it 'handles date range edge cases' do
      # Future dates
      stats = SearchAnalyticsService.organization_search_stats(organization, 1.day.from_now, 2.days.from_now)
      expect(stats[:total_searches]).to eq(0)

      # Inverted date range
      stats = SearchAnalyticsService.organization_search_stats(organization, Time.current, 1.day.ago)
      expect(stats[:total_searches]).to eq(0)
    end

    it 'handles large datasets efficiently' do
      # Create a large number of search records
      create_list(:search_history, 1000, user: user, created_at: 1.day.ago)

      start_time = Time.current
      SearchAnalyticsService.organization_search_stats(organization, 7.days.ago, Time.current)
      end_time = Time.current

      expect(end_time - start_time).to be < 5.0 # Should complete within 5 seconds
    end
  end

  describe 'privacy and compliance' do
    it 'anonymizes sensitive data in exports' do
      create(:search_history, user: user, query: 'sensitive client data')

      json_data = SearchAnalyticsService.export_analytics(organization, 7.days.ago, Time.current, 'json')
      parsed_data = JSON.parse(json_data)

      # Should not include user email or other PII
      search = parsed_data['searches'].first
      expect(search).not_to have_key('user_email')
      expect(search['user_id']).to be_present
    end

    it 'respects data retention policies' do
      old_search = create(:search_history, user: user, created_at: 2.years.ago)

      # Analytics should exclude data beyond retention period
      stats = SearchAnalyticsService.organization_search_stats(organization, 1.year.ago, Time.current)
      expect(stats[:total_searches]).to eq(0)
    end
  end
end
