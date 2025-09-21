require 'rails_helper'

RSpec.describe BusinessMetricsService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:client) { create(:client, organization: organization) }
  let(:insurance_company) { create(:insurance_company, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe '.collect_all_metrics' do
    before do
      # Create test data
      create_list(:insurance_application, 3, :submitted, organization: organization, user: user, client: client, created_at: 1.day.ago)
      create_list(:insurance_application, 2, :approved, organization: organization, user: user, client: client, created_at: 1.day.ago)

      # Create quotes
      application = create(:insurance_application, :approved, organization: organization, user: user, client: client)
      create_list(:quote, 2, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 1000, created_at: 1.day.ago)
    end

    it 'collects all business metrics for the organization' do
      metrics = BusinessMetricsService.collect_all_metrics(organization)

      expect(metrics).to be_a(Hash)
      expect(metrics.keys).to include(
        :total_applications,
        :pending_applications,
        :approved_applications,
        :total_quotes,
        :accepted_quotes,
        :total_revenue,
        :average_quote_value,
        :conversion_rate,
        :application_processing_time,
        :quote_response_time,
        :active_users,
        :customer_satisfaction,
        :revenue_growth,
        :market_share
      )
    end

    it 'calculates total applications correctly' do
      metrics = BusinessMetricsService.collect_all_metrics(organization)
      expect(metrics[:total_applications]).to eq(6) # 5 + 1 from before block
    end

    it 'calculates total revenue correctly' do
      metrics = BusinessMetricsService.collect_all_metrics(organization)
      expect(metrics[:total_revenue]).to eq(2000.0) # 2 quotes * 1000 each
    end

    it 'calculates conversion rate correctly' do
      metrics = BusinessMetricsService.collect_all_metrics(organization)
      # 2 accepted quotes out of 6 applications = 33.33%
      expect(metrics[:conversion_rate]).to be_within(0.1).of(33.33)
    end
  end

  describe '.calculate_total_applications' do
    before do
      create_list(:insurance_application, 5, organization: organization, user: user, client: client, created_at: 2.days.ago)
      create_list(:insurance_application, 3, organization: organization, user: user, client: client, created_at: 1.day.ago)
    end

    it 'returns total applications count' do
      result = BusinessMetricsService.calculate_total_applications(organization)
      expect(result).to eq(8)
    end

    it 'filters by time period when provided' do
      result = BusinessMetricsService.calculate_total_applications(organization, 1.day.ago)
      expect(result).to eq(3)
    end
  end

  describe '.calculate_pending_applications' do
    before do
      create_list(:insurance_application, 3, status: 'submitted', organization: organization, user: user, client: client)
      create_list(:insurance_application, 2, status: 'under_review', organization: organization, user: user, client: client)
      create_list(:insurance_application, 2, status: 'approved', organization: organization, user: user, client: client)
    end

    it 'returns count of pending applications' do
      result = BusinessMetricsService.calculate_pending_applications(organization)
      expect(result).to eq(5) # submitted + under_review
    end
  end

  describe '.calculate_approved_applications' do
    before do
      create_list(:insurance_application, 3, status: 'approved', organization: organization, user: user, client: client)
      create_list(:insurance_application, 2, status: 'rejected', organization: organization, user: user, client: client)
    end

    it 'returns count of approved applications' do
      result = BusinessMetricsService.calculate_approved_applications(organization)
      expect(result).to eq(3)
    end
  end

  describe '.calculate_total_quotes' do
    before do
      application = create(:insurance_application, organization: organization, user: user, client: client)
      create_list(:quote, 4, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, created_at: 2.days.ago)
      create_list(:quote, 2, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, created_at: 1.day.ago)
    end

    it 'returns total quotes count' do
      result = BusinessMetricsService.calculate_total_quotes(organization)
      expect(result).to eq(6)
    end

    it 'filters by time period when provided' do
      result = BusinessMetricsService.calculate_total_quotes(organization, 1.day.ago)
      expect(result).to eq(2)
    end
  end

  describe '.calculate_accepted_quotes' do
    before do
      application = create(:insurance_application, organization: organization, user: user, client: client)
      create_list(:quote, 3, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user)
      create_list(:quote, 2, :rejected, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user)
    end

    it 'returns count of accepted quotes' do
      result = BusinessMetricsService.calculate_accepted_quotes(organization)
      expect(result).to eq(3)
    end
  end

  describe '.calculate_total_revenue' do
    before do
      application = create(:insurance_application, organization: organization, user: user, client: client)
      create(:quote, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 1500, created_at: 2.days.ago)
      create(:quote, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 2000, created_at: 1.day.ago)
      create(:quote, :rejected, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 1000)
    end

    it 'returns total revenue from accepted quotes' do
      result = BusinessMetricsService.calculate_total_revenue(organization)
      expect(result).to eq(3500.0)
    end

    it 'filters by time period when provided' do
      result = BusinessMetricsService.calculate_total_revenue(organization, 1.day.ago)
      expect(result).to eq(2000.0)
    end
  end

  describe '.calculate_average_quote_value' do
    before do
      application = create(:insurance_application, organization: organization, user: user, client: client)
      create(:quote, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 1000)
      create(:quote, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 2000)
      create(:quote, :rejected, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 1500)
    end

    it 'returns average value of accepted quotes' do
      result = BusinessMetricsService.calculate_average_quote_value(organization)
      expect(result).to eq(1500.0)
    end
  end

  describe '.calculate_conversion_rate' do
    before do
      # Create applications
      create_list(:insurance_application, 10, organization: organization, user: user, client: client)

      # Create accepted quotes for 3 applications
      3.times do
        application = create(:insurance_application, organization: organization, user: user, client: client)
        create(:quote, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user)
      end
    end

    it 'calculates conversion rate as percentage' do
      result = BusinessMetricsService.calculate_conversion_rate(organization)
      expect(result).to be_within(0.1).of(23.08) # 3 out of 13 applications
    end

    it 'returns 0 when no applications exist' do
      InsuranceApplication.delete_all
      result = BusinessMetricsService.calculate_conversion_rate(organization)
      expect(result).to eq(0.0)
    end
  end

  describe '.calculate_application_processing_time' do
    before do
      # Create applications with processing times
      app1 = create(:insurance_application, :approved, organization: organization, user: user, client: client, submitted_at: 5.days.ago, approved_at: 3.days.ago)
      app2 = create(:insurance_application, :approved, organization: organization, user: user, client: client, submitted_at: 4.days.ago, approved_at: 2.days.ago)
      app3 = create(:insurance_application, :rejected, organization: organization, user: user, client: client, submitted_at: 6.days.ago, rejected_at: 1.day.ago)
    end

    it 'calculates average processing time in hours' do
      result = BusinessMetricsService.calculate_application_processing_time(organization)
      # Should return average of processing times
      expect(result).to be > 0
      expect(result).to be_a(Float)
    end

    it 'returns 0 when no completed applications exist' do
      InsuranceApplication.update_all(status: 'submitted')
      result = BusinessMetricsService.calculate_application_processing_time(organization)
      expect(result).to eq(0.0)
    end
  end

  describe '.calculate_quote_response_time' do
    before do
      application = create(:insurance_application, organization: organization, user: user, client: client)
      # Create quotes with response times
      create(:quote, :approved, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, quoted_at: 3.days.ago, approved_at: 1.day.ago)
      create(:quote, :rejected, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, quoted_at: 2.days.ago, rejected_at: 1.day.ago)
    end

    it 'calculates average quote response time in hours' do
      result = BusinessMetricsService.calculate_quote_response_time(organization)
      expect(result).to be > 0
      expect(result).to be_a(Float)
    end
  end

  describe '.calculate_active_users' do
    before do
      # Create users with recent activity
      create_list(:user, 3, organization: organization, last_sign_in_at: 1.day.ago)
      create_list(:user, 2, organization: organization, last_sign_in_at: 10.days.ago)
    end

    it 'returns count of users active within timeframe' do
      result = BusinessMetricsService.calculate_active_users(organization, 7.days)
      expect(result).to eq(3)
    end

    it 'defaults to 30 days when no timeframe specified' do
      result = BusinessMetricsService.calculate_active_users(organization)
      expect(result).to eq(5) # All users within 30 days
    end
  end

  describe '.calculate_customer_satisfaction' do
    before do
      # Create applications with ratings
      create(:insurance_application, organization: organization, user: user, client: client, customer_rating: 5)
      create(:insurance_application, organization: organization, user: user, client: client, customer_rating: 4)
      create(:insurance_application, organization: organization, user: user, client: client, customer_rating: 3)
      create(:insurance_application, organization: organization, user: user, client: client, customer_rating: nil)
    end

    it 'calculates average customer satisfaction score' do
      result = BusinessMetricsService.calculate_customer_satisfaction(organization)
      expect(result).to eq(4.0) # (5 + 4 + 3) / 3
    end

    it 'returns 0 when no ratings exist' do
      InsuranceApplication.update_all(customer_rating: nil)
      result = BusinessMetricsService.calculate_customer_satisfaction(organization)
      expect(result).to eq(0.0)
    end
  end

  describe '.calculate_revenue_growth' do
    before do
      application = create(:insurance_application, organization: organization, user: user, client: client)
      # Current period revenue
      create(:quote, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 2000, accepted_at: 1.day.ago)
      # Previous period revenue
      create(:quote, :accepted, insurance_application: application, organization: organization, insurance_company: insurance_company, user: user, total_premium: 1000, accepted_at: 35.days.ago)
    end

    it 'calculates revenue growth percentage' do
      result = BusinessMetricsService.calculate_revenue_growth(organization)
      expect(result).to eq(100.0) # 100% growth from 1000 to 2000
    end

    it 'returns 0 when no previous period revenue' do
      Quote.where('accepted_at < ?', 30.days.ago).delete_all
      result = BusinessMetricsService.calculate_revenue_growth(organization)
      expect(result).to eq(0.0)
    end
  end

  describe '.calculate_market_share' do
    it 'returns market share percentage' do
      # This would require market data which might not be available in test
      result = BusinessMetricsService.calculate_market_share(organization)
      expect(result).to be_a(Float)
      expect(result).to be >= 0
    end
  end

  describe 'error handling' do
    it 'handles division by zero gracefully' do
      # Test with no data
      expect { BusinessMetricsService.calculate_conversion_rate(organization) }.not_to raise_error
      expect { BusinessMetricsService.calculate_average_quote_value(organization) }.not_to raise_error
      expect { BusinessMetricsService.calculate_revenue_growth(organization) }.not_to raise_error
    end

    it 'handles nil values gracefully' do
      # Create application without submitted_at
      create(:insurance_application, organization: organization, user: user, client: client, submitted_at: nil)

      expect { BusinessMetricsService.calculate_application_processing_time(organization) }.not_to raise_error
    end
  end

  describe 'time period filtering' do
    before do
      # Create data across different time periods
      create(:insurance_application, organization: organization, user: user, client: client, created_at: 45.days.ago)
      create(:insurance_application, organization: organization, user: user, client: client, created_at: 15.days.ago)
      create(:insurance_application, organization: organization, user: user, client: client, created_at: 5.days.ago)
    end

    it 'filters data correctly by time period' do
      result_all = BusinessMetricsService.calculate_total_applications(organization)
      result_30d = BusinessMetricsService.calculate_total_applications(organization, 30.days.ago)
      result_7d = BusinessMetricsService.calculate_total_applications(organization, 7.days.ago)

      expect(result_all).to eq(3)
      expect(result_30d).to eq(2)
      expect(result_7d).to eq(1)
    end
  end

  describe 'performance' do
    it 'executes efficiently with large datasets' do
      # Create larger dataset
      create_list(:insurance_application, 100, organization: organization, user: user, client: client)

      start_time = Time.current
      BusinessMetricsService.collect_all_metrics(organization)
      execution_time = Time.current - start_time

      # Should complete within reasonable time (adjust threshold as needed)
      expect(execution_time).to be < 2.seconds
    end
  end
end
