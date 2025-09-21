class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :role
  belongs_to :granted_by, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :role_id }
  validates :granted_at, presence: true

  before_validation :set_granted_at, on: :create
  after_create :log_role_assignment
  after_destroy :log_role_removal
  after_update :log_role_update, if: :saved_change_to_active?

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :for_organization, ->(org) { joins(:role).where(roles: { organization: org }) }
  scope :system_roles, -> { joins(:role).where(roles: { organization_id: nil }) }

  def active?
    active && !expired?
  end

  def expired?
    expires_at&.past? || false
  end

  def expires_in_days
    return nil unless expires_at
    ((expires_at - Time.current) / 1.day).to_i
  end

  def time_remaining
    return nil unless expires_at
    expires_at - Time.current
  end

  def can_be_revoked_by?(current_user)
    return false unless current_user

    # Users can revoke their own roles (resign)
    return true if user_id == current_user.id

    # Check if current user has permission to manage this role
    current_user.roles.any? { |r| r.can_assign_role?(role) }
  end

  def revoke!(revoked_by = nil, reason = nil)
    update!(
      active: false,
      notes: [ notes, "Revoked: #{reason}" ].compact.join("; ")
    )

    role.log_role_removal(user, revoked_by || Current.user)
  end

  def extend_expiry!(new_expiry, extended_by = nil)
    update!(
      expires_at: new_expiry,
      notes: [ notes, "Extended to #{new_expiry.strftime('%Y-%m-%d')}" ].compact.join("; ")
    )

    AuditLog.log_user_management(
      extended_by || Current.user,
      "role_extended",
      {
        target_user_id: user.id,
        target_user_email: user.email,
        role_id: role.id,
        role_name: role.name,
        new_expiry: new_expiry.iso8601,
        extended_by: (extended_by || Current.user)&.email
      }
    )
  end

  def reactivate!(reactivated_by = nil)
    return false unless can_be_reactivated?

    update!(
      active: true,
      notes: [ notes, "Reactivated" ].compact.join("; ")
    )

    AuditLog.log_user_management(
      reactivated_by || Current.user,
      "role_reactivated",
      {
        target_user_id: user.id,
        target_user_email: user.email,
        role_id: role.id,
        role_name: role.name,
        reactivated_by: (reactivated_by || Current.user)&.email
      }
    )
  end

  def can_be_reactivated?
    !active? && !expired? && role.active?
  end

  def assignment_summary
    {
      user: user.email,
      role: role.display_name,
      organization: role.organization&.name || "System",
      granted_at: granted_at,
      granted_by: granted_by&.email || "System",
      expires_at: expires_at,
      expires_in_days: expires_in_days,
      active: active?,
      can_revoke: can_be_revoked_by?(Current.user)
    }
  end

  def permissions_summary
    {
      direct_permissions: role.permissions.count,
      inherited_permissions: role.inherited_permissions.count,
      total_permissions: role.all_permissions.count,
      permission_names: role.permission_names
    }
  end

  # Check if this role assignment conflicts with existing roles
  def conflicts_with_existing_roles?
    user.user_roles.active.includes(:role).any? do |ur|
      next if ur.id == id # Don't check against self

      # Check for level conflicts (can't have higher level role than current max)
      ur.role.level > role.level && ur.role.organization_id == role.organization_id
    end
  end

  # Get roles this assignment might conflict with
  def conflicting_roles
    return UserRole.none unless user

    user.user_roles.active.includes(:role).select do |ur|
      next if ur.id == id

      # Same organization and higher level
      ur.role.organization_id == role.organization_id && ur.role.level > role.level
    end
  end

  # Validate role assignment rules
  def validate_assignment_rules
    errors = []

    # Check if user already has this role
    if user.user_roles.active.joins(:role).exists?(roles: { id: role.id })
      errors << "User already has this role"
    end

    # Check role level conflicts
    if conflicts_with_existing_roles?
      conflicting = conflicting_roles.map { |ur| ur.role.display_name }.join(", ")
      errors << "Conflicts with existing higher-level roles: #{conflicting}"
    end

    # Check organization compatibility
    if role.organization_role? && user.organization_id != role.organization_id
      errors << "Role organization doesn't match user organization"
    end

    # Check if granter can assign this role
    if granted_by && !granted_by.roles.any? { |r| r.can_assign_role?(role) }
      errors << "Granting user doesn't have permission to assign this role"
    end

    errors
  end

  private

  def set_granted_at
    self.granted_at ||= Time.current
  end

  def log_role_assignment
    role.log_role_assignment(user, granted_by || Current.user)
  end

  def log_role_removal
    role.log_role_removal(user, Current.user)
  end

  def log_role_update
    if saved_change_to_active?
      action = active? ? "role_activated" : "role_deactivated"

      AuditLog.log_user_management(
        Current.user,
        action,
        {
          target_user_id: user.id,
          target_user_email: user.email,
          role_id: role.id,
          role_name: role.name,
          changed_by: Current.user&.email
        }
      )
    end
  end
end
