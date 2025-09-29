class CreateErrorReports < ActiveRecord::Migration[8.0]
  def change
    create_table :error_reports do |t|
      t.string :exception_class, null: false
      t.text :message, null: false
      t.string :severity, null: false
      t.string :category, null: false
      t.string :fingerprint, null: false
      t.text :backtrace
      t.text :context
      t.datetime :occurred_at, null: false
      t.string :environment
      t.string :application_version
      t.string :request_id
      t.references :user, null: true, foreign_key: true
      t.references :organization, null: true, foreign_key: true
      t.boolean :resolved, default: false
      t.integer :occurrence_count, default: 1

      t.timestamps
      
      t.index :fingerprint
      t.index :severity
      t.index :category
      t.index :occurred_at
      t.index :resolved
    end
  end
end
