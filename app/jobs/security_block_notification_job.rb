# frozen_string_literal: true

class SecurityBlockNotificationJob < ApplicationJob
  queue_as :default

  def perform(ip_address, reason, permanent, duration)
    # Send notification to security team about IP blocks

    # Find admin users to notify
    admin_users = User.joins(:user_roles)
                     .where(user_roles: { role: [ "super_admin", "admin" ] })
                     .where(active: true)

    admin_users.each do |user|
      SecurityMailer.ip_block_notification(user, ip_address, reason, permanent, duration).deliver_now
    end

    # Log the notification
    Rails.logger.info "IP block notification sent for #{ip_address} - Reason: #{reason}"

    # Create a security alert for the block
    SecurityAlertJob.perform_later(
      "ip_blocked",
      "IP address blocked: #{ip_address}",
      {
        ip_address: ip_address,
        reason: reason,
        permanent: permanent,
        duration: duration,
        blocked_at: Time.current
      },
      permanent ? "high" : "medium"
    )

  rescue StandardError => e
    Rails.logger.error "SecurityBlockNotificationJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
