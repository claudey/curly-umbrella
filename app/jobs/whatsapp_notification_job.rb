class WhatsappNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification_type, recipient_id, *args)
    recipient = User.find(recipient_id)
    return unless recipient.can_receive_whatsapp?

    ActsAsTenant.with_tenant(recipient.organization) do
      case notification_type.to_s
      when "application_submitted"
        handle_application_submitted(recipient, *args)
      when "quote_received"
        handle_quote_received(recipient, *args)
      when "quote_deadline_reminder"
        handle_quote_deadline_reminder(recipient, *args)
      when "application_status_update"
        handle_application_status_update(recipient, *args)
      when "urgent_notification"
        handle_urgent_notification(recipient, *args)
      else
        Rails.logger.warn "Unknown WhatsApp notification type: #{notification_type}"
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "WhatsApp notification failed - User not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "WhatsApp notification failed: #{e.message}"
    raise e
  end

  private

  def handle_application_submitted(recipient, application_id)
    application = InsuranceApplication.find(application_id)
    WhatsappService.new.send_application_notification(
      user: recipient,
      application: application
    )
  end

  def handle_quote_received(recipient, quote_id)
    quote = Quote.find(quote_id)
    application = quote.application

    message = "💰 *New Quote Available*\n\n" \
              "Application ID: ##{application.id}\n" \
              "Client: #{application.client_name}\n" \
              "Insurance Type: #{application.insurance_type.humanize}\n" \
              "Quote Amount: #{number_to_currency(quote.quote_amount)}\n\n" \
              "📋 *Quote Details:*\n" \
              "Coverage: #{quote.coverage_details}\n" \
              "Deadline: #{quote.deadline.strftime('%B %d, %Y')}\n\n" \
              "Please review this quote in your dashboard."

    WhatsappService.new.send_message(
      to: recipient.whatsapp_number,
      message: message
    )
  end

  def handle_quote_deadline_reminder(recipient, quote_id)
    quote = Quote.find(quote_id)
    WhatsappService.new.send_quote_reminder(
      user: recipient,
      quote: quote
    )
  end

  def handle_application_status_update(recipient, application_id, old_status, new_status)
    application = InsuranceApplication.find(application_id)

    status_emoji = case new_status
    when "approved" then "✅"
    when "rejected" then "❌"
    when "under_review" then "👀"
    when "pending_documents" then "📄"
    else "📋"
    end

    message = "#{status_emoji} *Application Status Update*\n\n" \
              "Application ID: ##{application.id}\n" \
              "Client: #{application.client_name}\n" \
              "Previous Status: #{old_status.humanize}\n" \
              "New Status: #{new_status.humanize}\n\n"

    case new_status
    when "approved"
      message += "🎉 Congratulations! The application has been approved. Contract generation will begin shortly."
    when "rejected"
      message += "❗ The application has been rejected. Please contact support for more information."
    when "pending_documents"
      message += "📎 Additional documents are required. Please check your dashboard for details."
    else
      message += "Please check your dashboard for more details about this status change."
    end

    WhatsappService.new.send_message(
      to: recipient.whatsapp_number,
      message: message
    )
  end

  def handle_urgent_notification(recipient, message_text)
    urgent_message = "🚨 *URGENT NOTIFICATION*\n\n#{message_text}\n\n" \
                     "This message requires immediate attention. Please log in to your dashboard or contact support if needed."

    WhatsappService.new.send_message(
      to: recipient.whatsapp_number,
      message: urgent_message
    )
  end

  def number_to_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount)
  end
end
