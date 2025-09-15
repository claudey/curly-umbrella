class CreateDistributionAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :distribution_analytics do |t|
      t.references :motor_application, null: false, foreign_key: true
      t.references :insurance_company, null: true, foreign_key: true
      t.string :event_type, null: false
      t.json :event_data, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    
    add_index :distribution_analytics, :event_type
    add_index :distribution_analytics, :occurred_at
    add_index :distribution_analytics, [:motor_application_id, :event_type]
    add_index :distribution_analytics, [:insurance_company_id, :event_type]
    add_index :distribution_analytics, [:occurred_at, :event_type]
  end
end
