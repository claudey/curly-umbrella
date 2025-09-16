# frozen_string_literal: true

# Redis configuration for BrokerSync
begin
  # Configure Redis connection
  redis_config = {
    host: ENV.fetch('REDIS_HOST', 'localhost'),
    port: ENV.fetch('REDIS_PORT', 6379),
    db: ENV.fetch('REDIS_DB', 0),
    timeout: 1,
    reconnect_attempts: 3
  }

  # Add password if provided
  redis_config[:password] = ENV['REDIS_PASSWORD'] if ENV['REDIS_PASSWORD'].present?

  # Create Redis connection
  $redis = Redis.new(redis_config)

  # Test connection
  $redis.ping

  Rails.logger.info "Redis connected successfully"

rescue Redis::CannotConnectError => e
  Rails.logger.warn "Redis connection failed: #{e.message}. Falling back to Rails.cache"
  $redis = nil
rescue => e
  Rails.logger.error "Redis initialization error: #{e.message}"
  $redis = nil
end

# Configure Solid Queue (built into Rails 8)
# Solid Queue uses the database by default, but we can optionally use Redis for certain operations