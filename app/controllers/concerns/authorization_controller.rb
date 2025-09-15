module AuthorizationController
  extend ActiveSupport::Concern
  
  included do
    include Authorizable
    
    before_action :set_current_user
    before_action :ensure_authenticated
    
    rescue_from AuthorizationError, with: :handle_authorization_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  end

  class_methods do
    def authorize_resource(action_map = {})
      before_action :authorize_resource_access, except: [:index, :show]
      before_action :authorize_specific_resource, only: [:show, :edit, :update, :destroy]
      
      # Store action mapping for this controller
      class_variable_set(:@@resource_action_map, action_map)
    end

    def skip_authorization(*actions)
      skip_before_action :authorize_resource_access, only: actions
      skip_before_action :authorize_specific_resource, only: actions
    end

    def require_role(*role_names, only: [], except: [])
      before_action -> { require_any_role(*role_names) }, only: only, except: except
    end

    def require_permission(permission_name, only: [], except: [])
      before_action -> { require_specific_permission(permission_name) }, only: only, except: except
    end

    def require_feature(feature_name, only: [], except: [])
      before_action -> { require_feature_access(feature_name) }, only: only, except: except
    end
  end

  private

  def set_current_user
    self.current_user = current_user_from_session || current_user_from_api
    Current.user = self.current_user
  end

  def current_user_from_session
    # Devise or session-based authentication
    user_signed_in? ? current_user : nil
  end

  def current_user_from_api
    # API key or JWT authentication
    return nil unless request.headers['Authorization'].present?
    
    token = request.headers['Authorization'].split(' ').last
    authenticate_via_api_key(token) || authenticate_via_jwt(token)
  end

  def authenticate_via_api_key(token)
    api_key = ApiKey.active.find_by(key: token)
    return nil unless api_key

    # Log API usage
    api_key.log_usage(
      endpoint: request.path,
      method: request.method,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      status_code: response.status
    )

    api_key.user
  end

  def authenticate_via_jwt(token)
    # JWT authentication logic would go here
    # This is a placeholder for JWT implementation
    nil
  end

  def ensure_authenticated
    unless current_user
      handle_unauthenticated_request
    end
  end

  def handle_unauthenticated_request
    if request.format.json? || api_request?
      render json: { error: 'Authentication required' }, status: :unauthorized
    else
      redirect_to new_user_session_path, alert: 'Please sign in to continue'
    end
  end

  def api_request?
    request.path.start_with?('/api/') || request.headers['Authorization'].present?
  end

  # Resource authorization methods
  def authorize_resource_access
    resource_class = controller_name.classify.constantize
    action = action_for_authorization
    
    authorize!(action, resource_class, authorization_context)
  rescue NameError
    # Controller doesn't have a corresponding model, skip authorization
    Rails.logger.warn "No model found for controller #{controller_name}, skipping resource authorization"
  end

  def authorize_specific_resource
    resource = find_resource_for_authorization
    return unless resource
    
    action = action_for_authorization
    authorize!(action, resource, authorization_context)
  end

  def find_resource_for_authorization
    resource_class = controller_name.classify.constantize
    resource_id = params[:id] || params["#{controller_name.singularize}_id"]
    
    return nil unless resource_id
    
    if resource_class.respond_to?(:with_discarded)
      resource_class.with_discarded.find(resource_id)
    else
      resource_class.find(resource_id)
    end
  rescue NameError, ActiveRecord::RecordNotFound
    nil
  end

  def action_for_authorization
    action_map = self.class.class_variable_get(:@@resource_action_map) rescue {}
    action_map[action_name.to_sym] || action_name
  end

  def authorization_context
    {
      controller: controller_name,
      action: action_name,
      organization_id: current_user&.organization_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      params: params.except(:controller, :action, :authenticity_token)
    }
  end

  # Role and permission requirements
  def require_any_role(*role_names)
    unless has_any_role?(*role_names)
      raise AuthorizationError, "Requires one of these roles: #{role_names.join(', ')}"
    end
  end

  def require_specific_permission(permission_name)
    unless has_permission?(permission_name)
      raise AuthorizationError, "Requires permission: #{permission_name}"
    end
  end

  def require_feature_access(feature_name)
    unless feature_enabled?(feature_name)
      raise AuthorizationError, "Feature '#{feature_name}' is not available"
    end
  end

  def require_admin
    require_any_role('super_admin', 'admin')
  end

  def require_super_admin
    require_any_role('super_admin')
  end

  def require_organization_admin
    unless organization_admin?
      raise AuthorizationError, "Requires organization administrator access"
    end
  end

  def require_minimum_role_level(level)
    unless has_role_level?(level)
      raise AuthorizationError, "Requires minimum role level: #{level}"
    end
  end

  # Organization context methods
  def ensure_organization_access
    org_id = params[:organization_id] || current_user&.organization_id
    return unless org_id

    organization = Organization.find(org_id)
    authorize_organization_access!(organization)
    
    @current_organization = organization
  end

  def current_organization
    @current_organization ||= current_user&.organization
  end

  def set_tenant_for_organization
    return unless current_organization
    
    ActsAsTenant.current_tenant = current_organization
  end

  # Error handling
  def handle_authorization_error(exception)
    log_authorization_failure(exception)
    
    if request.format.json? || api_request?
      render json: { 
        error: 'Access Denied', 
        message: exception.message 
      }, status: :forbidden
    else
      redirect_back(
        fallback_location: root_path,
        alert: "Access denied: #{exception.message}"
      )
    end
  end

  def handle_not_found(exception)
    if request.format.json? || api_request?
      render json: { 
        error: 'Not Found', 
        message: 'The requested resource was not found' 
      }, status: :not_found
    else
      redirect_to root_path, alert: 'The requested page was not found'
    end
  end

  def log_authorization_failure(exception)
    AuditLog.log_authorization(
      current_user,
      'authorization_failed',
      {
        controller: controller_name,
        action: action_name,
        error_message: exception.message,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        requested_url: request.url,
        severity: 'warning'
      }
    )
  end

  # Helper methods for common authorization patterns
  def authorize_own_resource(resource, action = :read)
    unless resource.user_id == current_user.id || can?(action, resource)
      raise AuthorizationError, "You can only #{action} your own resources"
    end
  end

  def authorize_organization_resource(resource, action = :read)
    unless resource.organization_id == current_user.organization_id || can?(action, resource)
      raise AuthorizationError, "You can only #{action} resources in your organization"
    end
  end

  def filter_by_authorization(collection, action = :read)
    filter_authorized(collection, action, authorization_context)
  end

  # Bulk operations authorization
  def authorize_bulk_action(action, resource_class, selected_ids)
    return if selected_ids.empty?
    
    # Check general permission
    authorize!(action, resource_class)
    
    # Check each specific resource
    resources = resource_class.where(id: selected_ids)
    resources.find_each do |resource|
      authorize!(action, resource)
    end
  end

  # API-specific authorization
  def authorize_api_access
    return unless api_request?
    
    api_key = current_api_key
    return unless api_key
    
    # Check API key scopes
    required_scope = determine_api_scope
    unless api_key.has_scope?(required_scope)
      raise AuthorizationError, "API key missing required scope: #{required_scope}"
    end
    
    # Check rate limits
    if api_key.rate_limit && api_key.usage_this_hour >= api_key.rate_limit
      raise AuthorizationError, "API rate limit exceeded"
    end
  end

  def current_api_key
    return @current_api_key if defined?(@current_api_key)
    
    token = request.headers['Authorization']&.split(' ')&.last
    @current_api_key = ApiKey.active.find_by(key: token) if token
  end

  def determine_api_scope
    resource = controller_name.singularize
    action = case action_name
            when 'index', 'show' then 'read'
            when 'create', 'update', 'destroy' then 'write'
            else 'access'
            end
    
    "#{resource}:#{action}"
  end

  # Feature flag methods
  def ensure_feature_enabled(feature_name)
    authorize_feature!(feature_name, { organization: current_organization })
  end

  def feature_flag_context
    {
      user: current_user,
      organization: current_organization,
      controller: controller_name,
      action: action_name
    }
  end
end