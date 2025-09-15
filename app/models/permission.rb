class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions

  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :resource, presence: true
  validates :action, presence: true

  scope :active, -> { where(active: true) }
  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :for_action, ->(action) { where(action: action) }
  scope :system_permissions, -> { where(system_permission: true) }
  scope :custom_permissions, -> { where(system_permission: false) }

  # Core resource types in the system
  RESOURCES = %w[
    users organizations roles permissions
    applications quotes policies claims
    clients brokerages insurance_companies
    reports exports audit_logs
    dashboard notifications settings
    integrations api_keys
    team billing risk_assessment
  ].freeze

  # Core actions that can be performed
  ACTIONS = %w[
    create read update delete
    manage view edit
    approve reject submit
    export import
    assign revoke
  ].freeze

  # System permissions that should always exist
  SYSTEM_PERMISSIONS = {
    # User Management
    'users.create' => 'Create new users',
    'users.read' => 'View user information',
    'users.update' => 'Edit user information',
    'users.delete' => 'Delete users',
    'users.manage' => 'Full user management',
    'users.view' => 'View users list',
    'users.edit' => 'Edit user profiles',

    # Organization Management
    'organizations.create' => 'Create organizations',
    'organizations.read' => 'View organization information',
    'organizations.update' => 'Edit organization settings',
    'organizations.delete' => 'Delete organizations',
    'organizations.manage' => 'Full organization management',

    # Role and Permission Management
    'roles.create' => 'Create new roles',
    'roles.read' => 'View roles',
    'roles.update' => 'Edit roles',
    'roles.delete' => 'Delete roles',
    'roles.manage' => 'Full role management',
    'roles.assign' => 'Assign roles to users',
    'permissions.manage' => 'Manage permissions',

    # Application Management
    'applications.create' => 'Create insurance applications',
    'applications.read' => 'View applications',
    'applications.update' => 'Edit applications',
    'applications.delete' => 'Delete applications',
    'applications.manage' => 'Full application management',
    'applications.view' => 'View applications list',
    'applications.edit' => 'Edit application details',
    'applications.submit' => 'Submit applications',
    'applications.approve' => 'Approve applications',
    'applications.reject' => 'Reject applications',

    # Quote Management
    'quotes.create' => 'Create quotes',
    'quotes.read' => 'View quotes',
    'quotes.update' => 'Edit quotes',
    'quotes.delete' => 'Delete quotes',
    'quotes.manage' => 'Full quote management',
    'quotes.view' => 'View quotes list',
    'quotes.edit' => 'Edit quote details',
    'quotes.submit' => 'Submit quotes',
    'quotes.approve' => 'Approve quotes',
    'quotes.reject' => 'Reject quotes',
    'quotes.compare' => 'Compare quotes',

    # Policy Management
    'policies.create' => 'Create policies',
    'policies.read' => 'View policies',
    'policies.update' => 'Edit policies',
    'policies.delete' => 'Delete policies',
    'policies.manage' => 'Full policy management',
    'policies.view' => 'View policies list',

    # Claims Management
    'claims.create' => 'Create claims',
    'claims.read' => 'View claims',
    'claims.update' => 'Edit claims',
    'claims.delete' => 'Delete claims',
    'claims.manage' => 'Full claims management',
    'claims.process' => 'Process claims',
    'claims.approve' => 'Approve claims',
    'claims.reject' => 'Reject claims',

    # Client Management
    'clients.create' => 'Create client records',
    'clients.read' => 'View client information',
    'clients.update' => 'Edit client information',
    'clients.delete' => 'Delete client records',
    'clients.manage' => 'Full client management',
    'clients.view' => 'View clients list',
    'clients.edit' => 'Edit client details',

    # Reporting and Analytics
    'reports.read' => 'View reports',
    'reports.create' => 'Create custom reports',
    'reports.manage' => 'Full reporting access',
    'reports.view' => 'View standard reports',
    'exports.create' => 'Export data',
    'exports.manage' => 'Manage exports',

    # Audit and Compliance
    'audit_logs.read' => 'View audit logs',
    'audit_logs.manage' => 'Manage audit logs',
    'audit_logs.export' => 'Export audit logs',

    # Dashboard and Interface
    'dashboard.view' => 'Access dashboard',
    'dashboard.manage' => 'Manage dashboard',
    'notifications.view' => 'View notifications',
    'notifications.manage' => 'Manage notifications',

    # System Settings
    'settings.read' => 'View system settings',
    'settings.update' => 'Edit system settings',
    'settings.manage' => 'Full settings management',

    # API and Integration
    'api_keys.create' => 'Create API keys',
    'api_keys.read' => 'View API keys',
    'api_keys.update' => 'Edit API keys',
    'api_keys.delete' => 'Delete API keys',
    'api_keys.manage' => 'Full API key management',
    'integrations.manage' => 'Manage integrations',

    # Team Management
    'team.view' => 'View team members',
    'team.manage' => 'Manage team',
    'team.invite' => 'Invite team members',

    # Billing and Finance
    'billing.view' => 'View billing information',
    'billing.manage' => 'Manage billing',

    # Risk Assessment
    'risk_assessment.view' => 'View risk assessments',
    'risk_assessment.create' => 'Create risk assessments',
    'risk_assessment.manage' => 'Manage risk assessments'
  }.freeze

  def self.create_system_permissions!
    SYSTEM_PERMISSIONS.each do |permission_name, description|
      resource, action = permission_name.split('.', 2)
      
      find_or_create_by(name: permission_name) do |permission|
        permission.display_name = description
        permission.description = description
        permission.resource = resource
        permission.action = action
        permission.system_permission = true
        permission.active = true
      end
    end
  end

  def self.for_resource_action(resource, action)
    find_by(resource: resource.to_s, action: action.to_s)
  end

  def self.create_permission(name, display_name, description = nil)
    resource, action = name.split('.', 2)
    return nil unless resource && action
    
    create!(
      name: name,
      display_name: display_name,
      description: description || display_name,
      resource: resource,
      action: action,
      system_permission: false,
      active: true
    )
  end

  def system_permission?
    system_permission
  end

  def custom_permission?
    !system_permission
  end

  def full_name
    "#{resource}.#{action}"
  end

  def implies?(other_permission)
    return false unless other_permission.is_a?(Permission)
    return true if name == other_permission.name
    
    # Management permissions imply specific actions
    if action == 'manage' && resource == other_permission.resource
      return %w[create read update delete view edit].include?(other_permission.action)
    end
    
    # Some specific implications
    case name
    when "#{resource}.update"
      other_permission.name == "#{resource}.read"
    when "#{resource}.delete"
      other_permission.name == "#{resource}.read"
    when "#{resource}.edit"
      other_permission.name == "#{resource}.view"
    else
      false
    end
  end

  def related_permissions
    Permission.where(resource: resource).where.not(id: id)
  end

  def dependent_permissions
    # Permissions that require this permission
    Permission.where(resource: resource)
              .where(action: dependent_actions)
  end

  def prerequisite_permissions
    # Permissions required for this permission
    case action
    when 'update', 'edit'
      Permission.where(resource: resource, action: ['read', 'view'])
    when 'delete'
      Permission.where(resource: resource, action: ['read', 'view'])
    when 'manage'
      Permission.where(resource: resource).where.not(action: 'manage')
    else
      Permission.none
    end
  end

  def can_be_granted_by?(role)
    return false unless role&.active?
    
    # Super admins can grant any permission
    return true if role.name == 'super_admin'
    
    # Admins can grant most permissions except system management
    if role.name == 'admin'
      return !system_critical_permission?
    end
    
    # Other roles can only grant permissions they have and are lower level
    role.has_permission?(name) && !management_permission?
  end

  def system_critical_permission?
    %w[
      users.delete organizations.delete roles.manage permissions.manage
      audit_logs.manage settings.manage
    ].include?(name)
  end

  def management_permission?
    action == 'manage' || action.in?(%w[delete approve reject])
  end

  def usage_stats
    {
      roles_count: roles.count,
      active_roles_count: roles.active.count,
      users_with_permission: users_with_permission_count,
      organizations_using: organizations_using_permission.count
    }
  end

  def users_with_permission_count
    User.joins(roles: :permissions)
        .where(permissions: { id: id })
        .distinct
        .count
  end

  def organizations_using_permission
    Organization.joins(users: { roles: :permissions })
               .where(permissions: { id: id })
               .distinct
  end

  def log_permission_granted(role, granted_by)
    AuditLog.log_user_management(
      granted_by,
      'permission_granted',
      {
        permission_id: id,
        permission_name: name,
        role_id: role.id,
        role_name: role.name,
        resource: resource,
        action: action
      }
    )
  end

  def log_permission_revoked(role, revoked_by)
    AuditLog.log_user_management(
      revoked_by,
      'permission_revoked',
      {
        permission_id: id,
        permission_name: name,
        role_id: role.id,
        role_name: role.name,
        resource: resource,
        action: action
      }
    )
  end

  private

  def dependent_actions
    case action
    when 'read', 'view'
      %w[update edit delete manage]
    when 'create'
      %w[manage]
    else
      []
    end
  end
end