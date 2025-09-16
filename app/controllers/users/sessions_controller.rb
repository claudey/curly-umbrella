# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  include SessionSecurity
  
  # Override Devise's create action to add session management
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    
    # Initialize session tracking
    initialize_user_session
    
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  # Override Devise's destroy action to clean up sessions
  def destroy
    # Destroy user session before signing out
    destroy_user_session if user_signed_in?
    
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    respond_to_on_destroy
  end

  # Custom action to manage active sessions
  def manage_sessions
    @active_sessions = get_active_user_sessions
  end

  # Custom action to terminate other sessions
  def terminate_other_sessions
    if terminate_other_sessions
      redirect_to manage_sessions_path, notice: 'Other sessions have been terminated.'
    else
      redirect_to manage_sessions_path, alert: 'No other sessions to terminate.'
    end
  end

  # Custom action to terminate specific session
  def terminate_session
    session_id = params[:session_id]
    
    if session_id && SessionManagementService.destroy_session(current_user, session_id)
      # Log the termination
      AuditLog.log_security_event(
        current_user,
        'session_terminated',
        {
          terminated_session_id: session_id,
          terminating_session_id: session[:session_id],
          ip_address: get_client_ip,
          terminated_at: Time.current
        }
      )

      flash[:notice] = 'Session terminated successfully.'
    else
      flash[:alert] = 'Failed to terminate session.'
    end

    redirect_to manage_sessions_path
  end

  private

  def initialize_user_session
    # Store initial session data for security tracking
    session[:original_ip] = get_client_ip
    session[:original_user_agent] = request.env['HTTP_USER_AGENT']
    session[:last_activity_at] = Time.current.iso8601
    
    # Create session in management service
    create_user_session
    
    # Check for suspicious login patterns
    check_login_anomalies
  end

  def check_login_anomalies
    return unless current_user

    # Check time-based anomalies
    check_unusual_login_time
    
    # Check location-based anomalies (if geolocation is available)
    check_unusual_login_location
    
    # Check for rapid successive logins
    check_rapid_login_attempts
  end

  def check_unusual_login_time
    current_hour = Time.current.hour
    
    # Check if login is during unusual hours (between 2 AM and 6 AM)
    if current_hour >= 2 && current_hour <= 6
      SecurityAlertJob.perform_later(
        'unusual_login_time',
        "User logged in during unusual hours",
        {
          user_id: current_user.id,
          user_email: current_user.email,
          login_hour: current_hour,
          ip_address: get_client_ip,
          login_time: Time.current
        },
        'low'
      )
    end
  end

  def check_unusual_login_location
    # This would require geolocation service integration
    # For now, just track different IPs
    
    recent_ips_key = "recent_login_ips:#{current_user.id}"
    recent_ips = Rails.cache.fetch(recent_ips_key, expires_in: 7.days) { [] }
    current_ip = get_client_ip
    
    unless recent_ips.include?(current_ip)
      # New IP detected
      SecurityAlertJob.perform_later(
        'new_login_location',
        "User logged in from new IP address",
        {
          user_id: current_user.id,
          user_email: current_user.email,
          new_ip: current_ip,
          previous_ips: recent_ips.last(5),
          login_time: Time.current
        },
        'medium'
      )
      
      # Add to recent IPs
      recent_ips << current_ip
      recent_ips = recent_ips.last(10) # Keep last 10 IPs
      Rails.cache.write(recent_ips_key, recent_ips, expires_in: 7.days)
    end
  end

  def check_rapid_login_attempts
    login_attempts_key = "login_attempts:#{current_user.id}"
    attempts = Rails.cache.fetch(login_attempts_key, expires_in: 1.hour) { [] }
    
    # Add current attempt
    attempts << Time.current
    attempts = attempts.select { |time| time > 1.hour.ago }
    
    Rails.cache.write(login_attempts_key, attempts, expires_in: 1.hour)
    
    # Check for more than 5 logins in an hour
    if attempts.size > 5
      SecurityAlertJob.perform_later(
        'rapid_login_attempts',
        "User has multiple login attempts in short period",
        {
          user_id: current_user.id,
          user_email: current_user.email,
          attempt_count: attempts.size,
          time_window: '1 hour',
          ip_address: get_client_ip
        },
        'medium'
      )
    end
  end

  def get_client_ip
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