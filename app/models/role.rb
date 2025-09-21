class Role < ApplicationRecord
  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  belongs_to :organization, optional: true

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :display_name, presence: true
  validates :level, presence: true, numericality: { greater_than: 0 }

  scope :system_roles, -> { where(organization_id: nil) }
  scope :organization_roles, ->(org) { where(organization: org) }
  scope :active, -> { where(active: true) }
  scope :by_level, -> { order(:level) }

  # System-defined roles
  SYSTEM_ROLES = {
    super_admin: {
      name: "super_admin",
      display_name: "Super Administrator",
      description: "Full system access across all organizations",
      level: 100,
      system_role: true
    },
    admin: {
      name: "admin",
      display_name: "Administrator",
      description: "Full administrative access within organization",
      level: 90,
      system_role: true
    },
    manager: {
      name: "manager",
      display_name: "Manager",
      description: "Management access with team oversight",
      level: 70,
      system_role: true
    },
    broker: {
      name: "broker",
      display_name: "Insurance Broker",
      description: "Full broker functionality",
      level: 50,
      system_role: true
    },
    agent: {
      name: "agent",
      display_name: "Insurance Agent",
      description: "Agent with limited broker functionality",
      level: 40,
      system_role: true
    },
    underwriter: {
      name: "underwriter",
      display_name: "Underwriter",
      description: "Risk assessment and policy approval",
      level: 60,
      system_role: true
    },
    claims_adjuster: {
      name: "claims_adjuster",
      display_name: "Claims Adjuster",
      description: "Claims processing and adjustment",
      level: 45,
      system_role: true
    },
    viewer: {
      name: "viewer",
      display_name: "Viewer",
      description: "Read-only access to assigned data",
      level: 10,
      system_role: true
    }
  }.freeze

  def self.create_system_roles!
    SYSTEM_ROLES.each do |role_key, role_data|
      find_or_create_by(name: role_data[:name], organization_id: nil) do |role|
        role.display_name = role_data[:display_name]
        role.description = role_data[:description]
        role.level = role_data[:level]
        role.system_role = role_data[:system_role]
        role.active = true
      end
    end
  end

  def system_role?
    organization_id.nil? && system_role
  end

  def organization_role?
    organization_id.present?
  end

  def can_assign_role?(other_role)
    return false unless active?
    return false if other_role.level >= level

    # System roles can only be assigned by super admins
    if other_role.system_role? && name != "super_admin"
      return false
    end

    # Organization roles can only be assigned within same organization
    if other_role.organization_role? && organization_id != other_role.organization_id
      return false
    end

    true
  end

  def inherits_from?(parent_role)
    return false unless parent_role

    # Check if this role should inherit permissions from parent_role
    case name
    when "admin"
      parent_role.name.in?([ "super_admin" ])
    when "manager"
      parent_role.name.in?([ "super_admin", "admin" ])
    when "broker"
      parent_role.name.in?([ "super_admin", "admin", "manager" ])
    when "agent"
      parent_role.name.in?([ "super_admin", "admin", "manager", "broker" ])
    when "underwriter"
      parent_role.name.in?([ "super_admin", "admin", "manager" ])
    when "claims_adjuster"
      parent_role.name.in?([ "super_admin", "admin", "manager" ])
    when "viewer"
      false # Viewers don't inherit from any role
    else
      false
    end
  end

  def inherited_permissions
    return Permission.none unless system_role?

    parent_roles = Role.system_roles.where(name: parent_role_names)
    Permission.joins(:role_permissions)
              .where(role_permissions: { role: parent_roles })
              .distinct
  end

  def all_permissions
    # Direct permissions + inherited permissions
    direct_permissions = permissions.active
    inherited_perms = inherited_permissions

    Permission.where(id: (direct_permissions.pluck(:id) + inherited_perms.pluck(:id)).uniq)
  end

  def has_permission?(permission_name)
    all_permissions.exists?(name: permission_name.to_s)
  end

  def add_permission(permission_name)
    permission = Permission.find_by(name: permission_name.to_s)
    return false unless permission

    role_permissions.find_or_create_by(permission: permission) do |rp|
      rp.granted_at = Time.current
      rp.granted_by = Current.user
    end
  end

  def remove_permission(permission_name)
    permission = Permission.find_by(name: permission_name.to_s)
    return false unless permission

    role_permissions.where(permission: permission).destroy_all
  end

  def permission_names
    all_permissions.pluck(:name)
  end

  def can_access_organization?(org)
    return true if name == "super_admin"
    return organization_id == org.id if organization_role?

    # System roles can access any organization they're assigned to
    users.joins(:organization).exists?(organization: org)
  end

  def default_permissions_for_role
    case name
    when "super_admin"
      Permission.all.pluck(:name)
    when "admin"
      %w[
        users.manage organizations.manage roles.manage
        applications.manage quotes.manage policies.manage
        reports.view exports.create audit_logs.view
        settings.manage integrations.manage
      ]
    when "manager"
      %w[
        users.view users.edit team.manage
        applications.manage quotes.manage
        reports.view exports.create
        dashboard.view notifications.manage
      ]
    when "broker"
      %w[
        applications.create applications.edit applications.view
        quotes.create quotes.edit quotes.view quotes.compare
        clients.create clients.edit clients.view
        policies.view reports.view
        dashboard.view notifications.view
      ]
    when "agent"
      %w[
        applications.create applications.view
        quotes.view clients.create clients.view
        dashboard.view notifications.view
      ]
    when "underwriter"
      %w[
        applications.view applications.approve applications.reject
        quotes.view quotes.approve quotes.reject
        risk_assessment.manage policies.create
        reports.view dashboard.view
      ]
    when "claims_adjuster"
      %w[
        claims.manage policies.view
        applications.view quotes.view
        reports.view dashboard.view
      ]
    when "viewer"
      %w[
        applications.view quotes.view
        clients.view policies.view
        dashboard.view reports.view
      ]
    else
      %w[dashboard.view notifications.view]
    end
  end

  def assign_default_permissions!
    transaction do
      default_permissions_for_role.each do |permission_name|
        add_permission(permission_name)
      end
    end
  end

  def clone_for_organization(target_organization, new_name = nil)
    return nil if organization_role? # Can't clone org-specific roles

    new_role_name = new_name || "#{name}_#{target_organization.name.parameterize}"

    target_organization.roles.create!(
      name: new_role_name,
      display_name: "#{display_name} (#{target_organization.name})",
      description: "#{description} - customized for #{target_organization.name}",
      level: level,
      system_role: false,
      active: active
    ).tap do |new_role|
      # Copy permissions
      role_permissions.each do |rp|
        new_role.role_permissions.create!(
          permission: rp.permission,
          granted_at: Time.current,
          granted_by: Current.user
        )
      end
    end
  end

  def usage_stats
    {
      users_count: users.count,
      active_users_count: users.where(active: true).count,
      permissions_count: all_permissions.count,
      direct_permissions_count: permissions.count,
      inherited_permissions_count: inherited_permissions.count,
      organizations_using: organizations_using_role.count
    }
  end

  def organizations_using_role
    if system_role?
      Organization.joins(users: :roles).where(roles: { id: id }).distinct
    else
      organization ? [ organization ] : []
    end
  end

  # Security and audit methods
  def log_role_assignment(user, assigned_by)
    AuditLog.log_user_management(
      assigned_by,
      "role_assigned",
      {
        target_user_id: user.id,
        target_user_email: user.email,
        role_id: id,
        role_name: name,
        organization_id: organization_id
      }
    )
  end

  def log_role_removal(user, removed_by)
    AuditLog.log_user_management(
      removed_by,
      "role_removed",
      {
        target_user_id: user.id,
        target_user_email: user.email,
        role_id: id,
        role_name: name,
        organization_id: organization_id
      }
    )
  end

  def log_permission_change(permission, action, changed_by)
    AuditLog.log_user_management(
      changed_by,
      "permission_#{action}",
      {
        role_id: id,
        role_name: name,
        permission_id: permission.id,
        permission_name: permission.name,
        organization_id: organization_id
      }
    )
  end

  private

  def parent_role_names
    case name
    when "admin" then [ "super_admin" ]
    when "manager" then [ "super_admin", "admin" ]
    when "broker" then [ "super_admin", "admin", "manager" ]
    when "agent" then [ "super_admin", "admin", "manager", "broker" ]
    when "underwriter" then [ "super_admin", "admin", "manager" ]
    when "claims_adjuster" then [ "super_admin", "admin", "manager" ]
    else []
    end
  end
end
