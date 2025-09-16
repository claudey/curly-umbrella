# frozen_string_literal: true

class ErrorHandlingController < ActionController::Base
  def handle_error
    @exception = request.env['action_dispatch.exception']
    @status_code = ActionDispatch::ExceptionWrapper.new(request.env, @exception).status_code
    
    # Track the error
    ErrorTrackingService.track_error(@exception, {
      status_code: @status_code,
      path: request.path,
      method: request.method,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      referer: request.referer
    })
    
    # Render appropriate error page
    case @status_code
    when 404
      render_error_page(:not_found, 404)
    when 422
      render_error_page(:unprocessable_entity, 422)
    when 500
      render_error_page(:internal_server_error, 500)
    else
      render_error_page(:internal_server_error, 500)
    end
  end
  
  private
  
  def render_error_page(template, status)
    if request.xhr? || request.format.json?
      render json: {
        error: true,
        status: status,
        message: error_message_for_status(status),
        timestamp: Time.current.iso8601
      }, status: status
    else
      render template: "errors/#{template}", 
             layout: 'error',
             status: status,
             formats: [:html]
    end
  rescue
    # Fallback if even error rendering fails
    render plain: error_message_for_status(status), status: status
  end
  
  def error_message_for_status(status)
    case status
    when 404
      'The page you were looking for could not be found.'
    when 422
      'The request could not be processed due to invalid data.'
    when 500
      'An internal server error occurred. We have been notified and are working to fix this issue.'
    else
      'An error occurred while processing your request.'
    end
  end
end