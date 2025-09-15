class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.text :message, null: false
      t.string :notification_type, null: false
      t.datetime :read_at
      t.json :data

      t.timestamps
    end

    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, [:organization_id, :notification_type]
    add_index :notifications, :created_at
  end
end
