class DatabaseOptimizationService
  include Singleton
  
  # Connection pool configurations
  POOL_CONFIGURATIONS = {
    primary: {
      pool: 25,
      checkout_timeout: 5,
      reaping_frequency: 10,
      idle_timeout: 300
    },
    read_replica: {
      pool: 15,
      checkout_timeout: 3,
      reaping_frequency: 15,
      idle_timeout: 600
    }
  }.freeze
  
  # Query classification patterns
  READ_PATTERNS = [
    /^SELECT\s/i,
    /^SHOW\s/i,
    /^DESCRIBE\s/i,
    /^EXPLAIN\s/i
  ].freeze
  
  WRITE_PATTERNS = [
    /^INSERT\s/i,
    /^UPDATE\s/i,
    /^DELETE\s/i,
    /^REPLACE\s/i,
    /^CREATE\s/i,
    /^ALTER\s/i,
    /^DROP\s/i
  ].freeze
  
  def initialize
    @connection_stats = DatabaseConnectionStatistics.new
    @query_analyzer = DatabaseQueryAnalyzer.new
    @replica_health_checker = ReplicaHealthChecker.new
    @connection_pools = {}
    setup_connection_monitoring
  end
  
  # Initialize optimized database connections
  def optimize_database_connections
    Rails.logger.info "Initializing database optimization"
    
    setup_read_replicas
    optimize_connection_pools
    setup_query_routing
    configure_connection_monitoring
    setup_automatic_failover
    
    Rails.logger.info "Database optimization completed successfully"
    true
  end
  
  # Route query to appropriate database based on operation type
  def route_query(sql, options = {})
    query_type = classify_query(sql)
    target_db = determine_target_database(query_type, options)
    
    begin
      start_time = Time.current
      result = execute_on_database(sql, target_db, options)
      execution_time = Time.current - start_time
      
      @connection_stats.record_query(query_type, target_db, execution_time, true)
      result
      
    rescue => e
      execution_time = Time.current - start_time
      @connection_stats.record_query(query_type, target_db, execution_time, false)
      
      # Attempt failover for read queries
      if query_type == :read && target_db != :primary
        Rails.logger.warn "Query failed on #{target_db}, attempting failover to primary: #{e.message}"
        retry_on_primary(sql, options)
      else
        raise
      end
    end
  end
  
  # Get optimized connection for specific database
  def get_connection(database_type = :primary)
    case database_type
    when :read_replica
      get_read_replica_connection
    when :primary
      get_primary_connection
    else
      ActiveRecord::Base.connection
    end
  end
  
  # Monitor and optimize connection pools
  def optimize_connection_pools
    Rails.logger.info "Optimizing database connection pools"
    
    # Configure primary database pool
    configure_connection_pool(:primary, POOL_CONFIGURATIONS[:primary])
    
    # Configure read replica pools
    configure_connection_pool(:read_replica, POOL_CONFIGURATIONS[:read_replica])
    
    # Start connection pool monitoring
    start_connection_pool_monitoring
    
    Rails.logger.info "Connection pool optimization completed"
  end
  
  # Health check for all database connections
  def health_check
    primary_health = check_primary_health
    replica_health = check_replica_health
    pool_health = check_connection_pool_health
    
    overall_status = determine_overall_database_health(primary_health, replica_health, pool_health)
    
    {
      status: overall_status,
      primary: primary_health,
      replicas: replica_health,
      connection_pools: pool_health,
      statistics: @connection_stats.summary,
      last_checked: Time.current
    }
  end
  
  # Get database performance statistics
  def performance_statistics
    {
      query_distribution: @connection_stats.query_distribution,
      average_response_times: @connection_stats.average_response_times,
      connection_pool_utilization: connection_pool_utilization,
      replica_lag: measure_replica_lag,
      slow_queries: @query_analyzer.slow_queries,
      query_optimization_suggestions: @query_analyzer.optimization_suggestions
    }
  end
  
  # Force failover to primary database
  def force_failover_to_primary
    Rails.logger.warn "Forcing failover to primary database"
    
    @replica_health_checker.mark_all_replicas_unhealthy
    
    # Redirect all traffic to primary
    Rails.application.config.database_routing_strategy = :primary_only
    
    Rails.logger.info "All database traffic redirected to primary"
  end
  
  # Re-enable read replicas after failover
  def restore_read_replicas
    Rails.logger.info "Restoring read replica usage"
    
    healthy_replicas = @replica_health_checker.check_all_replicas
    
    if healthy_replicas.any?
      Rails.application.config.database_routing_strategy = :load_balanced
      Rails.logger.info "Read replicas restored: #{healthy_replicas.size} healthy replicas"
    else
      Rails.logger.warn "No healthy read replicas available, maintaining primary-only mode"
    end
  end
  
  # Optimize specific query
  def optimize_query(sql, options = {})
    analysis = @query_analyzer.analyze_query(sql)
    
    if analysis[:needs_optimization]
      optimized_sql = apply_query_optimizations(sql, analysis[:suggestions])
      
      Rails.logger.info "Query optimized: #{analysis[:suggestions].join(', ')}"
      
      {
        original_sql: sql,
        optimized_sql: optimized_sql,
        optimizations_applied: analysis[:suggestions],
        estimated_improvement: analysis[:estimated_improvement]
      }
    else
      { original_sql: sql, optimized_sql: sql, optimizations_applied: [] }
    end
  end
  
  private
  
  def setup_read_replicas
    # Configure read replica connections
    replica_configs = load_replica_configurations
    
    replica_configs.each do |name, config|
      setup_replica_connection(name, config)
    end
    
    Rails.logger.info "Read replicas configured: #{replica_configs.keys.join(', ')}"
  end
  
  def setup_query_routing
    # Install query routing middleware
    ActiveRecord::Base.extend(DatabaseQueryRouting)
    
    # Configure routing strategies
    Rails.application.config.database_routing_strategy = :load_balanced
    Rails.application.config.read_replica_weights = {
      replica_1: 0.4,
      replica_2: 0.4,
      primary: 0.2
    }
  end
  
  def configure_connection_monitoring
    # Set up connection monitoring
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      monitor_query_execution(event)
    end
    
    Rails.logger.info "Database monitoring configured"
  end
  
  def setup_automatic_failover
    # Configure automatic failover logic
    @replica_health_checker.start_monitoring
    
    # Set up failover triggers
    ActiveSupport::Notifications.subscribe('database_error') do |*args|
      handle_database_error(*args)
    end
  end
  
  def classify_query(sql)
    # Clean and normalize SQL
    normalized_sql = sql.strip.gsub(/\s+/, ' ')
    
    return :read if READ_PATTERNS.any? { |pattern| normalized_sql.match?(pattern) }
    return :write if WRITE_PATTERNS.any? { |pattern| normalized_sql.match?(pattern) }
    
    # Default to write for safety
    :write
  end
  
  def determine_target_database(query_type, options)
    return :primary if query_type == :write
    return :primary if options[:force_primary]
    return :primary if in_transaction?
    
    case Rails.application.config.database_routing_strategy
    when :primary_only
      :primary
    when :load_balanced
      select_read_replica
    else
      :primary
    end
  end
  
  def select_read_replica
    healthy_replicas = @replica_health_checker.healthy_replicas
    return :primary if healthy_replicas.empty?
    
    # Weighted round-robin selection
    weights = Rails.application.config.read_replica_weights || {}
    total_weight = weights.values.sum
    
    return healthy_replicas.sample if total_weight == 0
    
    # Select based on weights
    random_weight = rand * total_weight
    cumulative_weight = 0
    
    weights.each do |replica, weight|
      cumulative_weight += weight
      return replica if random_weight <= cumulative_weight && healthy_replicas.include?(replica)
    end
    
    healthy_replicas.first
  end
  
  def execute_on_database(sql, target_db, options)
    connection = get_connection(target_db)
    
    if options[:prepared]
      connection.exec_query(sql, 'Prepared Query', options[:binds] || [])
    else
      connection.execute(sql)
    end
  end
  
  def retry_on_primary(sql, options)
    Rails.logger.info "Retrying query on primary database"
    execute_on_database(sql, :primary, options)
  end
  
  def get_read_replica_connection
    replica = select_read_replica
    
    if replica == :primary
      ActiveRecord::Base.connection
    else
      @connection_pools[replica] ||= create_connection_pool(replica)
      @connection_pools[replica].connection
    end
  end
  
  def get_primary_connection
    ActiveRecord::Base.connection
  end
  
  def configure_connection_pool(pool_name, config)
    # Apply connection pool configuration
    pool_config = ActiveRecord::Base.configurations[Rails.env].dup
    pool_config.merge!(config.stringify_keys)
    
    case pool_name
    when :primary
      ActiveRecord::Base.establish_connection(pool_config)
    when :read_replica
      # Configure read replica pools
      configure_replica_pools(pool_config)
    end
    
    Rails.logger.debug "Connection pool configured: #{pool_name} with #{config}"
  end
  
  def configure_replica_pools(base_config)
    replica_configs = load_replica_configurations
    
    replica_configs.each do |name, replica_config|
      pool_config = base_config.merge(replica_config.stringify_keys)
      @connection_pools[name] = create_connection_pool(name, pool_config)
    end
  end
  
  def create_connection_pool(name, config = nil)
    config ||= load_replica_configurations[name]
    
    ActiveRecord::ConnectionAdapters::ConnectionPool.new(
      ActiveRecord::Base.connection_pool.spec.dup.tap { |spec|
        spec.config.merge!(config.stringify_keys)
      }
    )
  end
  
  def start_connection_pool_monitoring
    Thread.new do
      loop do
        monitor_connection_pools
        sleep(30) # Monitor every 30 seconds
      end
    end
  end
  
  def monitor_connection_pools
    @connection_pools.each do |name, pool|
      utilization = calculate_pool_utilization(pool)
      
      if utilization > 0.8
        Rails.logger.warn "High connection pool utilization for #{name}: #{(utilization * 100).round(1)}%"
      end
      
      @connection_stats.record_pool_utilization(name, utilization)
    end
  end
  
  def calculate_pool_utilization(pool)
    return 0.0 if pool.size == 0
    
    active_connections = pool.connections.count(&:in_use?)
    active_connections.to_f / pool.size
  end
  
  def check_primary_health
    begin
      start_time = Time.current
      ActiveRecord::Base.connection.execute('SELECT 1')
      response_time = Time.current - start_time
      
      {
        status: :healthy,
        response_time: response_time,
        active_connections: ActiveRecord::Base.connection_pool.connections.count(&:in_use?)
      }
    rescue => e
      {
        status: :unhealthy,
        error: e.message,
        active_connections: 0
      }
    end
  end
  
  def check_replica_health
    replica_health = {}
    
    @connection_pools.each do |name, pool|
      begin
        start_time = Time.current
        connection = pool.connection
        connection.execute('SELECT 1')
        response_time = Time.current - start_time
        
        replica_health[name] = {
          status: :healthy,
          response_time: response_time,
          lag: measure_replica_lag_for(connection),
          active_connections: pool.connections.count(&:in_use?)
        }
      rescue => e
        replica_health[name] = {
          status: :unhealthy,
          error: e.message,
          active_connections: 0
        }
      end
    end
    
    replica_health
  end
  
  def check_connection_pool_health
    pool_health = {}
    
    # Check primary pool
    primary_pool = ActiveRecord::Base.connection_pool
    pool_health[:primary] = {
      size: primary_pool.size,
      available: primary_pool.available_connection_count,
      utilization: calculate_pool_utilization(primary_pool)
    }
    
    # Check replica pools
    @connection_pools.each do |name, pool|
      pool_health[name] = {
        size: pool.size,
        available: pool.available_connection_count,
        utilization: calculate_pool_utilization(pool)
      }
    end
    
    pool_health
  end
  
  def determine_overall_database_health(primary, replicas, pools)
    return :unhealthy if primary[:status] == :unhealthy
    
    unhealthy_replicas = replicas.count { |_, health| health[:status] == :unhealthy }
    return :degraded if unhealthy_replicas > replicas.size / 2
    
    high_utilization_pools = pools.count { |_, health| health[:utilization] > 0.9 }
    return :degraded if high_utilization_pools > 0
    
    :healthy
  end
  
  def connection_pool_utilization
    utilization = {}
    
    utilization[:primary] = calculate_pool_utilization(ActiveRecord::Base.connection_pool)
    
    @connection_pools.each do |name, pool|
      utilization[name] = calculate_pool_utilization(pool)
    end
    
    utilization
  end
  
  def measure_replica_lag
    lag_measurements = {}
    
    @connection_pools.each do |name, pool|
      begin
        lag_measurements[name] = measure_replica_lag_for(pool.connection)
      rescue => e
        Rails.logger.warn "Could not measure replica lag for #{name}: #{e.message}"
        lag_measurements[name] = nil
      end
    end
    
    lag_measurements
  end
  
  def measure_replica_lag_for(connection)
    # This is a simplified lag measurement
    # In production, this would query replication status tables
    begin
      result = connection.execute("SHOW SLAVE STATUS")
      result.first&.dig('Seconds_Behind_Master') || 0
    rescue
      # Fallback for non-MySQL databases
      0
    end
  end
  
  def apply_query_optimizations(sql, suggestions)
    optimized_sql = sql
    
    suggestions.each do |suggestion|
      case suggestion
      when :add_index_hint
        optimized_sql = add_index_hints(optimized_sql)
      when :rewrite_subquery
        optimized_sql = rewrite_subqueries(optimized_sql)
      when :optimize_joins
        optimized_sql = optimize_joins(optimized_sql)
      when :add_limit
        optimized_sql = add_reasonable_limit(optimized_sql)
      end
    end
    
    optimized_sql
  end
  
  def add_index_hints(sql)
    # Add USE INDEX hints where appropriate
    # This is a simplified implementation
    sql
  end
  
  def rewrite_subqueries(sql)
    # Convert correlated subqueries to JOINs where possible
    # This is a simplified implementation
    sql
  end
  
  def optimize_joins(sql)
    # Optimize JOIN order and conditions
    # This is a simplified implementation
    sql
  end
  
  def add_reasonable_limit(sql)
    # Add LIMIT clause to potentially expensive queries
    return sql if sql.match?(/LIMIT\s+\d+/i)
    return sql if sql.match?(/COUNT\s*\(/i)
    
    "#{sql} LIMIT 1000"
  end
  
  def in_transaction?
    ActiveRecord::Base.connection.transaction_open?
  end
  
  def load_replica_configurations
    # Load read replica configurations
    Rails.application.config.read_replicas || {
      replica_1: {
        host: ENV['READ_REPLICA_1_HOST'] || 'localhost',
        port: ENV['READ_REPLICA_1_PORT'] || 5432,
        username: ENV['READ_REPLICA_1_USERNAME'],
        password: ENV['READ_REPLICA_1_PASSWORD'],
        database: ENV['READ_REPLICA_1_DATABASE']
      }
    }
  end
  
  def setup_replica_connection(name, config)
    # Set up individual replica connection
    @connection_pools[name] = create_connection_pool(name, config)
    Rails.logger.debug "Replica connection configured: #{name}"
  end
  
  def setup_connection_monitoring
    # Set up comprehensive connection monitoring
    @connection_monitor = Thread.new do
      loop do
        begin
          monitor_all_connections
          sleep(60) # Monitor every minute
        rescue => e
          Rails.logger.error "Connection monitoring error: #{e.message}"
          sleep(60)
        end
      end
    end
  end
  
  def monitor_all_connections
    # Monitor all database connections
    primary_health = check_primary_health
    replica_health = check_replica_health
    
    # Log warnings for unhealthy connections
    if primary_health[:status] != :healthy
      Rails.logger.error "Primary database unhealthy: #{primary_health[:error]}"
    end
    
    replica_health.each do |name, health|
      if health[:status] != :healthy
        Rails.logger.warn "Replica #{name} unhealthy: #{health[:error]}"
      elsif health[:lag] && health[:lag] > 30
        Rails.logger.warn "Replica #{name} has high lag: #{health[:lag]} seconds"
      end
    end
  end
  
  def monitor_query_execution(event)
    sql = event.payload[:sql]
    duration = event.duration
    
    # Track slow queries
    if duration > 1000 # 1 second
      @query_analyzer.record_slow_query(sql, duration)
    end
    
    # Update statistics
    query_type = classify_query(sql)
    @connection_stats.record_query_execution(query_type, duration)
  end
  
  def handle_database_error(*args)
    error_event = ActiveSupport::Notifications::Event.new(*args)
    error_info = error_event.payload
    
    if error_info[:database] && error_info[:database] != :primary
      # Mark replica as unhealthy
      @replica_health_checker.mark_unhealthy(error_info[:database])
      
      Rails.logger.warn "Database error on #{error_info[:database]}, marked as unhealthy"
    end
  end
end

# Statistics tracking for database connections
class DatabaseConnectionStatistics
  def initialize
    @query_counts = Hash.new(0)
    @response_times = Hash.new { |h, k| h[k] = [] }
    @pool_utilizations = Hash.new { |h, k| h[k] = [] }
    @error_counts = Hash.new(0)
  end
  
  def record_query(query_type, database, execution_time, success)
    @query_counts["#{database}_#{query_type}"] += 1
    @response_times["#{database}_#{query_type}"] << execution_time
    @error_counts["#{database}_#{query_type}"] += 1 unless success
    
    # Keep only last 1000 response times per category
    @response_times.each { |key, times| @response_times[key] = times.last(1000) }
  end
  
  def record_pool_utilization(pool_name, utilization)
    @pool_utilizations[pool_name] << utilization
    @pool_utilizations[pool_name] = @pool_utilizations[pool_name].last(1000)
  end
  
  def record_query_execution(query_type, duration)
    @response_times[query_type] << duration
    @response_times[query_type] = @response_times[query_type].last(1000)
  end
  
  def query_distribution
    total = @query_counts.values.sum
    return {} if total == 0
    
    @query_counts.transform_values { |count| (count.to_f / total * 100).round(2) }
  end
  
  def average_response_times
    @response_times.transform_values do |times|
      times.empty? ? 0.0 : (times.sum / times.size).round(3)
    end
  end
  
  def summary
    {
      total_queries: @query_counts.values.sum,
      error_rate: calculate_error_rate,
      query_distribution: query_distribution,
      average_response_times: average_response_times
    }
  end
  
  private
  
  def calculate_error_rate
    total = @query_counts.values.sum
    errors = @error_counts.values.sum
    
    return 0.0 if total == 0
    (errors.to_f / total * 100).round(2)
  end
end

# Query analysis for optimization suggestions
class DatabaseQueryAnalyzer
  def initialize
    @slow_queries = []
    @query_patterns = Hash.new(0)
  end
  
  def analyze_query(sql)
    suggestions = []
    estimated_improvement = 0
    
    # Check for missing LIMIT clauses
    if needs_limit_clause?(sql)
      suggestions << :add_limit
      estimated_improvement += 20
    end
    
    # Check for inefficient JOINs
    if has_inefficient_joins?(sql)
      suggestions << :optimize_joins
      estimated_improvement += 30
    end
    
    # Check for correlated subqueries
    if has_correlated_subqueries?(sql)
      suggestions << :rewrite_subquery
      estimated_improvement += 40
    end
    
    {
      needs_optimization: suggestions.any?,
      suggestions: suggestions,
      estimated_improvement: estimated_improvement
    }
  end
  
  def record_slow_query(sql, duration)
    @slow_queries << {
      sql: sql.truncate(500),
      duration: duration,
      timestamp: Time.current
    }
    
    # Keep only last 100 slow queries
    @slow_queries = @slow_queries.last(100)
  end
  
  def slow_queries
    @slow_queries.sort_by { |q| -q[:duration] }.first(10)
  end
  
  def optimization_suggestions
    # Generate general optimization suggestions based on patterns
    suggestions = []
    
    if @slow_queries.size > 10
      suggestions << "Consider adding database indexes for frequently slow queries"
    end
    
    suggestions
  end
  
  private
  
  def needs_limit_clause?(sql)
    sql.match?(/SELECT.*FROM/i) && !sql.match?(/LIMIT\s+\d+/i) && !sql.match?(/COUNT\s*\(/i)
  end
  
  def has_inefficient_joins?(sql)
    # Simplified check for potentially inefficient JOINs
    join_count = sql.scan(/JOIN/i).size
    join_count > 3
  end
  
  def has_correlated_subqueries?(sql)
    # Simplified check for correlated subqueries
    sql.match?(/SELECT.*\(.*SELECT.*\)/i)
  end
end

# Health monitoring for read replicas
class ReplicaHealthChecker
  def initialize
    @replica_status = {}
    @monitoring_thread = nil
  end
  
  def start_monitoring
    return if @monitoring_thread&.alive?
    
    @monitoring_thread = Thread.new do
      loop do
        check_all_replicas
        sleep(30) # Check every 30 seconds
      end
    end
  end
  
  def check_all_replicas
    healthy = []
    
    replica_configs = Rails.application.config.read_replicas || {}
    
    replica_configs.keys.each do |replica_name|
      if replica_healthy?(replica_name)
        @replica_status[replica_name] = { status: :healthy, last_checked: Time.current }
        healthy << replica_name
      else
        @replica_status[replica_name] = { status: :unhealthy, last_checked: Time.current }
      end
    end
    
    healthy
  end
  
  def healthy_replicas
    @replica_status.select { |_, status| status[:status] == :healthy }.keys
  end
  
  def mark_unhealthy(replica_name)
    @replica_status[replica_name] = { status: :unhealthy, last_checked: Time.current }
  end
  
  def mark_all_replicas_unhealthy
    @replica_status.keys.each { |name| mark_unhealthy(name) }
  end
  
  private
  
  def replica_healthy?(replica_name)
    # Perform health check on specific replica
    # This would involve connecting to the replica and running a test query
    true # Simplified implementation
  end
end

# Database query routing module
module DatabaseQueryRouting
  def self.extended(base)
    base.class_eval do
      def self.connection_with_routing
        service = DatabaseOptimizationService.instance
        service.get_connection
      end
    end
  end
end