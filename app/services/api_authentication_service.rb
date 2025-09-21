# frozen_string_literal: true

class ApiAuthenticationService
  class AuthenticationError < StandardError; end
  class AuthorizationError < StandardError; end
  class RateLimitError < StandardError; end

  # JWT configuration
  JWT_SECRET = Rails.application.credentials.jwt_secret_key || ENV["JWT_SECRET_KEY"] || Rails.application.secret_key_base
  JWT_ALGORITHM = "HS256"
  JWT_EXPIRATION = 24.hours

  class << self
    # Authenticate API request using Bearer token or API key
    def authenticate_request!(headers)
      auth_header = headers["Authorization"]

      raise AuthenticationError, "Missing Authorization header" unless auth_header

      if auth_header.start_with?("Bearer ")
        token = auth_header.sub("Bearer ", "")

        if jwt_token?(token)
          authenticate_jwt_token!(token)
        else
          authenticate_api_key!(token)
        end
      else
        raise AuthenticationError, "Invalid Authorization header format. Expected: Bearer <token>"
      end
    end

    # Generate JWT token for API access
    def generate_jwt_token(api_key)
      payload = {
        api_key_id: api_key.id,
        organization_id: api_key.organization_id,
        user_id: api_key.user_id,
        scopes: api_key.scopes,
        issued_at: Time.current.to_i,
        expires_at: JWT_EXPIRATION.from_now.to_i
      }

      JWT.encode(payload, JWT_SECRET, JWT_ALGORITHM)
    end

    # Validate JWT token and return API key
    def authenticate_jwt_token!(token)
      begin
        payload = JWT.decode(token, JWT_SECRET, true, { algorithm: JWT_ALGORITHM }).first

        # Check expiration
        if payload["expires_at"] < Time.current.to_i
          raise JWT::ExpiredSignature, "Token has expired"
        end

        # Find and validate API key
        api_key = ApiKey.active.find(payload["api_key_id"])

        # Update last used timestamp
        api_key.touch(:last_used_at)

        # Check rate limiting
        check_rate_limit!(api_key)

        api_key
      rescue JWT::DecodeError => e
        raise AuthenticationError, "Invalid JWT token: #{e.message}"
      rescue ActiveRecord::RecordNotFound
        raise AuthenticationError, "API key not found or inactive"
      end
    end

    # Validate API key directly
    def authenticate_api_key!(key)
      api_key = ApiKey.active.find_by(key: key)

      raise AuthenticationError, "Invalid API key" unless api_key

      # Check if key is expired
      if api_key.expires_at && api_key.expires_at < Time.current
        raise AuthenticationError, "API key has expired"
      end

      # Update last used timestamp
      api_key.touch(:last_used_at)

      # Check rate limiting
      check_rate_limit!(api_key)

      api_key
    end

    # Check if string looks like JWT token
    def jwt_token?(token)
      token.count(".") == 2 && token.length > 50
    end

    # Authorize API action based on scopes and permissions
    def authorize_action!(api_key, action, resource = nil)
      # Check if action is allowed in API key scopes
      unless action_allowed_by_scope?(api_key.scopes, action)
        raise AuthorizationError, "Action '#{action}' not permitted by API key scopes"
      end

      # Check resource-specific permissions
      if resource
        unless resource_accessible?(api_key, resource)
          raise AuthorizationError, "Access to resource denied"
        end
      end

      # Log authorization for audit
      AuditLog.create!(
        user: api_key.user,
        organization: api_key.organization,
        action: "api_action_authorized",
        category: "api_access",
        resource_type: resource&.class&.name,
        resource_id: resource&.id,
        severity: "info",
        details: {
          api_key_id: api_key.id,
          action: action,
          authorized: true
        }
      )

      true
    end

    # Rate limiting check
    def check_rate_limit!(api_key)
      rate_limiter = ApiRateLimitService.new(api_key)

      unless rate_limiter.allow_request?
        # Log rate limit violation
        AuditLog.create!(
          user: api_key.user,
          organization: api_key.organization,
          action: "api_rate_limit_exceeded",
          category: "security_violation",
          severity: "warning",
          details: {
            api_key_id: api_key.id,
            current_usage: rate_limiter.current_usage,
            rate_limit: rate_limiter.rate_limit,
            reset_time: rate_limiter.reset_time
          }
        )

        raise RateLimitError, "Rate limit exceeded. Limit: #{rate_limiter.rate_limit} requests per #{rate_limiter.window_duration}. Try again at #{rate_limiter.reset_time}"
      end

      rate_limiter.record_request!
    end

    # Revoke API key
    def revoke_api_key!(api_key, reason = "manual_revocation")
      api_key.update!(
        status: "revoked",
        revoked_at: Time.current,
        revocation_reason: reason
      )

      # Log revocation
      AuditLog.create!(
        user: api_key.user,
        organization: api_key.organization,
        action: "api_key_revoked",
        category: "security_event",
        severity: "warning",
        details: {
          api_key_id: api_key.id,
          reason: reason,
          revoked_by: "system"
        }
      )

      # Clear any cached tokens
      Rails.cache.delete("api_key_#{api_key.id}")
    end

    # Generate new API key for organization
    def generate_api_key(organization, user, scopes: [], name: nil, expires_at: nil)
      api_key = ApiKey.create!(
        organization: organization,
        user: user,
        key: generate_secure_key,
        scopes: scopes,
        name: name || "API Key #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        expires_at: expires_at,
        status: "active"
      )

      # Log API key creation
      AuditLog.create!(
        user: user,
        organization: organization,
        action: "api_key_created",
        category: "security_event",
        severity: "info",
        details: {
          api_key_id: api_key.id,
          scopes: scopes,
          expires_at: expires_at
        }
      )

      api_key
    end

    private

    # Check if action is allowed by API key scopes
    def action_allowed_by_scope?(scopes, action)
      return true if scopes.include?("full_access")

      scope_permissions = {
        "read_applications" => %w[read_application list_applications],
        "write_applications" => %w[create_application update_application read_application list_applications],
        "read_quotes" => %w[read_quote list_quotes],
        "write_quotes" => %w[create_quote update_quote read_quote list_quotes],
        "read_documents" => %w[read_document list_documents download_document],
        "write_documents" => %w[upload_document update_document read_document list_documents],
        "read_analytics" => %w[read_analytics read_reports],
        "webhook_management" => %w[create_webhook update_webhook delete_webhook list_webhooks],
        "organization_read" => %w[read_organization read_users],
        "organization_write" => %w[update_organization create_user update_user]
      }

      scopes.any? do |scope|
        scope_permissions[scope]&.include?(action.to_s)
      end
    end

    # Check if resource is accessible by API key
    def resource_accessible?(api_key, resource)
      # Ensure resource belongs to the same organization
      case resource
      when Organization
        resource.id == api_key.organization_id
      when ->(r) { r.respond_to?(:organization_id) }
        resource.organization_id == api_key.organization_id
      when ->(r) { r.respond_to?(:organization) }
        resource.organization&.id == api_key.organization_id
      else
        # For resources without organization association, allow access
        true
      end
    end

    # Generate cryptographically secure API key
    def generate_secure_key
      "bsk_#{SecureRandom.hex(32)}"
    end
  end
end
