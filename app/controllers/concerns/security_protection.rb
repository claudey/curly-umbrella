# frozen_string_literal: true

module SecurityProtection
  extend ActiveSupport::Concern

  included do
    before_action :check_ip_blocking
    before_action :check_rate_limiting
    after_action :monitor_request_security
  end

  private

  def check_ip_blocking
    client_ip = get_client_ip

    if IpBlockingService.blocked?(client_ip)
      block_info = IpBlockingService.get_block_info(client_ip)

      Rails.logger.warn "Blocked IP #{client_ip} attempted access to #{request.path}"

      # Log the blocked attempt
      AuditLog.log_security_event(
        nil,
        "blocked_ip_attempt",
        {
          ip_address: client_ip,
          path: request.path,
          method: request.method,
          user_agent: request.env["HTTP_USER_AGENT"],
          block_reason: block_info&.dig(:reason),
          timestamp: Time.current
        }
      )

      render_blocked_response(block_info)
      false
    end
  end

  def check_rate_limiting
    client_ip = get_client_ip
    authenticated = user_signed_in?

    # Check if rate limited
    if RateLimitingService.check_request_rate_limit(client_ip, request.path, authenticated: authenticated)
      Rails.logger.warn "Rate limited request from #{client_ip} to #{request.path}"

      # Log the rate limiting
      AuditLog.log_security_event(
        current_user,
        "rate_limit_exceeded",
        {
          ip_address: client_ip,
          path: request.path,
          method: request.method,
          user_agent: request.env["HTTP_USER_AGENT"],
          authenticated: authenticated
        }
      )

      render_rate_limited_response
      return false
    end

    # Increment counter for successful requests
    RateLimitingService.increment_request_counter(client_ip, request.path, authenticated: authenticated)
  end

  def monitor_request_security
    client_ip = get_client_ip

    # Monitor for suspicious patterns
    monitor_path_traversal(client_ip)
    monitor_sql_injection_attempts(client_ip)
    monitor_xss_attempts(client_ip)
    monitor_suspicious_user_agents(client_ip)
  end

  def get_client_ip
    # Get the real client IP, handling proxies and load balancers
    forwarded_ips = request.env["HTTP_X_FORWARDED_FOR"]

    if forwarded_ips
      # Take the first IP in the chain (the original client)
      forwarded_ips.split(",").first.strip
    else
      request.env["HTTP_X_REAL_IP"] ||
      request.env["REMOTE_ADDR"] ||
      request.ip
    end
  end

  def render_blocked_response(block_info)
    if request.xhr? || request.format.json?
      render json: {
        error: "Access denied",
        message: "Your IP address has been blocked",
        code: "IP_BLOCKED"
      }, status: :forbidden
    else
      render "shared/blocked", status: :forbidden, layout: "error"
    end
  end

  def render_rate_limited_response
    rate_limit_info = RateLimitingService.get_rate_limit_info(
      get_client_ip,
      RateLimitingService.determine_limit_type_from_path(request.path)
    )

    response.headers["Retry-After"] = "300"
    response.headers["X-RateLimit-Limit"] = rate_limit_info&.dig(:limit)&.to_s || "60"
    response.headers["X-RateLimit-Remaining"] = "0"

    if request.xhr? || request.format.json?
      render json: {
        error: "Rate limit exceeded",
        message: "Too many requests. Please try again later.",
        retry_after: 300,
        code: "RATE_LIMITED"
      }, status: :too_many_requests
    else
      render "shared/rate_limited", status: :too_many_requests, layout: "error"
    end
  end

  # Security monitoring methods
  def monitor_path_traversal(ip_address)
    suspicious_patterns = [ "../", "..\\", "%2e%2e%2f", "%2e%2e%5c" ]
    path_and_query = "#{request.path}?#{request.query_string}"

    if suspicious_patterns.any? { |pattern| path_and_query.include?(pattern) }
      create_security_alert(
        "path_traversal_attempt",
        "Path traversal attempt detected from #{ip_address}",
        {
          ip_address: ip_address,
          path: request.path,
          query: request.query_string,
          user_agent: request.env["HTTP_USER_AGENT"]
        },
        "high"
      )
    end
  end

  def monitor_sql_injection_attempts(ip_address)
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
        "sql_injection_attempt",
        "SQL injection attempt detected from #{ip_address}",
        {
          ip_address: ip_address,
          query: query_string,
          path: request.path,
          user_agent: request.env["HTTP_USER_AGENT"]
        },
        "critical"
      )
    end
  end

  def monitor_xss_attempts(ip_address)
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
        "xss_attempt",
        "XSS attempt detected from #{ip_address}",
        {
          ip_address: ip_address,
          query: query_string,
          path: request.path,
          user_agent: request.env["HTTP_USER_AGENT"]
        },
        "high"
      )
    end
  end

  def monitor_suspicious_user_agents(ip_address)
    user_agent = request.env["HTTP_USER_AGENT"].to_s.downcase

    suspicious_agents = [
      "sqlmap", "nikto", "nmap", "masscan", "zap", "burp",
      "wget", "curl", "python-requests", "go-http-client"
    ]

    if suspicious_agents.any? { |agent| user_agent.include?(agent) }
      create_security_alert(
        "suspicious_user_agent",
        "Suspicious user agent detected from #{ip_address}",
        {
          ip_address: ip_address,
          user_agent: request.env["HTTP_USER_AGENT"],
          path: request.path
        },
        "medium"
      )
    end
  end

  def create_security_alert(type, message, data, severity)
    # Get current organization if available
    organization_id = ActsAsTenant.current_tenant&.id

    # Queue the alert creation to avoid blocking the request
    SecurityAlertJob.perform_later(type, message, data, severity, organization_id)
  end
end
