# frozen_string_literal: true

class IntegratedNotificationService
  include ActiveModel::Model

  def self.process_document_event(document, event_type, **options)
    new.process_document_event(document, event_type, **options)
  end

  def self.process_application_event(application, event_type, **options)
    new.process_application_event(application, event_type, **options)
  end

  def self.process_quote_event(quote, event_type, **options)
    new.process_quote_event(quote, event_type, **options)
  end

  def self.process_user_event(user, event_type, **options)
    new.process_user_event(user, event_type, **options)
  end

  def process_document_event(document, event_type, **options)
    # Create audit log first
    create_document_audit_log(document, event_type, options)

    # Process through existing document notification service
    case event_type
    when :uploaded
      DocumentNotificationService.notify_document_uploaded(document)
    when :updated
      DocumentNotificationService.notify_document_updated(document)
    when :archived
      DocumentNotificationService.notify_document_archived(document, options[:archived_by])
    when :restored
      DocumentNotificationService.notify_document_restored(document, options[:restored_by])
    when :expiring
      DocumentNotificationService.notify_document_expiring(document)
    when :expired
      DocumentNotificationService.notify_document_expired(document)
    when :version_created
      DocumentNotificationService.notify_new_version_created(document)
    when :shared
      DocumentNotificationService.notify_document_shared(document, options[:shared_with], options[:shared_by])
    when :deleted
      process_document_deletion(document, options)
    when :compliance_flagged
      process_compliance_flagged_document(document, options)
    end

    # Create system notifications for critical events
    create_system_notifications(document, event_type, options) if critical_document_event?(event_type)

    # Send security alerts if needed
    create_security_alerts(document, event_type, options) if security_sensitive_event?(event_type)
  end

  def process_application_event(application, event_type, **options)
    # Create audit log
    create_application_audit_log(application, event_type, options)

    case event_type
    when :submitted
      notify_application_submitted(application)
    when :approved
      notify_application_approved(application, options[:approved_by])
    when :rejected
      notify_application_rejected(application, options[:rejected_by], options[:reason])
    when :distributed
      notify_application_distributed(application, options[:companies])
    when :deadline_approaching
      notify_application_deadline_approaching(application)
    when :deadline_missed
      notify_application_deadline_missed(application)
    when :bulk_operation
      notify_bulk_application_operation(application, options)
    end
  end

  def process_quote_event(quote, event_type, **options)
    # Create audit log
    create_quote_audit_log(quote, event_type, options)

    case event_type
    when :received
      notify_quote_received(quote)
    when :accepted
      notify_quote_accepted(quote, options[:accepted_by])
    when :rejected
      notify_quote_rejected(quote, options[:rejected_by], options[:reason])
    when :expiring
      notify_quote_expiring(quote)
    when :expired
      notify_quote_expired(quote)
    when :premium_changed
      notify_quote_premium_changed(quote, options[:old_premium], options[:new_premium])
    end
  end

  def process_user_event(user, event_type, **options)
    # Create audit log
    create_user_audit_log(user, event_type, options)

    case event_type
    when :role_changed
      notify_user_role_changed(user, options[:old_role], options[:new_role], options[:changed_by])
    when :permissions_changed
      notify_user_permissions_changed(user, options[:permissions], options[:changed_by])
    when :account_locked
      notify_user_account_locked(user, options[:reason])
    when :account_unlocked
      notify_user_account_unlocked(user, options[:unlocked_by])
    when :suspicious_activity
      notify_suspicious_user_activity(user, options[:activity_details])
    end
  end

  private

  # Document event processors
  def process_document_deletion(document, options)
    recipients = determine_critical_recipients(document.organization)

    recipients.each do |user|
      create_notification(
        user: user,
        type: "document_deleted",
        title: "🗑️ Document Deleted: #{document.name}",
        message: "Document '#{document.name}' was permanently deleted by #{options[:deleted_by]&.full_name || 'System'}.",
        priority: "high",
        data: {
          document_name: document.name,
          document_type: document.document_type,
          deleted_by: options[:deleted_by]&.full_name,
          deleted_at: Time.current,
          original_location: document.file_path
        }
      )
    end

    # Send email for compliance-sensitive documents
    if compliance_sensitive_document?(document)
      ComplianceMailer.document_deleted_alert(recipients, document, options[:deleted_by]).deliver_now
    end
  end

  def process_compliance_flagged_document(document, options)
    compliance_officers = get_compliance_officers(document.organization)
    admins = get_organization_admins(document.organization)
    recipients = (compliance_officers + admins).uniq

    recipients.each do |user|
      create_notification(
        user: user,
        type: "compliance_alert",
        title: "⚠️ Compliance Issue: #{document.name}",
        message: "Document flagged for compliance review: #{options[:flag_reason]}",
        priority: "critical",
        data: {
          document_id: document.id,
          flag_reason: options[:flag_reason],
          flagged_by: options[:flagged_by]&.full_name,
          severity: options[:severity] || "medium"
        }
      )
    end
  end

  # Application event processors
  def notify_application_submitted(application)
    admins = get_organization_admins(application.organization)

    admins.each do |user|
      create_notification(
        user: user,
        type: "application_submitted",
        title: "📋 New Application: #{application.insurance_type.humanize}",
        message: "#{application.user.full_name} submitted a new #{application.insurance_type} insurance application.",
        data: {
          application_id: application.id,
          insurance_type: application.insurance_type,
          client_name: application.client&.full_name,
          submitted_at: application.created_at
        }
      )
    end
  end

  def notify_application_deadline_approaching(application)
    stakeholders = [ application.user, *get_organization_admins(application.organization) ].uniq

    stakeholders.each do |user|
      create_notification(
        user: user,
        type: "deadline_approaching",
        title: "⏰ Application Deadline Approaching",
        message: "Insurance application for #{application.client&.full_name} has a deadline in 24 hours.",
        priority: "high",
        data: {
          application_id: application.id,
          deadline: application.deadline,
          time_remaining: time_until_deadline(application.deadline)
        }
      )
    end
  end

  def notify_bulk_application_operation(application, options)
    security_admins = get_security_admins(application.organization)

    security_admins.each do |user|
      create_notification(
        user: user,
        type: "bulk_operation_alert",
        title: "🔒 Bulk Operation Detected",
        message: "#{options[:operation_type]} performed on #{options[:count]} applications by #{options[:performed_by]&.full_name}.",
        priority: "high",
        data: {
          operation_type: options[:operation_type],
          affected_count: options[:count],
          performed_by: options[:performed_by]&.full_name,
          timestamp: Time.current
        }
      )
    end
  end

  # Quote event processors
  def notify_quote_received(quote)
    stakeholders = [ quote.insurance_application.user, *get_organization_admins(quote.organization) ].uniq

    stakeholders.each do |user|
      create_notification(
        user: user,
        type: "quote_received",
        title: "💰 New Quote Received",
        message: "#{quote.insurance_company.name} submitted a quote for #{quote.insurance_application.client&.full_name}.",
        data: {
          quote_id: quote.id,
          company_name: quote.insurance_company.name,
          premium_amount: quote.premium_amount,
          application_id: quote.insurance_application.id
        }
      )
    end
  end

  def notify_quote_premium_changed(quote, old_premium, new_premium)
    stakeholders = [ quote.insurance_application.user, *get_organization_admins(quote.organization) ].uniq

    stakeholders.each do |user|
      create_notification(
        user: user,
        type: "quote_premium_changed",
        title: "📊 Quote Premium Updated",
        message: "#{quote.insurance_company.name} updated their quote premium from $#{old_premium} to $#{new_premium}.",
        data: {
          quote_id: quote.id,
          old_premium: old_premium,
          new_premium: new_premium,
          change_amount: new_premium - old_premium,
          company_name: quote.insurance_company.name
        }
      )
    end
  end

  # User event processors
  def notify_user_role_changed(user, old_role, new_role, changed_by)
    admins = get_organization_admins(user.organization)

    admins.each do |admin|
      next if admin == changed_by # Don't notify the person who made the change

      create_notification(
        user: admin,
        type: "user_role_changed",
        title: "👤 User Role Changed",
        message: "#{user.full_name}'s role was changed from #{old_role} to #{new_role} by #{changed_by.full_name}.",
        priority: "medium",
        data: {
          affected_user_id: user.id,
          old_role: old_role,
          new_role: new_role,
          changed_by: changed_by.full_name,
          changed_at: Time.current
        }
      )
    end
  end

  def notify_suspicious_user_activity(user, activity_details)
    security_admins = get_security_admins(user.organization)

    security_admins.each do |admin|
      create_notification(
        user: admin,
        type: "security_alert",
        title: "🚨 Suspicious Activity Detected",
        message: "Suspicious activity detected for user #{user.full_name}: #{activity_details[:summary]}",
        priority: "critical",
        data: {
          affected_user_id: user.id,
          activity_type: activity_details[:type],
          severity: activity_details[:severity],
          details: activity_details,
          detected_at: Time.current
        }
      )
    end
  end

  # Audit log creation methods
  def create_document_audit_log(document, event_type, options)
    AuditLog.log_data_modification(
      options[:user] || Current.user,
      document,
      event_type.to_s,
      options[:changes] || {},
      {
        event_type: event_type,
        document_type: document.document_type,
        file_size: document.file_size,
        **options.except(:user, :changes)
      }
    )
  end

  def create_application_audit_log(application, event_type, options)
    AuditLog.log_data_modification(
      options[:user] || Current.user,
      application,
      event_type.to_s,
      options[:changes] || {},
      {
        event_type: event_type,
        insurance_type: application.insurance_type,
        client_id: application.client_id,
        **options.except(:user, :changes)
      }
    )
  end

  def create_quote_audit_log(quote, event_type, options)
    AuditLog.log_financial_transaction(
      options[:user] || Current.user,
      quote,
      event_type.to_s,
      quote.premium_amount,
      {
        event_type: event_type,
        company_name: quote.insurance_company.name,
        application_id: quote.insurance_application.id,
        **options.except(:user, :changes)
      }
    )
  end

  def create_user_audit_log(user, event_type, options)
    AuditLog.create!(
      user: options[:user] || Current.user,
      organization: user.organization,
      auditable: user,
      action: event_type.to_s,
      category: "user_management",
      resource_type: "User",
      resource_id: user.id,
      severity: determine_user_event_severity(event_type),
      details: {
        event_type: event_type,
        affected_user_email: user.email,
        **options.except(:user)
      }
    )
  end

  # Helper methods
  def critical_document_event?(event_type)
    [ :deleted, :compliance_flagged, :expired, :security_breach ].include?(event_type)
  end

  def security_sensitive_event?(event_type)
    [ :deleted, :bulk_download, :unauthorized_access, :compliance_flagged ].include?(event_type)
  end

  def compliance_sensitive_document?(document)
    sensitive_types = %w[policy contract legal compliance certificate audit financial]
    sensitive_types.include?(document.document_type.downcase)
  end

  def determine_user_event_severity(event_type)
    case event_type
    when :suspicious_activity, :account_locked then "error"
    when :role_changed, :permissions_changed then "warning"
    else "info"
    end
  end

  def time_until_deadline(deadline)
    return "Past due" if deadline < Time.current

    distance = deadline - Time.current
    hours = (distance / 1.hour).round

    if hours < 24
      "#{hours} hours"
    else
      "#{(hours / 24).round} days"
    end
  end

  # Recipient determination methods
  def determine_critical_recipients(organization)
    get_organization_admins(organization) + get_compliance_officers(organization)
  end

  def get_organization_admins(organization)
    organization.users.joins(:user_roles)
               .where(user_roles: { role: [ "admin", "brokerage_admin" ] })
               .where(active: true)
  end

  def get_compliance_officers(organization)
    organization.users.joins(:user_roles)
               .where(user_roles: { role: "compliance_officer" })
               .where(active: true)
  end

  def get_security_admins(organization)
    organization.users.joins(:user_roles)
               .where(user_roles: { role: [ "security_admin", "admin" ] })
               .where(active: true)
  end

  def create_notification(user:, type:, title:, message:, priority: "medium", data: {})
    return unless defined?(Notification) && Notification.table_exists?

    Notification.create!(
      user: user,
      organization: user.organization,
      title: title,
      message: message,
      notification_type: type,
      priority: priority,
      data: data
    )
  rescue => e
    Rails.logger.error "Failed to create integrated notification: #{e.message}"
  end

  def create_system_notifications(resource, event_type, options)
    # Create high-priority system notifications for critical events
    return unless critical_document_event?(event_type)

    system_admins = User.joins(:user_roles)
                       .where(user_roles: { role: "super_admin" })
                       .where(active: true)

    system_admins.each do |admin|
      create_notification(
        user: admin,
        type: "system_alert",
        title: "🔔 System Alert: #{event_type.to_s.humanize}",
        message: "Critical event detected: #{resource.class.name} #{event_type}",
        priority: "critical",
        data: {
          resource_type: resource.class.name,
          resource_id: resource.id,
          event_type: event_type,
          timestamp: Time.current,
          **options
        }
      )
    end
  end

  def create_security_alerts(resource, event_type, options)
    return unless defined?(SecurityAlert) && SecurityAlert.table_exists?

    SecurityAlert.create!(
      organization: resource.try(:organization),
      alert_type: "integrated_#{event_type}",
      severity: determine_security_severity(event_type),
      status: "active",
      message: "#{resource.class.name} #{event_type} event detected",
      data: {
        resource_type: resource.class.name,
        resource_id: resource.id,
        event_type: event_type,
        **options
      },
      triggered_at: Time.current
    )
  end

  def determine_security_severity(event_type)
    case event_type
    when :deleted, :compliance_flagged, :bulk_download then "high"
    when :unauthorized_access, :security_breach then "critical"
    else "medium"
    end
  end
end
