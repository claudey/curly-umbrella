# frozen_string_literal: true

class Api::V1::WebhooksController < Api::V1::BaseController
  before_action :set_webhook, only: [:show, :update, :destroy, :test, :deliveries]
  before_action :track_usage
  before_action :check_webhook_permissions
  
  # GET /api/v1/webhooks
  def index
    webhooks = current_organization.webhooks
    
    # Apply filters
    webhooks = filter_webhooks(webhooks)
    
    # Order by most recent
    webhooks = webhooks.order(created_at: :desc)
    
    # Paginate results
    result = paginate_collection(webhooks)
    
    render_success({
      webhooks: serialize_webhooks(result[:data]),
      pagination: result[:pagination],
      available_events: available_webhook_events
    })
  end
  
  # GET /api/v1/webhooks/:id
  def show
    render_success({
      webhook: serialize_webhook(@webhook, with_details: true)
    })
  end
  
  # POST /api/v1/webhooks
  def create
    # Validate URL format and HTTPS requirement
    unless webhook_params[:url]&.match?(/\Ahttps:\/\//)
      return render_error(
        'Webhook URL must use HTTPS protocol',
        status: :bad_request
      )
    end
    
    # Validate event types
    invalid_events = webhook_params[:event_types] - available_webhook_events
    if invalid_events.any?
      return render_error(
        'Invalid event types provided',
        details: {
          invalid_events: invalid_events,
          available_events: available_webhook_events
        },
        status: :bad_request
      )
    end
    
    @webhook = current_organization.webhooks.build(
      webhook_params.merge(
        secret: webhook_params[:secret] || SecureRandom.hex(32),
        status: 'active',
        created_by: current_api_user
      )
    )
    
    if @webhook.save
      # Test webhook connectivity
      test_result = test_webhook_connectivity(@webhook)
      
      log_webhook_creation(test_result)
      
      render_success(
        {
          webhook: serialize_webhook(@webhook, with_details: true),
          test_result: test_result
        },
        status: :created
      )
    else
      render_error(
        'Webhook creation failed',
        details: @webhook.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # PUT/PATCH /api/v1/webhooks/:id
  def update
    update_params = webhook_update_params
    
    # Validate URL if provided
    if update_params[:url] && !update_params[:url].match?(/\Ahttps:\/\//)
      return render_error(
        'Webhook URL must use HTTPS protocol',
        status: :bad_request
      )
    end
    
    # Validate event types if provided
    if update_params[:event_types]
      invalid_events = update_params[:event_types] - available_webhook_events
      if invalid_events.any?
        return render_error(
          'Invalid event types provided',
          details: {
            invalid_events: invalid_events,
            available_events: available_webhook_events
          },
          status: :bad_request
        )
      end
    end
    
    if @webhook.update(update_params)
      # Test webhook if URL changed
      test_result = nil
      if update_params[:url]
        test_result = test_webhook_connectivity(@webhook)
      end
      
      log_webhook_update(test_result)
      
      render_success({
        webhook: serialize_webhook(@webhook, with_details: true),
        test_result: test_result
      })
    else
      render_error(
        'Webhook update failed',
        details: @webhook.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # DELETE /api/v1/webhooks/:id
  def destroy
    log_webhook_deletion
    @webhook.destroy
    
    render_success({
      message: 'Webhook deleted successfully'
    })
  end
  
  # POST /api/v1/webhooks/:id/test
  def test
    test_result = test_webhook_connectivity(@webhook)
    
    log_webhook_test(test_result)
    
    render_success(test_result)
  end
  
  # GET /api/v1/webhooks/:id/deliveries
  def deliveries
    deliveries = @webhook.webhook_deliveries.includes(:webhook_event)
    
    # Apply filters
    deliveries = deliveries.where(status: params[:status]) if params[:status]
    if params[:event_type]
      deliveries = deliveries.joins(:webhook_event)
                            .where(webhook_events: { event_type: params[:event_type] })
    end
    
    # Order by most recent
    deliveries = deliveries.order(created_at: :desc)
    
    # Paginate results
    result = paginate_collection(deliveries)
    
    render_success({
      webhook_id: @webhook.id,
      deliveries: serialize_deliveries(result[:data]),
      pagination: result[:pagination],
      delivery_stats: calculate_delivery_stats(@webhook)
    })
  end
  
  private
  
  def set_webhook
    @webhook = current_organization.webhooks.find(params[:id])
  end
  
  def track_usage
    track_api_usage('webhooks', action_name)
  end
  
  def check_webhook_permissions
    authorize_api_action!('webhook_management')
  end
  
  def webhook_params
    params.require(:webhook).permit(
      :url, :description, :secret, :retry_count, :timeout_seconds,
      event_types: []
    )
  end
  
  def webhook_update_params
    params.require(:webhook).permit(
      :url, :description, :secret, :retry_count, :timeout_seconds, :status,
      event_types: []
    )
  end
  
  def filter_webhooks(webhooks)
    webhooks = webhooks.where(event_type: params[:event_type]) if params[:event_type]
    webhooks = webhooks.where(status: params[:status]) if params[:status]
    webhooks
  end
  
  def available_webhook_events
    [
      'application.created',
      'application.updated', 
      'application.submitted',
      'application.approved',
      'application.rejected',
      'quote.created',
      'quote.updated',
      'quote.accepted',
      'quote.expired',
      'document.uploaded',
      'document.processed',
      'policy.created',
      'policy.renewed',
      'payment.received',
      'payment.failed'
    ]
  end
  
  def serialize_webhooks(webhooks)
    webhooks.map { |webhook| serialize_webhook(webhook) }
  end
  
  def serialize_webhook(webhook, with_details: false)
    base_data = {
      id: webhook.id,
      url: webhook.url,
      event_types: webhook.event_types,
      status: webhook.status,
      description: webhook.description,
      retry_count: webhook.retry_count,
      timeout_seconds: webhook.timeout_seconds,
      created_at: webhook.created_at,
      updated_at: webhook.updated_at,
      last_delivery_at: webhook.last_delivery_at,
      delivery_stats: {
        total_deliveries: webhook.webhook_deliveries.count,
        successful_deliveries: webhook.webhook_deliveries.where(status: 'success').count,
        failed_deliveries: webhook.webhook_deliveries.where(status: 'failed').count,
        success_rate: calculate_success_rate(webhook)
      }
    }
    
    if with_details
      base_data.merge!(
        secret: webhook.secret&.truncate(10) + '...',  # Masked secret
        created_by: {
          id: webhook.created_by.id,
          name: webhook.created_by.full_name,
          email: webhook.created_by.email
        },
        recent_deliveries: webhook.webhook_deliveries
                                 .recent
                                 .limit(5)
                                 .map { |delivery| serialize_delivery(delivery) }
      )
    end
    
    base_data
  end
  
  def serialize_deliveries(deliveries)
    deliveries.map { |delivery| serialize_delivery(delivery) }
  end
  
  def serialize_delivery(delivery)
    {
      id: delivery.id,
      event_type: delivery.webhook_event.event_type,
      status: delivery.status,
      response_code: delivery.response_code,
      response_time_ms: delivery.response_time,
      attempted_at: delivery.attempted_at,
      error_message: delivery.error_message,
      retry_count: delivery.retry_count
    }
  end
  
  def test_webhook_connectivity(webhook)
    begin
      # Create test payload
      test_payload = {
        event_type: 'webhook.test',
        data: {
          webhook_id: webhook.id,
          test_timestamp: Time.current.iso8601,
          message: 'This is a test webhook delivery from BrokerSync'
        },
        metadata: {
          api_version: 'v1',
          organization_id: current_organization.id
        }
      }
      
      # Make HTTP request to webhook URL
      uri = URI(webhook.url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = webhook.timeout_seconds || 30
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = 'BrokerSync-Webhook/1.0'
      
      # Add webhook signature if secret is present
      if webhook.secret
        signature = OpenSSL::HMAC.hexdigest('sha256', webhook.secret, test_payload.to_json)
        request['X-BrokerSync-Signature'] = "sha256=#{signature}"
      end
      
      request.body = test_payload.to_json
      
      start_time = Time.current
      response = http.request(request)
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      success = response.code.to_i.between?(200, 299)
      
      {
        success: success,
        status_code: response.code.to_i,
        response_time_ms: response_time,
        response_body: response.body&.truncate(500),
        message: success ? 'Webhook test successful' : 'Webhook test failed'
      }
      
    rescue => e
      {
        success: false,
        error: e.class.name,
        message: e.message,
        response_time_ms: nil
      }
    end
  end
  
  def calculate_success_rate(webhook)
    total = webhook.webhook_deliveries.count
    return 0 if total.zero?
    
    successful = webhook.webhook_deliveries.where(status: 'success').count
    ((successful.to_f / total) * 100).round(2)
  end
  
  def calculate_delivery_stats(webhook)
    deliveries = webhook.webhook_deliveries
    
    {
      total_deliveries: deliveries.count,
      successful_deliveries: deliveries.where(status: 'success').count,
      failed_deliveries: deliveries.where(status: 'failed').count,
      pending_deliveries: deliveries.where(status: 'pending').count,
      average_response_time: deliveries.where.not(response_time: nil).average(:response_time)&.round(2),
      success_rate: calculate_success_rate(webhook),
      last_delivery: deliveries.maximum(:attempted_at),
      deliveries_last_24h: deliveries.where(attempted_at: 24.hours.ago..Time.current).count
    }
  end
  
  def log_webhook_creation(test_result)
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'webhook_created_via_api',
      category: 'webhook_management',
      resource_type: 'Webhook',
      resource_id: @webhook.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        url: @webhook.url,
        event_types: @webhook.event_types,
        test_result: test_result
      }
    )
  end
  
  def log_webhook_update(test_result)
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'webhook_updated_via_api',
      category: 'webhook_management',
      resource_type: 'Webhook',
      resource_id: @webhook.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        updated_fields: webhook_update_params.keys,
        test_result: test_result
      }
    )
  end
  
  def log_webhook_deletion
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'webhook_deleted_via_api',
      category: 'webhook_management',
      resource_type: 'Webhook',
      resource_id: @webhook.id,
      severity: 'warning',
      details: {
        api_key_id: current_api_key.id,
        url: @webhook.url,
        event_types: @webhook.event_types
      }
    )
  end
  
  def log_webhook_test(test_result)
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'webhook_tested_via_api',
      category: 'webhook_management',
      resource_type: 'Webhook',
      resource_id: @webhook.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        test_result: test_result
      }
    )
  end
end