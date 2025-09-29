class CreateBusinessMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :business_metrics do |t|
      t.string :metric_name, null: false
      t.decimal :metric_value, precision: 15, scale: 4, null: false
      t.string :metric_unit, null: false
      t.string :metric_category, null: false
      t.datetime :recorded_at, null: false
      t.integer :period_hours, null: false
      t.text :metadata
      t.references :organization, null: true, foreign_key: true

      t.timestamps
      
      t.index :metric_name
      t.index :metric_category
      t.index :recorded_at
      t.index :period_hours
      t.index [:organization_id, :metric_name, :recorded_at]
    end
  end
end
