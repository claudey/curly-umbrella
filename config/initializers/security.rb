# Security Configuration for BrokerSync

# Configure Active Record Encryption
Rails.application.configure do
  # Primary encryption configuration
  config.active_record.encryption.primary_key = ENV["ENCRYPTION_PRIMARY_KEY"] ||
                                                SecureRandom.hex(32)

  config.active_record.encryption.deterministic_key = ENV["ENCRYPTION_DETERMINISTIC_KEY"] ||
                                                      SecureRandom.hex(32)

  config.active_record.encryption.key_derivation_salt = ENV["ENCRYPTION_KEY_DERIVATION_SALT"] ||
                                                        SecureRandom.hex(32)

  # Configure encryption behavior
  config.active_record.encryption.encrypt_fixtures = false
  config.active_record.encryption.store_key_references = true
  config.active_record.encryption.add_to_filter_parameters = true
  config.active_record.encryption.validate_column_size = true

  # Key rotation support
  config.active_record.encryption.support_unencrypted_data = true
  config.active_record.encryption.support_sha1_for_non_deterministic_encryption = false
end

# Security Headers Configuration
Rails.application.config.force_ssl = Rails.env.production?

# Configure Secure Headers (if gem is available)
if defined?(SecureHeaders)
  SecureHeaders::Configuration.default do |config|
    config.csp = {
      # Customize CSP based on your needs
      default_src: %w['self'],
      font_src: %w['self' data: fonts.gstatic.com],
      img_src: %w['self' data: https:],
      object_src: %w['none'],
      script_src: %w['self' 'unsafe-inline'],
      style_src: %w['self' 'unsafe-inline' fonts.googleapis.com],
      connect_src: %w['self' ws: wss:],
      frame_ancestors: %w['none']
    }

    config.hsts = "max-age=#{1.year.to_i}; includeSubDomains; preload"
    config.x_frame_options = "DENY"
    config.x_content_type_options = "nosniff"
    config.x_xss_protection = "1; mode=block"
    config.x_download_options = "noopen"
    config.x_permitted_cross_domain_policies = "none"
    config.referrer_policy = "strict-origin-when-cross-origin"
  end
else
  Rails.logger.warn "SecureHeaders gem not found. Consider adding it for enhanced security headers."
end

# Session Security
Rails.application.config.session_store :cookie_store,
  key: "_brokersync_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
  expire_after: 8.hours

# Configure password strength requirements
if defined?(Devise)
  Devise.setup do |config|
    config.password_length = 12..128
    config.reset_password_within = 2.hours
    config.maximum_attempts = 5
    config.unlock_in = 1.hour
    config.lock_strategy = :failed_attempts
    config.unlock_strategy = :both
    config.last_attempt_warning = true
  end
end

# Rate Limiting Configuration (if using Rack::Attack)
if defined?(Rack::Attack)
  class Rack::Attack
    # Throttle requests by IP (10 rpm)
    throttle("req/ip", limit: 600, period: 60.seconds) do |req|
      req.ip unless req.path.start_with?("/assets")
    end

    # Throttle login attempts by email
    throttle("logins/email", limit: 5, period: 20.minutes) do |req|
      if req.path == "/users/sign_in" && req.post?
        req.params["user"]["email"].to_s.downcase.gsub(/\s+/, "")
      end
    end

    # Throttle login attempts by IP
    throttle("logins/ip", limit: 10, period: 20.minutes) do |req|
      if req.path == "/users/sign_in" && req.post?
        req.ip
      end
    end

    # Block suspicious requests
    blocklist("block suspicious requests") do |req|
      # Block if user agent is missing or suspicious
      req.user_agent.blank? ||
      req.user_agent.include?("bot") ||
      req.user_agent.include?("crawler")
    end

    # Safelist admin IPs (customize as needed)
    safelist("allow admin IPs") do |req|
      # Add your admin IPs here
      # ['127.0.0.1', '::1'].include?(req.ip)
      false
    end
  end
end

# Data Protection Configuration
module DataProtection
  # GDPR/Privacy compliance settings
  RETENTION_PERIODS = {
    audit_logs: 7.years,
    user_data: 5.years,
    application_data: 10.years, # Insurance industry requirement
    financial_data: 7.years,
    session_data: 30.days
  }.freeze

  # PII Classification
  PII_FIELDS = %w[
    first_name last_name full_name
    email phone mobile_phone
    address street_address city state zip_code
    date_of_birth birth_date
    ssn social_security_number tax_id
    driver_license_number passport_number
  ].freeze

  SENSITIVE_FIELDS = %w[
    password encrypted_password password_digest
    reset_password_token confirmation_token
    api_key secret_key private_key
    credit_card_number bank_account_number routing_number
  ].freeze

  def self.classify_field(field_name)
    field_str = field_name.to_s.downcase

    return :sensitive if SENSITIVE_FIELDS.any? { |sf| field_str.include?(sf) }
    return :pii if PII_FIELDS.any? { |pf| field_str.include?(pf) }
    :standard
  end

  def self.retention_period_for(model_class)
    model_name = model_class.name.underscore.to_sym
    RETENTION_PERIODS[model_name] || RETENTION_PERIODS[:user_data]
  end
end

# Audit Configuration
module AuditConfiguration
  # Actions that require audit logging
  AUDITABLE_ACTIONS = %w[
    create update destroy
    approve reject submit
    login logout password_reset
    export download view_sensitive
  ].freeze

  # High-risk actions that require additional logging
  HIGH_RISK_ACTIONS = %w[
    destroy delete
    approve reject
    export download
    password_reset unlock_account
    change_permissions grant_access
  ].freeze

  def self.requires_audit?(action)
    AUDITABLE_ACTIONS.include?(action.to_s)
  end

  def self.high_risk?(action)
    HIGH_RISK_ACTIONS.include?(action.to_s)
  end
end

# API Security Configuration
module ApiSecurity
  # API rate limits (requests per hour)
  RATE_LIMITS = {
    guest: 100,
    user: 1000,
    premium: 5000,
    admin: 10000
  }.freeze

  # API endpoints that require special permissions
  RESTRICTED_ENDPOINTS = %w[
    /api/admin
    /api/reports
    /api/exports
    /api/audit_logs
  ].freeze

  def self.rate_limit_for(user_type)
    RATE_LIMITS[user_type.to_sym] || RATE_LIMITS[:guest]
  end

  def self.restricted_endpoint?(path)
    RESTRICTED_ENDPOINTS.any? { |endpoint| path.start_with?(endpoint) }
  end
end

# Compliance Configuration
module ComplianceConfiguration
  # Regulatory requirements
  REGULATIONS = {
    gdpr: {
      enabled: true,
      retention_period: 5.years,
      right_to_erasure: true,
      data_portability: true
    },
    ccpa: {
      enabled: true,
      retention_period: 5.years,
      right_to_delete: true,
      right_to_know: true
    },
    sox: {
      enabled: Rails.env.production?,
      audit_trail: true,
      data_integrity: true,
      retention_period: 7.years
    },
    hipaa: {
      enabled: false, # Enable if handling health data
      encryption_required: true,
      access_logging: true,
      retention_period: 6.years
    }
  }.freeze

  def self.regulation_enabled?(regulation)
    REGULATIONS.dig(regulation.to_sym, :enabled) || false
  end

  def self.requires_encryption?(regulation)
    REGULATIONS.dig(regulation.to_sym, :encryption_required) || false
  end
end

Rails.logger.info "Security configuration loaded successfully"
