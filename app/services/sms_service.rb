class SmsService
  include ActiveSupport::Configurable
  
  config_accessor :account_sid, :auth_token, :from_number, :enabled
  
  def self.configure
    yield(config) if block_given?
  end
  
  def initialize
    @client = twilio_client if enabled?
  end
  
  def send_sms(to:, body:, from: nil)
    return false unless enabled?
    return false if to.blank? || body.blank?
    
    # Normalize phone number
    formatted_to = normalize_phone_number(to)
    return false unless valid_phone_number?(formatted_to)
    
    begin
      message = @client.messages.create(
        to: formatted_to,
        from: from || config.from_number,
        body: body
      )
      
      Rails.logger.info "SMS sent successfully: #{message.sid}"
      
      # Store SMS record for audit trail
      SmsLog.create!(
        to: formatted_to,
        from: from || config.from_number,
        body: body,
        status: 'sent',
        external_id: message.sid,
        sent_at: Time.current
      )
      
      message.sid
    rescue Twilio::REST::RestError => e
      Rails.logger.error "SMS failed: #{e.message}"
      
      # Store failed SMS record
      SmsLog.create!(
        to: formatted_to,
        from: from || config.from_number,
        body: body,
        status: 'failed',
        error_message: e.message,
        sent_at: Time.current
      )
      
      false
    end
  end
  
  def send_verification_code(user:, code:)
    body = "Your #{Rails.application.class.module_parent_name} verification code is: #{code}. This code expires in 10 minutes."
    send_sms(to: user.phone_number, body: body)
  end
  
  def send_application_notification(user:, application:)
    body = case application.status
    when 'submitted'
      "New insurance application submitted for #{application.client_name}. Application ##{application.id}"
    when 'quoted'
      "New quote available for application ##{application.id}. Check your dashboard to review."
    when 'accepted'
      "Quote accepted for application ##{application.id}. Contract generation in progress."
    else
      "Application ##{application.id} status updated to #{application.status.humanize}"
    end
    
    send_sms(to: user.phone_number, body: body)
  end
  
  def send_quote_deadline_reminder(user:, quote:)
    days_left = (quote.deadline - Date.current).to_i
    body = if days_left == 1
      "Reminder: Quote deadline for application ##{quote.application_id} is tomorrow. Please submit your quote."
    elsif days_left > 1
      "Reminder: Quote deadline for application ##{quote.application_id} is in #{days_left} days."
    else
      "URGENT: Quote deadline for application ##{quote.application_id} has passed. Please contact support."
    end
    
    send_sms(to: user.phone_number, body: body)
  end
  
  private
  
  def enabled?
    config.enabled && config.account_sid.present? && config.auth_token.present?
  end
  
  def twilio_client
    @twilio_client ||= Twilio::REST::Client.new(config.account_sid, config.auth_token)
  end
  
  def normalize_phone_number(phone)
    # Remove all non-digit characters
    cleaned = phone.gsub(/\D/, '')
    
    # Add country code if missing (assuming US/CA)
    if cleaned.length == 10
      cleaned = "1#{cleaned}"
    end
    
    # Format as E.164
    "+#{cleaned}"
  end
  
  def valid_phone_number?(phone)
    # Basic E.164 validation
    phone.match?(/^\+\d{10,15}$/)
  end
end

# Configure SMS service
SmsService.configure do |config|
  config.account_sid = Rails.application.credentials.dig(:twilio, :account_sid)
  config.auth_token = Rails.application.credentials.dig(:twilio, :auth_token)
  config.from_number = Rails.application.credentials.dig(:twilio, :from_number)
  config.enabled = Rails.env.production? || Rails.application.credentials.dig(:twilio, :enabled) == true
end