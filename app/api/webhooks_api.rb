# frozen_string_literal: true

class WebhooksApi < Grape::API
  version 'v1', using: :header, vendor: 'brokersync'
  format :json
  
  resource :webhooks do
    desc 'List all webhooks', {
      summary: 'Retrieve list of configured webhooks',
      detail: 'Returns a list of webhooks configured for the organization',
      tags: ['Webhooks'],
      security: [{ bearer_token: [] }]
    }
    params do
      optional :page, type: Integer, default: 1, desc: 'Page number'
      optional :per_page, type: Integer, default: 25, desc: 'Items per page (max 100)'
      optional :event_type, type: String, desc: 'Filter by event type'
      optional :status, type: String, values: %w[active inactive], desc: 'Filter by status'
    end
    get do
      authenticate_api_request!
      authorize_api_action!('webhook_management')
      track_api_usage('webhooks', 'list')
      
      webhooks = current_organization.webhooks
      
      # Apply filters
      webhooks = webhooks.where(event_type: params[:event_type]) if params[:event_type]
      webhooks = webhooks.where(status: params[:status]) if params[:status]
      
      # Order by most recent
      webhooks = webhooks.order(created_at: :desc)
      
      # Paginate results
      result = paginate(webhooks, per_page: params[:per_page])
      
      {
        webhooks: result[:data].map { |webhook| WebhookEntity.represent(webhook) },
        pagination: result[:pagination],
        available_events: WebhookService::AVAILABLE_EVENTS
      }
    end
    
    desc 'Get webhook by ID', {
      summary: 'Retrieve a specific webhook',
      detail: 'Returns detailed information about a specific webhook',
      tags: ['Webhooks'],
      security: [{ bearer_token: [] }]
    }
    params do
      requires :id, type: Integer, desc: 'Webhook ID'
    end
    route_param :id do
      get do
        authenticate_api_request!
        authorize_api_action!('webhook_management')
        track_api_usage('webhooks', 'show')
        
        webhook = current_organization.webhooks.find(params[:id])
        
        WebhookEntity.represent(webhook, with_details: true)
      end
    end
    
    desc 'Create new webhook', {
      summary: 'Create a new webhook endpoint',
      detail: 'Creates a new webhook for receiving real-time notifications',
      tags: ['Webhooks'],
      security: [{ bearer_token: [] }]
    }
    params do
      requires :url, type: String, desc: 'Webhook endpoint URL (must be HTTPS)'
      requires :event_types, type: Array[String], desc: 'Array of event types to subscribe to'
      optional :description, type: String, desc: 'Description of the webhook'
      optional :secret, type: String, desc: 'Secret for webhook signature verification'
      optional :retry_count, type: Integer, default: 3, desc: 'Number of retry attempts'
      optional :timeout_seconds, type: Integer, default: 30, desc: 'Request timeout in seconds'
    end
    post do
      authenticate_api_request!
      authorize_api_action!('webhook_management')
      track_api_usage('webhooks', 'create')
      
      # Validate URL format and HTTPS requirement
      unless params[:url].match?(/\Ahttps:\/\//)
        error!({
          error: 'invalid_url',
          message: 'Webhook URL must use HTTPS protocol'
        }, 400)
      end
      
      # Validate event types
      invalid_events = params[:event_types] - WebhookService::AVAILABLE_EVENTS
      if invalid_events.any?
        error!({
          error: 'invalid_event_types',
          message: 'Invalid event types provided',
          invalid_events: invalid_events,
          available_events: WebhookService::AVAILABLE_EVENTS
        }, 400)
      end
      
      webhook = current_organization.webhooks.build(
        url: params[:url],
        event_types: params[:event_types],
        description: params[:description],
        secret: params[:secret] || SecureRandom.hex(32),
        retry_count: params[:retry_count],
        timeout_seconds: params[:timeout_seconds],
        status: 'active',
        created_by: current_api_user
      )
      
      if webhook.save
        # Test webhook connectivity
        test_result = WebhookService.test_webhook(webhook)
        
        # Log creation
        AuditLog.create!(
          user: current_api_user,
          organization: current_organization,
          action: 'webhook_created_via_api',
          category: 'webhook_management',
          resource_type: 'Webhook',
          resource_id: webhook.id,
          severity: 'info',
          details: {
            api_key_id: current_api_key.id,
            url: webhook.url,
            event_types: webhook.event_types,
            test_result: test_result
          }
        )
        
        status 201
        {
          webhook: WebhookEntity.represent(webhook, with_details: true),
          test_result: test_result
        }
      else
        error!({
          error: 'validation_error',
          message: 'Webhook creation failed',
          details: webhook.errors.as_json
        }, 422)
      end
    end
    
    desc 'Update webhook', {
      summary: 'Update an existing webhook',
      detail: 'Updates an existing webhook configuration',
      tags: ['Webhooks'],
      security: [{ bearer_token: [] }]
    }
    params do
      requires :id, type: Integer, desc: 'Webhook ID'
      optional :url, type: String, desc: 'Webhook endpoint URL (must be HTTPS)'
      optional :event_types, type: Array[String], desc: 'Array of event types to subscribe to'
      optional :description, type: String, desc: 'Description of the webhook'
      optional :secret, type: String, desc: 'Secret for webhook signature verification'
      optional :retry_count, type: Integer, desc: 'Number of retry attempts'
      optional :timeout_seconds, type: Integer, desc: 'Request timeout in seconds'
      optional :status, type: String, values: %w[active inactive], desc: 'Webhook status'
    end
    route_param :id do
      put do
        authenticate_api_request!
        authorize_api_action!('webhook_management')
        track_api_usage('webhooks', 'update')
        
        webhook = current_organization.webhooks.find(params[:id])
        
        update_params = params.except(:id)
        
        # Validate URL if provided
        if update_params[:url] && !update_params[:url].match?(/\Ahttps:\/\//)
          error!({
            error: 'invalid_url',
            message: 'Webhook URL must use HTTPS protocol'
          }, 400)
        end
        
        # Validate event types if provided
        if update_params[:event_types]
          invalid_events = update_params[:event_types] - WebhookService::AVAILABLE_EVENTS
          if invalid_events.any?
            error!({
              error: 'invalid_event_types',
              message: 'Invalid event types provided',
              invalid_events: invalid_events,
              available_events: WebhookService::AVAILABLE_EVENTS
            }, 400)
          end
        end
        
        if webhook.update(update_params)
          # Test webhook if URL changed
          test_result = nil
          if update_params[:url]
            test_result = WebhookService.test_webhook(webhook)
          end
          
          # Log update
          AuditLog.create!(
            user: current_api_user,
            organization: current_organization,
            action: 'webhook_updated_via_api',
            category: 'webhook_management',
            resource_type: 'Webhook',
            resource_id: webhook.id,
            severity: 'info',
            details: {
              api_key_id: current_api_key.id,
              updated_fields: update_params.keys,
              test_result: test_result
            }
          )
          
          {
            webhook: WebhookEntity.represent(webhook, with_details: true),
            test_result: test_result
          }
        else
          error!({
            error: 'validation_error',
            message: 'Webhook update failed',
            details: webhook.errors.as_json
          }, 422)
        end
      end
    end
    
    desc 'Delete webhook', {
      summary: 'Delete a webhook',
      detail: 'Permanently deletes a webhook endpoint',
      tags: ['Webhooks'],
      security: [{ bearer_token: [] }]
    }
    route_param :id do
      delete do
        authenticate_api_request!
        authorize_api_action!('webhook_management')
        track_api_usage('webhooks', 'delete')
        
        webhook = current_organization.webhooks.find(params[:id])
        
        # Log deletion before destroying
        AuditLog.create!(
          user: current_api_user,
          organization: current_organization,
          action: 'webhook_deleted_via_api',
          category: 'webhook_management',
          resource_type: 'Webhook',
          resource_id: webhook.id,
          severity: 'warning',
          details: {
            api_key_id: current_api_key.id,
            url: webhook.url,
            event_types: webhook.event_types
          }
        )
        
        webhook.destroy
        
        { message: 'Webhook deleted successfully' }
      end
    end
    
    desc 'Test webhook', {
      summary: 'Test webhook connectivity',
      detail: 'Sends a test event to verify webhook endpoint is working',
      tags: ['Webhooks'],
      security: [{ bearer_token: [] }]
    }
    route_param :id do
      post :test do
        authenticate_api_request!
        authorize_api_action!('webhook_management')
        track_api_usage('webhooks', 'test')
        
        webhook = current_organization.webhooks.find(params[:id])
        
        test_result = WebhookService.test_webhook(webhook)
        
        # Log test
        AuditLog.create!(
          user: current_api_user,
          organization: current_organization,
          action: 'webhook_tested_via_api',
          category: 'webhook_management',
          resource_type: 'Webhook',
          resource_id: webhook.id,
          severity: 'info',
          details: {
            api_key_id: current_api_key.id,
            test_result: test_result
          }
        )
        
        test_result
      end
    end
    
    desc 'Get webhook delivery history', {
      summary: 'Retrieve webhook delivery logs',
      detail: 'Returns a history of webhook delivery attempts and their results',
      tags: ['Webhooks'],
      security: [{ bearer_token: [] }]
    }
    params do
      optional :page, type: Integer, default: 1, desc: 'Page number'
      optional :per_page, type: Integer, default: 25, desc: 'Items per page (max 100)'
      optional :status, type: String, values: %w[success failed], desc: 'Filter by delivery status'
      optional :event_type, type: String, desc: 'Filter by event type'
    end
    route_param :id do
      get :deliveries do
        authenticate_api_request!
        authorize_api_action!('webhook_management')
        track_api_usage('webhooks', 'deliveries')
        
        webhook = current_organization.webhooks.find(params[:id])
        deliveries = webhook.webhook_deliveries.includes(:webhook_event)
        
        # Apply filters
        deliveries = deliveries.where(status: params[:status]) if params[:status]
        if params[:event_type]
          deliveries = deliveries.joins(:webhook_event)
                                .where(webhook_events: { event_type: params[:event_type] })
        end
        
        # Order by most recent
        deliveries = deliveries.order(created_at: :desc)
        
        # Paginate results
        result = paginate(deliveries, per_page: params[:per_page])
        
        {
          webhook_id: webhook.id,
          deliveries: result[:data].map { |delivery| WebhookDeliveryEntity.represent(delivery) },
          pagination: result[:pagination],
          delivery_stats: webhook.delivery_statistics
        }
      end
    end
  end
end