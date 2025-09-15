class RolePermission < ApplicationRecord
  belongs_to :role
  belongs_to :permission
  belongs_to :granted_by, class_name: 'User', optional: true

  validates :role_id, uniqueness: { scope: :permission_id }
  validates :granted_at, presence: true

  before_validation :set_granted_at, on: :create
  after_create :log_permission_granted
  after_destroy :log_permission_revoked

  scope :system_permissions, -> { joins(:permission).where(permissions: { system_permission: true }) }
  scope :custom_permissions, -> { joins(:permission).where(permissions: { system_permission: false }) }
  scope :for_resource, ->(resource) { joins(:permission).where(permissions: { resource: resource }) }
  scope :for_action, ->(action) { joins(:permission).where(permissions: { action: action }) }

  def can_be_revoked?
    # System permissions on system roles generally can't be revoked
    return false if role.system_role? && permission.system_permission?
    
    # Check if this permission is required by role hierarchy
    return false if required_by_role_hierarchy?
    
    # Check if other permissions depend on this one
    return false if has_dependent_permissions?
    
    true
  end

  def can_be_revoked_by?(current_user)
    return false unless current_user
    return false unless can_be_revoked?

    # Check if user has permission to manage this role's permissions
    permission.can_be_granted_by?(current_user.roles.first) # Simplified check
  end

  def revoke!(revoked_by = nil)
    return false unless can_be_revoked?

    transaction do
      # Remove dependent role permissions first
      remove_dependent_permissions!
      
      # Log the revocation
      permission.log_permission_revoked(role, revoked_by || Current.user)
      
      # Destroy this permission assignment
      destroy!
    end
  end

  def assignment_summary
    {
      role: role.display_name,
      permission: permission.display_name,
      resource: permission.resource,
      action: permission.action,
      granted_at: granted_at,
      granted_by: granted_by&.email || 'System',
      system_permission: permission.system_permission?,
      can_revoke: can_be_revoked?
    }
  end

  def impact_analysis
    {
      affected_users: users_affected.count,
      affected_organizations: organizations_affected.count,
      dependent_permissions: dependent_permissions.count,
      prerequisite_permissions: prerequisite_permissions.count,
      is_critical: critical_permission?,
      revocation_safe: can_be_revoked?
    }
  end

  def users_affected
    User.joins(roles: :role_permissions)
        .where(role_permissions: { id: id })
        .distinct
  end

  def organizations_affected
    if role.system_role?
      # System roles can affect multiple organizations
      Organization.joins(users: { roles: :role_permissions })
                 .where(role_permissions: { id: id })
                 .distinct
    else
      # Organization-specific role
      role.organization ? [role.organization] : []
    end
  end

  def dependent_permissions
    # Permissions that require this permission to function
    RolePermission.joins(:permission)
                  .where(role: role)
                  .where.not(id: id)
                  .select { |rp| rp.permission.prerequisite_permissions.include?(permission) }
  end

  def prerequisite_permissions
    # Permissions required for this permission to be meaningful
    permission.prerequisite_permissions
              .joins(:role_permissions)
              .where(role_permissions: { role: role })
  end

  def critical_permission?
    permission.system_critical_permission? || 
    permission.management_permission? ||
    users_affected.count > 10 # More than 10 users affected
  end

  def usage_statistics
    {
      permission_name: permission.name,
      role_name: role.name,
      users_with_permission: users_affected.count,
      organizations_using: organizations_affected.count,
      last_used: last_permission_usage,
      frequency_score: calculate_frequency_score
    }
  end

  def self.bulk_assign(role, permission_names, granted_by = nil)
    results = { success: [], failed: [] }
    
    permission_names.each do |permission_name|
      permission = Permission.find_by(name: permission_name)
      
      if permission
        role_permission = find_or_initialize_by(role: role, permission: permission)
        
        if role_permission.persisted?
          results[:failed] << { permission_name: permission_name, error: 'Already assigned' }
        else
          role_permission.granted_by = granted_by
          
          if role_permission.save
            results[:success] << permission_name
          else
            results[:failed] << { 
              permission_name: permission_name, 
              error: role_permission.errors.full_messages.join(', ') 
            }
          end
        end
      else
        results[:failed] << { permission_name: permission_name, error: 'Permission not found' }
      end
    end
    
    results
  end

  def self.bulk_revoke(role, permission_names, revoked_by = nil)
    results = { success: [], failed: [] }
    
    permission_names.each do |permission_name|
      role_permission = joins(:permission)
                       .find_by(role: role, permissions: { name: permission_name })
      
      if role_permission
        if role_permission.revoke!(revoked_by)
          results[:success] << permission_name
        else
          results[:failed] << { 
            permission_name: permission_name, 
            error: 'Cannot be revoked' 
          }
        end
      else
        results[:failed] << { permission_name: permission_name, error: 'Not assigned' }
      end
    end
    
    results
  end

  private

  def set_granted_at
    self.granted_at ||= Time.current
  end

  def log_permission_granted
    permission.log_permission_granted(role, granted_by || Current.user)
  end

  def log_permission_revoked
    permission.log_permission_revoked(role, Current.user)
  end

  def required_by_role_hierarchy?
    # Check if this permission is automatically granted by role hierarchy
    role.default_permissions_for_role.include?(permission.name)
  end

  def has_dependent_permissions?
    dependent_permissions.any?
  end

  def remove_dependent_permissions!
    # This is a placeholder - in practice, you might want to handle this more carefully
    # dependent_permissions.each(&:destroy!)
  end

  def last_permission_usage
    # This would require tracking permission usage in audit logs
    AuditLog.where(
      user: users_affected,
      details: { permission_used: permission.name }
    ).maximum(:created_at)
  end

  def calculate_frequency_score
    # Calculate how frequently this permission is used
    return 0 unless last_permission_usage
    
    days_since_last_use = (Time.current - last_permission_usage) / 1.day
    case days_since_last_use
    when 0..1 then 10      # Used today/yesterday = high frequency
    when 2..7 then 7       # Used this week = medium-high frequency  
    when 8..30 then 4      # Used this month = medium frequency
    when 31..90 then 2     # Used this quarter = low frequency
    else 1                 # Used longer ago = very low frequency
    end
  end
end