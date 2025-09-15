class CreateWhatsappLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :whatsapp_logs do |t|
      t.string :to, null: false
      t.text :message, null: false
      t.string :message_type, null: false, default: 'text'
      t.string :status, null: false, default: 'pending'
      t.string :external_id
      t.text :error_message
      t.datetime :sent_at
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
    
    add_index :whatsapp_logs, :status
    add_index :whatsapp_logs, :external_id
    add_index :whatsapp_logs, :sent_at
    add_index :whatsapp_logs, [:organization_id, :sent_at]
  end
end
