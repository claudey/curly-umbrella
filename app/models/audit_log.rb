class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true
  belongs_to :organization, optional: true

  validates :action, presence: true
  validates :resource_type, presence: true
  
  # Callbacks for notifications
  after_create :trigger_audit_notifications, if: :should_trigger_notifications?

  enum :severity, {
    info: 'info',
    warning: 'warning',
    error: 'error',
    critical: 'critical'
  }

  enum :category, {
    authentication: 'authentication',
    authorization: 'authorization',
    data_access: 'data_access',
    data_modification: 'data_modification',
    system_access: 'system_access',
    compliance: 'compliance',
    security: 'security',
    financial: 'financial',
    user_management: 'user_management'
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :for_resource, ->(resource) { where(auditable: resource) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :in_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :suspicious, -> { where(severity: ['warning', 'error', 'critical']) }

  # Class methods for logging different types of activities
  def self.log_authentication(user, action, details = {})
    create!(
      user: user,
      organization: user&.organization,
      action: action,
      category: 'authentication',
      resource_type: 'User',
      details: base_details.merge(details),
      severity: determine_auth_severity(action),
      ip_address: details[:ip_address],
      user_agent: details[:user_agent]
    )
  end

  def self.log_data_access(user, resource, action = 'read', details = {})
    create!(
      user: user,
      organization: user&.organization,
      auditable: resource,
      action: action,
      category: 'data_access',
      resource_type: resource.class.name,
      resource_id: resource.id,
      details: base_details.merge(details),
      severity: 'info',
      ip_address: details[:ip_address]
    )
  end

  def self.log_data_modification(user, resource, action, changes = {}, details = {})
    create!(
      user: user,
      organization: user&.organization,
      auditable: resource,
      action: action,
      category: 'data_modification',
      resource_type: resource.class.name,
      resource_id: resource.id,
      details: base_details.merge(
        changes: sanitize_changes(changes),
        **details
      ),
      severity: determine_modification_severity(action, resource),
      ip_address: details[:ip_address]
    )
  end

  def self.log_authorization_failure(user, resource, action, details = {})
    create!(
      user: user,
      organization: user&.organization,
      auditable: resource,
      action: "unauthorized_#{action}",
      category: 'authorization',
      resource_type: resource&.class&.name || 'Unknown',
      resource_id: resource&.id,
      details: base_details.merge(details),
      severity: 'warning',
      ip_address: details[:ip_address]
    )
  end

  def self.log_compliance_event(user, event_type, details = {})
    create!(
      user: user,
      organization: user&.organization,
      action: event_type,
      category: 'compliance',
      resource_type: 'Compliance',
      details: base_details.merge(details),
      severity: details[:severity] || 'info',
      ip_address: details[:ip_address]
    )
  end

  def self.log_security_event(user, event_type, details = {})
    create!(
      user: user,
      organization: user&.organization,
      action: event_type,
      category: 'security',
      resource_type: 'Security',
      details: base_details.merge(details),
      severity: details[:severity] || 'warning',
      ip_address: details[:ip_address]
    )
  end

  def self.log_financial_transaction(user, resource, action, amount = nil, details = {})
    create!(
      user: user,
      organization: user&.organization,
      auditable: resource,
      action: action,
      category: 'financial',
      resource_type: resource.class.name,
      resource_id: resource.id,
      details: base_details.merge(
        amount: amount,
        **details
      ),
      severity: determine_financial_severity(amount),
      ip_address: details[:ip_address]
    )
  end

  # Instance methods
  def display_action
    action.humanize
  end

  def display_severity
    case severity
    when 'info' then 'Information'
    when 'warning' then 'Warning'
    when 'error' then 'Error'
    when 'critical' then 'Critical'
    else severity.humanize
    end
  end

  def display_category
    category.humanize
  end

  def formatted_details
    return {} if details.blank?
    
    formatted = {}
    details.each do |key, value|
      case key.to_s
      when 'changes'
        formatted['Changes'] = format_changes(value)
      when 'amount'
        formatted['Amount'] = "$#{number_with_delimiter(value)}" if value
      when 'ip_address'
        formatted['IP Address'] = value
      when 'user_agent'
        formatted['Browser'] = parse_user_agent(value)
      else
        formatted[key.humanize] = value
      end
    end
    formatted
  end

  def requires_retention?
    # Compliance and financial logs require longer retention
    ['compliance', 'financial'].include?(category) || 
    ['critical', 'error'].include?(severity)
  end

  def retention_period
    if requires_retention?
      7.years # Compliance requirement
    else
      2.years # Standard retention
    end
  end

  def expired?
    created_at < retention_period.ago
  end

  # Search and filtering methods
  def self.search(query)
    return all if query.blank?
    
    where(
      "action ILIKE ? OR resource_type ILIKE ? OR details::text ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end

  def self.compliance_report(start_date, end_date, organization = nil)
    logs = in_date_range(start_date, end_date)
    logs = logs.for_organization(organization) if organization
    
    {
      total_activities: logs.count,
      by_category: logs.group(:category).count,
      by_severity: logs.group(:severity).count,
      by_user: logs.joins(:user).group('users.email').count,
      suspicious_activities: logs.suspicious.count,
      data_access_count: logs.by_category('data_access').count,
      authentication_events: logs.by_category('authentication').count,
      failed_authorizations: logs.where("action LIKE 'unauthorized_%'").count
    }
  end

  def self.export_for_compliance(start_date, end_date, format: 'csv')
    logs = in_date_range(start_date, end_date).includes(:user, :organization)
    
    case format.to_s
    when 'csv'
      CSV.generate(headers: true) do |csv|
        csv << csv_headers
        logs.each { |log| csv << log.to_csv_row }
      end
    when 'json'
      logs.map(&:to_compliance_hash).to_json
    else
      raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  def to_csv_row
    [
      created_at.iso8601,
      user&.email || 'System',
      organization&.name || 'N/A',
      action,
      category,
      severity,
      resource_type,
      resource_id,
      ip_address,
      details.to_json
    ]
  end

  def to_compliance_hash
    {
      timestamp: created_at.iso8601,
      user_email: user&.email,
      organization: organization&.name,
      action: action,
      category: category,
      severity: severity,
      resource_type: resource_type,
      resource_id: resource_id,
      ip_address: ip_address,
      details: details
    }
  end

  private

  def self.base_details
    {
      timestamp: Time.current.iso8601,
      application: 'BrokerSync',
      version: (Rails.application.config.version rescue '1.0.0')
    }
  end

  def self.sanitize_changes(changes)
    return {} if changes.blank?
    
    sanitized = {}
    changes.each do |field, (old_val, new_val)|
      # Sanitize sensitive fields
      if sensitive_field?(field)
        sanitized[field] = ['[REDACTED]', '[REDACTED]']
      else
        sanitized[field] = [old_val, new_val]
      end
    end
    sanitized
  end

  def self.sensitive_field?(field)
    sensitive_fields = %w[
      password password_digest encrypted_password
      ssn social_security_number tax_id
      credit_card_number bank_account_number
      api_key secret_key private_key
    ]
    
    sensitive_fields.any? { |sf| field.to_s.downcase.include?(sf) }
  end

  def self.determine_auth_severity(action)
    case action.to_s
    when 'login_success' then 'info'
    when 'login_failure', 'password_reset_request' then 'warning'
    when 'account_locked', 'multiple_login_failures' then 'error'
    when 'suspicious_login_attempt' then 'critical'
    else 'info'
    end
  end

  def self.determine_modification_severity(action, resource)
    case action.to_s
    when 'create', 'update' then 'info'
    when 'delete', 'destroy' then 'warning'
    when 'approve', 'reject' then 'info'
    else 'info'
    end
  end

  def self.determine_financial_severity(amount)
    return 'info' unless amount
    
    case amount.to_f
    when 0...1000 then 'info'
    when 1000...10000 then 'warning'
    when 10000...Float::INFINITY then 'error'
    else 'info'
    end
  end

  def self.csv_headers
    [
      'Timestamp',
      'User Email',
      'Organization',
      'Action',
      'Category',
      'Severity',
      'Resource Type',
      'Resource ID',
      'IP Address',
      'Details'
    ]
  end

  def format_changes(changes)
    return '' if changes.blank?
    
    changes.map do |field, (old_val, new_val)|
      "#{field}: #{old_val} → #{new_val}"
    end.join(', ')
  end

  def parse_user_agent(user_agent)
    return user_agent if user_agent.blank?
    
    # Simple user agent parsing - could be enhanced with a gem like browser
    case user_agent
    when /Chrome/
      'Chrome'
    when /Firefox/
      'Firefox'
    when /Safari/
      'Safari'
    when /Edge/
      'Edge'
    else
      'Unknown Browser'
    end
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
  
  # Notification trigger methods
  def should_trigger_notifications?
    # Don't trigger notifications for system-generated audit logs about notifications
    return false if action.include?('notification_') || action.include?('digest_')
    
    # Don't trigger for very old logs (in case of bulk imports)
    return false if created_at < 1.hour.ago
    
    # Don't trigger for info-level authentication events (too noisy)
    return false if category == 'authentication' && severity == 'info' && action == 'login_success'
    
    # Trigger for anything warning level or above
    severity.in?(['warning', 'error', 'critical']) ||
    # Or for specific important actions regardless of severity
    important_action? ||
    # Or for financial/compliance events
    category.in?(['financial', 'compliance', 'security'])
  end
  
  def important_action?
    important_actions = %w[
      create update delete destroy
      approve reject submit
      role_change permission_change
      export bulk_operation mass_operation
      login_failure unauthorized_access
    ]
    
    important_actions.any? { |action_pattern| action.include?(action_pattern) }
  end
  
  def trigger_audit_notifications
    # Use background job to avoid blocking the main request
    AuditNotificationJob.perform_later(self.id)
  rescue => e
    Rails.logger.error "Failed to trigger audit notification for audit log #{id}: #{e.message}"
  end
end