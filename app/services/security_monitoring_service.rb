# frozen_string_literal: true

class SecurityMonitoringService
  include Singleton

  # Anomaly detection thresholds
  FAILED_LOGIN_THRESHOLD = 5
  SUSPICIOUS_IP_THRESHOLD = 10
  RAPID_ACTION_THRESHOLD = 20
  TIME_WINDOW = 15.minutes
  IP_LOCATION_CHANGE_THRESHOLD = 500 # kilometers

  def self.monitor_login_attempt(user, ip_address, user_agent, success)
    instance.monitor_login_attempt(user, ip_address, user_agent, success)
  end

  def self.monitor_action(user, action, resource, ip_address)
    instance.monitor_action(user, action, resource, ip_address)
  end

  def self.check_anomalies
    instance.check_anomalies
  end

  def monitor_login_attempt(user, ip_address, user_agent, success)
    # Log the login attempt
    login_data = {
      user: user,
      ip_address: ip_address,
      user_agent: user_agent,
      success: success,
      timestamp: Time.current
    }

    if success
      AuditLog.log_authentication(user, 'login_success', login_data)
      check_location_anomaly(user, ip_address)
      check_unusual_login_time(user)
    else
      AuditLog.log_authentication(user, 'login_failure', login_data)
      check_failed_login_pattern(user, ip_address)
    end

    # Check for concurrent sessions if successful
    check_concurrent_sessions(user) if success
  end

  def monitor_action(user, action, resource, ip_address)
    action_data = {
      user: user,
      action: action,
      resource: resource&.class&.name,
      resource_id: resource&.id,
      ip_address: ip_address,
      timestamp: Time.current
    }

    # Check for rapid successive actions
    check_rapid_actions(user, action)
    
    # Check for privilege escalation attempts
    check_privilege_escalation(user, action, resource)
    
    # Check for unusual data access patterns
    check_data_access_patterns(user, action, resource)
  end

  def check_anomalies
    Rails.logger.info "Starting security anomaly check..."
    
    anomalies = []
    anomalies.concat(check_failed_login_clusters)
    anomalies.concat(check_suspicious_ip_patterns)
    anomalies.concat(check_unusual_activity_spikes)
    anomalies.concat(check_off_hours_activity)
    
    anomalies.each { |anomaly| handle_security_anomaly(anomaly) }
    
    Rails.logger.info "Security anomaly check completed. Found #{anomalies.count} anomalies."
    anomalies
  end

  private

  def check_failed_login_pattern(user, ip_address)
    recent_failures = AuditLog.where(
      action: 'login_failure',
      created_at: TIME_WINDOW.ago..Time.current
    )

    # Check failures by user
    user_failures = recent_failures.where(user: user).count
    if user_failures >= FAILED_LOGIN_THRESHOLD
      create_security_alert(
        :multiple_failed_logins,
        "Multiple failed login attempts detected for user #{user&.email || 'unknown'}",
        { user: user, count: user_failures, ip_address: ip_address },
        :high
      )
    end

    # Check failures by IP
    ip_failures = recent_failures.where("details->>'ip_address' = ?", ip_address).count
    if ip_failures >= SUSPICIOUS_IP_THRESHOLD
      create_security_alert(
        :suspicious_ip_activity,
        "Suspicious activity detected from IP #{ip_address}",
        { ip_address: ip_address, count: ip_failures },
        :critical
      )
    end
  end

  def check_rapid_actions(user, action)
    return unless user

    recent_actions = AuditLog.where(
      user: user,
      created_at: TIME_WINDOW.ago..Time.current
    ).count

    if recent_actions >= RAPID_ACTION_THRESHOLD
      create_security_alert(
        :rapid_user_activity,
        "Unusually rapid activity detected for user #{user.email}",
        { user: user, action_count: recent_actions, action: action },
        :medium
      )
    end
  end

  def check_location_anomaly(user, ip_address)
    return unless user

    # Get previous login location
    previous_login = AuditLog.where(
      user: user,
      action: 'login_success'
    ).where.not("details->>'ip_address' = ?", ip_address)
     .order(created_at: :desc)
     .first

    return unless previous_login

    # Simple location check (in production, use GeoIP service)
    previous_ip = previous_login.details['ip_address']
    if previous_ip && significant_location_change?(previous_ip, ip_address)
      create_security_alert(
        :unusual_login_location,
        "Login from unusual location detected for user #{user.email}",
        { 
          user: user, 
          current_ip: ip_address, 
          previous_ip: previous_ip,
          time_since_last_login: Time.current - previous_login.created_at
        },
        :medium
      )
    end
  end

  def check_concurrent_sessions(user)
    # This would integrate with session store to check active sessions
    # For now, we'll check recent successful logins
    recent_logins = AuditLog.where(
      user: user,
      action: 'login_success',
      created_at: 1.hour.ago..Time.current
    )

    unique_ips = recent_logins.pluck("details->>'ip_address'").uniq.compact
    
    if unique_ips.length > 3 # More than 3 different IPs in 1 hour
      create_security_alert(
        :concurrent_sessions,
        "Multiple concurrent sessions detected for user #{user.email}",
        { user: user, ip_addresses: unique_ips },
        :medium
      )
    end
  end

  def check_privilege_escalation(user, action, resource)
    return unless user && resource

    # Check if user is accessing resources outside their organization
    if resource.respond_to?(:organization_id) && resource.organization_id != user.organization_id
      create_security_alert(
        :unauthorized_access_attempt,
        "Attempt to access resource outside organization by #{user.email}",
        { 
          user: user, 
          action: action, 
          resource: resource.class.name, 
          resource_id: resource.id,
          user_org: user.organization_id,
          resource_org: resource.organization_id
        },
        :high
      )
    end

    # Check for admin action attempts by non-admin users
    admin_actions = %w[destroy delete activate deactivate manage_users assign_permissions]
    if admin_actions.any? { |admin_action| action.to_s.include?(admin_action) }
      unless user.super_admin? || user.brokerage_admin?
        create_security_alert(
          :privilege_escalation_attempt,
          "Privilege escalation attempt by #{user.email}",
          { user: user, action: action, resource: resource.class.name },
          :critical
        )
      end
    end
  end

  def check_data_access_patterns(user, action, resource)
    return unless user

    # Check for bulk data access
    recent_access = AuditLog.where(
      user: user,
      category: 'data_access',
      created_at: 1.hour.ago..Time.current
    )

    if recent_access.count > 50 # More than 50 data access events in 1 hour
      create_security_alert(
        :bulk_data_access,
        "Bulk data access pattern detected for user #{user.email}",
        { user: user, access_count: recent_access.count },
        :medium
      )
    end
  end

  def check_failed_login_clusters
    anomalies = []
    
    # Check for IP addresses with multiple failed attempts across different users
    failed_logins = AuditLog.where(
      action: 'login_failure',
      created_at: 1.hour.ago..Time.current
    )

    ip_failures = failed_logins.group("details->>'ip_address'").count
    ip_failures.each do |ip, count|
      next unless ip && count >= SUSPICIOUS_IP_THRESHOLD

      anomalies << {
        type: :brute_force_attack,
        message: "Potential brute force attack from IP #{ip}",
        data: { ip_address: ip, attempt_count: count },
        severity: :critical
      }
    end

    anomalies
  end

  def check_suspicious_ip_patterns
    anomalies = []
    
    # Check for IPs accessing multiple user accounts
    recent_activity = AuditLog.where(created_at: 1.hour.ago..Time.current)
                             .where.not(user: nil)
    
    ip_user_map = {}
    recent_activity.find_each do |log|
      ip = log.details['ip_address']
      next unless ip
      
      ip_user_map[ip] ||= Set.new
      ip_user_map[ip] << log.user_id
    end

    ip_user_map.each do |ip, user_ids|
      if user_ids.size >= 5 # Same IP accessing 5+ different user accounts
        anomalies << {
          type: :ip_user_anomaly,
          message: "IP #{ip} accessing multiple user accounts",
          data: { ip_address: ip, user_count: user_ids.size },
          severity: :high
        }
      end
    end

    anomalies
  end

  def check_unusual_activity_spikes
    anomalies = []
    
    current_hour_activity = AuditLog.where(created_at: 1.hour.ago..Time.current).count
    previous_hour_activity = AuditLog.where(created_at: 2.hours.ago..1.hour.ago).count
    
    # Check for 300% increase in activity
    if previous_hour_activity > 0 && current_hour_activity > (previous_hour_activity * 3)
      anomalies << {
        type: :activity_spike,
        message: "Unusual spike in system activity detected",
        data: { 
          current_hour: current_hour_activity, 
          previous_hour: previous_hour_activity,
          increase_factor: (current_hour_activity.to_f / previous_hour_activity).round(2)
        },
        severity: :medium
      }
    end

    anomalies
  end

  def check_off_hours_activity
    anomalies = []
    
    # Define business hours (9 AM to 6 PM in system timezone)
    current_time = Time.current
    business_start = current_time.beginning_of_day + 9.hours
    business_end = current_time.beginning_of_day + 18.hours
    
    # Check if current time is outside business hours
    if current_time < business_start || current_time > business_end
      recent_activity = AuditLog.where(created_at: 30.minutes.ago..Time.current)
                               .where.not(action: ['login_success', 'login_failure'])
                               .count
      
      if recent_activity > 10 # More than 10 non-login activities outside business hours
        anomalies << {
          type: :off_hours_activity,
          message: "Significant activity detected outside business hours",
          data: { activity_count: recent_activity, time: current_time },
          severity: :low
        }
      end
    end

    anomalies
  end

  def significant_location_change?(ip1, ip2)
    # In production, use a GeoIP service like MaxMind
    # For now, simple check if IPs are significantly different
    return false if ip1 == ip2
    
    # Basic heuristic: if first 2 octets are different, consider it significant
    ip1_parts = ip1.split('.')
    ip2_parts = ip2.split('.')
    
    return true if ip1_parts[0] != ip2_parts[0] || ip1_parts[1] != ip2_parts[1]
    
    false
  rescue StandardError
    false
  end

  def create_security_alert(type, message, data, severity)
    alert = SecurityAlert.create!(
      alert_type: type,
      message: message,
      severity: severity,
      data: data,
      organization: data[:user]&.organization,
      triggered_at: Time.current,
      status: 'active'
    )

    handle_security_alert(alert)
    alert
  end

  def handle_security_anomaly(anomaly)
    create_security_alert(
      anomaly[:type],
      anomaly[:message],
      anomaly[:data],
      anomaly[:severity]
    )
  end

  def handle_security_alert(alert)
    # Log to audit system
    AuditLog.log_security_event(
      alert.data[:user],
      alert.alert_type,
      alert.data.merge(
        alert_id: alert.id,
        severity: alert.severity,
        message: alert.message
      )
    )

    # Send notifications based on severity
    case alert.severity.to_sym
    when :critical
      notify_security_team_immediately(alert)
      notify_affected_user(alert) if alert.data[:user]
    when :high
      notify_security_team(alert)
      notify_affected_user(alert) if alert.data[:user]
    when :medium
      notify_security_team(alert)
    when :low
      # Log only, review in daily reports
    end

    # Auto-respond to certain alert types
    auto_respond_to_alert(alert)
  end

  def notify_security_team_immediately(alert)
    # In production, this would send to security team via Slack, PagerDuty, etc.
    Rails.logger.error "CRITICAL SECURITY ALERT: #{alert.message}"
    
    # Send email to all super admins
    User.super_admin.find_each do |admin|
      SecurityMailer.critical_alert(admin, alert).deliver_now
    end
  end

  def notify_security_team(alert)
    Rails.logger.warn "SECURITY ALERT: #{alert.message}"
    
    # Queue notification email
    SecurityMailer.security_alert(alert).deliver_later
  end

  def notify_affected_user(alert)
    user = alert.data[:user]
    return unless user

    # Send security notification to affected user
    SecurityMailer.user_security_alert(user, alert).deliver_later
  end

  def auto_respond_to_alert(alert)
    case alert.alert_type.to_sym
    when :brute_force_attack, :suspicious_ip_activity
      # Auto-block IP after critical threshold
      if alert.severity == 'critical'
        ip_address = alert.data[:ip_address]
        IpBlockingService.block_ip(ip_address, "Automatic block due to #{alert.alert_type}")
      end
    when :multiple_failed_logins
      # Lock user account after multiple alerts
      user = alert.data[:user]
      if user && recent_alerts_for_user(user, :multiple_failed_logins).count >= 3
        user.lock_access!
        Rails.logger.warn "Auto-locked user account: #{user.email}"
      end
    end
  end

  def recent_alerts_for_user(user, alert_type)
    SecurityAlert.where(
      alert_type: alert_type,
      created_at: 1.hour.ago..Time.current
    ).where("data->>'user_id' = ?", user.id.to_s)
  end

  def check_unusual_login_time(user)
    # Get user's typical login hours from historical data
    typical_hours = get_user_typical_login_hours(user)
    current_hour = Time.current.hour
    
    unless typical_hours.include?(current_hour)
      create_security_alert(
        :unusual_login_time,
        "Login at unusual time for user #{user.email}",
        { user: user, current_hour: current_hour, typical_hours: typical_hours },
        :low
      )
    end
  end

  def get_user_typical_login_hours(user)
    # Analyze last 30 days of successful logins
    logins = AuditLog.where(
      user: user,
      action: 'login_success',
      created_at: 30.days.ago..Time.current
    )

    login_hours = logins.pluck(:created_at).map(&:hour)
    
    # Return hours that represent 80% of user's login activity
    hour_counts = login_hours.group_by(&:itself).transform_values(&:count)
    total_logins = login_hours.count
    
    return (0..23).to_a if total_logins < 5 # Not enough data
    
    sorted_hours = hour_counts.sort_by { |_, count| -count }
    
    typical_hours = []
    accumulated_count = 0
    threshold = (total_logins * 0.8).ceil
    
    sorted_hours.each do |hour, count|
      typical_hours << hour
      accumulated_count += count
      break if accumulated_count >= threshold
    end
    
    typical_hours
  end
end