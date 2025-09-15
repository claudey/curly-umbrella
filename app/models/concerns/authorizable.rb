module Authorizable
  extend ActiveSupport::Concern

  included do
    # Add authorization tracking
    attr_accessor :current_user, :authorization_context
  end

  class_methods do
    def authorize_resource(action, options = {})
      before_action -> { authorize_action(action, options) }
    end

    def authorize_specific_resource(resource_method, action, options = {})
      before_action -> { 
        resource = send(resource_method)
        authorize_resource_action(resource, action, options) 
      }
    end
  end

  # Core authorization method
  def can?(action, resource = nil, context = {})
    return false unless current_user
    
    # Handle different resource types
    case resource
    when Class
      can_access_resource_type?(action, resource, context)
    when ActiveRecord::Base
      can_access_specific_resource?(action, resource, context)
    when String, Symbol
      can_perform_named_action?(action, resource, context)
    else
      can_perform_general_action?(action, context)
    end
  end

  def cannot?(action, resource = nil, context = {})
    !can?(action, resource, context)
  end

  # Policy-based authorization
  def authorize!(action, resource = nil, context = {})
    unless can?(action, resource, context)
      raise_authorization_error(action, resource, context)
    end
  end

  def authorize_action(action, options = {})
    resource = options[:resource]
    context = options.except(:resource)
    
    authorize!(action, resource, context)
  end

  def authorize_resource_action(resource, action, options = {})
    context = options.merge(resource_instance: resource)
    authorize!(action, resource, context)
  end

  # Permission checking methods
  def has_permission?(permission_name)
    return false unless current_user
    current_user.has_permission?(permission_name)
  end

  def has_any_permission?(*permission_names)
    return false unless current_user
    permission_names.any? { |perm| current_user.has_permission?(perm) }
  end

  def has_all_permissions?(*permission_names)
    return false unless current_user
    permission_names.all? { |perm| current_user.has_permission?(perm) }
  end

  # Role checking methods
  def has_role?(role_name)
    return false unless current_user
    current_user.has_role?(role_name)
  end

  def has_any_role?(*role_names)
    return false unless current_user
    role_names.any? { |role| current_user.has_role?(role) }
  end

  def has_role_level?(minimum_level)
    return false unless current_user
    current_user.highest_role_level >= minimum_level
  end

  # Organization-based authorization
  def can_access_organization?(organization)
    return false unless current_user && organization
    current_user.can_access_organization?(organization)
  end

  def authorize_organization_access!(organization)
    unless can_access_organization?(organization)
      raise AuthorizationError, "Access denied to organization: #{organization.name}"
    end
  end

  # Resource-specific authorization helpers
  def can_create?(resource_class, context = {})
    can?(:create, resource_class, context)
  end

  def can_read?(resource, context = {})
    can?(:read, resource, context)
  end

  def can_update?(resource, context = {})
    can?(:update, resource, context)
  end

  def can_destroy?(resource, context = {})
    can?(:destroy, resource, context)
  end

  def can_manage?(resource, context = {})
    can?(:manage, resource, context)
  end

  # Bulk authorization for collections
  def filter_authorized(collection, action, context = {})
    return collection.none unless current_user
    
    collection.select { |item| can?(action, item, context) }
  end

  def authorize_collection!(collection, action, context = {})
    unauthorized = collection.reject { |item| can?(action, item, context) }
    
    if unauthorized.any?
      raise AuthorizationError, 
        "Access denied to #{unauthorized.size} items in collection"
    end
  end

  # Context-aware authorization
  def with_authorization_context(context = {})
    old_context = @authorization_context
    @authorization_context = (old_context || {}).merge(context)
    yield
  ensure
    @authorization_context = old_context
  end

  def authorization_context
    @authorization_context || {}
  end

  # Administrative checks
  def admin?
    has_any_role?('super_admin', 'admin')
  end

  def super_admin?
    has_role?('super_admin')
  end

  def organization_admin?
    has_role?('admin') && current_user&.organization_id.present?
  end

  def system_admin?
    has_role?('super_admin') || (has_role?('admin') && current_user&.organization_id.nil?)
  end

  # Feature flag authorization
  def feature_enabled?(feature_name, context = {})
    # Check if user has permission to access feature
    feature_permission = "features.#{feature_name}"
    return false unless has_permission?(feature_permission)
    
    # Check organization-level feature flags
    org = context[:organization] || current_user&.organization
    return true unless org # System users get all features
    
    org.feature_enabled?(feature_name)
  end

  def authorize_feature!(feature_name, context = {})
    unless feature_enabled?(feature_name, context)
      raise AuthorizationError, "Feature '#{feature_name}' is not available"
    end
  end

  # Audit logging for authorization
  def log_authorization_attempt(action, resource, result, context = {})
    return unless should_log_authorization?(action, resource)
    
    AuditLog.log_authorization(
      current_user,
      action,
      {
        resource_type: resource.class.name,
        resource_id: resource.try(:id),
        result: result ? 'allowed' : 'denied',
        context: context.slice(:organization_id, :ip_address, :user_agent)
      }
    )
  end

  private

  def can_access_resource_type?(action, resource_class, context)
    resource_name = resource_class.name.underscore.pluralize
    permission_name = "#{resource_name}.#{action}"
    
    # Check direct permission
    return true if has_permission?(permission_name)
    
    # Check management permission
    management_permission = "#{resource_name}.manage"
    return true if has_permission?(management_permission)
    
    # Check role-based access
    check_role_based_access(action, resource_class, context)
  end

  def can_access_specific_resource?(action, resource, context)
    # First check general resource access
    return false unless can_access_resource_type?(action, resource.class, context)
    
    # Then check resource-specific constraints
    check_resource_ownership(resource, context) &&
    check_organization_constraints(resource, context) &&
    check_custom_resource_rules(action, resource, context)
  end

  def can_perform_named_action?(action, named_resource, context)
    permission_name = "#{named_resource}.#{action}"
    has_permission?(permission_name)
  end

  def can_perform_general_action?(action, context)
    # For general actions, check if user has any relevant permissions
    current_user.permission_names.any? { |perm| perm.end_with?(".#{action}") }
  end

  def check_role_based_access(action, resource_class, context)
    # Define role-based access rules
    case action.to_s
    when 'read', 'index'
      has_role_level?(10) # Viewer level and above
    when 'create'
      has_role_level?(40) # Agent level and above
    when 'update'
      has_role_level?(50) # Broker level and above
    when 'destroy'
      has_role_level?(70) # Manager level and above
    else
      has_role_level?(90) # Admin level for unknown actions
    end
  end

  def check_resource_ownership(resource, context)
    # Check if user owns or has access to the resource
    return true unless resource.respond_to?(:user_id)
    
    # Owner always has access
    return true if resource.user_id == current_user.id
    
    # Organization members can access organization resources
    if resource.respond_to?(:organization_id)
      return current_user.organization_id == resource.organization_id
    end
    
    false
  end

  def check_organization_constraints(resource, context)
    # Skip if no organization constraints
    return true unless resource.respond_to?(:organization_id)
    return true unless resource.organization_id
    
    # Check if user can access this organization's resources
    can_access_organization?(Organization.find(resource.organization_id))
  end

  def check_custom_resource_rules(action, resource, context)
    # Implement custom authorization rules per resource type
    method_name = "authorize_#{resource.class.name.underscore}_#{action}"
    
    if respond_to?(method_name, true)
      send(method_name, resource, context)
    else
      true # No custom rules means access allowed
    end
  end

  def raise_authorization_error(action, resource, context)
    resource_info = case resource
                   when Class then resource.name
                   when ActiveRecord::Base then "#{resource.class.name}##{resource.id}"
                   else resource.to_s
                   end
    
    message = "Access denied: cannot #{action} #{resource_info}"
    
    # Log the authorization failure
    log_authorization_attempt(action, resource, false, context)
    
    raise AuthorizationError, message
  end

  def should_log_authorization?(action, resource)
    # Log high-risk actions or failures
    high_risk_actions = %w[destroy delete manage admin export]
    high_risk_actions.include?(action.to_s) || 
    resource.is_a?(Class) && %w[User Role Permission].include?(resource.name)
  end

  # Custom authorization rules for specific resources
  def authorize_user_destroy(user, context)
    # Users can't delete themselves
    return false if user.id == current_user.id
    
    # Can only delete users with lower role levels
    current_user.highest_role_level > user.highest_role_level
  end

  def authorize_role_manage(role, context)
    # System roles can only be managed by super admins
    return false if role.system_role? && !super_admin?
    
    # Organization roles can only be managed within same organization
    if role.organization_role?
      return can_access_organization?(role.organization)
    end
    
    true
  end

  def authorize_application_update(application, context)
    # Applications can be updated by:
    # 1. Owner
    # 2. Organization members with broker+ level
    # 3. Assigned insurance company users
    
    return true if application.user_id == current_user.id
    return true if application.organization_id == current_user.organization_id && has_role_level?(50)
    
    # Check if user's organization is assigned to this application
    application.insurance_companies.include?(current_user.organization)
  end
end

# Custom authorization error
class AuthorizationError < StandardError; end