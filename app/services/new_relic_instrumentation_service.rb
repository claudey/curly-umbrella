# frozen_string_literal: true

class NewRelicInstrumentationService
  include NewRelic::Agent::MethodTracer
  
  class << self
    # Track business-specific custom events
    def track_business_event(event_name, attributes = {})
      return unless new_relic_enabled?
      
      # Add common business context
      enhanced_attributes = attributes.merge(
        timestamp: Time.current.to_i,
        environment: Rails.env,
        app_version: ENV['APP_VERSION'] || '1.0.0'
      )
      
      NewRelic::Agent.record_custom_event(event_name, enhanced_attributes)
    rescue => e
      Rails.logger.error "Failed to track New Relic business event #{event_name}: #{e.message}"
    end
    
    # Track application performance metrics
    def track_application_submitted(application)
      track_business_event('ApplicationSubmitted', {
        application_id: application.id,
        organization_id: application.organization_id,
        application_type: application.application_type,
        user_id: application.user_id,
        processing_time_estimate: calculate_processing_estimate(application)
      })
    end
    
    def track_application_approved(application, processing_time)
      track_business_event('ApplicationApproved', {
        application_id: application.id,
        organization_id: application.organization_id,
        application_type: application.application_type,
        processing_time_hours: processing_time,
        approval_efficiency: calculate_approval_efficiency(processing_time)
      })
    end
    
    def track_quote_generated(quote, generation_time)
      track_business_event('QuoteGenerated', {
        quote_id: quote.id,
        organization_id: quote.organization_id,
        quote_amount: quote.total_premium,
        generation_time_seconds: generation_time,
        coverage_types: quote.coverage_types&.join(','),
        risk_assessment_score: quote.risk_score
      })
    end
    
    def track_document_processed(document, processing_time)
      track_business_event('DocumentProcessed', {
        document_id: document.id,
        organization_id: document.organization_id,
        document_type: document.document_type,
        file_size_mb: (document.file_size / 1.megabyte).round(2),
        processing_time_seconds: processing_time,
        processing_status: document.processing_status
      })
    end
    
    def track_user_session_activity(user, session_duration, actions_count)
      track_business_event('UserSessionActivity', {
        user_id: user.id,
        organization_id: user.organization_id,
        user_role: user.primary_role,
        session_duration_minutes: (session_duration / 60).round(1),
        actions_performed: actions_count,
        engagement_level: calculate_engagement_level(session_duration, actions_count)
      })
    end
    
    def track_system_performance_alert(alert_type, severity, metrics)
      track_business_event('SystemPerformanceAlert', {
        alert_type: alert_type,
        severity: severity,
        affected_components: metrics[:components]&.join(','),
        response_time_ms: metrics[:response_time],
        error_rate_percent: metrics[:error_rate],
        cpu_usage_percent: metrics[:cpu_usage],
        memory_usage_percent: metrics[:memory_usage]
      })
    end
    
    # Track custom metrics for business KPIs
    def record_business_metric(metric_name, value, unit = 'count')
      return unless new_relic_enabled?
      
      metric_key = "Custom/Business/#{metric_name}"
      NewRelic::Agent.record_metric(metric_key, value)
      
      # Also record as custom attribute for easier querying
      NewRelic::Agent.add_custom_attributes({
        "business.#{metric_name}" => value,
        "business.#{metric_name}.unit" => unit,
        "business.#{metric_name}.recorded_at" => Time.current.iso8601
      })
    rescue => e
      Rails.logger.error "Failed to record New Relic business metric #{metric_name}: #{e.message}"
    end
    
    # Track application-wide performance metrics
    def record_application_metrics
      return unless new_relic_enabled?
      
      # Record active user counts
      record_business_metric('active_users_today', User.active.where('last_sign_in_at > ?', 24.hours.ago).count)
      record_business_metric('active_organizations', Organization.active.count)
      
      # Record application processing metrics
      record_business_metric('applications_pending', Application.where(status: 'pending').count)
      record_business_metric('applications_processed_today', Application.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count)
      
      # Record document processing metrics
      record_business_metric('documents_uploaded_today', Document.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count)
      record_business_metric('documents_pending_review', Document.where(status: 'pending_review').count)
      
      # Record quote metrics
      record_business_metric('quotes_generated_today', Quote.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count)
      record_business_metric('quotes_pending', Quote.where(status: 'pending').count)
      
      # Record system health metrics
      record_system_health_metrics
    rescue => e
      Rails.logger.error "Failed to record New Relic application metrics: #{e.message}"
    end
    
    # Add custom attributes to current transaction
    def add_transaction_attributes(attributes)
      return unless new_relic_enabled?
      
      NewRelic::Agent.add_custom_attributes(attributes)
    rescue => e
      Rails.logger.error "Failed to add New Relic transaction attributes: #{e.message}"
    end
    
    # Track database query performance
    def track_slow_query(query, duration, model_name = nil)
      return unless new_relic_enabled? && duration > 1.0 # Only track queries slower than 1 second
      
      track_business_event('SlowDatabaseQuery', {
        query_hash: Digest::MD5.hexdigest(query),
        duration_seconds: duration.round(3),
        model_name: model_name,
        query_type: extract_query_type(query),
        complexity_score: calculate_query_complexity(query)
      })
    end
    
    # Track API endpoint performance
    def track_api_performance(endpoint, method, duration, status_code, user_id = nil)
      track_business_event('APIPerformance', {
        endpoint: endpoint,
        http_method: method,
        duration_ms: (duration * 1000).round(2),
        status_code: status_code,
        user_id: user_id,
        performance_tier: categorize_performance(duration)
      })
    end
    
    # Track background job performance
    def track_job_performance(job_class, duration, status, error_message = nil)
      track_business_event('BackgroundJobPerformance', {
        job_class: job_class,
        duration_seconds: duration.round(2),
        status: status,
        error_message: error_message&.truncate(500),
        performance_category: categorize_job_performance(duration, status)
      })
    end
    
    # Instrument method calls for performance tracking
    def instrument_method(klass, method_name, metric_name = nil)
      return unless new_relic_enabled?
      
      metric_name ||= "Custom/#{klass.name}/#{method_name}"
      
      klass.class_eval do
        add_method_tracer method_name, metric_name
      end
    rescue => e
      Rails.logger.error "Failed to instrument method #{klass.name}##{method_name}: #{e.message}"
    end
    
    # Error tracking integration
    def track_application_error(error, context = {})
      return unless new_relic_enabled?
      
      # Enhanced error context for business applications
      enhanced_context = context.merge(
        error_class: error.class.name,
        error_fingerprint: generate_error_fingerprint(error),
        business_impact: assess_business_impact(error, context),
        user_impact: assess_user_impact(context)
      )
      
      NewRelic::Agent.notice_error(error, enhanced_context)
      
      # Also track as custom event for business intelligence
      track_business_event('ApplicationError', enhanced_context.merge(
        error_message: error.message.truncate(500),
        stack_trace_hash: Digest::MD5.hexdigest(error.backtrace&.join("\n") || "")
      ))
    rescue => e
      Rails.logger.error "Failed to track New Relic application error: #{e.message}"
    end
    
    private
    
    def new_relic_enabled?
      defined?(NewRelic::Agent) && NewRelic::Agent.config[:agent_enabled]
    end
    
    def calculate_processing_estimate(application)
      # Business logic to estimate processing time based on application complexity
      base_time = 24 # hours
      complexity_factors = {
        'auto' => 1.0,
        'home' => 1.2,
        'business' => 1.8,
        'life' => 2.0
      }
      
      factor = complexity_factors[application.application_type] || 1.0
      (base_time * factor).round(1)
    end
    
    def calculate_approval_efficiency(processing_time)
      # Categorize approval efficiency based on processing time
      case processing_time
      when 0..12 then 'excellent'
      when 12..24 then 'good'
      when 24..48 then 'average'
      when 48..72 then 'below_average'
      else 'poor'
      end
    end
    
    def calculate_engagement_level(duration_seconds, actions_count)
      # Calculate user engagement based on session duration and activity
      engagement_score = (actions_count.to_f / (duration_seconds / 60.0)).round(2)
      
      case engagement_score
      when 0..0.5 then 'low'
      when 0.5..1.5 then 'medium'
      when 1.5..3.0 then 'high'
      else 'very_high'
      end
    end
    
    def record_system_health_metrics
      # Record Redis performance
      if defined?(Redis)
        begin
          redis_info = Redis.current.info
          record_business_metric('redis_connected_clients', redis_info['connected_clients'].to_i)
          record_business_metric('redis_used_memory_mb', (redis_info['used_memory'].to_i / 1.megabyte).round(2))
        rescue => e
          Rails.logger.warn "Could not collect Redis metrics: #{e.message}"
        end
      end
      
      # Record database connection pool metrics
      begin
        pool = ActiveRecord::Base.connection_pool
        record_business_metric('db_connection_pool_size', pool.size)
        record_business_metric('db_active_connections', pool.connections.count(&:in_use?))
      rescue => e
        Rails.logger.warn "Could not collect database pool metrics: #{e.message}"
      end
    end
    
    def extract_query_type(query)
      case query.upcase
      when /^SELECT/ then 'SELECT'
      when /^INSERT/ then 'INSERT'
      when /^UPDATE/ then 'UPDATE'
      when /^DELETE/ then 'DELETE'
      else 'OTHER'
      end
    end
    
    def calculate_query_complexity(query)
      # Simple complexity scoring based on query characteristics
      complexity = 0
      complexity += 1 if query.include?('JOIN')
      complexity += 1 if query.include?('GROUP BY')
      complexity += 1 if query.include?('ORDER BY')
      complexity += 1 if query.include?('HAVING')
      complexity += 1 if query.count('(') > 2 # Subqueries
      complexity
    end
    
    def categorize_performance(duration_seconds)
      case duration_seconds
      when 0..0.1 then 'excellent'
      when 0.1..0.5 then 'good'
      when 0.5..1.0 then 'acceptable'
      when 1.0..2.0 then 'slow'
      else 'very_slow'
      end
    end
    
    def categorize_job_performance(duration_seconds, status)
      return 'failed' if status == 'failed'
      
      case duration_seconds
      when 0..30 then 'fast'
      when 30..120 then 'normal'
      when 120..300 then 'slow'
      else 'very_slow'
      end
    end
    
    def generate_error_fingerprint(error)
      # Create a consistent fingerprint for grouping similar errors
      fingerprint_data = "#{error.class.name}:#{error.message}:#{error.backtrace&.first}"
      Digest::MD5.hexdigest(fingerprint_data)
    end
    
    def assess_business_impact(error, context)
      # Assess business impact based on error type and context
      high_impact_errors = ['ActiveRecord::RecordNotFound', 'Stripe::CardError', 'Net::TimeoutError']
      critical_paths = ['/applications', '/quotes', '/documents', '/payments']
      
      impact_score = 0
      impact_score += 3 if high_impact_errors.include?(error.class.name)
      impact_score += 2 if context[:controller]&.match?(/applications|quotes|documents/)
      impact_score += 1 if context[:user_id].present?
      
      case impact_score
      when 0..1 then 'low'
      when 2..3 then 'medium'
      when 4..5 then 'high'
      else 'critical'
      end
    end
    
    def assess_user_impact(context)
      # Assess user impact based on context
      return 'none' unless context[:user_id]
      return 'high' if context[:organization_id] # Affects organization
      return 'medium' if context[:controller]&.match?(/applications|quotes/)
      'low'
    end
  end
end