class Admin::RolesController < ApplicationController
  include AuthorizationController
  
  before_action :require_admin
  before_action :set_role, only: [:show, :edit, :update, :destroy, :assign_permissions, :revoke_permissions]
  before_action :authorize_role_management, only: [:edit, :update, :destroy, :assign_permissions, :revoke_permissions]
  
  def index
    @system_roles = Role.system_roles.includes(:permissions, :users).by_level
    @organization_roles = if current_user.super_admin?
                           Role.includes(:organization, :permissions, :users)
                               .where.not(organization_id: nil)
                               .order(:organization_id, :level)
                         else
                           current_organization&.roles&.includes(:permissions, :users)&.by_level || Role.none
                         end
    
    @role_statistics = {
      total_system_roles: @system_roles.count,
      total_organization_roles: @organization_roles.count,
      total_users_with_roles: User.joins(:roles).distinct.count,
      most_used_role: most_used_role,
      recent_role_assignments: recent_role_assignments
    }
  end

  def show
    @permissions = @role.all_permissions.includes(:role_permissions)
    @direct_permissions = @role.permissions
    @inherited_permissions = @role.inherited_permissions
    @users_with_role = @role.users.includes(:organization).limit(10)
    @role_usage_stats = @role.usage_stats
    @permission_categories = group_permissions_by_category(@permissions)
  end

  def new
    @role = current_organization&.roles&.build || Role.new
    @available_permissions = Permission.active.order(:resource, :action)
    @permission_categories = group_permissions_by_category(@available_permissions)
  end

  def create
    @role = if role_params[:organization_id].present?
              Organization.find(role_params[:organization_id]).roles.build(role_params)
            else
              Role.new(role_params.merge(organization_id: nil)) # System role
            end

    if @role.save
      # Assign selected permissions
      assign_selected_permissions
      
      AuditLog.log_user_management(
        current_user,
        'role_created',
        {
          role_id: @role.id,
          role_name: @role.name,
          organization_id: @role.organization_id,
          permissions_assigned: params[:permission_ids]&.size || 0
        }
      )
      
      redirect_to admin_role_path(@role), notice: 'Role created successfully.'
    else
      @available_permissions = Permission.active.order(:resource, :action)
      @permission_categories = group_permissions_by_category(@available_permissions)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_permissions = Permission.active.order(:resource, :action)
    @permission_categories = group_permissions_by_category(@available_permissions)
    @assigned_permission_ids = @role.permissions.pluck(:id)
  end

  def update
    old_attributes = @role.attributes.dup
    
    if @role.update(role_params)
      # Handle permission updates
      handle_permission_updates
      
      # Log the update
      log_role_update(old_attributes)
      
      redirect_to admin_role_path(@role), notice: 'Role updated successfully.'
    else
      @available_permissions = Permission.active.order(:resource, :action)
      @permission_categories = group_permissions_by_category(@available_permissions)
      @assigned_permission_ids = @role.permissions.pluck(:id)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @role.can_be_deleted?
      redirect_to admin_role_path(@role), alert: 'This role cannot be deleted as it has active users or dependencies.'
      return
    end

    role_name = @role.name
    organization_name = @role.organization&.name || 'System'
    
    @role.destroy!
    
    AuditLog.log_user_management(
      current_user,
      'role_deleted',
      {
        role_name: role_name,
        organization_name: organization_name,
        severity: 'high'
      }
    )
    
    redirect_to admin_roles_path, notice: "Role '#{role_name}' deleted successfully."
  end

  def assign_permissions
    if request.post?
      permission_ids = params[:permission_ids] || []
      results = RolePermission.bulk_assign(@role, permission_names_from_ids(permission_ids), current_user)
      
      if results[:failed].empty?
        redirect_to admin_role_path(@role), notice: "#{results[:success].size} permissions assigned successfully."
      else
        flash.now[:alert] = "Some permissions could not be assigned: #{results[:failed].map { |f| f[:error] }.join(', ')}"
        render :assign_permissions
      end
    else
      @available_permissions = Permission.active.where.not(
        id: @role.permissions.select(:id)
      ).order(:resource, :action)
      @permission_categories = group_permissions_by_category(@available_permissions)
    end
  end

  def revoke_permissions
    if request.post?
      permission_ids = params[:permission_ids] || []
      results = RolePermission.bulk_revoke(@role, permission_names_from_ids(permission_ids), current_user)
      
      if results[:failed].empty?
        redirect_to admin_role_path(@role), notice: "#{results[:success].size} permissions revoked successfully."
      else
        flash.now[:alert] = "Some permissions could not be revoked: #{results[:failed].map { |f| f[:error] }.join(', ')}"
        render :revoke_permissions
      end
    else
      @assigned_permissions = @role.permissions.order(:resource, :action)
      @permission_categories = group_permissions_by_category(@assigned_permissions)
      @revokable_permissions = @assigned_permissions.select { |p| can_revoke_permission?(@role, p) }
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def authorize_role_management
    unless can?(:manage, @role) || (@role.organization_role? && can_access_organization?(@role.organization))
      raise AuthorizationError, "You don't have permission to manage this role"
    end
  end

  def role_params
    params.require(:role).permit(:name, :display_name, :description, :level, :active, :organization_id)
  end

  def assign_selected_permissions
    return unless params[:permission_ids].present?
    
    permission_names = permission_names_from_ids(params[:permission_ids])
    RolePermission.bulk_assign(@role, permission_names, current_user)
  end

  def handle_permission_updates
    return unless params[:permission_ids]
    
    current_permission_ids = @role.permissions.pluck(:id).map(&:to_s)
    new_permission_ids = params[:permission_ids] || []
    
    # Permissions to add
    to_add = new_permission_ids - current_permission_ids
    if to_add.any?
      RolePermission.bulk_assign(@role, permission_names_from_ids(to_add), current_user)
    end
    
    # Permissions to remove
    to_remove = current_permission_ids - new_permission_ids
    if to_remove.any?
      RolePermission.bulk_revoke(@role, permission_names_from_ids(to_remove), current_user)
    end
  end

  def permission_names_from_ids(permission_ids)
    Permission.where(id: permission_ids).pluck(:name)
  end

  def group_permissions_by_category(permissions)
    permissions.group_by(&:resource).transform_values do |resource_permissions|
      resource_permissions.group_by(&:action)
    end
  end

  def most_used_role
    Role.joins(:users)
        .group('roles.id')
        .order('COUNT(users.id) DESC')
        .limit(1)
        .pick(:name)
  end

  def recent_role_assignments
    UserRole.includes(:user, :role)
           .order(created_at: :desc)
           .limit(5)
           .map do |ur|
             {
               user: ur.user.email,
               role: ur.role.display_name,
               assigned_at: ur.granted_at,
               organization: ur.role.organization&.name || 'System'
             }
           end
  end

  def log_role_update(old_attributes)
    changes = @role.previous_changes.except('updated_at')
    return if changes.empty?
    
    AuditLog.log_user_management(
      current_user,
      'role_updated',
      {
        role_id: @role.id,
        role_name: @role.name,
        changes: changes,
        organization_id: @role.organization_id
      }
    )
  end

  def can_revoke_permission?(role, permission)
    role_permission = role.role_permissions.find_by(permission: permission)
    role_permission&.can_be_revoked_by?(current_user) || false
  end
end
