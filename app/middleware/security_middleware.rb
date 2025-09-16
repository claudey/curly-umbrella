# frozen_string_literal: true

class SecurityMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    ip_address = get_client_ip(request)

    # Check if IP is blocked
    if IpBlockingService.blocked?(ip_address)
      return blocked_response(ip_address, request)
    end

    # Rate limiting check
    if rate_limited?(ip_address, request)
      return rate_limit_response(ip_address, request)
    end

    # Monitor the request
    monitor_request(request, ip_address)

    @app.call(env)
  end

  private

  def get_client_ip(request)
    # Get the real client IP, handling proxies and load balancers
    forwarded_ips = request.env['HTTP_X_FORWARDED_FOR']
    
    if forwarded_ips
      # Take the first IP in the chain (the original client)
      forwarded_ips.split(',').first.strip
    else
      request.env['HTTP_X_REAL_IP'] || 
      request.env['REMOTE_ADDR'] || 
      request.ip
    end
  end

  def blocked_response(ip_address, request)
    Rails.logger.warn "Blocked request from #{ip_address} to #{request.path}"
    
    # Log the blocked attempt
    AuditLog.log_security_event(
      nil,
      'blocked_ip_attempt',
      {
        ip_address: ip_address,
        path: request.path,
        method: request.method,
        user_agent: request.env['HTTP_USER_AGENT'],
        timestamp: Time.current
      }
    )

    [
      403,
      {
        'Content-Type' => 'text/html',
        'X-Request-ID' => request.uuid
      },
      [blocked_html_response]
    ]
  end

  def rate_limited?(ip_address, request)
    return false if whitelisted_path?(request.path)
    
    # Different limits for different endpoints
    limit_key, limit_count, window = get_rate_limit_params(request)
    
    return false unless limit_key

    # Use Rails.cache for rate limiting (fallback when Redis not available)
    cache_key = "rate_limit:#{limit_key}:#{ip_address}"
    current_count = Rails.cache.fetch(cache_key, expires_in: window.seconds) { 0 }

    if current_count >= limit_count
      # Check if user is authenticated for higher limits
      if authenticated_request?(request)
        return current_count >= (limit_count * 2) # Double limit for authenticated users
      end
      return true
    end

    # Increment counter
    Rails.cache.write(cache_key, current_count + 1, expires_in: window.seconds)

    false
  rescue StandardError => e
    Rails.logger.error "Rate limiting error: #{e.message}"
    false # Allow request if cache is down
  end

  def get_rate_limit_params(request)
    case request.path
    when %r{^/users/sign_in}
      ['login', 5, 300] # 5 attempts per 5 minutes
    when %r{^/users/password}
      ['password_reset', 3, 3600] # 3 attempts per hour
    when %r{^/api/}
      ['api', 100, 3600] # 100 API calls per hour
    when %r{^/audits}
      ['audit_access', 50, 300] # 50 audit page requests per 5 minutes
    else
      ['general', 200, 3600] # 200 general requests per hour
    end
  end

  def rate_limit_response(ip_address, request)
    Rails.logger.warn "Rate limited request from #{ip_address} to #{request.path}"
    
    # Log the rate limiting
    AuditLog.log_security_event(
      nil,
      'rate_limit_exceeded',
      {
        ip_address: ip_address,
        path: request.path,
        method: request.method,
        user_agent: request.env['HTTP_USER_AGENT']
      }
    )

    # Auto-block IP if it's hitting rate limits frequently
    check_for_auto_block(ip_address)

    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => '300',
        'X-RateLimit-Limit' => '60',
        'X-RateLimit-Remaining' => '0',
        'X-Request-ID' => request.uuid
      },
      [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
    ]
  end

  def monitor_request(request, ip_address)
    # Monitor for suspicious patterns
    monitor_path_traversal(request, ip_address)
    monitor_sql_injection_attempts(request, ip_address)
    monitor_xss_attempts(request, ip_address)
    monitor_suspicious_user_agents(request, ip_address)
  end

  def monitor_path_traversal(request, ip_address)
    suspicious_patterns = ['../', '..\\', '%2e%2e%2f', '%2e%2e%5c']
    path_and_query = "#{request.path}?#{request.query_string}"
    
    if suspicious_patterns.any? { |pattern| path_and_query.include?(pattern) }
      create_security_alert(
        :path_traversal_attempt,
        "Path traversal attempt detected from #{ip_address}",
        { ip_address: ip_address, path: request.path, query: request.query_string },
        :high
      )
    end
  end

  def monitor_sql_injection_attempts(request, ip_address)
    sql_patterns = [
      /union\s+select/i,
      /drop\s+table/i,
      /insert\s+into/i,
      /delete\s+from/i,
      /'.*or.*'/i,
      /\;\s*drop/i
    ]

    query_string = request.query_string.to_s
    
    if sql_patterns.any? { |pattern| query_string.match?(pattern) }
      create_security_alert(
        :sql_injection_attempt,
        "SQL injection attempt detected from #{ip_address}",
        { ip_address: ip_address, query: query_string, path: request.path },
        :critical
      )
    end
  end

  def monitor_xss_attempts(request, ip_address)
    xss_patterns = [
      /<script/i,
      /javascript:/i,
      /on\w+\s*=/i,
      /eval\s*\(/i,
      /<iframe/i
    ]

    query_string = request.query_string.to_s
    
    if xss_patterns.any? { |pattern| query_string.match?(pattern) }
      create_security_alert(
        :xss_attempt,
        "XSS attempt detected from #{ip_address}",
        { ip_address: ip_address, query: query_string, path: request.path },
        :high
      )
    end
  end

  def monitor_suspicious_user_agents(request, ip_address)
    user_agent = request.env['HTTP_USER_AGENT'].to_s.downcase
    
    suspicious_agents = [
      'sqlmap', 'nikto', 'nmap', 'masscan', 'zap', 'burp',
      'wget', 'curl', 'python-requests', 'go-http-client'
    ]

    if suspicious_agents.any? { |agent| user_agent.include?(agent) }
      create_security_alert(
        :suspicious_user_agent,
        "Suspicious user agent detected from #{ip_address}",
        { ip_address: ip_address, user_agent: request.env['HTTP_USER_AGENT'], path: request.path },
        :medium
      )
    end
  end

  def check_for_auto_block(ip_address)
    # Check if this IP has hit rate limits multiple times
    rate_limit_key = "rate_limit_violations:#{ip_address}"
    
    violations = Rails.cache.fetch(rate_limit_key, expires_in: 1.hour) { 0 }
    violations += 1
    Rails.cache.write(rate_limit_key, violations, expires_in: 1.hour)
    
    if violations >= 5 # 5 rate limit violations in an hour
      IpBlockingService.block_ip(
        ip_address, 
        "Auto-blocked: #{violations} rate limit violations",
        duration: 2.hours
      )
    end
  rescue StandardError => e
    Rails.logger.error "Auto-block check error: #{e.message}"
  end

  def whitelisted_path?(path)
    # Don't rate limit these paths as strictly
    whitelist = [
      '/health', '/up', '/assets/', '/favicon.ico'
    ]
    
    whitelist.any? { |pattern| path.start_with?(pattern) }
  end

  def authenticated_request?(request)
    # Check if request has valid session or API key
    session_id = request.session['session_id']
    api_key = request.headers['Authorization']
    
    session_id.present? || api_key.present?
  end

  def create_security_alert(type, message, data, severity)
    # Queue the alert creation to avoid blocking the request
    # Try to get current organization from the request context
    organization_id = ActsAsTenant.current_tenant&.id
    SecurityAlertJob.perform_later(type, message, data, severity, organization_id)
  end

  def blocked_html_response
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Access Denied</title>
        <style>
          body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            margin-top: 50px;
            background-color: #f8f9fa;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 40px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
          }
          .error-code { 
            font-size: 72px; 
            color: #dc3545; 
            font-weight: bold;
            margin-bottom: 20px;
          }
          .error-message {
            font-size: 24px;
            color: #333;
            margin-bottom: 20px;
          }
          .error-details {
            color: #666;
            font-size: 16px;
            line-height: 1.5;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="error-code">403</div>
          <div class="error-message">Access Denied</div>
          <div class="error-details">
            Your IP address has been temporarily blocked due to suspicious activity.<br>
            If you believe this is an error, please contact the system administrator.<br><br>
            <strong>Request ID:</strong> #{SecureRandom.uuid}
          </div>
        </div>
      </body>
      </html>
    HTML
  end
end