class WhatsappService
  include HTTParty
  include ActiveSupport::Configurable
  
  config_accessor :access_token, :phone_number_id, :business_account_id, :enabled, :webhook_verify_token
  
  base_uri 'https://graph.facebook.com/v21.0'
  
  def self.configure
    yield(config) if block_given?
  end
  
  def initialize
    @access_token = config.access_token
    @phone_number_id = config.phone_number_id
  end
  
  def send_message(to:, message:, message_type: 'text')
    return false unless enabled?
    return false if to.blank? || message.blank?
    
    # Normalize phone number for WhatsApp (remove + and spaces)
    formatted_to = normalize_whatsapp_number(to)
    
    begin
      response = self.class.post(
        "/#{@phone_number_id}/messages",
        headers: headers,
        body: build_message_payload(formatted_to, message, message_type).to_json
      )
      
      if response.success?
        message_id = response.dig('messages', 0, 'id')
        Rails.logger.info "WhatsApp message sent successfully: #{message_id}"
        
        # Store WhatsApp message record
        WhatsappLog.create!(
          to: formatted_to,
          message: message.is_a?(String) ? message : message.to_json,
          message_type: message_type,
          status: 'sent',
          external_id: message_id,
          sent_at: Time.current
        )
        
        message_id
      else
        error_message = response.dig('error', 'message') || 'Unknown error'
        Rails.logger.error "WhatsApp message failed: #{error_message}"
        
        # Store failed message record
        WhatsappLog.create!(
          to: formatted_to,
          message: message.is_a?(String) ? message : message.to_json,
          message_type: message_type,
          status: 'failed',
          error_message: error_message,
          sent_at: Time.current
        )
        
        false
      end
    rescue StandardError => e
      Rails.logger.error "WhatsApp service error: #{e.message}"
      false
    end
  end
  
  def send_template_message(to:, template_name:, language: 'en_US', parameters: [])
    template_payload = {
      name: template_name,
      language: { code: language }
    }
    
    if parameters.any?
      template_payload[:components] = [
        {
          type: 'body',
          parameters: parameters.map { |param| { type: 'text', text: param.to_s } }
        }
      ]
    end
    
    send_message(
      to: to,
      message: { template: template_payload },
      message_type: 'template'
    )
  end
  
  def send_application_notification(user:, application:)
    return false unless user.whatsapp_enabled? && user.whatsapp_number.present?
    
    message = case application.status
    when 'submitted'
      "🔔 *New Insurance Application*\n\n" \
      "Application ID: ##{application.id}\n" \
      "Client: #{application.client_name}\n" \
      "Type: #{application.insurance_type.humanize}\n" \
      "Status: #{application.status.humanize}\n\n" \
      "Please review the application in your dashboard."
    when 'quoted'
      "💰 *New Quote Available*\n\n" \
      "Application ID: ##{application.id}\n" \
      "Client: #{application.client_name}\n\n" \
      "A new quote is available for review. Check your dashboard for details."
    when 'accepted'
      "✅ *Quote Accepted*\n\n" \
      "Application ID: ##{application.id}\n" \
      "Client: #{application.client_name}\n\n" \
      "The quote has been accepted. Contract generation is in progress."
    else
      "📋 *Application Status Update*\n\n" \
      "Application ID: ##{application.id}\n" \
      "Status: #{application.status.humanize}\n\n" \
      "Please check your dashboard for more details."
    end
    
    send_message(to: user.whatsapp_number, message: message)
  end
  
  def send_quote_reminder(user:, quote:)
    return false unless user.whatsapp_enabled? && user.whatsapp_number.present?
    
    days_left = (quote.deadline - Date.current).to_i
    
    message = if days_left == 1
      "⏰ *Quote Deadline Reminder*\n\n" \
      "Application ID: ##{quote.application_id}\n" \
      "Deadline: Tomorrow\n\n" \
      "⚠️ Please submit your quote by end of business tomorrow."
    elsif days_left > 1
      "⏰ *Quote Deadline Reminder*\n\n" \
      "Application ID: ##{quote.application_id}\n" \
      "Deadline: #{days_left} days\n\n" \
      "Please submit your quote soon."
    else
      "🚨 *URGENT: Quote Deadline Passed*\n\n" \
      "Application ID: ##{quote.application_id}\n\n" \
      "The quote deadline has passed. Please contact support immediately."
    end
    
    send_message(to: user.whatsapp_number, message: message)
  end
  
  def handle_webhook(webhook_data)
    return unless webhook_data.dig('object') == 'whatsapp_business_account'
    
    webhook_data.dig('entry')&.each do |entry|
      entry.dig('changes')&.each do |change|
        if change.dig('field') == 'messages'
          handle_message_status_update(change['value'])
        end
      end
    end
  end
  
  private
  
  def enabled?
    config.enabled && @access_token.present? && @phone_number_id.present?
  end
  
  def headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end
  
  def build_message_payload(to, message, message_type)
    payload = {
      messaging_product: 'whatsapp',
      to: to
    }
    
    case message_type
    when 'text'
      payload[:type] = 'text'
      payload[:text] = { body: message }
    when 'template'
      payload[:type] = 'template'
      payload[:template] = message
    else
      raise ArgumentError, "Unsupported message type: #{message_type}"
    end
    
    payload
  end
  
  def normalize_whatsapp_number(phone)
    # Remove all non-digit characters
    cleaned = phone.gsub(/\D/, '')
    
    # Add country code if missing (assuming US/CA)
    if cleaned.length == 10
      cleaned = "1#{cleaned}"
    end
    
    # WhatsApp doesn't use + prefix in API
    cleaned
  end
  
  def handle_message_status_update(value)
    return unless value.dig('statuses')
    
    value['statuses'].each do |status|
      message_id = status['id']
      new_status = status['status'] # sent, delivered, read, failed
      
      if whatsapp_log = WhatsappLog.find_by(external_id: message_id)
        whatsapp_log.update!(
          status: new_status,
          updated_at: Time.current
        )
        
        Rails.logger.info "Updated WhatsApp message #{message_id} status to #{new_status}"
      end
    end
  end
end

# Configure WhatsApp service
WhatsappService.configure do |config|
  config.access_token = Rails.application.credentials.dig(:whatsapp, :access_token)
  config.phone_number_id = Rails.application.credentials.dig(:whatsapp, :phone_number_id)
  config.business_account_id = Rails.application.credentials.dig(:whatsapp, :business_account_id)
  config.webhook_verify_token = Rails.application.credentials.dig(:whatsapp, :webhook_verify_token)
  config.enabled = Rails.env.production? || Rails.application.credentials.dig(:whatsapp, :enabled) == true
end