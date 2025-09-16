# frozen_string_literal: true

class BusinessMetricsService
  include ActiveModel::Model
  
  # Core business KPIs for insurance brokerage
  BUSINESS_KPIS = {
    # Application Processing Metrics
    application_volume: {
      name: 'Application Volume',
      description: 'Number of insurance applications submitted',
      unit: 'count',
      category: 'applications'
    },
    application_approval_rate: {
      name: 'Application Approval Rate',
      description: 'Percentage of applications approved',
      unit: 'percentage',
      category: 'applications'
    },
    average_processing_time: {
      name: 'Average Processing Time',
      description: 'Average time to process applications',
      unit: 'hours',
      category: 'applications'
    },
    
    # Quote Management Metrics
    quote_conversion_rate: {
      name: 'Quote Conversion Rate',
      description: 'Percentage of quotes that are accepted',
      unit: 'percentage',
      category: 'quotes'
    },
    average_quote_value: {
      name: 'Average Quote Value',
      description: 'Average premium amount of quotes',
      unit: 'currency',
      category: 'quotes'
    },
    quote_response_time: {
      name: 'Quote Response Time',
      description: 'Average time to receive quotes from companies',
      unit: 'hours',
      category: 'quotes'
    },
    
    # User Engagement Metrics
    user_activity_rate: {
      name: 'User Activity Rate',
      description: 'Percentage of users active in the last 30 days',
      unit: 'percentage',
      category: 'users'
    },
    session_duration: {
      name: 'Average Session Duration',
      description: 'Average time users spend in the application',
      unit: 'minutes',
      category: 'users'
    },
    
    # Document Management Metrics
    document_processing_efficiency: {
      name: 'Document Processing Efficiency',
      description: 'Average time to process documents',
      unit: 'hours',
      category: 'documents'
    },
    document_compliance_rate: {
      name: 'Document Compliance Rate',
      description: 'Percentage of documents meeting compliance requirements',
      unit: 'percentage',
      category: 'documents'
    },
    
    # Business Performance Metrics
    revenue_per_application: {
      name: 'Revenue per Application',
      description: 'Average revenue generated per application',
      unit: 'currency',
      category: 'revenue'
    },
    customer_acquisition_cost: {
      name: 'Customer Acquisition Cost',
      description: 'Cost to acquire a new customer',
      unit: 'currency',
      category: 'revenue'
    },
    
    # System Performance Metrics
    system_uptime: {
      name: 'System Uptime',
      description: 'Percentage of time system is available',
      unit: 'percentage',
      category: 'performance'
    },
    error_rate: {
      name: 'Error Rate',
      description: 'Percentage of requests resulting in errors',
      unit: 'percentage',
      category: 'performance'
    }
  }.freeze
  
  def self.collect_all_metrics(organization = nil, period: 24.hours)
    new.collect_all_metrics(organization, period: period)
  end
  
  def self.collect_metric(metric_name, organization = nil, period: 24.hours)
    new.collect_metric(metric_name.to_sym, organization, period: period)
  end
  
  def self.store_metric_snapshot(organization = nil)
    new.store_metric_snapshot(organization)
  end
  
  def collect_all_metrics(organization = nil, period: 24.hours)
    metrics = {}
    
    BUSINESS_KPIS.each_key do |metric_name|
      begin
        metrics[metric_name] = collect_metric(metric_name, organization, period: period)
      rescue => e
        Rails.logger.error "Failed to collect metric #{metric_name}: #{e.message}"
        metrics[metric_name] = { error: e.message, value: nil }
      end
    end
    
    # Store metrics in cache for dashboard access
    cache_key = "business_metrics:#{organization&.id || 'global'}:#{period.to_i}"
    Rails.cache.write(cache_key, metrics, expires_in: 30.minutes)
    
    metrics
  end
  
  def collect_metric(metric_name, organization = nil, period: 24.hours)
    case metric_name
    when :application_volume
      calculate_application_volume(organization, period)
    when :application_approval_rate
      calculate_application_approval_rate(organization, period)
    when :average_processing_time
      calculate_average_processing_time(organization, period)
    when :quote_conversion_rate
      calculate_quote_conversion_rate(organization, period)
    when :average_quote_value
      calculate_average_quote_value(organization, period)
    when :quote_response_time
      calculate_quote_response_time(organization, period)
    when :user_activity_rate
      calculate_user_activity_rate(organization, period)
    when :session_duration
      calculate_session_duration(organization, period)
    when :document_processing_efficiency
      calculate_document_processing_efficiency(organization, period)
    when :document_compliance_rate
      calculate_document_compliance_rate(organization, period)
    when :revenue_per_application
      calculate_revenue_per_application(organization, period)
    when :customer_acquisition_cost
      calculate_customer_acquisition_cost(organization, period)
    when :system_uptime
      calculate_system_uptime(period)
    when :error_rate
      calculate_error_rate(period)
    else
      { error: "Unknown metric: #{metric_name}", value: nil }
    end
  end
  
  def store_metric_snapshot(organization = nil)
    timestamp = Time.current
    metrics = collect_all_metrics(organization, period: 24.hours)
    
    # Store snapshot in database for historical analysis
    snapshot = BusinessMetricSnapshot.create!(
      organization: organization,
      snapshot_timestamp: timestamp,
      metrics_data: metrics,
      period_hours: 24
    )
    
    # Store individual metric records for easier querying
    metrics.each do |metric_name, metric_data|
      next if metric_data[:error]
      
      BusinessMetric.create!(
        organization: organization,
        metric_name: metric_name.to_s,
        metric_value: metric_data[:value],
        metric_unit: BUSINESS_KPIS.dig(metric_name, :unit),
        metric_category: BUSINESS_KPIS.dig(metric_name, :category),
        recorded_at: timestamp,
        period_hours: 24,
        metadata: metric_data.except(:value)
      )
    end
    
    snapshot
  end
  
  private
  
  # Application Metrics
  def calculate_application_volume(organization, period)
    scope = organization ? organization.insurance_applications : InsuranceApplication.all
    applications = scope.where('created_at > ?', period.ago)
    
    {
      value: applications.count,
      trend: calculate_trend(applications, period),
      breakdown: applications.group(:insurance_type).count,
      metadata: {
        period_start: period.ago,
        period_end: Time.current
      }
    }
  end
  
  def calculate_application_approval_rate(organization, period)
    scope = organization ? organization.insurance_applications : InsuranceApplication.all
    applications = scope.where('created_at > ?', period.ago)
    
    total = applications.count
    return { value: 0, error: 'No applications in period' } if total.zero?
    
    approved = applications.where(status: 'approved').count
    rate = (approved.to_f / total * 100).round(2)
    
    {
      value: rate,
      trend: calculate_approval_rate_trend(scope, period),
      metadata: {
        total_applications: total,
        approved_applications: approved,
        rejection_rate: ((total - approved).to_f / total * 100).round(2)
      }
    }
  end
  
  def calculate_average_processing_time(organization, period)
    scope = organization ? organization.insurance_applications : InsuranceApplication.all
    applications = scope.where('created_at > ?', period.ago)
                       .where.not(status: 'pending')
                       .where.not(processed_at: nil)
    
    return { value: 0, error: 'No processed applications' } if applications.empty?
    
    processing_times = applications.map do |app|
      ((app.processed_at - app.created_at) / 1.hour).round(2)
    end
    
    {
      value: (processing_times.sum / processing_times.size).round(2),
      trend: calculate_processing_time_trend(scope, period),
      metadata: {
        fastest: processing_times.min,
        slowest: processing_times.max,
        median: processing_times.sort[processing_times.size / 2]
      }
    }
  end
  
  # Quote Metrics
  def calculate_quote_conversion_rate(organization, period)
    scope = organization ? organization.quotes : Quote.all
    quotes = scope.where('created_at > ?', period.ago)
    
    total = quotes.count
    return { value: 0, error: 'No quotes in period' } if total.zero?
    
    accepted = quotes.where(status: 'accepted').count
    rate = (accepted.to_f / total * 100).round(2)
    
    {
      value: rate,
      trend: calculate_conversion_rate_trend(scope, period),
      metadata: {
        total_quotes: total,
        accepted_quotes: accepted,
        pending_quotes: quotes.where(status: 'pending').count,
        rejected_quotes: quotes.where(status: 'rejected').count
      }
    }
  end
  
  def calculate_average_quote_value(organization, period)
    scope = organization ? organization.quotes : Quote.all
    quotes = scope.where('created_at > ?', period.ago)
                  .where.not(premium_amount: nil)
    
    return { value: 0, error: 'No quotes with premium amounts' } if quotes.empty?
    
    {
      value: quotes.average(:premium_amount).round(2),
      trend: calculate_quote_value_trend(scope, period),
      metadata: {
        highest_quote: quotes.maximum(:premium_amount),
        lowest_quote: quotes.minimum(:premium_amount),
        total_value: quotes.sum(:premium_amount)
      }
    }
  end
  
  def calculate_quote_response_time(organization, period)
    scope = organization ? organization.quotes : Quote.all
    quotes = scope.joins(:insurance_application)
                  .where('quotes.created_at > ?', period.ago)
    
    return { value: 0, error: 'No quotes in period' } if quotes.empty?
    
    response_times = quotes.map do |quote|
      app_created = quote.insurance_application.created_at
      quote_created = quote.created_at
      ((quote_created - app_created) / 1.hour).round(2)
    end
    
    {
      value: (response_times.sum / response_times.size).round(2),
      metadata: {
        fastest_response: response_times.min,
        slowest_response: response_times.max
      }
    }
  end
  
  # User Metrics
  def calculate_user_activity_rate(organization, period)
    scope = organization ? organization.users : User.all
    total_users = scope.where(active: true).count
    
    return { value: 0, error: 'No active users' } if total_users.zero?
    
    active_users = scope.where('last_sign_in_at > ?', period.ago).count
    rate = (active_users.to_f / total_users * 100).round(2)
    
    {
      value: rate,
      metadata: {
        total_users: total_users,
        active_users: active_users,
        inactive_users: total_users - active_users
      }
    }
  end
  
  def calculate_session_duration(organization, period)
    # This would require session tracking - placeholder implementation
    {
      value: 45.5,
      metadata: {
        note: 'Session tracking not yet implemented'
      }
    }
  end
  
  # Document Metrics
  def calculate_document_processing_efficiency(organization, period)
    scope = organization ? organization.documents : Document.all
    documents = scope.where('created_at > ?', period.ago)
    
    return { value: 0, error: 'No documents in period' } if documents.empty?
    
    processed_docs = documents.where.not(processed_at: nil)
    return { value: 0, error: 'No processed documents' } if processed_docs.empty?
    
    processing_times = processed_docs.map do |doc|
      ((doc.processed_at - doc.created_at) / 1.hour).round(2)
    end
    
    {
      value: (processing_times.sum / processing_times.size).round(2),
      metadata: {
        total_documents: documents.count,
        processed_documents: processed_docs.count,
        processing_rate: (processed_docs.count.to_f / documents.count * 100).round(2)
      }
    }
  end
  
  def calculate_document_compliance_rate(organization, period)
    scope = organization ? organization.documents : Document.all
    documents = scope.where('created_at > ?', period.ago)
    
    return { value: 0, error: 'No documents in period' } if documents.empty?
    
    compliant_docs = documents.where(compliance_status: 'compliant').count
    rate = (compliant_docs.to_f / documents.count * 100).round(2)
    
    {
      value: rate,
      metadata: {
        total_documents: documents.count,
        compliant_documents: compliant_docs,
        non_compliant_documents: documents.count - compliant_docs
      }
    }
  end
  
  # Revenue Metrics
  def calculate_revenue_per_application(organization, period)
    scope = organization ? organization.insurance_applications : InsuranceApplication.all
    applications = scope.where('created_at > ?', period.ago)
    
    return { value: 0, error: 'No applications in period' } if applications.empty?
    
    # This would need to be connected to actual revenue data
    # Placeholder calculation based on quote values
    total_revenue = applications.joins(:quotes)
                               .where(quotes: { status: 'accepted' })
                               .sum('quotes.premium_amount * 0.1') # Assuming 10% commission
    
    {
      value: (total_revenue / applications.count).round(2),
      metadata: {
        total_applications: applications.count,
        total_revenue: total_revenue,
        commission_rate: 0.1
      }
    }
  end
  
  def calculate_customer_acquisition_cost(organization, period)
    # This would need to be connected to marketing/sales cost data
    # Placeholder implementation
    {
      value: 150.00,
      metadata: {
        note: 'Customer acquisition cost tracking not yet implemented'
      }
    }
  end
  
  # System Performance Metrics
  def calculate_system_uptime(period)
    # This would integrate with monitoring systems
    # For now, calculate based on error reports
    total_minutes = (period.to_f / 1.minute).round
    error_minutes = ErrorReport.where('occurred_at > ?', period.ago)
                              .where(severity: ['critical', 'high'])
                              .count # Rough estimate
    
    uptime_percentage = [((total_minutes - error_minutes).to_f / total_minutes * 100), 0].max.round(3)
    
    {
      value: uptime_percentage,
      metadata: {
        total_minutes: total_minutes,
        estimated_downtime_minutes: error_minutes,
        calculation_method: 'estimated_based_on_errors'
      }
    }
  end
  
  def calculate_error_rate(period)
    total_requests = AuditLog.where('created_at > ?', period.ago).count
    return { value: 0, error: 'No requests in period' } if total_requests.zero?
    
    error_requests = ErrorReport.where('occurred_at > ?', period.ago).count
    error_rate = (error_requests.to_f / total_requests * 100).round(4)
    
    {
      value: error_rate,
      metadata: {
        total_requests: total_requests,
        error_requests: error_requests,
        error_distribution: ErrorReport.where('occurred_at > ?', period.ago)
                                      .group(:severity)
                                      .count
      }
    }
  end
  
  # Trend calculation helpers
  def calculate_trend(scope, period)
    current_period = scope.where('created_at > ?', period.ago).count
    previous_period = scope.where('created_at BETWEEN ? AND ?', (period * 2).ago, period.ago).count
    
    return 0 if previous_period.zero?
    
    ((current_period - previous_period).to_f / previous_period * 100).round(2)
  end
  
  def calculate_approval_rate_trend(scope, period)
    current_approved = scope.where('created_at > ?', period.ago).where(status: 'approved').count
    current_total = scope.where('created_at > ?', period.ago).count
    
    previous_approved = scope.where('created_at BETWEEN ? AND ?', (period * 2).ago, period.ago)
                            .where(status: 'approved').count
    previous_total = scope.where('created_at BETWEEN ? AND ?', (period * 2).ago, period.ago).count
    
    return 0 if previous_total.zero? || current_total.zero?
    
    current_rate = (current_approved.to_f / current_total * 100)
    previous_rate = (previous_approved.to_f / previous_total * 100)
    
    (current_rate - previous_rate).round(2)
  end
  
  def calculate_processing_time_trend(scope, period)
    # Simplified trend calculation for processing times
    0 # Placeholder
  end
  
  def calculate_conversion_rate_trend(scope, period)
    # Similar to approval rate trend but for quotes
    current_accepted = scope.where('created_at > ?', period.ago).where(status: 'accepted').count
    current_total = scope.where('created_at > ?', period.ago).count
    
    previous_accepted = scope.where('created_at BETWEEN ? AND ?', (period * 2).ago, period.ago)
                            .where(status: 'accepted').count
    previous_total = scope.where('created_at BETWEEN ? AND ?', (period * 2).ago, period.ago).count
    
    return 0 if previous_total.zero? || current_total.zero?
    
    current_rate = (current_accepted.to_f / current_total * 100)
    previous_rate = (previous_accepted.to_f / previous_total * 100)
    
    (current_rate - previous_rate).round(2)
  end
  
  def calculate_quote_value_trend(scope, period)
    current_avg = scope.where('created_at > ?', period.ago).average(:premium_amount) || 0
    previous_avg = scope.where('created_at BETWEEN ? AND ?', (period * 2).ago, period.ago)
                       .average(:premium_amount) || 0
    
    return 0 if previous_avg.zero?
    
    ((current_avg - previous_avg) / previous_avg * 100).round(2)
  end
end