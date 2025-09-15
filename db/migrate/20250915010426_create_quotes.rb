class CreateQuotes < ActiveRecord::Migration[8.0]
  def change
    create_table :quotes do |t|
      t.references :motor_application, null: false, foreign_key: true
      t.references :insurance_company, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :quoted_by, null: false, foreign_key: { to_table: :users }
      t.string :quote_number, null: false
      t.decimal :premium_amount, precision: 12, scale: 2
      t.decimal :coverage_amount, precision: 15, scale: 2
      t.decimal :commission_rate, precision: 5, scale: 2
      t.decimal :commission_amount, precision: 12, scale: 2
      t.json :coverage_details
      t.text :terms_conditions
      t.integer :validity_period, default: 30
      t.string :status, null: false, default: 'draft'
      t.datetime :quoted_at
      t.datetime :accepted_at
      t.datetime :rejected_at
      t.datetime :expires_at
      t.text :notes

      t.timestamps
    end

    add_index :quotes, :quote_number, unique: true
    add_index :quotes, [:motor_application_id, :insurance_company_id]
    add_index :quotes, [:organization_id, :status]
    add_index :quotes, :expires_at
  end
end
