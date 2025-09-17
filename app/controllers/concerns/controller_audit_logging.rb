# frozen_string_literal: true

module ControllerAuditLogging
  extend ActiveSupport::Concern
  
  included do
    before_action :set_audit_context
    around_action :audit_controller_action
    after_action :log_data_access, if: :should_log_data_access?
  end
  
  private
  
  def set_audit_context
    # Set current user and request context for audit logging
    Current.user = current_user if respond_to?(:current_user)
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
    Current.request_id = request.uuid
    Current.controller = self.class.name
    Current.action = action_name
    Current.request_path = request.path
    Current.request_method = request.method
    
    # Also set in Thread for backward compatibility
    Thread.current[:current_user] = current_user if respond_to?(:current_user)
    Thread.current[:request_ip] = request.remote_ip
    Thread.current[:user_agent] = request.user_agent
  end
  
  def audit_controller_action
    audit_start_time = Time.current
    
    begin
      # Log the start of the action
      log_controller_action_start
      
      result = yield
      
      # Log successful completion
      log_controller_action_success(audit_start_time)
      
      result
    rescue => exception
      # Log the error
      log_controller_action_error(exception, audit_start_time)
      
      # Re-raise the exception
      raise
    ensure
      # Clean up audit context
      clear_audit_context
    end
  end
  
  def log_controller_action_start
    return if skip_audit_for_action?
    
    AuditLog.create!(
      user: current_user_for_audit,
      organization: current_organization_for_audit,
      action: "#{action_name}_start",
      category: determine_audit_category,
      resource_type: controller_resource_type,
      severity: 'info',
      details: controller_audit_details.merge(
        status: 'started',
        request_id: request.uuid
      ),
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
  
  def log_controller_action_success(start_time)
    return if skip_audit_for_action?
    
    duration = ((Time.current - start_time) * 1000).round(2) # milliseconds
    
    AuditLog.create!(
      user: current_user_for_audit,
      organization: current_organization_for_audit,
      action: action_name,
      category: determine_audit_category,
      resource_type: controller_resource_type,
      severity: determine_success_severity(duration),
      details: controller_audit_details.merge(
        status: 'completed',
        duration_ms: duration,
        request_id: request.uuid,
        response_status: response.status
      ),
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
  
  def log_controller_action_error(exception, start_time)
    duration = ((Time.current - start_time) * 1000).round(2) # milliseconds
    
    AuditLog.create!(
      user: current_user_for_audit,
      organization: current_organization_for_audit,
      action: "#{action_name}_error",
      category: 'security', # Errors might be security-related
      resource_type: controller_resource_type,
      severity: determine_error_severity(exception),
      details: controller_audit_details.merge(
        status: 'error',
        duration_ms: duration,
        request_id: request.uuid,
        error_class: exception.class.name,
        error_message: exception.message,
        error_backtrace: Rails.env.development? ? exception.backtrace&.first(5) : nil
      ),
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    
    # Create security alert for certain types of errors
    create_security_alert_for_error(exception) if should_alert_for_error?(exception)
  end
  
  def log_data_access
    return if skip_audit_for_action?
    return unless should_log_data_access?
    
    # Log data access for show/index actions
    resource = instance_variable_get("@#{controller_name.singularize}")
    resources = instance_variable_get("@#{controller_name}")
    
    if resource
      AuditLog.log_data_access(
        current_user_for_audit,
        resource,
        'view_details',
        audit_context_details
      )
    elsif resources&.respond_to?(:count)
      AuditLog.create!(
        user: current_user_for_audit,
        organization: current_organization_for_audit,
        action: 'view_list',
        category: 'data_access',
        resource_type: controller_resource_type,
        severity: 'info',
        details: audit_context_details.merge(
          records_count: resources.count,
          filtered: params.except(:controller, :action, :format).present?
        ),
        ip_address: request.remote_ip
      )
    end
  end
  
  def current_user_for_audit
    if respond_to?(:current_user)
      current_user
    else
      nil
    end
  end
  
  def current_organization_for_audit
    user = current_user_for_audit
    return user.organization if user&.respond_to?(:organization)
    return ActsAsTenant.current_tenant if defined?(ActsAsTenant)
    nil
  end
  
  def controller_resource_type
    # Try to determine the resource type from controller name
    controller_name.classify
  rescue
    'Controller'
  end
  
  def determine_audit_category
    case action_name
    when 'index', 'show' then 'data_access'
    when 'new', 'create' then 'data_modification'
    when 'edit', 'update' then 'data_modification'
    when 'destroy', 'delete' then 'data_modification'
    when 'sign_in', 'login' then 'authentication'
    when 'sign_out', 'logout' then 'authentication'
    else 'system_access'
    end
  end
  
  def determine_success_severity(duration)
    case duration
    when 0...1000 then 'info'      # < 1 second
    when 1000...5000 then 'warning' # 1-5 seconds  
    else 'error'                     # > 5 seconds
    end
  end
  
  def determine_error_severity(exception)
    case exception
    when ActiveRecord::RecordNotFound, ActionController::RoutingError
      'warning'
    when SecurityError
      'error'
    when StandardError
      'error'
    else
      'critical'
    end
  end

  def should_log_data_access?
    # Only log for index actions and not for authentication controllers
    action_name == 'index' && 
    !controller_name.include?('session') && 
    !controller_name.include?('registration')
  end
  
  def controller_audit_details
    details = {
      controller: self.class.name,
      action: action_name,
      method: request.method,
      path: request.path,
      format: request.format.to_s,
      timestamp: Time.current.iso8601
    }
    
    # Add filtered parameters (excluding sensitive data)
    details[:parameters] = filter_sensitive_params(params.except(:controller, :action, :format))
    
    # Add referer if present
    details[:referer] = request.referer if request.referer.present?
    
    # Add session info (non-sensitive)
    if session.present?
      details[:session_id] = session.id&.to_s
      details[:has_session] = true
    end
    
    details
  end
  
  def audit_context_details
    {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_id: request.uuid,
      timestamp: Time.current.iso8601
    }
  end
  
  def filter_sensitive_params(params)
    # Filter out sensitive parameters
    sensitive_keys = %w[
      password password_confirmation
      token api_key secret
      ssn social_security_number
      credit_card_number bank_account
    ]
    
    filtered = params.deep_dup
    filter_hash_recursively(filtered, sensitive_keys)
    filtered
  end
  
  def filter_hash_recursively(hash, sensitive_keys)
    hash.each do |key, value|
      if sensitive_keys.any? { |sk| key.to_s.downcase.include?(sk) }
        hash[key] = '[FILTERED]'
      elsif value.is_a?(Hash)
        filter_hash_recursively(value, sensitive_keys)
      elsif value.is_a?(Array) && value.first.is_a?(Hash)
        value.each { |item| filter_hash_recursively(item, sensitive_keys) if item.is_a?(Hash) }
      end
    end
  end
  
  def skip_audit_for_action?
    # Skip audit for certain actions that are too noisy
    skip_actions = %w[ping health_check status heartbeat]
    skip_actions.include?(action_name) ||
    request.path.start_with?('/assets') ||
    request.path.start_with?('/favicon') ||
    request.path.start_with?('/robots.txt')
  end
  
  def should_log_data_access?
    # Only log data access for authenticated users
    current_user_for_audit.present?
  end
  
  def should_alert_for_error?(exception)
    # Create alerts for security-related errors
    security_errors = [
      'SecurityError',
      'CanCan::AccessDenied', 
      'ActionController::InvalidAuthenticityToken',
      'ActiveRecord::StatementInvalid' # Potential SQL injection
    ]
    
    security_errors.include?(exception.class.name) ||
    exception.message.downcase.include?('unauthorized') ||
    exception.message.downcase.include?('forbidden')
  end
  
  def create_security_alert_for_error(exception)
    return unless defined?(SecurityAlert) && SecurityAlert.table_exists?
    
    begin
      SecurityAlert.create!(
        alert_type: 'controller_error',
        severity: determine_error_severity(exception) == 'critical' ? 'high' : 'medium',
        status: 'active',
        message: "Controller error in #{self.class.name}##{action_name}: #{exception.class}",
        data: {
          controller: self.class.name,
          action: action_name,
          error_class: exception.class.name,
          error_message: exception.message,
          user_id: current_user_for_audit&.id,
          ip_address: request.remote_ip,
          path: request.path,
          method: request.method,
          parameters: filter_sensitive_params(params.except(:controller, :action, :format))
        },
        triggered_at: Time.current,
        organization: current_organization_for_audit
      )
    rescue => e
      Rails.logger.error "Failed to create security alert for controller error: #{e.message}"
    end
  end
  
  def clear_audit_context
    # Clear thread-local variables
    Thread.current[:current_user] = nil
    Thread.current[:request_ip] = nil
    Thread.current[:user_agent] = nil
    
    # Clear Current attributes if defined
    if defined?(Current)
      Current.user = nil
      Current.ip_address = nil
      Current.user_agent = nil
      Current.request_id = nil
      Current.controller = nil
      Current.action = nil
      Current.request_path = nil
      Current.request_method = nil
    end
  end
  
  # Class methods for configuration
  module ClassMethods
    def skip_audit_logging_for(*actions)
      @skip_audit_actions ||= []
      @skip_audit_actions.concat(actions.map(&:to_s))
    end
    
    def audit_sensitive_actions(*actions)
      @sensitive_audit_actions ||= []
      @sensitive_audit_actions.concat(actions.map(&:to_s))
    end
    
    def skip_audit_actions
      @skip_audit_actions || []
    end
    
    def sensitive_audit_actions
      @sensitive_audit_actions || []
    end
  end
end