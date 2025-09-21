module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, as: :auditable, dependent: :destroy

    after_create :log_creation
    after_update :log_update
    after_destroy :log_destruction
  end

  class_methods do
    def auditable_fields(*fields)
      @auditable_fields = fields
    end

    def get_auditable_fields
      @auditable_fields || []
    end

    def skip_audit_for(*actions)
      @skip_audit_actions = actions
    end

    def should_skip_audit?(action)
      return false unless @skip_audit_actions
      @skip_audit_actions.include?(action.to_sym)
    end
  end

  private

  def log_creation
    return if self.class.should_skip_audit?(:create)

    AuditLog.log_data_modification(
      current_audit_user,
      self,
      "create",
      auditable_changes,
      audit_context
    )
  end

  def log_update
    return if self.class.should_skip_audit?(:update)
    return unless saved_changes.any?

    # Filter out timestamps and non-auditable changes
    filtered_changes = filter_auditable_changes(saved_changes)
    return if filtered_changes.empty?

    AuditLog.log_data_modification(
      current_audit_user,
      self,
      "update",
      filtered_changes,
      audit_context
    )
  end

  def log_destruction
    return if self.class.should_skip_audit?(:destroy)

    AuditLog.log_data_modification(
      current_audit_user,
      self,
      "destroy",
      {},
      audit_context.merge(destroyed_attributes: auditable_attributes)
    )
  end

  def current_audit_user
    # Try to get user from various sources
    return Current.user if defined?(Current) && Current.respond_to?(:user) && Current.user
    return Thread.current[:current_user] if Thread.current[:current_user]
    return RequestStore[:current_user] if defined?(RequestStore) && RequestStore[:current_user]

    # Fallback for system operations
    nil
  end

  def audit_context
    context = {}

    # Add IP address if available
    if defined?(Current) && Current.respond_to?(:ip_address)
      context[:ip_address] = Current.ip_address
    elsif Thread.current[:request_ip]
      context[:ip_address] = Thread.current[:request_ip]
    end

    # Add user agent if available
    if defined?(Current) && Current.respond_to?(:user_agent)
      context[:user_agent] = Current.user_agent
    elsif Thread.current[:user_agent]
      context[:user_agent] = Thread.current[:user_agent]
    end

    # Add additional context
    context[:model] = self.class.name
    context[:record_id] = id

    context
  end

  def filter_auditable_changes(changes)
    filtered = {}

    changes.each do |field, (old_val, new_val)|
      # Skip timestamp fields unless explicitly auditable
      next if skip_field_for_audit?(field)

      # Include field if in auditable_fields list or if no list specified
      auditable_fields = self.class.get_auditable_fields
      if auditable_fields.empty? || auditable_fields.include?(field.to_sym)
        filtered[field] = [ old_val, new_val ]
      end
    end

    filtered
  end

  def skip_field_for_audit?(field)
    skip_fields = %w[
      created_at updated_at
      lock_version
      encrypted_password password_digest
    ]

    skip_fields.include?(field.to_s)
  end

  def auditable_changes
    return {} unless respond_to?(:saved_changes)
    filter_auditable_changes(saved_changes)
  end

  def auditable_attributes
    attrs = attributes.dup

    # Remove sensitive fields
    sensitive_fields = %w[
      encrypted_password password_digest
      reset_password_token confirmation_token
    ]

    sensitive_fields.each { |field| attrs.delete(field) }
    attrs
  end

  # Public methods for manual audit logging
  def log_custom_action(action, user = nil, details = {})
    AuditLog.log_data_modification(
      user || current_audit_user,
      self,
      action,
      {},
      audit_context.merge(details)
    )
  end

  def log_access(user = nil, details = {})
    AuditLog.log_data_access(
      user || current_audit_user,
      self,
      "read",
      audit_context.merge(details)
    )
  end

  def log_approval(approver, details = {})
    log_custom_action("approve", approver, details.merge(approved_at: Time.current))
  end

  def log_rejection(rejector, reason = nil, details = {})
    rejection_details = details.merge(rejected_at: Time.current)
    rejection_details[:reason] = reason if reason
    log_custom_action("reject", rejector, rejection_details)
  end

  def log_submission(submitter = nil, details = {})
    log_custom_action("submit", submitter, details.merge(submitted_at: Time.current))
  end

  def log_status_change(new_status, user = nil, details = {})
    log_custom_action(
      "status_change",
      user,
      details.merge(
        old_status: status_was,
        new_status: new_status,
        changed_at: Time.current
      )
    )
  end
end
