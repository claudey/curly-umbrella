class CreateSmsLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :sms_logs do |t|
      t.string :to, null: false
      t.string :from
      t.text :body, null: false
      t.string :status, null: false, default: 'pending'
      t.string :external_id
      t.text :error_message
      t.datetime :sent_at
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :sms_logs, :status
    add_index :sms_logs, :sent_at
    add_index :sms_logs, [ :organization_id, :sent_at ]
  end
end
