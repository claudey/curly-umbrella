# frozen_string_literal: true

class SessionManagementService
  include Singleton

  # Session management constants
  MAX_CONCURRENT_SESSIONS = 3
  SESSION_TIMEOUT = 8.hours
  INACTIVE_SESSION_TIMEOUT = 30.minutes
  SESSION_KEY_PREFIX = 'user_session:'
  ACTIVE_SESSIONS_KEY = 'active_sessions:'

  def self.create_session(user, session_id, request_info = {})
    instance.create_session(user, session_id, request_info)
  end

  def self.destroy_session(user, session_id)
    instance.destroy_session(user, session_id)
  end

  def self.destroy_all_sessions(user, except_session_id = nil)
    instance.destroy_all_sessions(user, except_session_id)
  end

  def self.get_active_sessions(user)
    instance.get_active_sessions(user)
  end

  def self.check_concurrent_sessions(user)
    instance.check_concurrent_sessions(user)
  end

  def self.update_session_activity(user, session_id, request_info = {})
    instance.update_session_activity(user, session_id, request_info)
  end

  def self.cleanup_expired_sessions
    instance.cleanup_expired_sessions
  end

  def self.is_session_valid?(user, session_id)
    instance.is_session_valid?(user, session_id)
  end

  def self.force_logout_user(user, reason = 'Security policy enforcement')
    instance.force_logout_user(user, reason)
  end

  def create_session(user, session_id, request_info = {})
    return false unless user&.id && session_id

    # Check for concurrent session limits
    if exceeds_session_limit?(user)
      cleanup_oldest_session(user)
    end

    session_data = {
      user_id: user.id,
      session_id: session_id,
      created_at: Time.current.to_i,
      last_activity: Time.current.to_i,
      ip_address: request_info[:ip_address],
      user_agent: request_info[:user_agent],
      location: request_info[:location],
      device_fingerprint: request_info[:device_fingerprint]
    }

    # Store session data
    session_key = "#{SESSION_KEY_PREFIX}#{user.id}:#{session_id}"
    Rails.cache.write(session_key, session_data, expires_in: SESSION_TIMEOUT)

    # Add to active sessions list
    active_sessions = get_user_sessions(user)
    active_sessions[session_id] = session_data
    store_user_sessions(user, active_sessions)

    # Log session creation
    log_session_event(user, 'session_created', session_data)

    # Check for suspicious login patterns
    check_suspicious_login_pattern(user, session_data)

    session_data
  end

  def destroy_session(user, session_id)
    return false unless user&.id && session_id

    # Remove from active sessions
    active_sessions = get_user_sessions(user)
    session_data = active_sessions.delete(session_id)
    store_user_sessions(user, active_sessions)

    # Remove session data
    session_key = "#{SESSION_KEY_PREFIX}#{user.id}:#{session_id}"
    Rails.cache.delete(session_key)

    # Log session destruction
    log_session_event(user, 'session_destroyed', session_data) if session_data

    true
  end

  def destroy_all_sessions(user, except_session_id = nil)
    return false unless user&.id

    active_sessions = get_user_sessions(user)
    destroyed_count = 0

    active_sessions.each do |session_id, session_data|
      next if session_id == except_session_id

      # Remove session data
      session_key = "#{SESSION_KEY_PREFIX}#{user.id}:#{session_id}"
      Rails.cache.delete(session_key)

      # Log session destruction
      log_session_event(user, 'session_force_destroyed', session_data)
      destroyed_count += 1
    end

    # Keep only the excepted session
    if except_session_id && active_sessions[except_session_id]
      store_user_sessions(user, { except_session_id => active_sessions[except_session_id] })
    else
      store_user_sessions(user, {})
    end

    Rails.logger.info "Destroyed #{destroyed_count} sessions for user #{user.id}"
    destroyed_count
  end

  def get_active_sessions(user)
    return [] unless user&.id

    active_sessions = get_user_sessions(user)
    current_time = Time.current.to_i

    # Filter out expired sessions
    valid_sessions = active_sessions.select do |session_id, session_data|
      session_age = current_time - session_data[:created_at]
      last_activity_age = current_time - session_data[:last_activity]

      # Check if session is still valid
      session_age < SESSION_TIMEOUT.to_i && last_activity_age < INACTIVE_SESSION_TIMEOUT.to_i
    end

    # Clean up expired sessions
    if valid_sessions.size != active_sessions.size
      store_user_sessions(user, valid_sessions)
    end

    valid_sessions.values.map do |session_data|
      {
        session_id: session_data[:session_id],
        created_at: Time.at(session_data[:created_at]),
        last_activity: Time.at(session_data[:last_activity]),
        ip_address: session_data[:ip_address],
        user_agent: session_data[:user_agent],
        location: session_data[:location],
        is_current: false # This would be set by the controller
      }
    end
  end

  def check_concurrent_sessions(user)
    active_sessions = get_active_sessions(user)
    
    if active_sessions.size > MAX_CONCURRENT_SESSIONS
      # Create security alert
      SecurityAlertJob.perform_later(
        'concurrent_sessions',
        "User has #{active_sessions.size} concurrent sessions",
        {
          user_id: user.id,
          user_email: user.email,
          session_count: active_sessions.size,
          max_allowed: MAX_CONCURRENT_SESSIONS,
          sessions: active_sessions.map { |s| s.except(:user_agent) }
        },
        'medium'
      )

      return false
    end

    true
  end

  def update_session_activity(user, session_id, request_info = {})
    return false unless user&.id && session_id

    session_key = "#{SESSION_KEY_PREFIX}#{user.id}:#{session_id}"
    session_data = Rails.cache.read(session_key)
    
    return false unless session_data

    # Update last activity
    session_data[:last_activity] = Time.current.to_i
    session_data[:ip_address] = request_info[:ip_address] if request_info[:ip_address]

    # Store updated session
    Rails.cache.write(session_key, session_data, expires_in: SESSION_TIMEOUT)

    # Update in active sessions list
    active_sessions = get_user_sessions(user)
    active_sessions[session_id] = session_data if active_sessions[session_id]
    store_user_sessions(user, active_sessions)

    # Check for IP changes (potential session hijacking)
    check_session_anomalies(user, session_data, request_info)

    true
  end

  def cleanup_expired_sessions
    # This would ideally scan all user sessions, but that's expensive
    # In practice, this cleanup happens naturally when sessions are accessed
    Rails.logger.info "Session cleanup completed (cleanup happens on access)"
  end

  def is_session_valid?(user, session_id)
    return false unless user&.id && session_id

    session_key = "#{SESSION_KEY_PREFIX}#{user.id}:#{session_id}"
    session_data = Rails.cache.read(session_key)
    
    return false unless session_data

    current_time = Time.current.to_i
    session_age = current_time - session_data[:created_at]
    last_activity_age = current_time - session_data[:last_activity]

    # Check timeouts
    if session_age > SESSION_TIMEOUT.to_i || last_activity_age > INACTIVE_SESSION_TIMEOUT.to_i
      destroy_session(user, session_id)
      return false
    end

    true
  end

  def force_logout_user(user, reason = 'Security policy enforcement')
    return false unless user&.id

    sessions_destroyed = destroy_all_sessions(user)
    
    # Log the forced logout
    AuditLog.log_security_event(
      user,
      'forced_logout',
      {
        user_id: user.id,
        user_email: user.email,
        reason: reason,
        sessions_destroyed: sessions_destroyed,
        forced_at: Time.current
      }
    )

    # Create security alert
    SecurityAlertJob.perform_later(
      'forced_logout',
      "User forcibly logged out: #{reason}",
      {
        user_id: user.id,
        user_email: user.email,
        reason: reason,
        sessions_destroyed: sessions_destroyed
      },
      'high'
    )

    Rails.logger.warn "Force logout for user #{user.id}: #{reason}"
    true
  end

  private

  def get_user_sessions(user)
    sessions_key = "#{ACTIVE_SESSIONS_KEY}#{user.id}"
    Rails.cache.fetch(sessions_key, expires_in: SESSION_TIMEOUT) { {} }
  end

  def store_user_sessions(user, sessions)
    sessions_key = "#{ACTIVE_SESSIONS_KEY}#{user.id}"
    Rails.cache.write(sessions_key, sessions, expires_in: SESSION_TIMEOUT)
  end

  def exceeds_session_limit?(user)
    active_sessions = get_user_sessions(user)
    active_sessions.size >= MAX_CONCURRENT_SESSIONS
  end

  def cleanup_oldest_session(user)
    active_sessions = get_user_sessions(user)
    return if active_sessions.empty?

    # Find oldest session
    oldest_session = active_sessions.min_by { |_, data| data[:created_at] }
    oldest_session_id = oldest_session[0]

    Rails.logger.info "Cleaning up oldest session #{oldest_session_id} for user #{user.id}"
    destroy_session(user, oldest_session_id)
  end

  def log_session_event(user, event_type, session_data)
    AuditLog.log_security_event(
      user,
      event_type,
      {
        session_id: session_data[:session_id],
        ip_address: session_data[:ip_address],
        user_agent: session_data[:user_agent],
        location: session_data[:location],
        timestamp: Time.current
      }
    )
  end

  def check_suspicious_login_pattern(user, session_data)
    # Check for logins from different locations/IPs in short time
    recent_sessions = Rails.cache.fetch("recent_logins:#{user.id}", expires_in: 1.hour) { [] }
    recent_sessions << session_data
    recent_sessions = recent_sessions.last(10) # Keep last 10 logins

    Rails.cache.write("recent_logins:#{user.id}", recent_sessions, expires_in: 1.hour)

    # Check for multiple different IPs in short time
    recent_ips = recent_sessions.map { |s| s[:ip_address] }.compact.uniq
    if recent_ips.size > 3
      SecurityAlertJob.perform_later(
        'suspicious_login_pattern',
        "User logged in from multiple IPs recently",
        {
          user_id: user.id,
          user_email: user.email,
          recent_ips: recent_ips,
          session_count: recent_sessions.size
        },
        'medium'
      )
    end
  end

  def check_session_anomalies(user, session_data, request_info)
    # Check for IP address changes during session
    if session_data[:ip_address] && request_info[:ip_address] && 
       session_data[:ip_address] != request_info[:ip_address]
      
      SecurityAlertJob.perform_later(
        'session_ip_change',
        "Session IP address changed during active session",
        {
          user_id: user.id,
          user_email: user.email,
          session_id: session_data[:session_id],
          original_ip: session_data[:ip_address],
          new_ip: request_info[:ip_address],
          timestamp: Time.current
        },
        'high'
      )
    end
  end
end