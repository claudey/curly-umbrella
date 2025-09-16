# frozen_string_literal: true

# N+1 Query Detection and Monitoring
class QueryMonitor
  SUSPICIOUS_QUERY_THRESHOLD = 5
  SIMILAR_QUERY_WINDOW = 1.second
  
  def self.setup
    return unless Rails.env.development? || Rails.env.test? || ENV['ENABLE_QUERY_MONITORING']
    
    # Track query patterns
    @query_tracker = {
      queries: [],
      potential_n_plus_ones: [],
      start_time: nil
    }
    
    # Subscribe to SQL events
    ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      track_query(payload, start, finish)
    end
    
    # Subscribe to controller events to reset tracking per request
    ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |name, start, finish, id, payload|
      reset_query_tracking
    end
    
    # Log findings after each request
    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, start, finish, id, payload|
      analyze_and_log_queries(payload)
    end
  end
  
  private
  
  def self.track_query(payload, start_time, finish_time)
    return if payload[:name] == 'SCHEMA' # Skip schema queries
    return if payload[:sql].include?('SHOW ') # Skip SHOW queries
    return if payload[:sql].include?('EXPLAIN ') # Skip EXPLAIN queries
    
    duration = (finish_time - start_time) * 1000 # Convert to milliseconds
    
    query_info = {
      sql: payload[:sql],
      duration: duration,
      timestamp: start_time,
      binds: payload[:binds],
      normalized_sql: normalize_sql(payload[:sql])
    }
    
    @query_tracker[:queries] << query_info
    
    # Check for potential N+1 queries
    detect_n_plus_one(query_info)
  end
  
  def self.normalize_sql(sql)
    # Normalize SQL by replacing bind parameters with placeholders
    normalized = sql.gsub(/\$\d+/, '?')
                   .gsub(/= \d+/, '= ?')
                   .gsub(/IN \([^)]+\)/, 'IN (?)')
                   .gsub(/= '[^']+'/, "= '?'")
                   .strip
    normalized
  end
  
  def self.detect_n_plus_one(query_info)
    return unless @query_tracker[:queries].size > 1
    
    recent_queries = @query_tracker[:queries].last(20) # Look at recent queries
    similar_queries = recent_queries.select do |q|
      q[:normalized_sql] == query_info[:normalized_sql] &&
      (query_info[:timestamp] - q[:timestamp]) < SIMILAR_QUERY_WINDOW
    end
    
    if similar_queries.size >= SUSPICIOUS_QUERY_THRESHOLD
      @query_tracker[:potential_n_plus_ones] << {
        pattern: query_info[:normalized_sql],
        count: similar_queries.size,
        queries: similar_queries,
        detected_at: Time.current
      }
    end
  end
  
  def self.reset_query_tracking
    @query_tracker = {
      queries: [],
      potential_n_plus_ones: [],
      start_time: Time.current
    }
  end
  
  def self.analyze_and_log_queries(controller_payload)
    return unless @query_tracker[:queries].any?
    
    total_queries = @query_tracker[:queries].size
    total_duration = @query_tracker[:queries].sum { |q| q[:duration] }
    slow_queries = @query_tracker[:queries].select { |q| q[:duration] > 100 } # > 100ms
    
    # Log basic stats
    Rails.logger.info "[Query Monitor] #{controller_payload[:controller]}##{controller_payload[:action]} - " \
                     "Queries: #{total_queries}, Duration: #{total_duration.round(2)}ms, Slow queries: #{slow_queries.size}"
    
    # Log potential N+1 queries
    @query_tracker[:potential_n_plus_ones].each do |n_plus_one|
      Rails.logger.warn "[N+1 Detection] Potential N+1 query detected:"
      Rails.logger.warn "  Pattern: #{n_plus_one[:pattern]}"
      Rails.logger.warn "  Count: #{n_plus_one[:count]} similar queries"
      Rails.logger.warn "  Controller: #{controller_payload[:controller]}##{controller_payload[:action]}"
      
      # Create security alert for excessive queries
      if n_plus_one[:count] >= 10
        create_performance_alert(n_plus_one, controller_payload)
      end
    end
    
    # Log slow queries
    slow_queries.each do |query|
      Rails.logger.warn "[Slow Query] #{query[:duration].round(2)}ms: #{query[:sql].truncate(200)}"
    end
    
    # Performance recommendations
    if total_queries > 50
      Rails.logger.warn "[Performance] High query count (#{total_queries}) detected. Consider using includes() or joins()."
    end
    
    if total_duration > 1000 # > 1 second
      Rails.logger.warn "[Performance] High total query duration (#{total_duration.round(2)}ms). Consider query optimization."
    end
  end
  
  def self.create_performance_alert(n_plus_one, controller_payload)
    return unless defined?(SecurityAlert) && SecurityAlert.table_exists?
    
    # Create a performance alert if we have too many similar queries
    begin
      ActsAsTenant.without_tenant do
        SecurityAlert.create(
          alert_type: 'performance_issue',
          severity: 'medium',
          status: 'active',
          message: "Potential N+1 query detected in #{controller_payload[:controller]}##{controller_payload[:action]}",
          data: {
            query_pattern: n_plus_one[:pattern],
            query_count: n_plus_one[:count],
            controller: controller_payload[:controller],
            action: controller_payload[:action],
            detected_at: n_plus_one[:detected_at]
          },
          triggered_at: Time.current
        )
      end
    rescue => e
      Rails.logger.error "Failed to create performance alert: #{e.message}"
    end
  end
  
  # Public method to get current stats
  def self.current_stats
    {
      total_queries: @query_tracker&.dig(:queries)&.size || 0,
      potential_n_plus_ones: @query_tracker&.dig(:potential_n_plus_ones)&.size || 0,
      queries: @query_tracker&.dig(:queries) || []
    }
  end
end

# Bullet gem configuration for N+1 detection in development
if Rails.env.development? && defined?(Bullet)
  Rails.application.configure do
    config.after_initialize do
      Bullet.enable = true
      Bullet.alert = false
      Bullet.bullet_logger = true
      Bullet.console = true
      Bullet.rails_logger = true
      Bullet.add_footer = false
      
      # Enable specific detectors
      Bullet.n_plus_one_query_enable = true
      Bullet.unused_eager_loading_enable = true
      Bullet.counter_cache_enable = true
    end
  end
end

# Initialize query monitoring
Rails.application.configure do
  config.after_initialize do
    QueryMonitor.setup
  end
end

# Add Rack middleware for additional monitoring
class QueryMonitoringMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    start_time = Time.current
    
    response = @app.call(env)
    
    end_time = Time.current
    request_duration = (end_time - start_time) * 1000
    
    # Log request-level performance metrics
    if request_duration > 2000 # > 2 seconds
      Rails.logger.warn "[Slow Request] #{env['REQUEST_METHOD']} #{env['PATH_INFO']} took #{request_duration.round(2)}ms"
    end
    
    response
  rescue => e
    Rails.logger.error "[Query Monitor Middleware] Error: #{e.message}"
    raise
  end
end

# Add middleware only in development and when monitoring is enabled
if Rails.env.development? || ENV['ENABLE_QUERY_MONITORING']
  Rails.application.configure do
    config.middleware.use QueryMonitoringMiddleware
  end
end