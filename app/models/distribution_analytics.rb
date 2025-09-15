class DistributionAnalytics < ApplicationRecord
  belongs_to :motor_application
  belongs_to :insurance_company, optional: true
  
  validates :event_type, presence: true
  validates :motor_application_id, presence: true
  
  enum event_type: {
    application_distributed: 'application_distributed',
    application_viewed: 'application_viewed',
    quote_submitted: 'quote_submitted',
    quote_approved: 'quote_approved',
    quote_rejected: 'quote_rejected',
    quote_accepted: 'quote_accepted',
    application_expired: 'application_expired',
    distribution_ignored: 'distribution_ignored'
  }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_application, ->(app) { where(motor_application: app) }
  scope :for_company, ->(company) { where(insurance_company: company) }
  scope :for_period, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :this_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :last_month, -> { where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month) }
  
  # Class methods for tracking events
  def self.track_distribution(application:, companies_count:, method: 'automatic')
    create!(
      motor_application: application,
      event_type: 'application_distributed',
      event_data: {
        companies_count: companies_count,
        distribution_method: method,
        coverage_type: application.coverage_type,
        vehicle_category: application.vehicle_category,
        sum_insured: application.sum_insured,
        driver_age: application.driver_age
      },
      occurred_at: Time.current
    )
  end
  
  def self.track_status_change(distribution:, previous_status:, new_status:)
    event_type = case new_status
                when 'viewed' then 'application_viewed'
                when 'quoted' then 'quote_submitted'
                when 'ignored' then 'distribution_ignored'
                when 'expired' then 'application_expired'
                else 'status_change'
                end
    
    create!(
      motor_application: distribution.motor_application,
      insurance_company: distribution.insurance_company,
      event_type: event_type,
      event_data: {
        distribution_id: distribution.id,
        previous_status: previous_status,
        new_status: new_status,
        match_score: distribution.match_score,
        time_to_change: (Time.current - distribution.created_at).to_i
      },
      occurred_at: Time.current
    )
  end
  
  def self.track_quote_event(quote:, event:)
    event_type = case event
                when :approved then 'quote_approved'
                when :rejected then 'quote_rejected'
                when :accepted then 'quote_accepted'
                else event.to_s
                end
    
    create!(
      motor_application: quote.motor_application,
      insurance_company: quote.insurance_company,
      event_type: event_type,
      event_data: {
        quote_id: quote.id,
        quote_number: quote.quote_number,
        premium_amount: quote.premium_amount,
        commission_amount: quote.commission_amount,
        time_to_event: quote.time_since_creation
      },
      occurred_at: Time.current
    )
  end
  
  # Distribution performance analytics
  def self.distribution_performance_report(period: :this_month)
    analytics = case period
               when :this_month then this_month
               when :last_month then last_month
               else for_period(1.month.ago, Time.current)
               end
    
    {
      total_applications_distributed: analytics.application_distributed.count,
      total_companies_reached: analytics.pluck(:insurance_company_id).compact.uniq.count,
      average_companies_per_application: analytics.application_distributed
                                                 .average("CAST(event_data->>'companies_count' AS INTEGER)") || 0,
      view_rate: calculate_conversion_rate(analytics, 'application_distributed', 'application_viewed'),
      quote_rate: calculate_conversion_rate(analytics, 'application_viewed', 'quote_submitted'),
      acceptance_rate: calculate_conversion_rate(analytics, 'quote_submitted', 'quote_accepted'),
      average_time_to_view: calculate_average_time(analytics, 'application_distributed', 'application_viewed'),
      average_time_to_quote: calculate_average_time(analytics, 'application_viewed', 'quote_submitted'),
      top_performing_companies: top_performing_companies_report(analytics),
      coverage_type_breakdown: coverage_type_performance(analytics),
      daily_distribution_trend: daily_distribution_trend(analytics)
    }
  end
  
  def self.company_performance_report(company, period: :this_month)
    analytics = case period
               when :this_month then for_company(company).this_month
               when :last_month then for_company(company).last_month
               else for_company(company).for_period(1.month.ago, Time.current)
               end
    
    {
      applications_received: analytics.application_distributed.count,
      applications_viewed: analytics.application_viewed.count,
      quotes_submitted: analytics.quote_submitted.count,
      quotes_accepted: analytics.quote_accepted.count,
      view_rate: calculate_conversion_rate(analytics, 'application_distributed', 'application_viewed'),
      quote_rate: calculate_conversion_rate(analytics, 'application_viewed', 'quote_submitted'),
      acceptance_rate: calculate_conversion_rate(analytics, 'quote_submitted', 'quote_accepted'),
      average_time_to_view: calculate_average_time(analytics, 'application_distributed', 'application_viewed'),
      average_time_to_quote: calculate_average_time(analytics, 'application_viewed', 'quote_submitted'),
      average_match_score: analytics.average("CAST(event_data->>'match_score' AS DECIMAL)") || 0,
      preferred_coverage_types: preferred_coverage_types(analytics),
      performance_trend: company_performance_trend(analytics)
    }
  end
  
  def self.application_journey_report(application)
    analytics = for_application(application).order(:created_at)
    
    journey = analytics.map do |event|
      {
        event_type: event.event_type,
        company: event.insurance_company&.name,
        occurred_at: event.occurred_at,
        time_since_distribution: event.time_since_distribution,
        event_data: event.event_data
      }
    end
    
    {
      application_number: application.application_number,
      total_companies_reached: analytics.where(event_type: 'application_distributed')
                                       .first&.event_data&.dig('companies_count') || 0,
      companies_viewed: analytics.application_viewed.count,
      quotes_received: analytics.quote_submitted.count,
      quotes_accepted: analytics.quote_accepted.count,
      journey: journey,
      performance_summary: {
        distribution_success: analytics.quote_submitted.any?,
        best_match_score: analytics.maximum("CAST(event_data->>'match_score' AS DECIMAL)") || 0,
        fastest_response: analytics.where.not(event_data: { time_to_change: nil })
                                 .minimum("CAST(event_data->>'time_to_change' AS INTEGER)") || 0
      }
    }
  end
  
  # Helper methods
  def time_since_distribution
    return nil unless occurred_at && motor_application.created_at
    
    (occurred_at - motor_application.created_at).to_i
  end
  
  def self.calculate_conversion_rate(analytics, from_event, to_event)
    from_count = analytics.where(event_type: from_event).count
    to_count = analytics.where(event_type: to_event).count
    
    return 0 if from_count == 0
    
    ((to_count.to_f / from_count) * 100).round(2)
  end
  
  def self.calculate_average_time(analytics, from_event, to_event)
    from_events = analytics.where(event_type: from_event)
    to_events = analytics.where(event_type: to_event)
    
    times = []
    
    from_events.each do |from_event|
      to_event = to_events.find do |te|
        te.motor_application_id == from_event.motor_application_id &&
        te.insurance_company_id == from_event.insurance_company_id &&
        te.occurred_at > from_event.occurred_at
      end
      
      if to_event
        times << (to_event.occurred_at - from_event.occurred_at).to_i
      end
    end
    
    return 0 if times.empty?
    
    times.sum / times.length
  end
  
  def self.top_performing_companies_report(analytics)
    analytics.joins(:insurance_company)
            .where(event_type: 'quote_accepted')
            .group('insurance_companies.name')
            .count
            .sort_by { |_, count| -count }
            .first(10)
            .to_h
  end
  
  def self.coverage_type_performance(analytics)
    analytics.application_distributed
            .group("event_data->>'coverage_type'")
            .count
  end
  
  def self.daily_distribution_trend(analytics)
    analytics.application_distributed
            .group_by_day(:occurred_at)
            .count
  end
  
  def self.preferred_coverage_types(analytics)
    analytics.application_distributed
            .group("event_data->>'coverage_type'")
            .count
            .sort_by { |_, count| -count }
            .to_h
  end
  
  def self.company_performance_trend(analytics)
    analytics.group_by_day(:occurred_at)
            .group(:event_type)
            .count
  end
end