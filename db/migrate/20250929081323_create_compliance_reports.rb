class CreateComplianceReports < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_reports do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :report_type
      t.integer :status
      t.string :title
      t.text :description
      t.text :configuration
      t.text :data
      t.text :metadata
      t.datetime :generated_at
      t.datetime :expires_at

      t.timestamps
    end
  end
end
