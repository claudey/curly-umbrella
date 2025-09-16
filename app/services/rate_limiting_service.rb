# frozen_string_literal: true

class RateLimitingService
  include Singleton

  # Rate limiting rules
  RATE_LIMITS = {
    login: { limit: 5, window: 300 },           # 5 attempts per 5 minutes
    password_reset: { limit: 3, window: 3600 }, # 3 attempts per hour
    api: { limit: 100, window: 3600 },          # 100 API calls per hour
    general: { limit: 200, window: 3600 },      # 200 general requests per hour
    audit_access: { limit: 50, window: 300 },   # 50 audit page requests per 5 minutes
    document_download: { limit: 30, window: 600 } # 30 downloads per 10 minutes
  }.freeze

  def self.check_rate_limit(identifier, limit_type, options = {})
    instance.check_rate_limit(identifier, limit_type, options)
  end

  def self.increment_counter(identifier, limit_type, options = {})
    instance.increment_counter(identifier, limit_type, options)
  end

  def self.reset_counter(identifier, limit_type)
    instance.reset_counter(identifier, limit_type)
  end

  def self.get_remaining_attempts(identifier, limit_type)
    instance.get_remaining_attempts(identifier, limit_type)
  end

  def self.get_rate_limit_info(identifier, limit_type)
    instance.get_rate_limit_info(identifier, limit_type)
  end

  def check_rate_limit(identifier, limit_type, options = {})
    return false if whitelisted?(identifier) || local_identifier?(identifier)

    limit_config = get_limit_config(limit_type, options)
    return false unless limit_config

    cache_key = build_cache_key(identifier, limit_type)
    current_count = Rails.cache.fetch(cache_key, expires_in: limit_config[:window].seconds) { 0 }

    current_count >= limit_config[:limit]
  end

  def increment_counter(identifier, limit_type, options = {})
    return false if whitelisted?(identifier) || local_identifier?(identifier)

    limit_config = get_limit_config(limit_type, options)
    return false unless limit_config

    cache_key = build_cache_key(identifier, limit_type)
    
    # Get current count or initialize to 0
    current_count = Rails.cache.fetch(cache_key, expires_in: limit_config[:window].seconds) { 0 }
    new_count = current_count + 1
    
    # Update the counter with the same expiration
    Rails.cache.write(cache_key, new_count, expires_in: limit_config[:window].seconds)

    # Check if limit exceeded after increment
    if new_count >= limit_config[:limit]
      handle_rate_limit_exceeded(identifier, limit_type, new_count, limit_config)
      return true
    end

    false
  rescue StandardError => e
    Rails.logger.error "Rate limiting error for #{identifier}: #{e.message}"
    false
  end

  def reset_counter(identifier, limit_type)
    cache_key = build_cache_key(identifier, limit_type)
    Rails.cache.delete(cache_key)
    true
  rescue StandardError => e
    Rails.logger.error "Error resetting rate limit for #{identifier}: #{e.message}"
    false
  end

  def get_remaining_attempts(identifier, limit_type)
    return nil if whitelisted?(identifier) || local_identifier?(identifier)

    limit_config = get_limit_config(limit_type)
    return nil unless limit_config

    cache_key = build_cache_key(identifier, limit_type)
    current_count = Rails.cache.fetch(cache_key, expires_in: limit_config[:window].seconds) { 0 }

    [limit_config[:limit] - current_count, 0].max
  end

  def get_rate_limit_info(identifier, limit_type)
    limit_config = get_limit_config(limit_type)
    return nil unless limit_config

    cache_key = build_cache_key(identifier, limit_type)
    current_count = Rails.cache.fetch(cache_key, expires_in: limit_config[:window].seconds) { 0 }

    {
      identifier: identifier,
      limit_type: limit_type,
      limit: limit_config[:limit],
      window: limit_config[:window],
      current_count: current_count,
      remaining: [limit_config[:limit] - current_count, 0].max,
      window_start: Time.current - limit_config[:window].seconds,
      window_end: Time.current,
      blocked: current_count >= limit_config[:limit]
    }
  end

  # Check rate limits by IP address for requests
  def self.check_request_rate_limit(ip_address, path, authenticated: false)
    limit_type = determine_limit_type_from_path(path)
    options = { authenticated: authenticated }
    
    instance.check_rate_limit(ip_address, limit_type, options)
  end

  def self.increment_request_counter(ip_address, path, authenticated: false)
    limit_type = determine_limit_type_from_path(path)
    options = { authenticated: authenticated }
    
    instance.increment_counter(ip_address, limit_type, options)
  end

  # Application controller helper method
  def self.determine_limit_type_from_path(path)
    case path
    when %r{^/users/sign_in}
      :login
    when %r{^/users/password}
      :password_reset
    when %r{^/api/}
      :api
    when %r{^/audits}
      :audit_access
    when %r{/download}
      :document_download
    else
      :general
    end
  end

  # Get current rate limit violations for monitoring
  def self.get_violations_summary(time_window = 1.hour)
    violations = []
    
    # This would typically be stored in a more persistent way
    # For now, we'll simulate based on current cache state
    cache_keys = Rails.cache.instance_variable_get(:@data)&.keys || []
    rate_limit_keys = cache_keys.select { |key| key.to_s.start_with?('rate_limit:') }
    
    rate_limit_keys.each do |key|
      parts = key.to_s.split(':')
      next unless parts.length >= 3
      
      identifier = parts[2]
      limit_type = parts[3]
      
      info = instance.get_rate_limit_info(identifier, limit_type.to_sym)
      if info && info[:blocked]
        violations << {
          identifier: identifier,
          limit_type: limit_type,
          violations: info[:current_count],
          limit: info[:limit],
          timestamp: Time.current
        }
      end
    end
    
    violations
  end

  private

  def get_limit_config(limit_type, options = {})
    config = RATE_LIMITS[limit_type]
    return nil unless config

    # Apply multipliers for authenticated users
    if options[:authenticated] && limit_type != :login
      {
        limit: config[:limit] * 2,  # Double limit for authenticated users
        window: config[:window]
      }
    else
      config
    end
  end

  def build_cache_key(identifier, limit_type)
    "rate_limit:#{limit_type}:#{identifier}"
  end

  def handle_rate_limit_exceeded(identifier, limit_type, count, limit_config)
    # Log the rate limit violation
    Rails.logger.warn "Rate limit exceeded for #{identifier}: #{count}/#{limit_config[:limit]} #{limit_type}"

    # Create security alert
    SecurityAlertJob.perform_later(
      'rate_limit_exceeded',
      "Rate limit exceeded for #{limit_type}",
      {
        identifier: identifier,
        limit_type: limit_type,
        attempts: count,
        limit: limit_config[:limit],
        window: limit_config[:window]
      },
      'medium'
    )

    # Auto-block for excessive violations
    check_for_auto_block(identifier, limit_type)
  end

  def check_for_auto_block(identifier, limit_type)
    # Count violations across different limit types
    violation_key = "rate_limit_violations:#{identifier}"
    violations = Rails.cache.fetch(violation_key, expires_in: 1.hour) { 0 }
    violations += 1
    Rails.cache.write(violation_key, violations, expires_in: 1.hour)

    # Auto-block after multiple violations
    if violations >= 5
      # Try to extract IP if identifier looks like one
      if identifier =~ /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/
        IpBlockingService.block_ip(
          identifier,
          "Auto-blocked: #{violations} rate limit violations",
          duration: 2.hours
        )
      end

      # Create critical security alert
      SecurityAlertJob.perform_later(
        'brute_force_attack',
        "Multiple rate limit violations detected",
        {
          identifier: identifier,
          violation_count: violations,
          auto_blocked: true
        },
        'critical'
      )
    end
  end

  def whitelisted?(identifier)
    # Check if identifier is in whitelist
    # For IP addresses, delegate to IpBlockingService
    if identifier =~ /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/
      IpBlockingService.new.whitelisted?(identifier)
    else
      false
    end
  end

  def local_identifier?(identifier)
    # Don't rate limit local/development identifiers
    return true if Rails.env.development? && identifier == '127.0.0.1'
    
    # Check for local IP ranges if it's an IP
    if identifier =~ /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/
      IpBlockingService.new.send(:local_ip?, identifier)
    else
      false
    end
  end
end