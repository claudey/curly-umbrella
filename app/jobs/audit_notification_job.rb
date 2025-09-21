# frozen_string_literal: true

class AuditNotificationJob < ApplicationJob
  queue_as :high_priority

  retry_on StandardError, wait: 1.minute, attempts: 3

  def perform(audit_log_id)
    audit_log = AuditLog.find_by(id: audit_log_id)
    return unless audit_log

    # Process the audit notification
    AuditNotificationService.process_audit_event(audit_log)

    # Update the audit log to indicate notification was processed
    audit_log.update_column(:notification_sent_at, Time.current) if audit_log.respond_to?(:notification_sent_at)

  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "AuditNotificationJob: Audit log #{audit_log_id} not found"
  rescue => e
    Rails.logger.error "AuditNotificationJob failed for audit log #{audit_log_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Create a system audit log for the failure
    create_notification_failure_log(audit_log_id, e) if audit_log

    raise # Re-raise to trigger retry mechanism
  end

  private

  def create_notification_failure_log(audit_log_id, error)
    AuditLog.create!(
      user: nil, # System-generated
      action: "audit_notification_failed",
      category: "system_access",
      resource_type: "AuditNotification",
      resource_id: audit_log_id,
      severity: "error",
      details: {
        original_audit_log_id: audit_log_id,
        error_class: error.class.name,
        error_message: error.message,
        failed_at: Time.current,
        job_class: self.class.name
      }
    )
  rescue => nested_error
    Rails.logger.error "Failed to create notification failure log: #{nested_error.message}"
  end
end
