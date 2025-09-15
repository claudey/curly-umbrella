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
      sms_status_updates: false
    )
  end
end
