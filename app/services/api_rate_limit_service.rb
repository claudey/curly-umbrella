# frozen_string_literal: true

class ApiRateLimitService
  class RateLimitError < StandardError
    attr_reader :retry_after, :limit, :usage

    def initialize(message, retry_after: nil, limit: nil, usage: nil)
      super(message)
      @retry_after = retry_after
      @limit = limit
      @usage = usage
    end
  end
  attr_reader :api_key, :rate_limit, :window_duration, :current_usage, :reset_time

  # Rate limit configurations by API key tier
  RATE_LIMITS = {
    "basic" => { requests: 1000, window: 1.hour },
    "standard" => { requests: 5000, window: 1.hour },
    "premium" => { requests: 20000, window: 1.hour },
    "enterprise" => { requests: 100000, window: 1.hour }
  }.freeze

  def initialize(api_key)
    @api_key = api_key
    @tier = determine_tier_from_rate_limit(api_key.rate_limit)
    @rate_limit = api_key.rate_limit || RATE_LIMITS[@tier][:requests]
    @window_duration = RATE_LIMITS[@tier][:window]
    @current_usage = get_current_usage
    @reset_time = get_reset_time
  end

  # Check if request is allowed under rate limit
  def allow_request?
    current_usage < rate_limit
  end

  # Check rate limit and raise error if exceeded
  def check_rate_limit!
    return true if allow_request?

    raise RateLimitError.new(
      "Rate limit exceeded for API key tier '#{@tier}'. Limit: #{rate_limit} requests per hour.",
      retry_after: reset_time.to_i,
      limit: rate_limit,
      usage: current_usage
    )
  end

  # Record a new request
  def record_request!
    cache_key = rate_limit_cache_key

    Rails.cache.write(cache_key, current_usage + 1, expires_in: window_duration)
    @current_usage += 1

    # Update API key usage statistics
    update_usage_statistics!

    # Track in New Relic if available
    if defined?(NewRelicInstrumentationService)
      NewRelicInstrumentationService.record_business_metric(
        "api_requests_per_hour",
        current_usage,
        "count"
      )
    end
  end

  # Get remaining requests in current window
  def remaining_requests
    [ rate_limit - current_usage, 0 ].max
  end

  # Get rate limit info for API response headers
  def rate_limit_headers
    {
      "X-RateLimit-Limit" => rate_limit.to_s,
      "X-RateLimit-Remaining" => remaining_requests.to_s,
      "X-RateLimit-Reset" => reset_time.to_i.to_s,
      "X-RateLimit-Window" => window_duration.to_i.to_s
    }
  end

  # Check if API key is approaching rate limit
  def approaching_limit?(threshold: 0.8)
    (current_usage.to_f / rate_limit) >= threshold
  end

  # Get detailed usage statistics
  def usage_statistics
    {
      tier: @tier,
      rate_limit: rate_limit,
      current_usage: current_usage,
      remaining_requests: remaining_requests,
      usage_percentage: ((current_usage.to_f / rate_limit) * 100).round(2),
      window_duration_seconds: window_duration.to_i,
      reset_time: reset_time,
      approaching_limit: approaching_limit?
    }
  end

  # Reset rate limit (admin function)
  def reset_rate_limit!
    Rails.cache.delete(rate_limit_cache_key)
    @current_usage = 0
    @reset_time = window_duration.from_now

    # Log reset action
    AuditLog.create!(
      user: nil,
      organization: api_key.organization,
      action: "api_rate_limit_reset",
      category: "system_admin",
      severity: "info",
      details: {
        api_key_id: api_key.id,
        tier: @tier,
        reset_by: "admin"
      }
    )
  end

  # Upgrade API key tier
  def upgrade_tier!(new_tier)
    return false unless RATE_LIMITS.key?(new_tier)

    old_tier = @tier
    api_key.update!(tier: new_tier)

    @tier = new_tier
    @rate_limit = RATE_LIMITS[@tier][:requests]
    @window_duration = RATE_LIMITS[@tier][:window]

    # Log tier upgrade
    AuditLog.create!(
      user: api_key.user,
      organization: api_key.organization,
      action: "api_tier_upgraded",
      category: "subscription_change",
      severity: "info",
      details: {
        api_key_id: api_key.id,
        old_tier: old_tier,
        new_tier: new_tier,
        new_rate_limit: rate_limit
      }
    )

    true
  end

  # Get usage patterns for analytics
  def usage_patterns(days: 7)
    end_date = Date.current
    start_date = end_date - days.days

    patterns = {}

    (start_date..end_date).each do |date|
      daily_key = "api_usage:#{api_key.id}:#{date.strftime('%Y-%m-%d')}"
      daily_usage = Rails.cache.read(daily_key) || 0

      patterns[date.strftime("%Y-%m-%d")] = {
        date: date,
        requests: daily_usage,
        percentage_of_limit: ((daily_usage.to_f / rate_limit) * 100).round(2)
      }
    end

    patterns
  end

  # Predictive rate limiting - warn before hitting limits
  def predict_limit_breach(minutes_ahead: 15)
    recent_requests = get_recent_request_rate(minutes: 5)
    requests_per_minute = recent_requests / 5.0

    projected_usage = current_usage + (requests_per_minute * minutes_ahead)

    {
      will_breach: projected_usage >= rate_limit,
      projected_usage: projected_usage.round,
      minutes_to_breach: requests_per_minute > 0 ? ((rate_limit - current_usage) / requests_per_minute).round : nil,
      recommended_action: projected_usage >= rate_limit ? "slow_down" : "continue"
    }
  end

  private

  def determine_tier_from_rate_limit(limit)
    case limit
    when 0..1000
      "basic"
    when 1001..5000
      "standard"
    when 5001..20000
      "premium"
    else
      "enterprise"
    end
  end

  def rate_limit_cache_key
    window_start = (Time.current.to_i / window_duration.to_i) * window_duration.to_i
    "api_rate_limit:#{api_key.id}:#{window_start}"
  end

  def get_current_usage
    Rails.cache.read(rate_limit_cache_key) || 0
  end

  def get_reset_time
    window_start = (Time.current.to_i / window_duration.to_i) * window_duration.to_i
    Time.at(window_start + window_duration.to_i)
  end

  def update_usage_statistics!
    # Update daily usage counter
    daily_key = "api_usage:#{api_key.id}:#{Date.current.strftime('%Y-%m-%d')}"
    daily_usage = Rails.cache.read(daily_key) || 0
    Rails.cache.write(daily_key, daily_usage + 1, expires_in: 25.hours)

    # Update API key's last activity
    api_key.touch(:last_used_at)

    # Update monthly usage if tracking subscription limits
    monthly_key = "api_usage_monthly:#{api_key.id}:#{Date.current.strftime('%Y-%m')}"
    monthly_usage = Rails.cache.read(monthly_key) || 0
    Rails.cache.write(monthly_key, monthly_usage + 1, expires_in: 32.days)

    # Send warning if approaching limits
    send_usage_warning_if_needed
  end

  def get_recent_request_rate(minutes: 5)
    # Get request count for the last N minutes
    recent_key = "api_recent:#{api_key.id}:#{(Time.current.to_i / 60) * 60}" # Round to minute
    Rails.cache.read(recent_key) || 0
  end

  def send_usage_warning_if_needed
    return unless approaching_limit?(threshold: 0.9) # 90% of limit

    warning_key = "api_warning_sent:#{api_key.id}:#{rate_limit_cache_key}"
    return if Rails.cache.exist?(warning_key)

    # Send warning notification
    ApiUsageWarningMailer.rate_limit_warning(api_key, usage_statistics).deliver_later

    # Mark warning as sent for this window
    Rails.cache.write(warning_key, true, expires_in: window_duration)

    # Log warning
    AuditLog.create!(
      user: api_key.user,
      organization: api_key.organization,
      action: "api_usage_warning",
      category: "usage_alert",
      severity: "warning",
      details: usage_statistics.merge(warning_threshold: "90%")
    )
  end
end
