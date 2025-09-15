# frozen_string_literal: true

Audited.config do |config|
  # Store the current user in audits
  config.current_user_method = :current_user
  
  # Track changes to these attributes by default
  config.max_audits = 100 # Limit audits per record to prevent bloat
  
  # Use organization_id for multi-tenant auditing
  config.audit_class = Audited::Audit
end

# Extend Audited::Audit for multi-tenancy support
Audited::Audit.class_eval do
  belongs_to :organization, optional: true
  
  # Scope audits to current organization
  scope :for_organization, ->(org) { where(organization_id: org&.id) }
  
  # Set organization from current tenant
  before_create :set_organization
  
  private
  
  def set_organization
    self.organization = ActsAsTenant.current_tenant if ActsAsTenant.current_tenant
  end
end