# frozen_string_literal: true

class BrokersyncApi < Grape::API
  version 'v1', using: :header, vendor: 'brokersync'
  format :json
  prefix :api
  
  # Error handling
  rescue_from :all do |e|
    error_response = case e
                    when Grape::Exceptions::ValidationErrors
                      {
                        error: 'validation_error',
                        message: 'Request validation failed',
                        details: e.errors.transform_keys { |key| key.join('.') }
                      }
                    when Grape::Exceptions::MethodNotAllowed
                      {
                        error: 'method_not_allowed',
                        message: 'HTTP method not allowed for this endpoint'
                      }
                    when JWT::DecodeError, JWT::ExpiredSignature
                      {
                        error: 'authentication_error',
                        message: 'Invalid or expired authentication token'
                      }
                    when ApiAuthenticationService::AuthenticationError
                      {
                        error: 'authentication_error',
                        message: e.message
                      }
                    when ApiAuthenticationService::AuthorizationError
                      {
                        error: 'authorization_error',
                        message: e.message
                      }
                    when ActiveRecord::RecordNotFound
                      {
                        error: 'not_found',
                        message: 'Requested resource not found'
                      }
                    when ActiveRecord::RecordInvalid
                      {
                        error: 'validation_error',
                        message: 'Record validation failed',
                        details: e.record.errors.as_json
                      }
                    else
                      # Log unexpected errors
                      Rails.logger.error "API Error: #{e.class.name}: #{e.message}"
                      Rails.logger.error e.backtrace.join("\n")
                      
                      # Track error in monitoring
                      ErrorTrackingService.track_error(e, {
                        context: 'api_request',
                        endpoint: env['REQUEST_PATH'],
                        method: env['REQUEST_METHOD']
                      })
                      
                      {
                        error: 'internal_error',
                        message: 'An internal error occurred'
                      }
                    end
    
    status_code = case e
                 when Grape::Exceptions::ValidationErrors
                   400
                 when Grape::Exceptions::MethodNotAllowed
                   405
                 when JWT::DecodeError, JWT::ExpiredSignature, ApiAuthenticationService::AuthenticationError
                   401
                 when ApiAuthenticationService::AuthorizationError
                   403
                 when ActiveRecord::RecordNotFound
                   404
                 when ActiveRecord::RecordInvalid
                   422
                 else
                   500
                 end
    
    error!(error_response, status_code)
  end
  
  # Authentication helpers
  helpers do
    def current_api_key
      @current_api_key ||= authenticate_api_request!
    end
    
    def current_organization
      @current_organization ||= current_api_key.organization
    end
    
    def current_api_user
      @current_api_user ||= current_api_key.user
    end
    
    def authenticate_api_request!
      ApiAuthenticationService.authenticate_request!(headers)
    end
    
    def authorize_api_action!(action, resource = nil)
      ApiAuthenticationService.authorize_action!(current_api_key, action, resource)
    end
    
    def paginate(collection, per_page: 25)
      page = params[:page] || 1
      per_page = [params[:per_page] || per_page, 100].min # Max 100 items per page
      
      paginated = collection.page(page).per(per_page)
      
      {
        data: paginated,
        pagination: {
          current_page: paginated.current_page,
          per_page: paginated.limit_value,
          total_pages: paginated.total_pages,
          total_count: paginated.total_count,
          has_next_page: paginated.next_page.present?,
          has_prev_page: paginated.prev_page.present?
        }
      }
    end
    
    def track_api_usage(endpoint, action)
      ApiUsageTrackingService.track_request(
        api_key: current_api_key,
        endpoint: endpoint,
        action: action,
        request_data: {
          method: env['REQUEST_METHOD'],
          path: env['REQUEST_PATH'],
          user_agent: headers['User-Agent'],
          ip_address: env['REMOTE_ADDR']
        }
      )
    end
  end
  
  # Add API documentation
  add_swagger_documentation(
    api_version: 'v1',
    hide_documentation_path: true,
    mount_path: '/api/docs',
    hide_format: true,
    info: {
      title: 'BrokerSync API',
      description: 'Comprehensive API for insurance brokerage platform integration',
      contact: {
        name: 'BrokerSync API Support',
        email: 'api-support@brokersync.com'
      },
      license: {
        name: 'Proprietary',
        url: 'https://brokersync.com/terms'
      }
    },
    security_definitions: {
      bearer_token: {
        type: 'apiKey',
        name: 'Authorization',
        in: 'header',
        description: 'Bearer token authentication. Format: Bearer <your_api_key>'
      }
    },
    security: [
      {
        bearer_token: []
      }
    ]
  )
  
  # Mount API modules
  mount ApplicationsApi
  mount QuotesApi
  mount DocumentsApi
  mount OrganizationsApi
  mount WebhooksApi
  mount AnalyticsApi
end