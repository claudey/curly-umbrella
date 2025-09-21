if Rails.env.test? || Rails.env.development?
  # Monkey patch security services to always return safe values in test

  module IpBlockingService
    def self.blocked?(ip)
      false
    end

    def self.get_block_info(ip)
      nil
    end
  end

  module RateLimitingService
    def self.check_request_rate_limit(ip, path, authenticated: false)
      false # Not rate limited
    end
  end

  module SecurityMonitoringService
    def self.monitor_request(params)
      true
    end
  end

  # Bypass security protection entirely for test environment
  module SecurityProtection
    extend ActiveSupport::Concern

    private

    def check_ip_blocking
      # Do nothing in test
    end

    def check_rate_limiting
      # Do nothing in test
    end

    def monitor_request_security
      # Do nothing in test
    end
  end

  # Bypass session security for development/test
  module SessionSecurity
    extend ActiveSupport::Concern

    private

    def track_session_activity
      # Do nothing in development/test
    end

    def validate_session_security
      # Do nothing in development/test
    end

    def update_session_activity
      # Do nothing in development/test
    end

    def create_user_session
      # Do nothing in development/test - just set a session ID
      session[:session_id] ||= SecureRandom.hex(32)
    end

    def destroy_user_session
      # Do nothing in development/test
      session[:session_id] = nil
    end

    def check_login_anomalies
      # Do nothing in development/test
    end

    def check_unusual_login_time
      # Do nothing in development/test
    end

    def force_user_logout(reason = nil)
      # Do nothing in development/test
    end
  end

  # Bypass audit logging
  module ControllerAuditLogging
    extend ActiveSupport::Concern

    private

    def log_controller_action
      # Do nothing in development/test
    end

    def log_sensitive_action
      # Do nothing in development/test
    end
  end
end
