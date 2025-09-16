# frozen_string_literal: true

Rails.application.configure do
  # Database connection pooling and optimization configuration
  
  # Configure connection pool settings based on environment
  if Rails.env.production?
    # Production optimizations
    config.after_initialize do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        # Set connection timeout for long-running queries
        connection.execute("SET statement_timeout = '30s'")
        
        # Optimize PostgreSQL settings for performance
        connection.execute("SET work_mem = '256MB'") if Rails.env.production?
        connection.execute("SET maintenance_work_mem = '1GB'") if Rails.env.production?
        connection.execute("SET effective_cache_size = '4GB'") if Rails.env.production?
        connection.execute("SET random_page_cost = 1.1")
        connection.execute("SET seq_page_cost = 1.0")
        
        # Enable query plan caching
        connection.execute("SET plan_cache_mode = 'auto'")
        
        # Set connection pool parameters
        connection.execute("SET tcp_keepalives_idle = 600")
        connection.execute("SET tcp_keepalives_interval = 30")
        connection.execute("SET tcp_keepalives_count = 3")
      end
    end
  elsif Rails.env.development?
    # Development optimizations - more conservative
    config.after_initialize do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET statement_timeout = '60s'")
        connection.execute("SET work_mem = '64MB'")
        connection.execute("SET random_page_cost = 1.1")
        connection.execute("SET seq_page_cost = 1.0")
      end
    end
  end

  # Configure connection pool monitoring
  if defined?(Rails::Server)
    config.after_initialize do
      # Log connection pool stats periodically in development
      if Rails.env.development?
        Thread.new do
          loop do
            sleep 30
            pool = ActiveRecord::Base.connection_pool
            Rails.logger.debug "[DB Pool] Size: #{pool.size}, Checked out: #{pool.checked_out_size}, Available: #{pool.available_count}"
          rescue => e
            Rails.logger.error "Connection pool monitoring error: #{e.message}"
          end
        end
      end
    end
  end

  # Configure statement timeout and connection settings for all environments
  config.after_initialize do
    ActiveRecord::Base.configurations.configurations.each do |env_config|
      next unless env_config.adapter == 'postgresql'
      
      # Set optimal connection parameters
      env_config.configuration_hash.merge!({
        # Connection pooling optimizations
        pool: ENV.fetch("DB_POOL_SIZE", Rails.env.production? ? 25 : 5).to_i,
        checkout_timeout: ENV.fetch("DB_CHECKOUT_TIMEOUT", 10).to_i,
        reaping_frequency: ENV.fetch("DB_REAPING_FREQUENCY", 60).to_i,
        
        # Connection parameters
        connect_timeout: ENV.fetch("DB_CONNECT_TIMEOUT", 5).to_i,
        
        # PostgreSQL specific optimizations
        variables: {
          statement_timeout: Rails.env.production? ? '30s' : '60s',
          lock_timeout: '10s',
          idle_in_transaction_session_timeout: '60s'
        }
      })
    end
  end
end

# Monkey patch to add connection pool monitoring methods
module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      def pool_stats
        {
          size: size,
          checked_out: checked_out_size,
          available: available_count,
          connections: connections.size,
          busy_connections: connections.count(&:in_use?)
        }
      end

      def log_pool_stats
        stats = pool_stats
        Rails.logger.info "[DB Pool Stats] #{stats.inspect}"
        stats
      end
    end
  end
end

# Connection pool health check
class ConnectionPoolHealthCheck
  def self.check
    pool = ActiveRecord::Base.connection_pool
    stats = pool.pool_stats
    
    # Check for potential issues
    issues = []
    issues << "High connection usage (#{stats[:checked_out]}/#{stats[:size]})" if stats[:checked_out].to_f / stats[:size] > 0.8
    issues << "No available connections" if stats[:available] == 0
    issues << "Pool at capacity" if stats[:checked_out] == stats[:size]
    
    {
      healthy: issues.empty?,
      issues: issues,
      stats: stats
    }
  end
end

# Add to Rails console for debugging
if defined?(Rails::Console)
  def pool_stats
    ActiveRecord::Base.connection_pool.log_pool_stats
  end
  
  def pool_health
    ConnectionPoolHealthCheck.check
  end
end