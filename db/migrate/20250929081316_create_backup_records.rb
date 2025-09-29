class CreateBackupRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :backup_records do |t|
      t.string :backup_type
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at
      t.string :file_path
      t.bigint :file_size
      t.boolean :integrity_verified
      t.text :metadata
      t.text :error_details
      t.text :verification_details
      t.decimal :duration_seconds

      t.timestamps
    end
  end
end
