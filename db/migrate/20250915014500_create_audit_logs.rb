class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: true, foreign_key: true
      t.references :auditable, polymorphic: true, null: true
      t.references :organization, null: true, foreign_key: true
      t.string :action, null: false
      t.string :category, null: false, default: 'system_access'
      t.string :severity, null: false, default: 'info'
      t.string :resource_type, null: false
      t.bigint :resource_id
      t.inet :ip_address
      t.text :user_agent
      t.json :details, default: {}

      t.timestamps
    end
    
    add_index :audit_logs, [:user_id, :created_at]
    add_index :audit_logs, [:organization_id, :created_at]
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, [:category, :severity]
    add_index :audit_logs, [:action, :created_at]
    add_index :audit_logs, :ip_address
    add_index :audit_logs, :created_at
  end
end
