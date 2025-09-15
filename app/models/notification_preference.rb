class NotificationPreference < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization

  belongs_to :user
  belongs_to :organization

  validates :user_id, uniqueness: { scope: :organization_id }

  # Email notification helpers
  def should_email_for?(notification_type)
    case notification_type
    when :new_application
      email_new_applications?
    when :status_update
      email_status_updates?
    when :user_invitation
      email_user_invitations?
    when :marketing
      email_marketing?
    when :document_uploaded
      email_document_uploaded?
    when :document_updated
      email_document_updated?
    when :document_archived
      email_document_archived?
    when :document_restored
      email_document_restored?
    when :document_expiring
      email_document_expiring?
    when :document_expired
      email_document_expired?
    when :document_shared
      email_document_shared?
    when :document_version_created
      email_document_version_created?
    else
      false
    end
  end

  # SMS notification helpers
  def should_sms_for?(notification_type)
    case notification_type
    when :new_application
      sms_new_applications?
    when :status_update
      sms_status_updates?
    else
      false
    end
  end

  # Check if user should receive email notifications
  def email_enabled?
    email_new_applications? || email_status_updates? || email_user_invitations? ||
    email_document_uploaded? || email_document_updated? || email_document_archived? ||
    email_document_restored? || email_document_expiring? || email_document_expired? ||
    email_document_shared? || email_document_version_created?
  end

  # Check if user wants weekly digest
  def weekly_digest_enabled?
    email_weekly_digest?
  rescue
    true # Default to true if column doesn't exist yet
  end

  # Create default preferences for new user
  def self.create_defaults_for_user(user, organization)
    create!(
      user: user,
      organization: organization,
      email_new_applications: true,
      email_status_updates: true,
      email_user_invitations: true,
      email_marketing: false,
      sms_new_applications: false,
      sms_status_updates: false,
      # Document notification defaults
      email_document_uploaded: true,
      email_document_updated: false,
      email_document_archived: false,
      email_document_restored: false,
      email_document_expiring: true,
      email_document_expired: true,
      email_document_shared: true,
      email_document_version_created: false,
      email_weekly_digest: true
    )
  rescue ActiveRecord::StatementInvalid => e
    # Handle case where new columns don't exist yet
    create!(
      user: user,
      organization: organization,
      email_new_applications: true,
      email_status_updates: true,
      email_user_invitations: true,
      email_marketing: false,
      sms_new_applications: false,
      sms_status_updates: false
    )
  end
end
