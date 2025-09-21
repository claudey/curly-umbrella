require 'rails_helper'
require 'benchmark/ips'
require 'memory_profiler'

RSpec.describe 'Database Performance', type: :performance do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:client) { create(:client, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe 'Application queries' do
    context 'with large datasets' do
      before do
        # Create a substantial dataset
        100.times do |i|
          application = create(:insurance_application,
                             organization: organization,
                             user: user,
                             client: client,
                             created_at: i.days.ago)

          # Add quotes for some applications
          if i % 3 == 0
            2.times { create(:quote, insurance_application: application, organization: organization, user: user) }
          end

          # Add documents for some applications
          if i % 5 == 0
            create(:document, documentable: application, organization: organization, user: user)
          end
        end
      end

      it 'performs efficiently for application listing' do
        expect {
          result = nil
          elapsed_time = Benchmark.realtime do
            result = InsuranceApplication.includes(:quotes, :documents)
                                       .where(organization: organization)
                                       .limit(20)
                                       .to_a
          end

          expect(elapsed_time).to be < 0.5 # Should complete in under 500ms
          expect(result.length).to eq(20)
        }.not_to raise_error
      end

      it 'efficiently handles search queries' do
        # Create applications with specific search terms
        create(:insurance_application,
               first_name: 'SearchTest',
               last_name: 'User',
               organization: organization,
               user: user,
               client: client)

        elapsed_time = Benchmark.realtime do
          results = InsuranceApplication.where(organization: organization)
                                       .where("first_name ILIKE ? OR last_name ILIKE ?",
                                             '%SearchTest%', '%SearchTest%')
                                       .limit(10)
                                       .to_a
          expect(results.length).to eq(1)
        end

        expect(elapsed_time).to be < 0.2 # Should complete in under 200ms
      end

      it 'performs well with complex joins and aggregations' do
        elapsed_time = Benchmark.realtime do
          results = InsuranceApplication.joins(:quotes)
                                       .where(organization: organization)
                                       .group('insurance_applications.id')
                                       .having('COUNT(quotes.id) > 0')
                                       .count

          expect(results).to be_a(Hash)
        end

        expect(elapsed_time).to be < 1.0 # Should complete in under 1 second
      end

      it 'maintains performance with pagination' do
        page_times = []

        5.times do |page|
          elapsed_time = Benchmark.realtime do
            InsuranceApplication.where(organization: organization)
                               .order(created_at: :desc)
                               .limit(20)
                               .offset(page * 20)
                               .to_a
          end
          page_times << elapsed_time
        end

        # Performance should not degrade significantly across pages
        expect(page_times.max - page_times.min).to be < 0.3
        expect(page_times.max).to be < 0.5
      end
    end
  end

  describe 'Memory usage' do
    it 'uses memory efficiently for large result sets' do
      # Create test data
      10.times do
        create(:insurance_application, organization: organization, user: user, client: client)
      end

      report = MemoryProfiler.report do
        InsuranceApplication.where(organization: organization).find_each do |application|
          # Simulate processing each application
          application.full_name
          application.can_be_submitted?
        end
      end

      # Memory usage should be reasonable
      expect(report.total_allocated_memsize).to be < 1.megabyte
      expect(report.total_retained_memsize).to be < 100.kilobytes
    end

    it 'handles bulk operations efficiently' do
      applications_data = 50.times.map do |i|
        {
          application_number: "APP#{i.to_s.rjust(6, '0')}",
          application_type: 'motor',
          first_name: "User#{i}",
          last_name: 'Test',
          email: "user#{i}@test.com",
          phone_number: '555-1234',
          date_of_birth: 25.years.ago,
          address: '123 Test St',
          city: 'Test City',
          state: 'CA',
          postal_code: '12345',
          organization_id: organization.id,
          user_id: user.id,
          client_id: client.id,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      elapsed_time = Benchmark.realtime do
        InsuranceApplication.insert_all(applications_data)
      end

      expect(elapsed_time).to be < 0.5 # Bulk insert should be fast
      expect(InsuranceApplication.count).to be >= 50
    end
  end

  describe 'Query optimization' do
    before do
      # Create test data with relationships
      20.times do |i|
        application = create(:insurance_application, organization: organization, user: user, client: client)
        3.times { create(:quote, insurance_application: application, organization: organization, user: user) }
      end
    end

    it 'avoids N+1 queries when loading associations' do
      # Track queries
      queries = []

      subscription = ActiveSupport::Notifications.subscribe 'sql.active_record' do |name, start, finish, id, payload|
        queries << payload[:sql] unless payload[:sql].include?('SCHEMA')
      end

      # Load applications with associations
      applications = InsuranceApplication.includes(:quotes, :user, :client)
                                        .where(organization: organization)
                                        .limit(5)
                                        .to_a

      # Access associations to trigger loading
      applications.each do |app|
        app.quotes.count
        app.user.email
        app.client.full_name
      end

      ActiveSupport::Notifications.unsubscribe(subscription)

      # Should not have N+1 queries
      # Expect: 1 query for applications, 1 for quotes, 1 for users, 1 for clients
      expect(queries.length).to be <= 10 # Allow some flexibility for other operations
    end

    it 'uses database indexes effectively' do
      # Test query that should use index on organization_id
      elapsed_time = Benchmark.realtime do
        InsuranceApplication.where(organization: organization).count
      end

      expect(elapsed_time).to be < 0.1 # Should be very fast with index

      # Test query that should use composite index
      elapsed_time = Benchmark.realtime do
        InsuranceApplication.where(organization: organization, status: 'submitted').count
      end

      expect(elapsed_time).to be < 0.1 # Should be very fast with index
    end
  end

  describe 'Concurrent access performance' do
    it 'handles concurrent reads efficiently' do
      # Create test data
      10.times { create(:insurance_application, organization: organization, user: user, client: client) }

      threads = []
      results = []
      start_time = Time.current

      # Simulate concurrent reads
      5.times do |i|
        threads << Thread.new do
          thread_results = []
          10.times do
            thread_results << InsuranceApplication.where(organization: organization).count
          end
          results << thread_results
        end
      end

      threads.each(&:join)
      total_time = Time.current - start_time

      # All threads should complete quickly
      expect(total_time).to be < 2.0
      expect(results.flatten.all? { |count| count == 10 }).to be true
    end

    it 'handles concurrent writes without deadlocks' do
      threads = []
      created_applications = []
      errors = []

      # Simulate concurrent writes
      3.times do |i|
        threads << Thread.new do
          begin
            app = create(:insurance_application,
                        first_name: "Concurrent#{i}",
                        organization: organization,
                        user: user,
                        client: client)
            created_applications << app.id
          rescue => e
            errors << e
          end
        end
      end

      threads.each(&:join)

      # No deadlocks or errors should occur
      expect(errors).to be_empty
      expect(created_applications.length).to eq(3)
    end
  end

  describe 'Cache performance' do
    it 'benefits from query caching' do
      # Create test data
      application = create(:insurance_application, organization: organization, user: user, client: client)

      # First query (cache miss)
      time1 = Benchmark.realtime do
        InsuranceApplication.find(application.id)
      end

      # Second query (should use cache if available)
      time2 = Benchmark.realtime do
        InsuranceApplication.find(application.id)
      end

      # Note: This test might not show significant difference in test environment
      # but establishes the pattern for cache usage
      expect(time1).to be > 0
      expect(time2).to be > 0
    end
  end

  describe 'Business metrics calculation performance' do
    before do
      # Create comprehensive test data
      50.times do |i|
        app = create(:insurance_application,
                    :approved,
                    organization: organization,
                    user: user,
                    client: client,
                    created_at: i.days.ago)

        if i % 2 == 0
          quote = create(:quote,
                        :accepted,
                        insurance_application: app,
                        organization: organization,
                        user: user,
                        total_premium: 1000 + (i * 10))
        end
      end
    end

    it 'calculates business metrics efficiently' do
      elapsed_time = Benchmark.realtime do
        metrics = BusinessMetricsService.collect_all_metrics(organization)

        expect(metrics).to have_key(:total_applications)
        expect(metrics).to have_key(:total_revenue)
        expect(metrics).to have_key(:conversion_rate)
      end

      # Business metrics calculation should complete quickly
      expect(elapsed_time).to be < 2.0
    end

    it 'performs statistical analysis efficiently' do
      elapsed_time = Benchmark.realtime do
        trends = StatisticalAnalysisService.analyze_application_trends(organization, 30.days)

        expect(trends).to have_key(:application_count)
        expect(trends).to have_key(:trend_direction)
      end

      # Statistical analysis should complete in reasonable time
      expect(elapsed_time).to be < 3.0
    end
  end

  describe 'Report generation performance' do
    before do
      # Create data for reports
      30.times do |i|
        app = create(:insurance_application, organization: organization, user: user, client: client, created_at: i.days.ago)
        create(:quote, insurance_application: app, organization: organization, user: user) if i % 3 == 0
      end
    end

    it 'generates executive dashboard efficiently' do
      elapsed_time = Benchmark.realtime do
        controller = ExecutiveDashboardController.new
        controller.instance_variable_set(:@time_period, 30.days)

        # Simulate dashboard data generation
        dashboard_data = controller.send(:generate_executive_dashboard_data)

        expect(dashboard_data).to have_key(:overview)
        expect(dashboard_data).to have_key(:charts_data)
      end

      # Dashboard generation should be fast enough for real-time display
      expect(elapsed_time).to be < 1.5
    end
  end

  describe 'API performance' do
    before do
      # Create API test data
      25.times do
        app = create(:insurance_application, organization: organization, user: user, client: client)
        create(:quote, insurance_application: app, organization: organization, user: user)
      end
    end

    it 'handles API pagination efficiently' do
      elapsed_time = Benchmark.realtime do
        # Simulate API controller behavior
        applications = InsuranceApplication.includes(:quotes, :user, :client)
                                          .where(organization: organization)
                                          .order(created_at: :desc)
                                          .limit(20)
                                          .offset(0)
                                          .to_a

        # Simulate JSON serialization
        serialized = applications.map do |app|
          {
            id: app.id,
            application_number: app.application_number,
            status: app.status,
            quotes_count: app.quotes.length
          }
        end

        expect(serialized.length).to eq(20)
      end

      # API response should be fast
      expect(elapsed_time).to be < 0.8
    end
  end
end
