module ApiSecurity
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_request
    before_action :check_rate_limit
    before_action :validate_api_version
    before_action :log_api_access
    after_action :log_api_response
  end

  private

  def authenticate_api_request
    return if api_authenticated?
    
    log_authentication_failure
    render_api_error('Unauthorized', 401)
  end

  def api_authenticated?
    case authentication_method
    when :bearer_token
      authenticate_with_bearer_token
    when :api_key
      authenticate_with_api_key
    when :session
      authenticate_with_session
    else
      false
    end
  end

  def authentication_method
    if request.headers['Authorization']&.start_with?('Bearer ')
      :bearer_token
    elsif request.headers['X-API-Key'].present?
      :api_key
    elsif user_signed_in?
      :session
    else
      :none
    end
  end

  def authenticate_with_bearer_token
    token = request.headers['Authorization']&.split(' ')&.last
    return false unless token

    begin
      decoded_token = JWT.decode(token, jwt_secret, true, algorithm: 'HS256')
      payload = decoded_token.first
      
      # Check token expiration
      return false if payload['exp'] < Time.current.to_i
      
      # Find user
      @current_api_user = User.find_by(id: payload['user_id'])
      
      # Validate token permissions
      validate_token_permissions(payload)
      
      @current_api_user.present?
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.warn "JWT authentication failed: #{e.message}"
      false
    end
  end

  def authenticate_with_api_key
    api_key = request.headers['X-API-Key']
    return false unless api_key

    # Find API key record (you'll need to create an ApiKey model)
    api_key_record = ApiKey.find_by(key: api_key, active: true)
    return false unless api_key_record

    # Check expiration
    return false if api_key_record.expires_at&.past?

    # Check rate limits specific to this API key
    return false unless check_api_key_rate_limit(api_key_record)

    @current_api_user = api_key_record.user
    @current_api_key = api_key_record

    # Update last used
    api_key_record.update_column(:last_used_at, Time.current)

    true
  end

  def authenticate_with_session
    # For web API requests, use session authentication
    user_signed_in? && current_user.active?
  end

  def validate_token_permissions(payload)
    # Check if token has required scopes/permissions
    required_scopes = determine_required_scopes
    token_scopes = payload['scopes'] || []
    
    unless (required_scopes - token_scopes).empty?
      raise JWT::DecodeError, 'Insufficient token permissions'
    end
  end

  def determine_required_scopes
    # Map controller/action to required scopes
    case "#{controller_name}##{action_name}"
    when /quotes#/
      ['quotes:read', 'quotes:write']
    when /applications#/
      ['applications:read']
    when /reports#/
      ['reports:read']
    when /admin/
      ['admin:access']
    else
      ['api:access']
    end
  end

  def check_rate_limit
    return true unless rate_limiting_enabled?

    user_identifier = api_user_identifier
    rate_limit = determine_rate_limit
    
    current_usage = get_current_usage(user_identifier)
    
    if current_usage >= rate_limit
      log_rate_limit_exceeded(user_identifier, current_usage, rate_limit)
      render_api_error('Rate limit exceeded', 429, {
        'X-RateLimit-Limit' => rate_limit,
        'X-RateLimit-Remaining' => 0,
        'X-RateLimit-Reset' => next_reset_time
      })
      return false
    end

    # Increment usage
    increment_usage(user_identifier)
    
    # Add rate limit headers
    response.headers['X-RateLimit-Limit'] = rate_limit.to_s
    response.headers['X-RateLimit-Remaining'] = (rate_limit - current_usage - 1).to_s
    response.headers['X-RateLimit-Reset'] = next_reset_time.to_s

    true
  end

  def rate_limiting_enabled?
    Rails.env.production? || Rails.application.config.enable_api_rate_limiting
  end

  def api_user_identifier
    if @current_api_key
      "api_key:#{@current_api_key.id}"
    elsif @current_api_user
      "user:#{@current_api_user.id}"
    else
      "ip:#{request.remote_ip}"
    end
  end

  def determine_rate_limit
    if @current_api_key
      @current_api_key.rate_limit || ApiSecurity.rate_limit_for(:user)
    elsif @current_api_user
      user_type = @current_api_user.admin? ? :admin : :user
      ApiSecurity.rate_limit_for(user_type)
    else
      ApiSecurity.rate_limit_for(:guest)
    end
  end

  def get_current_usage(identifier)
    cache_key = "api_rate_limit:#{identifier}:#{current_hour}"
    Rails.cache.read(cache_key) || 0
  end

  def increment_usage(identifier)
    cache_key = "api_rate_limit:#{identifier}:#{current_hour}"
    Rails.cache.increment(cache_key, 1, expires_in: 1.hour)
  end

  def current_hour
    Time.current.strftime('%Y%m%d%H')
  end

  def next_reset_time
    (Time.current.beginning_of_hour + 1.hour).to_i
  end

  def validate_api_version
    return unless version_validation_enabled?

    requested_version = request.headers['Accept-Version'] || 
                       request.headers['X-API-Version'] ||
                       params[:version] ||
                       'v1'

    unless supported_api_version?(requested_version)
      render_api_error("Unsupported API version: #{requested_version}", 400)
    end

    @api_version = requested_version
  end

  def version_validation_enabled?
    true # Enable API versioning
  end

  def supported_api_version?(version)
    %w[v1 v2].include?(version)
  end

  def check_api_key_rate_limit(api_key_record)
    return true unless api_key_record.rate_limit

    identifier = "api_key:#{api_key_record.id}"
    current_usage = get_current_usage(identifier)
    
    current_usage < api_key_record.rate_limit
  end

  def log_api_access
    return unless audit_api_access?

    AuditLog.log_data_access(
      current_api_user,
      nil, # No specific resource for API access
      'api_request',
      {
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        endpoint: "#{request.method} #{request.path}",
        params: filtered_params,
        api_version: @api_version,
        authentication_method: authentication_method
      }
    )
  end

  def log_api_response
    return unless audit_api_responses?

    AuditLog.create!(
      user: current_api_user,
      organization: current_api_user&.organization,
      action: 'api_response',
      category: 'data_access',
      severity: determine_response_severity,
      resource_type: 'API',
      details: {
        endpoint: "#{request.method} #{request.path}",
        status_code: response.status,
        response_time: request_duration,
        api_version: @api_version
      },
      ip_address: request.remote_ip
    )
  end

  def audit_api_access?
    # Audit all API access in production, configurable in other environments
    Rails.env.production? || Rails.application.config.audit_api_access
  end

  def audit_api_responses?
    # Only audit responses for sensitive endpoints or errors
    sensitive_endpoint? || response.status >= 400
  end

  def sensitive_endpoint?
    sensitive_patterns = [
      /\/api\/.*\/export/,
      /\/api\/.*\/reports/,
      /\/api\/admin/,
      /\/api\/.*\/audit_logs/
    ]

    sensitive_patterns.any? { |pattern| request.path.match?(pattern) }
  end

  def determine_response_severity
    case response.status
    when 200..299 then 'info'
    when 400..499 then 'warning'
    when 500..599 then 'error'
    else 'info'
    end
  end

  def current_api_user
    @current_api_user || current_user
  end

  def log_authentication_failure
    AuditLog.log_authentication(
      nil,
      'api_authentication_failure',
      {
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        endpoint: "#{request.method} #{request.path}",
        authentication_method: authentication_method,
        severity: 'warning'
      }
    )
  end

  def log_rate_limit_exceeded(identifier, current_usage, limit)
    AuditLog.log_security_event(
      current_api_user,
      'rate_limit_exceeded',
      {
        ip_address: request.remote_ip,
        user_identifier: identifier,
        current_usage: current_usage,
        rate_limit: limit,
        endpoint: "#{request.method} #{request.path}",
        severity: 'warning'
      }
    )
  end

  def render_api_error(message, status, headers = {})
    headers.each { |key, value| response.headers[key] = value }
    
    render json: {
      error: {
        message: message,
        status: status,
        timestamp: Time.current.iso8601
      }
    }, status: status
  end

  def filtered_params
    # Remove sensitive parameters from logs
    filter = ActionDispatch::Http::ParameterFilter.new(Rails.application.config.filter_parameters)
    filter.filter(params.to_unsafe_h)
  end

  def request_duration
    return nil unless defined?(@request_start_time)
    
    ((Time.current - @request_start_time) * 1000).round(2) # milliseconds
  end

  def jwt_secret
    Rails.application.credentials.jwt_secret || 
    ENV['JWT_SECRET'] ||
    Rails.application.secret_key_base
  end

  # Callback for tracking request duration
  def track_request_start
    @request_start_time = Time.current
  end

  # CORS handling for API requests
  def set_cors_headers
    if request.headers['Origin']
      allowed_origins = Rails.application.config.allowed_cors_origins || []
      
      if allowed_origins.include?(request.headers['Origin'])
        response.headers['Access-Control-Allow-Origin'] = request.headers['Origin']
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-API-Key, Accept-Version'
        response.headers['Access-Control-Max-Age'] = '86400'
      end
    end
  end

  # Handle preflight OPTIONS requests
  def handle_options_request
    if request.method == 'OPTIONS'
      set_cors_headers
      head :ok
    end
  end
end