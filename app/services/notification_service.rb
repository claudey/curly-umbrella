class NotificationService
  def self.send_application_notification(application:, recipient:, event:)
    new(application: application, recipient: recipient, event: event).send_notification
  end

  def self.send_quote_notification(quote:, recipient:, event:)
    new(quote: quote, recipient: recipient, event: event).send_notification
  end

  def self.send_user_notification(recipient:, event:, **options)
    new(recipient: recipient, event: event, **options).send_notification
  end

  attr_reader :application, :quote, :recipient, :event, :options

  def initialize(application: nil, quote: nil, recipient:, event:, **options)
    @application = application
    @quote = quote
    @recipient = recipient
    @event = event.to_s
    @options = options
  end

  def send_notification
    return unless recipient&.persisted?

    # Check user's notification preferences
    preferences = recipient.notification_preferences

    # Send email notification if enabled
    if should_send_email?(preferences)
      send_email_notification
    end

    # Send SMS notification if enabled
    if should_send_sms?(preferences)
      send_sms_notification
    end

    # Send WhatsApp notification if enabled
    if should_send_whatsapp?(preferences)
      send_whatsapp_notification
    end

    # Create in-app notification record
    create_notification_record
  end

  private

  def should_send_email?(preferences)
    return true unless preferences # Default to true if no preferences set
    preferences.email_enabled? && preferences.send_email_for?(event)
  end

  def should_send_sms?(preferences)
    return false unless preferences&.sms_enabled?
    recipient.can_receive_sms? && preferences.send_sms_for?(event)
  end

  def should_send_whatsapp?(preferences)
    return false unless preferences&.whatsapp_enabled?
    recipient.can_receive_whatsapp? && preferences.send_whatsapp_for?(event)
  end

  def send_email_notification
    case event
    when "application_submitted"
      ApplicationMailer.application_submitted(application, recipient).deliver_later
    when "application_status_updated"
      ApplicationMailer.status_updated(application, recipient, options[:old_status], options[:new_status]).deliver_later
    when "quote_received"
      QuoteMailer.quote_received(quote, recipient).deliver_later
    when "quote_deadline_reminder"
      QuoteMailer.deadline_reminder(quote, recipient).deliver_later
    when "user_invited"
      UserMailer.invitation_email(recipient, options[:invitation_token]).deliver_later
    when "mfa_enabled"
      UserMailer.mfa_enabled(recipient).deliver_later
    when "password_changed"
      UserMailer.password_changed(recipient).deliver_later
    else
      Rails.logger.warn "Unknown email notification event: #{event}"
    end
  end

  def send_sms_notification
    case event
    when "application_submitted"
      SmsNotificationJob.perform_later("application_submitted", recipient.id, application.id)
    when "application_status_updated"
      SmsNotificationJob.perform_later("application_status_update", recipient.id, application.id, options[:old_status], options[:new_status])
    when "quote_received"
      SmsNotificationJob.perform_later("quote_received", recipient.id, quote.id)
    when "quote_deadline_reminder"
      SmsNotificationJob.perform_later("quote_deadline_reminder", recipient.id, quote.id)
    when "verification_code"
      SmsNotificationJob.perform_later("verification_code", recipient.id, options[:code])
    when "urgent_notification"
      # Send immediately for urgent notifications
      recipient.send_sms(body: options[:message])
    else
      Rails.logger.warn "Unknown SMS notification event: #{event}"
    end
  end

  def send_whatsapp_notification
    case event
    when "application_submitted"
      WhatsappNotificationJob.perform_later("application_submitted", recipient.id, application.id)
    when "application_status_updated"
      WhatsappNotificationJob.perform_later("application_status_update", recipient.id, application.id, options[:old_status], options[:new_status])
    when "quote_received"
      WhatsappNotificationJob.perform_later("quote_received", recipient.id, quote.id)
    when "quote_deadline_reminder"
      WhatsappNotificationJob.perform_later("quote_deadline_reminder", recipient.id, quote.id)
    when "urgent_notification"
      WhatsappNotificationJob.perform_later("urgent_notification", recipient.id, options[:message])
    else
      Rails.logger.warn "Unknown WhatsApp notification event: #{event}"
    end
  end

  def create_notification_record
    notification_data = {
      user: recipient,
      organization: recipient.organization,
      notification_type: event,
      title: notification_title,
      message: notification_message,
      read: false,
      created_at: Time.current
    }

    # Add contextual data
    if application
      notification_data[:related_type] = "InsuranceApplication"
      notification_data[:related_id] = application.id
    elsif quote
      notification_data[:related_type] = "Quote"
      notification_data[:related_id] = quote.id
    end

    Notification.create!(notification_data)
  end

  def notification_title
    case event
    when "application_submitted"
      "New Application Submitted"
    when "application_status_updated"
      "Application Status Updated"
    when "quote_received"
      "New Quote Received"
    when "quote_deadline_reminder"
      "Quote Deadline Reminder"
    when "user_invited"
      "You've been invited to join #{recipient.organization.name}"
    when "mfa_enabled"
      "Two-Factor Authentication Enabled"
    when "password_changed"
      "Password Changed"
    else
      event.humanize
    end
  end

  def notification_message
    case event
    when "application_submitted"
      "Application ##{application.id} for #{application.client_name} has been submitted."
    when "application_status_updated"
      "Application ##{application.id} status has been updated to #{options[:new_status].humanize}."
    when "quote_received"
      "A new quote has been received for application ##{quote.application_id}."
    when "quote_deadline_reminder"
      deadline_text = if quote.deadline == Date.current
        "today"
      elsif quote.deadline < Date.current
        "#{(Date.current - quote.deadline).to_i} day(s) ago"
      else
        "in #{(quote.deadline - Date.current).to_i} day(s)"
      end
      "Quote deadline for application ##{quote.application_id} is #{deadline_text}."
    when "user_invited"
      "You have been invited to join #{recipient.organization.name} as a #{recipient.role.humanize}."
    when "mfa_enabled"
      "Two-factor authentication has been successfully enabled for your account."
    when "password_changed"
      "Your password has been successfully changed."
    else
      options[:message] || "You have a new notification."
    end
  end
end
