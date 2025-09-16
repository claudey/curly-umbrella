# frozen_string_literal: true

class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_request!
  before_action :set_default_response_format
  
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  rescue_from ApiAuthenticationService::AuthenticationError, with: :handle_authentication_error
  rescue_from ApiAuthenticationService::AuthorizationError, with: :handle_authorization_error
  rescue_from ApiRateLimitService::RateLimitError, with: :handle_rate_limit_error
  
  protected
  
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
    ApiAuthenticationService.authenticate_request!(request.headers)
  end
  
  def authorize_api_action!(action, resource = nil)
    ApiAuthenticationService.authorize_action!(current_api_key, action, resource)
  end
  
  def track_api_usage(endpoint, action)
    ApiUsageTrackingService.track_request(
      api_key: current_api_key,
      endpoint: endpoint,
      action: action,
      request_data: {
        method: request.method,
        path: request.path,
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      }
    )
  end
  
  def paginate_collection(collection, per_page: 25)
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
  
  def render_success(data, status: :ok)
    render json: data, status: status
  end
  
  def render_error(message, details: nil, status: :bad_request)
    error_response = {
      error: true,
      message: message
    }
    error_response[:details] = details if details
    
    render json: error_response, status: status
  end
  
  private
  
  def set_default_response_format
    request.format = :json
  end
  
  def handle_standard_error(exception)
    Rails.logger.error "API Error: #{exception.class.name}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    # Track error in monitoring
    ErrorTrackingService.track_error(exception, {
      context: 'api_request',
      endpoint: request.path,
      method: request.method,
      user_id: current_api_user&.id,
      organization_id: current_organization&.id
    })
    
    render_error('An internal error occurred', status: :internal_server_error)
  end
  
  def handle_not_found(exception)
    render_error('Resource not found', status: :not_found)
  end
  
  def handle_validation_error(exception)
    render_error(
      'Validation failed',
      details: exception.record.errors.as_json,
      status: :unprocessable_entity
    )
  end
  
  def handle_parameter_missing(exception)
    render_error(
      'Required parameter missing',
      details: { missing_parameter: exception.param },
      status: :bad_request
    )
  end
  
  def handle_authentication_error(exception)
    render_error(exception.message, status: :unauthorized)
  end
  
  def handle_authorization_error(exception)
    render_error(exception.message, status: :forbidden)
  end
  
  def handle_rate_limit_error(exception)
    render_error(
      'Rate limit exceeded',
      details: { message: exception.message },
      status: :too_many_requests
    )
  end
  
  # Standardized response methods
  def render_success(data = {}, status: :ok, message: nil)
    response_hash = {
      success: true,
      data: data,
      meta: {
        timestamp: Time.current.iso8601,
        api_version: 'v1',
        request_id: request.uuid,
        organization_id: current_organization&.id
      }
    }
    
    response_hash[:message] = message if message.present?
    
    # Add rate limit headers
    add_rate_limit_headers if current_api_key
    
    render json: response_hash, status: status
  end
  
  def render_error(message, details: nil, status: :bad_request, code: nil)
    error_hash = {
      message: message,
      code: code || infer_error_code_from_status(status)
    }
    
    error_hash[:details] = details if details.present?
    
    response_hash = {
      success: false,
      error: error_hash,
      meta: {
        timestamp: Time.current.iso8601,
        api_version: 'v1',
        request_id: request.uuid,
        organization_id: current_organization&.id
      }
    }
    
    # Add rate limit headers
    add_rate_limit_headers if current_api_key
    
    render json: response_hash, status: status
  end
  
  # Pagination helper
  def paginate_collection(collection, page: params[:page], per_page: params[:per_page])
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 100].min # Max 100 items per page
    per_page = 25 if per_page.zero? # Default to 25
    
    paginated = collection.page(page).per(per_page)
    
    {
      data: paginated,
      pagination: {
        current_page: paginated.current_page,
        per_page: paginated.limit_value,
        total_pages: paginated.total_pages,
        total_count: paginated.total_count,
        next_page: paginated.next_page,
        prev_page: paginated.prev_page,
        first_page: paginated.first_page?,
        last_page: paginated.last_page?
      }
    }
  end
  
  # Usage tracking helper
  def track_api_usage(resource, action)
    ApiUsageTrackingService.track_usage(
      api_key: current_api_key,
      endpoint: "#{resource}##{action}",
      http_method: request.method,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
  
  # Authorization helper
  def authorize_api_action!(action, resource = nil)
    unless current_api_key.can_perform?(action, resource)
      raise ApiAuthenticationService::AuthorizationError,
            "API key does not have permission to perform #{action}"
    end
  end
  
  private
  
  def add_rate_limit_headers
    rate_limit_info = ApiRateLimitService.get_rate_limit_info(current_api_key)
    
    headers['X-RateLimit-Limit'] = rate_limit_info[:limit].to_s
    headers['X-RateLimit-Remaining'] = rate_limit_info[:remaining].to_s
    headers['X-RateLimit-Reset'] = rate_limit_info[:reset_at].to_i.to_s
    headers['X-RateLimit-Window'] = rate_limit_info[:window].to_s
  end
  
  def infer_error_code_from_status(status)
    case status.to_s
    when '400', 'bad_request' then 'BAD_REQUEST'
    when '401', 'unauthorized' then 'UNAUTHORIZED'
    when '403', 'forbidden' then 'FORBIDDEN'
    when '404', 'not_found' then 'NOT_FOUND'
    when '422', 'unprocessable_entity' then 'VALIDATION_ERROR'
    when '429', 'too_many_requests' then 'RATE_LIMIT_EXCEEDED'
    when '500', 'internal_server_error' then 'INTERNAL_ERROR'
    when '503', 'service_unavailable' then 'SERVICE_UNAVAILABLE'
    else 'UNKNOWN_ERROR'
    end
  end
end