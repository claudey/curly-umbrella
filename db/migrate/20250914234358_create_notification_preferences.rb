class CreateNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.boolean :email_new_applications, default: true, null: false
      t.boolean :email_status_updates, default: true, null: false
      t.boolean :email_user_invitations, default: true, null: false
      t.boolean :email_marketing, default: false, null: false
      t.boolean :sms_new_applications, default: false, null: false
      t.boolean :sms_status_updates, default: false, null: false

      t.timestamps
    end

    add_index :notification_preferences, [ :user_id, :organization_id ], unique: true
  end
end
