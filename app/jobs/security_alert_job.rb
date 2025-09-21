# frozen_string_literal: true

class SecurityAlertJob < ApplicationJob
  queue_as :critical

  def perform(alert_type, message, data, severity, organization_id = nil)
    organization = organization_id ? Organization.find(organization_id) : ActsAsTenant.current_tenant

    return unless organization

    # Create the security alert
    alert = SecurityAlert.create!(
      organization: organization,
      alert_type: alert_type,
      message: message,
      data: data || {},
      severity: severity,
      status: "active",
      triggered_at: Time.current
    )

    # Send notifications for critical alerts
    if alert.severity == "critical"
      send_critical_alert_notifications(alert)
    end

    # Auto-resolve certain low-priority alerts after creating them
    if alert.auto_resolvable? && alert.severity == "low"
      auto_resolve_alert(alert)
    end

    alert
  rescue StandardError => e
    Rails.logger.error "SecurityAlertJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def send_critical_alert_notifications(alert)
    # Find admin users to notify
    admin_users = alert.organization.users
                      .joins(:user_roles)
                      .where(user_roles: { role: [ "super_admin", "admin" ] })
                      .where(active: true)

    admin_users.each do |user|
      SecurityMailer.critical_security_alert(user, alert).deliver_now
    end
  end

  def auto_resolve_alert(alert)
    # Auto-resolve certain types of alerts that are just informational
    alert.update!(
      status: "resolved",
      resolved_at: Time.current,
      resolution_notes: "Auto-resolved: Low priority informational alert"
    )
  end
end
