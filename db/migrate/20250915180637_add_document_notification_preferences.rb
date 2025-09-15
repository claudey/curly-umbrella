class AddDocumentNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :notification_preferences, :email_document_uploaded, :boolean, default: true
    add_column :notification_preferences, :email_document_updated, :boolean, default: false
    add_column :notification_preferences, :email_document_archived, :boolean, default: false
    add_column :notification_preferences, :email_document_restored, :boolean, default: false
    add_column :notification_preferences, :email_document_expiring, :boolean, default: true
    add_column :notification_preferences, :email_document_expired, :boolean, default: true
    add_column :notification_preferences, :email_document_shared, :boolean, default: true
    add_column :notification_preferences, :email_document_version_created, :boolean, default: false
    add_column :notification_preferences, :email_weekly_digest, :boolean, default: true
    
    # SMS notification preferences for critical document events
    add_column :notification_preferences, :sms_document_expiring, :boolean, default: false
    add_column :notification_preferences, :sms_document_expired, :boolean, default: false
  end
end
