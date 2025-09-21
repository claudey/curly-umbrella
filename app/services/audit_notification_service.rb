# frozen_string_literal: true

class AuditNotificationService
  include ActiveModel::Model

  # Critical events that require immediate notification
  CRITICAL_EVENTS = %w[
    unauthorized_access
    multiple_login_failures
    suspicious_login_attempt
    data_breach_attempt
    privilege_escalation
    mass_data_export
    admin_privilege_granted
    admin_privilege_revoked
    financial_transaction_large
    compliance_violation
    security_policy_violation
    account_locked
    password_reset_suspicious
    api_abuse_detected
    rate_limit_exceeded_critical
  ].freeze

  # High-severity events that need notification within hours
  HIGH_SEVERITY_EVENTS = %w[
    login_failure
    authorization_failure
    sensitive_data_access
    financial_transaction
    user_role_changed
    permission_changed
    document_deleted
    application_rejected
    quote_expired
    insurance_application_deleted
    bulk_operation
  ].freeze

  def self.process_audit_event(audit_log)
    new.process_audit_event(audit_log)
  end

  def process_audit_event(audit_log)
    return unless should_notify?(audit_log)

    notification_level = determine_notification_level(audit_log)
    recipients = determine_recipients(audit_log, notification_level)

    case notification_level
    when :critical
      send_immediate_notifications(audit_log, recipients)
      create_security_alert(audit_log)
      send_emergency_sms(audit_log, recipients) if extremely_critical?(audit_log)
    when :high
      send_high_priority_notifications(audit_log, recipients)
      create_security_alert(audit_log) if security_related?(audit_log)
    when :medium
      queue_notification_digest(audit_log, recipients)
    end

    # Always log the notification action
    log_notification_sent(audit_log, notification_level, recipients)
  end

  private

  def should_notify?(audit_log)
    return false if audit_log.severity == "info" && !critical_action?(audit_log)
    return false if audit_log.created_at < 1.hour.ago # Don't notify for old events
    return false if duplicate_recent_notification?(audit_log)

    true
  end

  def determine_notification_level(audit_log)
    return :critical if critical_event?(audit_log)
    return :high if high_severity_event?(audit_log)
    return :medium if audit_log.severity.in?([ "warning", "error" ])

    :low
  end

  def critical_event?(audit_log)
    CRITICAL_EVENTS.include?(audit_log.action) ||
    audit_log.severity == "critical" ||
    mass_operation?(audit_log) ||
    financial_threshold_exceeded?(audit_log) ||
    security_breach_indicators?(audit_log)
  end

  def high_severity_event?(audit_log)
    HIGH_SEVERITY_EVENTS.include?(audit_log.action) ||
    audit_log.severity == "error" ||
    admin_operation?(audit_log) ||
    sensitive_data_operation?(audit_log)
  end

  def critical_action?(audit_log)
    audit_log.action.in?(%w[
      delete destroy approve reject
      role_change permission_change
      export bulk_delete mass_update
    ])
  end

  def mass_operation?(audit_log)
    details = audit_log.details || {}
    details[:records_count].to_i > 50 ||
    details[:bulk_operation] == true ||
    audit_log.action.include?("bulk_") ||
    audit_log.action.include?("mass_")
  end

  def financial_threshold_exceeded?(audit_log)
    return false unless audit_log.category == "financial"

    amount = audit_log.details&.dig("amount")
    return false unless amount

    amount.to_f > 100_000 # $100k threshold
  end

  def security_breach_indicators?(audit_log)
    details = audit_log.details || {}

    # Check for suspicious patterns
    suspicious_patterns = [
      "sql injection", "xss", "csrf", "injection",
      "unauthorized", "breach", "exploit", "attack"
    ]

    message_content = [
      audit_log.action,
      audit_log.details&.dig("error_message"),
      audit_log.details&.dig("request_path")
    ].compact.join(" ").downcase

    suspicious_patterns.any? { |pattern| message_content.include?(pattern) }
  end

  def admin_operation?(audit_log)
    audit_log.user&.admin? ||
    audit_log.action.include?("admin_") ||
    audit_log.details&.dig("controller")&.include?("Admin")
  end

  def sensitive_data_operation?(audit_log)
    sensitive_resources = %w[User Client Quote InsuranceApplication Document]
    sensitive_actions = %w[export download bulk_access view_sensitive]

    sensitive_resources.include?(audit_log.resource_type) &&
    (sensitive_actions.include?(audit_log.action) || audit_log.action.include?("sensitive"))
  end

  def security_related?(audit_log)
    audit_log.category.in?([ "security", "authorization", "authentication" ]) ||
    audit_log.action.include?("security") ||
    audit_log.action.include?("unauthorized")
  end

  def extremely_critical?(audit_log)
    audit_log.action.in?(%w[
      data_breach_attempt
      unauthorized_admin_access
      mass_data_export
      privilege_escalation
      suspicious_login_attempt
    ]) || financial_threshold_exceeded?(audit_log)
  end

  def determine_recipients(audit_log, notification_level)
    recipients = []
    organization = audit_log.organization

    case notification_level
    when :critical
      # Notify all admins and super admins immediately
      recipients.concat(get_admin_users(organization))
      recipients.concat(get_super_admin_users) if organization
      recipients.concat(get_security_team_users(organization))
    when :high
      # Notify admins and relevant stakeholders
      recipients.concat(get_admin_users(organization))
      recipients.concat(get_stakeholder_users(audit_log, organization))
    when :medium
      # Notify relevant users based on the audit event
      recipients.concat(get_relevant_users(audit_log, organization))
    end

    recipients.uniq.compact
  end

  def get_admin_users(organization)
    return [] unless organization

    organization.users
                .joins(:user_roles)
                .where(user_roles: { role: [ "admin", "brokerage_admin" ] })
                .where(active: true)
                .includes(:notification_preferences)
  end

  def get_super_admin_users
    User.joins(:user_roles)
        .where(user_roles: { role: "super_admin" })
        .where(active: true)
        .includes(:notification_preferences)
  end

  def get_security_team_users(organization)
    return [] unless organization

    # Get users with security-related roles or permissions
    organization.users
                .joins(:user_roles)
                .where(user_roles: { role: "security_admin" })
                .where(active: true)
                .includes(:notification_preferences)
  end

  def get_stakeholder_users(audit_log, organization)
    stakeholders = []

    # Add the user who performed the action (if different from affected user)
    stakeholders << audit_log.user if audit_log.user

    # Add users related to the affected resource
    if audit_log.auditable.respond_to?(:user)
      stakeholders << audit_log.auditable.user
    end

    # Add account managers or responsible parties
    if organization && audit_log.category == "financial"
      stakeholders.concat(
        organization.users
                   .joins(:user_roles)
                   .where(user_roles: { role: [ "account_manager", "financial_admin" ] })
      )
    end

    stakeholders.compact.uniq
  end

  def get_relevant_users(audit_log, organization)
    return [] unless organization

    # Return users based on the specific audit category and action
    case audit_log.category
    when "financial"
      organization.users.joins(:user_roles)
                  .where(user_roles: { role: [ "financial_admin", "account_manager" ] })
    when "compliance"
      organization.users.joins(:user_roles)
                  .where(user_roles: { role: [ "compliance_officer", "admin" ] })
    else
      # For general events, notify managers and above
      organization.users.joins(:user_roles)
                  .where(user_roles: { role: [ "manager", "admin", "brokerage_admin" ] })
    end
  end

  def send_immediate_notifications(audit_log, recipients)
    recipients.each do |user|
      # Send email immediately
      AuditNotificationMailer.critical_audit_alert(user, audit_log).deliver_now

      # Create in-app notification
      create_in_app_notification(user, audit_log, priority: "critical")

      # Send SMS if enabled and critical enough
      send_sms_notification(user, audit_log) if user.sms_enabled? && extremely_critical?(audit_log)
    end
  end

  def send_high_priority_notifications(audit_log, recipients)
    recipients.each do |user|
      # Queue email for faster delivery
      AuditNotificationMailer.high_priority_audit_alert(user, audit_log).deliver_later(priority: 10)

      # Create in-app notification
      create_in_app_notification(user, audit_log, priority: "high")
    end
  end

  def queue_notification_digest(audit_log, recipients)
    # Add to daily/weekly digest queue
    recipients.each do |user|
      AuditDigestJob.perform_later(user.id, audit_log.id)
    end
  end

  def send_emergency_sms(audit_log, recipients)
    recipients.each do |user|
      next unless user.sms_enabled? && user.phone.present?

      SmsNotificationJob.perform_now(
        user.phone,
        "CRITICAL SECURITY ALERT: #{audit_log.action.humanize} detected in #{audit_log.organization&.name}. Check your email immediately."
      )
    end
  end

  def create_security_alert(audit_log)
    return unless defined?(SecurityAlert) && SecurityAlert.table_exists?

    SecurityAlert.create!(
      organization: audit_log.organization,
      alert_type: "audit_event",
      severity: map_severity_to_alert(audit_log.severity),
      status: "active",
      message: generate_alert_message(audit_log),
      data: {
        audit_log_id: audit_log.id,
        action: audit_log.action,
        category: audit_log.category,
        resource_type: audit_log.resource_type,
        user_id: audit_log.user_id,
        ip_address: audit_log.ip_address,
        details: audit_log.details
      },
      triggered_at: audit_log.created_at
    )
  end

  def create_in_app_notification(user, audit_log, priority: "medium")
    return unless defined?(Notification) && Notification.table_exists?

    Notification.create!(
      user: user,
      organization: audit_log.organization,
      title: generate_notification_title(audit_log),
      message: generate_notification_message(audit_log),
      notification_type: "audit_alert",
      priority: priority,
      data: {
        audit_log_id: audit_log.id,
        action: audit_log.action,
        category: audit_log.category,
        severity: audit_log.severity
      }
    )
  end

  def send_sms_notification(user, audit_log)
    return unless user.sms_enabled? && user.phone.present?

    message = "Security Alert: #{audit_log.action.humanize} detected. " \
             "Time: #{audit_log.created_at.strftime('%Y-%m-%d %H:%M')}. " \
             "Check your email for details."

    SmsNotificationJob.perform_later(user.phone, message)
  end

  def duplicate_recent_notification?(audit_log)
    # Check if we've sent a similar notification recently to avoid spam
    recent_cutoff = 15.minutes.ago

    AuditLog.where(
      action: audit_log.action,
      user: audit_log.user,
      organization: audit_log.organization
    ).where("created_at > ?", recent_cutoff)
     .where.not(id: audit_log.id)
     .exists?
  end

  def log_notification_sent(audit_log, level, recipients)
    AuditLog.create!(
      user: nil, # System notification
      organization: audit_log.organization,
      action: "audit_notification_sent",
      category: "system_access",
      resource_type: "AuditNotification",
      resource_id: audit_log.id,
      severity: "info",
      details: {
        original_audit_id: audit_log.id,
        notification_level: level,
        recipient_count: recipients.size,
        recipient_emails: recipients.map(&:email),
        notification_reason: audit_log.action
      }
    )
  end

  def map_severity_to_alert(severity)
    case severity
    when "critical" then "critical"
    when "error" then "high"
    when "warning" then "medium"
    else "low"
    end
  end

  def generate_alert_message(audit_log)
    user_info = audit_log.user ? "by #{audit_log.user.email}" : "by system"
    "Audit event '#{audit_log.action}' #{user_info} in #{audit_log.resource_type}"
  end

  def generate_notification_title(audit_log)
    case audit_log.severity
    when "critical"
      "🚨 Critical Security Alert"
    when "error"
      "⚠️ Security Alert"
    when "warning"
      "⚡ Audit Alert"
    else
      "📋 Audit Notification"
    end
  end

  def generate_notification_message(audit_log)
    user_info = audit_log.user ? audit_log.user.email : "System"
    time_info = audit_log.created_at.strftime("%Y-%m-%d at %H:%M")

    "#{user_info} performed '#{audit_log.action.humanize}' on #{audit_log.resource_type} at #{time_info}."
  end
end
