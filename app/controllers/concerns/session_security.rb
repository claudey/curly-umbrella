# frozen_string_literal: true

module SessionSecurity
  extend ActiveSupport::Concern

  included do
    before_action :track_session_activity, if: :user_signed_in?
    before_action :validate_session_security, if: :user_signed_in?
    after_action :update_session_activity, if: :user_signed_in?
  end

  private

  def track_session_activity
    return unless current_user && session[:session_id]

    # Check if session is still valid
    unless SessionManagementService.is_session_valid?(current_user, session[:session_id])
      Rails.logger.warn "Invalid session detected for user #{current_user.id}, forcing logout"
      force_user_logout('Session expired or invalid')
      return
    end

    # Check concurrent session limits
    unless SessionManagementService.check_concurrent_sessions(current_user)
      Rails.logger.warn "Too many concurrent sessions for user #{current_user.id}"
      # Don't force logout here, just log the alert
    end
  end

  def validate_session_security
    return unless current_user && session[:session_id]

    # Additional security validations
    validate_session_ip_consistency
    validate_user_agent_consistency
    check_session_timeout
  end

  def update_session_activity
    return unless current_user && session[:session_id]

    request_info = {
      ip_address: get_client_ip,
      user_agent: request.env['HTTP_USER_AGENT'],
      location: nil, # Could be populated with IP geolocation
      path: request.path,
      timestamp: Time.current
    }

    SessionManagementService.update_session_activity(
      current_user, 
      session[:session_id], 
      request_info
    )
  end

  def create_user_session
    return unless current_user

    # Generate or use existing session ID
    session[:session_id] ||= SecureRandom.hex(32)
    
    request_info = {
      ip_address: get_client_ip,
      user_agent: request.env['HTTP_USER_AGENT'],
      location: detect_location_from_ip(get_client_ip),
      device_fingerprint: generate_device_fingerprint
    }

    SessionManagementService.create_session(
      current_user, 
      session[:session_id], 
      request_info
    )

    # Log successful login
    AuditLog.log_security_event(
      current_user,
      'user_login',
      {
        ip_address: request_info[:ip_address],
        user_agent: request_info[:user_agent],
        location: request_info[:location],
        session_id: session[:session_id],
        login_time: Time.current
      }
    )
  end

  def destroy_user_session
    return unless current_user && session[:session_id]

    SessionManagementService.destroy_session(current_user, session[:session_id])
    
    # Log logout
    AuditLog.log_security_event(
      current_user,
      'user_logout',
      {
        ip_address: get_client_ip,
        session_id: session[:session_id],
        logout_time: Time.current
      }
    )

    session[:session_id] = nil
  end

  def force_user_logout(reason = 'Security violation')
    if current_user
      # Destroy all sessions for this user
      SessionManagementService.destroy_all_sessions(current_user)
      
      # Log the forced logout
      AuditLog.log_security_event(
        current_user,
        'forced_logout',
        {
          reason: reason,
          ip_address: get_client_ip,
          user_agent: request.env['HTTP_USER_AGENT'],
          forced_at: Time.current
        }
      )
    end

    # Clear session
    session[:session_id] = nil
    sign_out(current_user) if user_signed_in?
    
    # Redirect with message
    redirect_to new_user_session_path, alert: "Your session has been terminated for security reasons: #{reason}"
  end

  def get_active_user_sessions
    return [] unless current_user

    sessions = SessionManagementService.get_active_sessions(current_user)
    
    # Mark current session
    current_session_id = session[:session_id]
    sessions.map do |session_info|
      session_info[:is_current] = (session_info[:session_id] == current_session_id)
      session_info
    end
  end

  def terminate_other_sessions
    return false unless current_user && session[:session_id]

    destroyed_count = SessionManagementService.destroy_all_sessions(
      current_user, 
      session[:session_id]
    )

    if destroyed_count > 0
      flash[:notice] = "Successfully terminated #{destroyed_count} other session(s)"
      
      # Log the action
      AuditLog.log_security_event(
        current_user,
        'terminate_other_sessions',
        {
          sessions_terminated: destroyed_count,
          ip_address: get_client_ip,
          initiated_at: Time.current
        }
      )
    end

    destroyed_count > 0
  end

  private

  def validate_session_ip_consistency
    return unless session[:original_ip]

    current_ip = get_client_ip
    if session[:original_ip] != current_ip
      # Create security alert for IP change
      SecurityAlertJob.perform_later(
        'session_ip_change',
        "User session IP changed during active session",
        {
          user_id: current_user.id,
          user_email: current_user.email,
          original_ip: session[:original_ip],
          current_ip: current_ip,
          session_id: session[:session_id]
        },
        'medium'
      )

      # Update the IP for future checks
      session[:original_ip] = current_ip
    end
  end

  def validate_user_agent_consistency
    return unless session[:original_user_agent]

    current_user_agent = request.env['HTTP_USER_AGENT']
    if session[:original_user_agent] != current_user_agent
      # This could indicate session hijacking or browser changes
      SecurityAlertJob.perform_later(
        'session_user_agent_change',
        "User agent changed during active session",
        {
          user_id: current_user.id,
          user_email: current_user.email,
          original_user_agent: session[:original_user_agent],
          current_user_agent: current_user_agent,
          session_id: session[:session_id]
        },
        'low'
      )
    end
  end

  def check_session_timeout
    last_activity = session[:last_activity_at]
    return unless last_activity

    if Time.current - Time.parse(last_activity) > SessionManagementService::INACTIVE_SESSION_TIMEOUT
      force_user_logout('Session timeout due to inactivity')
    else
      session[:last_activity_at] = Time.current.iso8601
    end
  end

  def detect_location_from_ip(ip_address)
    # This would integrate with a geolocation service like MaxMind
    # For now, return a placeholder
    return nil if ip_address.blank?
    
    # You could use a gem like geocoder or maxmind-geoip2
    "Unknown Location" # Placeholder
  end

  def generate_device_fingerprint
    # Generate a fingerprint based on user agent, headers, etc.
    user_agent = request.env['HTTP_USER_AGENT']
    accept_language = request.env['HTTP_ACCEPT_LANGUAGE']
    accept_encoding = request.env['HTTP_ACCEPT_ENCODING']
    
    fingerprint_data = [user_agent, accept_language, accept_encoding].compact.join('|')
    Digest::SHA256.hexdigest(fingerprint_data)[0, 16]
  end

  def get_client_ip
    # This method should be consistent with SecurityProtection concern
    forwarded_ips = request.env['HTTP_X_FORWARDED_FOR']
    
    if forwarded_ips
      forwarded_ips.split(',').first.strip
    else
      request.env['HTTP_X_REAL_IP'] || 
      request.env['REMOTE_ADDR'] || 
      request.ip
    end
  end
end