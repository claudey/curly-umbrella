class ApiKey < ApplicationRecord
  belongs_to :user
  belongs_to :organization, optional: true

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :rate_limit, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :generate_api_key, on: :create
  before_create :set_defaults

  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }

  enum access_level: {
    read_only: 'read_only',
    read_write: 'read_write',
    admin: 'admin'
  }

  # Scopes that define what the API key can access
  AVAILABLE_SCOPES = %w[
    api:access
    applications:read
    applications:write
    quotes:read
    quotes:write
    reports:read
    exports:create
    admin:access
    audit_logs:read
  ].freeze

  def self.generate_key
    SecureRandom.hex(32)
  end

  def active?
    active && !expired?
  end

  def expired?
    expires_at&.past? || false
  end

  def expires_in_days
    return nil unless expires_at
    ((expires_at - Time.current) / 1.day).to_i
  end

  def usage_today
    api_requests.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
  end

  def usage_this_hour
    api_requests.where(created_at: 1.hour.ago..Time.current).count
  end

  def has_scope?(scope)
    scopes.include?(scope.to_s)
  end

  def can_access?(resource, action)
    return false unless active?
    
    required_scope = determine_required_scope(resource, action)
    has_scope?(required_scope)
  end

  def revoke!
    update!(
      active: false,
      revoked_at: Time.current,
      revoked_reason: 'Manually revoked'
    )
    
    # Log the revocation
    AuditLog.log_security_event(
      user,
      'api_key_revoked',
      {
        api_key_id: id,
        api_key_name: name,
        revoked_by: Current.user&.email || 'System',
        severity: 'warning'
      }
    )
  end

  def renew!(new_expiry = 1.year.from_now)
    update!(expires_at: new_expiry)
    
    AuditLog.log_security_event(
      user,
      'api_key_renewed',
      {
        api_key_id: id,
        api_key_name: name,
        new_expiry: new_expiry.iso8601,
        renewed_by: Current.user&.email || 'System',
        severity: 'info'
      }
    )
  end

  def regenerate_key!
    old_key = key
    new_key = self.class.generate_key
    
    update!(
      key: new_key,
      last_rotated_at: Time.current
    )
    
    AuditLog.log_security_event(
      user,
      'api_key_rotated',
      {
        api_key_id: id,
        api_key_name: name,
        rotated_by: Current.user&.email || 'System',
        severity: 'info'
      }
    )
    
    new_key
  end

  def rate_limit_status
    return nil unless rate_limit
    
    current_usage = usage_this_hour
    {
      limit: rate_limit,
      used: current_usage,
      remaining: [rate_limit - current_usage, 0].max,
      reset_at: Time.current.beginning_of_hour + 1.hour
    }
  end

  def log_usage(request_details = {})
    # Create API request log entry
    ApiRequestLog.create!(
      api_key: self,
      user: user,
      organization: organization,
      endpoint: request_details[:endpoint],
      method: request_details[:method],
      ip_address: request_details[:ip_address],
      user_agent: request_details[:user_agent],
      status_code: request_details[:status_code],
      response_time: request_details[:response_time]
    )
    
    # Update last used timestamp
    update_column(:last_used_at, Time.current)
  end

  def usage_stats(period = 30.days)
    start_date = period.ago
    logs = api_requests.where(created_at: start_date..Time.current)
    
    {
      total_requests: logs.count,
      successful_requests: logs.where(status_code: 200..299).count,
      failed_requests: logs.where(status_code: 400..599).count,
      average_response_time: logs.average(:response_time)&.round(2),
      requests_by_day: logs.group_by_day(:created_at).count,
      most_used_endpoints: logs.group(:endpoint).order(count: :desc).limit(10).count
    }
  end

  def security_summary
    {
      key_age: time_since_creation,
      last_rotation: last_rotated_at || created_at,
      days_since_rotation: days_since_rotation,
      expires_in: expires_in_days,
      recent_usage: usage_stats(7.days),
      security_incidents: security_incidents_count
    }
  end

  private

  def generate_api_key
    self.key ||= self.class.generate_key
  end

  def set_defaults
    self.scopes ||= default_scopes_for_access_level
    self.rate_limit ||= default_rate_limit_for_access_level
    self.expires_at ||= 1.year.from_now
    self.active = true if active.nil?
  end

  def default_scopes_for_access_level
    case access_level
    when 'read_only'
      %w[api:access applications:read quotes:read]
    when 'read_write'
      %w[api:access applications:read applications:write quotes:read quotes:write]
    when 'admin'
      AVAILABLE_SCOPES
    else
      %w[api:access]
    end
  end

  def default_rate_limit_for_access_level
    case access_level
    when 'read_only'
      500 # requests per hour
    when 'read_write'
      1000
    when 'admin'
      5000
    else
      100
    end
  end

  def determine_required_scope(resource, action)
    resource_name = resource.to_s.downcase
    
    case action.to_s
    when 'read', 'show', 'index'
      "#{resource_name}:read"
    when 'create', 'update', 'destroy'
      "#{resource_name}:write"
    when 'export'
      'exports:create'
    when 'admin'
      'admin:access'
    else
      'api:access'
    end
  end

  def time_since_creation
    Time.current - created_at
  end

  def days_since_rotation
    last_rotation = last_rotated_at || created_at
    ((Time.current - last_rotation) / 1.day).to_i
  end

  def security_incidents_count
    # Count security-related audit logs for this API key
    AuditLog.where(
      details: { api_key_id: id },
      category: 'security'
    ).where(created_at: 30.days.ago..Time.current).count
  end

  # Associations for tracking usage
  def api_requests
    # This would be a separate model to track API requests
    # ApiRequestLog.where(api_key: self)
    
    # For now, we'll use audit logs as a proxy
    AuditLog.where(
      user: user,
      action: 'api_request',
      created_at: 30.days.ago..Time.current
    )
  end
end