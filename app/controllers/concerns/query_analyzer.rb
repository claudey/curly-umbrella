# frozen_string_literal: true

module QueryAnalyzer
  extend ActiveSupport::Concern
  
  included do
    around_action :analyze_queries, if: -> { should_analyze_queries? }
  end
  
  private
  
  def analyze_queries
    return yield unless should_analyze_queries?
    
    query_tracker = QueryTracker.new(
      controller: self.class.name,
      action: action_name,
      request_path: request.path,
      request_method: request.method
    )
    
    query_tracker.start_tracking
    
    begin
      result = yield
      query_tracker.complete_tracking(success: true)
      result
    rescue => e
      query_tracker.complete_tracking(success: false, error: e)
      raise
    end
  end
  
  def should_analyze_queries?
    Rails.env.development? || 
    Rails.env.test? || 
    ENV['ENABLE_QUERY_MONITORING'] == 'true' ||
    current_user&.admin?
  end
end

# Query tracking class for detailed monitoring
class QueryTracker
  attr_reader :controller, :action, :request_path, :request_method, :queries, :start_time, :end_time
  
  def initialize(controller:, action:, request_path:, request_method:)
    @controller = controller
    @action = action
    @request_path = request_path
    @request_method = request_method
    @queries = []
    @similar_query_groups = {}
    @start_time = nil
    @end_time = nil
  end
  
  def start_tracking
    @start_time = Time.current
    @queries.clear
    
    # Subscribe to SQL notifications for this request
    @subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      track_sql_query(payload, start, finish)
    end
  end
  
  def complete_tracking(success: true, error: nil)
    @end_time = Time.current
    request_duration = (@end_time - @start_time) * 1000 # in milliseconds
    
    # Unsubscribe from notifications
    ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
    
    # Analyze the collected queries
    analysis = analyze_query_patterns
    
    # Log the results
    log_analysis_results(analysis, request_duration, success, error)
    
    # Create alerts if necessary
    create_alerts_if_needed(analysis, request_duration)
    
    analysis
  end
  
  private
  
  def track_sql_query(payload, start_time, finish_time)
    return if payload[:name] == 'SCHEMA'
    return if payload[:sql]&.include?('SHOW ')
    return if payload[:sql]&.include?('EXPLAIN ')
    
    duration = (finish_time - start_time) * 1000 # Convert to milliseconds
    
    query_info = {
      sql: payload[:sql],
      duration: duration,
      timestamp: start_time,
      binds: payload[:binds]&.map(&:value),
      normalized_sql: normalize_sql(payload[:sql]),
      connection_id: payload[:connection]&.object_id
    }
    
    @queries << query_info
    
    # Group similar queries for N+1 detection
    normalized = query_info[:normalized_sql]
    @similar_query_groups[normalized] ||= []
    @similar_query_groups[normalized] << query_info
  end
  
  def normalize_sql(sql)
    return '' unless sql
    
    # Remove specific values and normalize for pattern matching
    normalized = sql.gsub(/\$\d+/, '?')                    # PostgreSQL parameters
                   .gsub(/= \d+/, '= ?')                   # Numeric values
                   .gsub(/= '\d+'/, "= '?'")               # Quoted numeric values  
                   .gsub(/= '[^']+'/, "= '?'")             # String values
                   .gsub(/IN \([^)]+\)/, 'IN (?)')         # IN clauses
                   .gsub(/VALUES \([^)]+\)/, 'VALUES (?)')  # INSERT values
                   .gsub(/\s+/, ' ')                       # Normalize whitespace
                   .strip
    
    normalized
  end
  
  def analyze_query_patterns
    total_queries = @queries.size
    total_duration = @queries.sum { |q| q[:duration] }
    slow_queries = @queries.select { |q| q[:duration] > 100 } # > 100ms
    
    # Detect potential N+1 queries
    potential_n_plus_ones = @similar_query_groups.select do |pattern, queries|
      queries.size >= 5 && # At least 5 similar queries
      queries.first[:duration] < 50 && # Individual queries are fast
      queries.sum { |q| q[:duration] } > 200 # But total time is significant
    end
    
    # Analyze query distribution
    query_types = analyze_query_types
    
    # Detect sequential query patterns (possible N+1)
    sequential_patterns = detect_sequential_patterns
    
    {
      total_queries: total_queries,
      total_duration: total_duration.round(2),
      slow_queries: slow_queries,
      potential_n_plus_ones: potential_n_plus_ones,
      query_types: query_types,
      sequential_patterns: sequential_patterns,
      similar_query_groups: @similar_query_groups.transform_values(&:size)
    }
  end
  
  def analyze_query_types
    types = { select: 0, insert: 0, update: 0, delete: 0, other: 0 }
    
    @queries.each do |query|
      sql = query[:sql].upcase.strip
      case sql
      when /^SELECT/
        types[:select] += 1
      when /^INSERT/
        types[:insert] += 1
      when /^UPDATE/
        types[:update] += 1
      when /^DELETE/
        types[:delete] += 1
      else
        types[:other] += 1
      end
    end
    
    types
  end
  
  def detect_sequential_patterns
    patterns = []
    
    # Look for sequences of similar queries
    @queries.each_cons(5) do |query_sequence|
      normalized_queries = query_sequence.map { |q| q[:normalized_sql] }
      
      # Check if all queries in sequence are the same (potential N+1)
      if normalized_queries.uniq.size == 1
        patterns << {
          pattern: normalized_queries.first,
          count: query_sequence.size,
          duration: query_sequence.sum { |q| q[:duration] }
        }
      end
    end
    
    patterns.uniq { |p| p[:pattern] }
  end
  
  def log_analysis_results(analysis, request_duration, success, error)
    level = determine_log_level(analysis, request_duration, success)
    
    message = "[Query Analysis] #{@controller}##{@action} #{@request_method} #{@request_path} - " \
             "#{request_duration.round(2)}ms total, #{analysis[:total_queries]} queries " \
             "(#{analysis[:total_duration]}ms), #{analysis[:slow_queries].size} slow"
    
    Rails.logger.public_send(level, message)
    
    # Log potential N+1 queries
    analysis[:potential_n_plus_ones].each do |pattern, queries|
      Rails.logger.warn "[N+1 Query] Pattern: #{pattern.truncate(100)}, Count: #{queries.size}"
    end
    
    # Log slow queries
    analysis[:slow_queries].each do |query|
      Rails.logger.warn "[Slow Query] #{query[:duration].round(2)}ms: #{query[:sql].truncate(150)}"
    end
    
    # Log error information if request failed
    if error
      Rails.logger.error "[Query Analysis Error] #{error.class}: #{error.message}"
    end
  end
  
  def determine_log_level(analysis, request_duration, success)
    return :error unless success
    return :warn if request_duration > 2000 # > 2 seconds
    return :warn if analysis[:total_queries] > 50
    return :warn if analysis[:potential_n_plus_ones].any?
    return :warn if analysis[:slow_queries].size > 3
    
    :info
  end
  
  def create_alerts_if_needed(analysis, request_duration)
    return unless should_create_alerts?
    
    # Create alert for excessive queries
    if analysis[:total_queries] > 100
      create_performance_alert(
        'excessive_queries',
        "Excessive database queries detected: #{analysis[:total_queries]} queries",
        {
          query_count: analysis[:total_queries],
          duration: analysis[:total_duration],
          controller: @controller,
          action: @action
        }
      )
    end
    
    # Create alert for N+1 queries
    if analysis[:potential_n_plus_ones].any?
      create_performance_alert(
        'n_plus_one_queries',
        "Potential N+1 queries detected",
        {
          patterns: analysis[:potential_n_plus_ones].keys,
          controller: @controller,
          action: @action
        }
      )
    end
    
    # Create alert for slow requests
    if request_duration > 5000 # > 5 seconds
      create_performance_alert(
        'slow_request',
        "Slow request detected: #{request_duration.round(2)}ms",
        {
          duration: request_duration,
          query_count: analysis[:total_queries],
          controller: @controller,
          action: @action
        }
      )
    end
  end
  
  def should_create_alerts?
    defined?(SecurityAlert) && 
    SecurityAlert.table_exists? && 
    Rails.env.production?
  end
  
  def create_performance_alert(alert_type, message, data)
    ActsAsTenant.without_tenant do
      SecurityAlert.create(
        alert_type: "performance_#{alert_type}",
        severity: 'medium',
        status: 'active',
        message: message,
        data: data.merge(
          request_path: @request_path,
          request_method: @request_method,
          timestamp: Time.current
        ),
        triggered_at: Time.current
      )
    end
  rescue => e
    Rails.logger.error "Failed to create performance alert: #{e.message}"
  end
end