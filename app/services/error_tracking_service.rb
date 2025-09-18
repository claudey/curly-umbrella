# frozen_string_literal: true

class ErrorTrackingService
  include ActiveModel::Model

  # Error severity levels
  SEVERITY_LEVELS = {
    low: "low",
    medium: "medium",
    high: "high",
    critical: "critical"
  }.freeze

  # Error categories for classification
  ERROR_CATEGORIES = {
    application: "application_error",
    database: "database_error",
    network: "network_error",
    authentication: "authentication_error",
    authorization: "authorization_error",
    validation: "validation_error",
    external_service: "external_service_error",
    performance: "performance_error",
    security: "security_error",
    business_logic: "business_logic_error"
  }.freeze

  def self.track_error(exception, context = {})
    new.track_error(exception, context)
  end

  def self.track_custom_error(message, severity: :medium, category: :application, context: {})
    new.track_custom_error(message, severity, category, context)
  end

  def track_error(exception, context = {})
    # Determine error details
    error_details = extract_error_details(exception, context)

    # Create error record
    error_record = create_error_record(error_details)

    # Send notifications if severe enough
    send_error_notifications(error_record) if should_notify?(error_record)

    # Update error metrics
    update_error_metrics(error_record)

    # Log to audit system
    log_to_audit_system(error_record, exception, context)

    error_record
  rescue => nested_error
    # Fallback logging to prevent infinite loops
    Rails.logger.error "ErrorTrackingService failed: #{nested_error.message}"
    Rails.logger.error "Original error: #{exception}" if exception
  end

  def track_custom_error(message, severity, category, context)
    error_details = {
      message: message,
      severity: severity.to_s,
      category: category.to_s,
      occurred_at: Time.current,
      context: context,
      custom: true
    }

    error_record = create_error_record(error_details)
    send_error_notifications(error_record) if should_notify?(error_record)
    update_error_metrics(error_record)

    error_record
  end

  private

  def extract_error_details(exception, context)
    {
      exception_class: exception.class.name,
      message: exception.message,
      backtrace: clean_backtrace(exception.backtrace),
      severity: determine_severity(exception),
      category: determine_category(exception),
      occurred_at: Time.current,
      fingerprint: generate_fingerprint(exception),
      context: enrich_context(context),
      environment: Rails.env,
      application_version: app_version,
      request_id: context[:request_id] || Current.request_id
    }
  end

  def determine_severity(exception)
    case exception
    when SecurityError, NoMethodError, SystemStackError
      "critical"
    when ActiveRecord::RecordNotFound, ActionController::RoutingError
      "low"
    when ActiveRecord::ConnectionNotEstablished, Redis::CannotConnectError
      "high"
    when StandardError
      "medium"
    else
      "medium"
    end
  end

  def determine_category(exception)
    case exception
    when ActiveRecord::ActiveRecordError, PG::Error
      "database"
    when Net::TimeoutError, Timeout::Error, SocketError
      "network"
    when SecurityError, CanCan::AccessDenied
      "security"
    when Devise::InvalidAuthenticityToken
      "authentication"
    when ActionController::ParameterMissing, ActiveRecord::RecordInvalid
      "validation"
    when NoMethodError, ArgumentError, TypeError
      "application"
    else
      "application"
    end
  end

  def generate_fingerprint(exception)
    # Create a unique fingerprint for grouping similar errors
    content = "#{exception.class.name}:#{exception.message}"

    # Include relevant backtrace lines (app code only)
    app_backtrace = exception.backtrace&.select { |line| line.include?(Rails.root.to_s) }&.first(3)
    content += ":#{app_backtrace.join('|')}" if app_backtrace&.any?

    Digest::SHA256.hexdigest(content)
  end

  def clean_backtrace(backtrace)
    return [] unless backtrace

    # Filter out gem paths and system paths, keep app code
    app_root = Rails.root.to_s
    filtered = backtrace.select { |line| line.include?(app_root) }

    # Limit to first 20 lines to avoid huge backtraces
    filtered.first(20).map do |line|
      line.gsub(app_root + "/", "")
    end
  end

  def enrich_context(context)
    enriched = context.dup

    # Add current user info
    if Current.user
      enriched[:user_id] = Current.user.id
      enriched[:user_email] = Current.user.email
      enriched[:organization_id] = Current.user.organization_id
    end

    # Add request info
    enriched[:ip_address] = Current.ip_address if Current.ip_address
    enriched[:user_agent] = Current.user_agent if Current.user_agent
    enriched[:controller] = Current.controller if Current.controller
    enriched[:action] = Current.action if Current.action
    enriched[:request_path] = Current.request_path if Current.request_path
    enriched[:request_method] = Current.request_method if Current.request_method

    # Add system info
    enriched[:hostname] = Socket.gethostname
    enriched[:process_id] = Process.pid
    enriched[:memory_usage] = get_memory_usage

    enriched
  end

  def create_error_record(error_details)
    ErrorReport.create!(
      exception_class: error_details[:exception_class] || "CustomError",
      message: error_details[:message],
      severity: error_details[:severity],
      category: error_details[:category],
      fingerprint: error_details[:fingerprint] || generate_custom_fingerprint(error_details),
      backtrace: error_details[:backtrace] || [],
      context: error_details[:context] || {},
      occurred_at: error_details[:occurred_at],
      environment: error_details[:environment] || Rails.env,
      application_version: error_details[:application_version] || app_version,
      request_id: error_details[:request_id],
      user_id: error_details.dig(:context, :user_id),
      organization_id: error_details.dig(:context, :organization_id),
      resolved: false
    )
  end

  def should_notify?(error_record)
    # Always notify for critical errors
    return true if error_record.severity == "critical"

    # Notify for high severity errors
    return true if error_record.severity == "high"

    # Check if this is a new error pattern (first occurrence)
    return true if first_occurrence?(error_record)

    # Check if error frequency is increasing
    return true if error_frequency_increasing?(error_record)

    false
  end

  def first_occurrence?(error_record)
    ErrorReport.where(fingerprint: error_record.fingerprint)
               .where("occurred_at < ?", error_record.occurred_at)
               .empty?
  end

  def error_frequency_increasing?(error_record)
    # Check if this error has occurred more than 5 times in the last hour
    recent_count = ErrorReport.where(fingerprint: error_record.fingerprint)
                             .where("occurred_at > ?", 1.hour.ago)
                             .count

    recent_count > 5
  end

  def send_error_notifications(error_record)
    # Send to appropriate stakeholders based on severity and category
    recipients = determine_error_recipients(error_record)

    recipients.each do |user|
      # Send email notification
      ErrorNotificationMailer.error_alert(user, error_record).deliver_later(priority: notification_priority(error_record))

      # Create in-app notification
      create_error_notification(user, error_record)
    end

    # Send to external monitoring services if configured
    send_to_external_services(error_record)

    # Create security alert for security-related errors
    create_security_alert(error_record) if error_record.category == "security"
  end

  def determine_error_recipients(error_record)
    recipients = []

    case error_record.severity
    when "critical"
      # Critical errors go to all admins and on-call team
      recipients.concat(get_admin_users)
      recipients.concat(get_on_call_users)
    when "high"
      # High severity goes to admins and developers
      recipients.concat(get_admin_users)
      recipients.concat(get_developer_users)
    when "medium"
      # Medium severity goes to developers during business hours
      recipients.concat(get_developer_users) if business_hours?
    end

    # Category-specific recipients
    case error_record.category
    when "security"
      recipients.concat(get_security_team)
    when "database"
      recipients.concat(get_database_admins)
    when "external_service"
      recipients.concat(get_integration_team)
    end

    recipients.uniq
  end

  def update_error_metrics(error_record)
    # Update Redis-based metrics for real-time dashboards
    return unless Rails.cache.respond_to?(:redis)

    date_key = error_record.occurred_at.strftime("%Y-%m-%d")
    hour_key = error_record.occurred_at.strftime("%Y-%m-%d:%H")

    # Daily metrics
    Rails.cache.increment("errors:daily:#{date_key}:total", 1)
    Rails.cache.increment("errors:daily:#{date_key}:severity:#{error_record.severity}", 1)
    Rails.cache.increment("errors:daily:#{date_key}:category:#{error_record.category}", 1)

    # Hourly metrics
    Rails.cache.increment("errors:hourly:#{hour_key}:total", 1)
    Rails.cache.increment("errors:hourly:#{hour_key}:severity:#{error_record.severity}", 1)

    # Fingerprint tracking
    Rails.cache.increment("errors:fingerprint:#{error_record.fingerprint}:count", 1)
    Rails.cache.write("errors:fingerprint:#{error_record.fingerprint}:last_seen", Time.current, expires_in: 30.days)

    # Set expiration for cleanup
    Rails.cache.expire("errors:daily:#{date_key}:total", 90.days)
    Rails.cache.expire("errors:hourly:#{hour_key}:total", 7.days)
  end

  def log_to_audit_system(error_record, exception, context)
    AuditLog.create!(
      user: Current.user,
      organization_id: error_record.organization_id,
      action: "error_occurred",
      category: "system_access",
      resource_type: "ErrorReport",
      resource_id: error_record.id,
      severity: map_severity_to_audit(error_record.severity),
      details: {
        error_id: error_record.id,
        exception_class: error_record.exception_class,
        message: error_record.message.truncate(500),
        fingerprint: error_record.fingerprint,
        category: error_record.category,
        request_id: error_record.request_id,
        user_affected: context[:user_id].present?
      },
      ip_address: context[:ip_address]
    )
  rescue => e
    Rails.logger.error "Failed to create audit log for error: #{e.message}"
  end

  def create_error_notification(user, error_record)
    Notification.create!(
      user: user,
      organization: user.organization,
      title: "🚨 #{error_record.severity.humanize} Error Detected",
      message: "#{error_record.exception_class}: #{error_record.message.truncate(100)}",
      notification_type: "error_alert",
      priority: error_record.severity,
      data: {
        error_id: error_record.id,
        severity: error_record.severity,
        category: error_record.category,
        fingerprint: error_record.fingerprint
      }
    )
  rescue => e
    Rails.logger.error "Failed to create error notification: #{e.message}"
  end

  def create_security_alert(error_record)
    return unless defined?(SecurityAlert)

    SecurityAlert.create!(
      organization_id: error_record.organization_id,
      alert_type: "application_error",
      severity: error_record.severity == "critical" ? "critical" : "high",
      status: "active",
      message: "Security-related application error: #{error_record.exception_class}",
      data: {
        error_id: error_record.id,
        exception_class: error_record.exception_class,
        message: error_record.message,
        category: error_record.category,
        fingerprint: error_record.fingerprint,
        context: error_record.context
      },
      triggered_at: error_record.occurred_at
    )
  rescue => e
    Rails.logger.error "Failed to create security alert for error: #{e.message}"
  end

  # Helper methods
  def generate_custom_fingerprint(error_details)
    content = "#{error_details[:message]}:#{error_details[:category]}"
    Digest::SHA256.hexdigest(content)
  end

  def app_version
    Rails.application.config.version rescue "1.0.0"
  end

  def get_memory_usage
    return nil unless defined?(GetProcessMem)
    GetProcessMem.new.mb.round(2)
  rescue
    nil
  end

  def notification_priority(error_record)
    case error_record.severity
    when "critical" then 20
    when "high" then 15
    when "medium" then 10
    else 5
    end
  end

  def map_severity_to_audit(severity)
    case severity
    when "critical" then "critical"
    when "high" then "error"
    when "medium" then "warning"
    else "info"
    end
  end

  def business_hours?
    time = Time.current
    time.hour.between?(9, 17) && time.wday.between?(1, 5)
  end

  def send_to_external_services(error_record)
    # Hook for external services like Bugsnag, Sentry, etc.
    # This would be implemented based on configured services

    if defined?(Bugsnag)
      Bugsnag.notify(StandardError.new(error_record.message)) do |report|
        report.severity = error_record.severity
        report.add_metadata(:error_details, error_record.context)
      end
    end

    # Add other external service integrations here
  end

  # User group methods - these would be implemented based on your user role system
  def get_admin_users
    User.joins(:user_roles).where(user_roles: { role: [ "admin", "super_admin" ] }).where(active: true)
  end

  def get_developer_users
    User.joins(:user_roles).where(user_roles: { role: "developer" }).where(active: true)
  end

  def get_on_call_users
    # This would integrate with your on-call system
    get_admin_users.limit(2) # Fallback to first 2 admins
  end

  def get_security_team
    User.joins(:user_roles).where(user_roles: { role: "security_admin" }).where(active: true)
  end

  def get_database_admins
    User.joins(:user_roles).where(user_roles: { role: "database_admin" }).where(active: true)
  end

  def get_integration_team
    User.joins(:user_roles).where(user_roles: { role: "integration_admin" }).where(active: true)
  end
end
