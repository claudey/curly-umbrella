class SmsNotificationJob < ApplicationJob
  queue_as :default
  
  def perform(notification_type, recipient_id, *args)
    recipient = User.find(recipient_id)
    return unless recipient.can_receive_sms?
    
    ActsAsTenant.with_tenant(recipient.organization) do
      case notification_type.to_s
      when 'application_submitted'
        handle_application_submitted(recipient, *args)
      when 'quote_received'
        handle_quote_received(recipient, *args)
      when 'quote_deadline_reminder'
        handle_quote_deadline_reminder(recipient, *args)
      when 'application_status_update'
        handle_application_status_update(recipient, *args)
      when 'verification_code'
        handle_verification_code(recipient, *args)
      else
        Rails.logger.warn "Unknown SMS notification type: #{notification_type}"
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "SMS notification failed - User not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "SMS notification failed: #{e.message}"
    raise e
  end
  
  private
  
  def handle_application_submitted(recipient, application_id)
    application = InsuranceApplication.find(application_id)
    SmsService.new.send_application_notification(
      user: recipient,
      application: application
    )
  end
  
  def handle_quote_received(recipient, quote_id)
    quote = Quote.find(quote_id)
    body = "New quote received for application ##{quote.application_id}. " \
           "Quote amount: #{number_to_currency(quote.quote_amount)}. " \
           "Review at: #{Rails.application.routes.url_helpers.quotes_url(host: organization_host(recipient.organization))}"
    
    SmsService.new.send_sms(
      to: recipient.phone_number,
      body: body
    )
  end
  
  def handle_quote_deadline_reminder(recipient, quote_id)
    quote = Quote.find(quote_id)
    SmsService.new.send_quote_deadline_reminder(
      user: recipient,
      quote: quote
    )
  end
  
  def handle_application_status_update(recipient, application_id, old_status, new_status)
    application = InsuranceApplication.find(application_id)
    body = "Application ##{application.id} status updated from #{old_status.humanize} to #{new_status.humanize}."
    
    if new_status == 'accepted'
      body += " Contract generation in progress."
    elsif new_status == 'rejected'
      body += " Please contact support for more information."
    end
    
    SmsService.new.send_sms(
      to: recipient.phone_number,
      body: body
    )
  end
  
  def handle_verification_code(recipient, code)
    SmsService.new.send_verification_code(
      user: recipient,
      code: code
    )
  end
  
  def number_to_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount)
  end
  
  def organization_host(organization)
    # This would need to be configured based on your domain setup
    if Rails.env.production?
      "#{organization.subdomain}.brokersync.com"
    else
      "localhost:3000"
    end
  end
end