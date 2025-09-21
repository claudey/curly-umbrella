# frozen_string_literal: true

class AuditDigestJob < ApplicationJob
  queue_as :default

  def perform(user_id, audit_log_id = nil)
    user = User.find_by(id: user_id)
    return unless user&.active?

    if audit_log_id
      # Single audit log notification
      audit_log = AuditLog.find_by(id: audit_log_id)
      return unless audit_log

      process_single_audit_notification(user, audit_log)
    else
      # Generate periodic digest
      generate_audit_digest(user)
    end
  end

  private

  def process_single_audit_notification(user, audit_log)
    # Check if user should receive this notification
    return unless should_notify_user?(user, audit_log)

    # Add to pending notifications for batching
    add_to_notification_batch(user, audit_log)

    # Schedule batch processing if needed
    schedule_batch_processing(user) if should_send_batch?(user)
  end

  def generate_audit_digest(user, period: :daily)
    organization = user.organization
    return unless organization

    # Get audit logs for the specified period
    audit_logs = get_audit_logs_for_period(organization, period)
    return if audit_logs.empty?

    # Filter logs based on user's role and preferences
    filtered_logs = filter_logs_for_user(audit_logs, user)
    return if filtered_logs.empty?

    # Send digest email
    AuditNotificationMailer.audit_digest(user, filtered_logs, period: period.to_s).deliver_now

    # Log the digest generation
    log_digest_sent(user, filtered_logs.count, period)
  end

  def should_notify_user?(user, audit_log)
    # Check notification preferences
    return false unless user.notification_preferences&.audit_alerts_enabled?

    # Check if user has permission to see this type of audit log
    return false unless user_can_view_audit_category?(user, audit_log.category)

    # Check if this is a duplicate notification
    return false if duplicate_notification_exists?(user, audit_log)

    true
  end

  def user_can_view_audit_category?(user, category)
    case category
    when "authentication", "system_access"
      true # All users can see their own auth events
    when "financial", "compliance"
      user.has_role?([ "admin", "financial_admin", "compliance_officer" ])
    when "security"
      user.has_role?([ "admin", "security_admin" ])
    when "user_management"
      user.has_role?([ "admin", "super_admin" ])
    else
      user.has_role?([ "admin" ]) # Default to admin-only
    end
  end

  def add_to_notification_batch(user, audit_log)
    cache_key = "audit_notification_batch:#{user.id}"

    # Get existing batch or create new one
    batch = Rails.cache.read(cache_key) || {
      user_id: user.id,
      audit_log_ids: [],
      created_at: Time.current,
      last_updated: Time.current
    }

    # Add audit log to batch
    batch[:audit_log_ids] << audit_log.id
    batch[:last_updated] = Time.current

    # Store updated batch
    Rails.cache.write(cache_key, batch, expires_in: 1.hour)
  end

  def should_send_batch?(user)
    cache_key = "audit_notification_batch:#{user.id}"
    batch = Rails.cache.read(cache_key)

    return false unless batch

    # Send batch if:
    # - We have 5 or more notifications
    # - Or it's been 30 minutes since the first notification
    # - Or it's been 10 minutes since the last update
    batch[:audit_log_ids].size >= 5 ||
    batch[:created_at] < 30.minutes.ago ||
    batch[:last_updated] < 10.minutes.ago
  end

  def schedule_batch_processing(user)
    cache_key = "audit_notification_batch:#{user.id}"
    batch = Rails.cache.read(cache_key)

    return unless batch

    # Get audit logs for the batch
    audit_logs = AuditLog.where(id: batch[:audit_log_ids])

    # Send batched notification
    send_batched_notification(user, audit_logs)

    # Clear the batch
    Rails.cache.delete(cache_key)
  end

  def send_batched_notification(user, audit_logs)
    # Group audit logs by severity and category
    grouped_logs = group_audit_logs(audit_logs)

    # Send appropriate notification based on highest severity
    highest_severity = determine_highest_severity(audit_logs)

    case highest_severity
    when "critical"
      # Send individual critical alerts
      critical_logs = audit_logs.where(severity: "critical")
      critical_logs.each do |log|
        AuditNotificationMailer.critical_audit_alert(user, log).deliver_now
      end

      # Send summary for other logs if any
      other_logs = audit_logs.where.not(severity: "critical")
      if other_logs.any?
        AuditNotificationMailer.audit_digest(user, other_logs, period: "batch").deliver_now
      end
    when "error"
      # Send high priority notification
      AuditNotificationMailer.audit_digest(user, audit_logs, period: "batch").deliver_now
    else
      # Send regular digest
      AuditNotificationMailer.audit_digest(user, audit_logs, period: "batch").deliver_now
    end
  end

  def get_audit_logs_for_period(organization, period)
    start_time = case period
    when :hourly then 1.hour.ago
    when :daily then 1.day.ago
    when :weekly then 1.week.ago
    when :monthly then 1.month.ago
    else 1.day.ago
    end

    AuditLog.where(organization: organization)
            .where("created_at >= ?", start_time)
            .includes(:user, :auditable)
            .order(created_at: :desc)
  end

  def filter_logs_for_user(audit_logs, user)
    # Filter based on user's role and what they should see
    filtered = audit_logs.select do |log|
      user_can_view_audit_category?(user, log.category)
    end

    # Further filter based on user preferences
    if user.notification_preferences
      prefs = user.notification_preferences

      filtered = filtered.reject { |log| log.severity == "info" } unless prefs.info_alerts_enabled?
      filtered = filtered.reject { |log| log.severity == "warning" } unless prefs.warning_alerts_enabled?
      filtered = filtered.reject { |log| log.category == "authentication" } unless prefs.auth_alerts_enabled?
    end

    filtered
  end

  def group_audit_logs(audit_logs)
    {
      by_severity: audit_logs.group_by(&:severity),
      by_category: audit_logs.group_by(&:category),
      by_user: audit_logs.group_by { |log| log.user&.email || "System" },
      by_hour: audit_logs.group_by { |log| log.created_at.beginning_of_hour }
    }
  end

  def determine_highest_severity(audit_logs)
    severities = audit_logs.pluck(:severity).uniq

    return "critical" if severities.include?("critical")
    return "error" if severities.include?("error")
    return "warning" if severities.include?("warning")
    "info"
  end

  def duplicate_notification_exists?(user, audit_log)
    # Check if we've already sent a notification for this exact audit log
    cache_key = "audit_notification:#{user.id}:#{audit_log.id}"
    Rails.cache.exist?(cache_key)
  end

  def mark_notification_sent(user, audit_log)
    cache_key = "audit_notification:#{user.id}:#{audit_log.id}"
    Rails.cache.write(cache_key, true, expires_in: 24.hours)
  end

  def log_digest_sent(user, log_count, period)
    AuditLog.create!(
      user: nil, # System-generated
      organization: user.organization,
      action: "audit_digest_sent",
      category: "system_access",
      resource_type: "AuditDigest",
      severity: "info",
      details: {
        recipient_email: user.email,
        log_count: log_count,
        digest_period: period,
        sent_at: Time.current
      }
    )
  end

  # Class method to schedule periodic digests
  def self.schedule_periodic_digests
    # Schedule daily digests for all active users who want them
    User.joins(:notification_preferences)
        .where(notification_preferences: { audit_digest_enabled: true })
        .where(active: true)
        .find_each do |user|
      AuditDigestJob.perform_later(user.id)
    end
  end

  # Class method to schedule weekly digests
  def self.schedule_weekly_digests
    User.joins(:notification_preferences)
        .where(notification_preferences: { weekly_digest_enabled: true })
        .where(active: true)
        .find_each do |user|
      # Generate weekly digest
      audit_logs = get_audit_logs_for_period(user.organization, :weekly)
      filtered_logs = filter_logs_for_user(audit_logs, user)

      if filtered_logs.any?
        AuditNotificationMailer.audit_digest(user, filtered_logs, period: "weekly").deliver_now
      end
    end
  end
end
