class CreateSecurityAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :security_alerts do |t|
      t.string :alert_type, null: false
      t.text :message, null: false
      t.string :severity, null: false
      t.jsonb :data, default: {}
      t.references :organization, null: false, foreign_key: true
      t.datetime :triggered_at, null: false
      t.string :status, null: false, default: 'active'
      t.datetime :resolved_at
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
      t.text :resolution_notes

      t.timestamps
    end

    add_index :security_alerts, :alert_type
    add_index :security_alerts, :severity
    add_index :security_alerts, :status
    add_index :security_alerts, :triggered_at
    add_index :security_alerts, [:organization_id, :status]
    add_index :security_alerts, [:organization_id, :severity]
    add_index :security_alerts, [:organization_id, :triggered_at]
  end
end
