class CreateAnalyticsReports < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_reports do |t|
      # Basic information
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :scheduled_by, null: true, foreign_key: { to_table: :users }

      # Report details
      t.string :name, null: false, limit: 255
      t.text :description
      t.string :report_type, null: false, limit: 50
      t.string :status, null: false, limit: 20, default: 'draft'
      t.string :frequency, limit: 20

      # Configuration and data
      t.json :configuration, default: {}
      t.json :data, default: {}
      t.json :metadata, default: {}

      # Execution tracking
      t.timestamp :started_at
      t.timestamp :completed_at
      t.timestamp :last_generated_at
      t.text :error_message
      t.decimal :generation_time_seconds, precision: 10, scale: 3
      t.bigint :file_size

      # Soft deletes
      t.timestamp :discarded_at

      t.timestamps
    end

    # Basic indexes will be added later
    # add_index :analytics_reports, :organization_id
  end
end
