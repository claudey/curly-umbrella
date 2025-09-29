class CreateBusinessMetricSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :business_metric_snapshots do |t|
      t.references :organization, null: false, foreign_key: true
      t.datetime :snapshot_timestamp
      t.integer :period_hours
      t.text :metrics_data
      t.integer :total_records
      t.decimal :avg_value
      t.decimal :min_value
      t.decimal :max_value

      t.timestamps
    end
  end
end
