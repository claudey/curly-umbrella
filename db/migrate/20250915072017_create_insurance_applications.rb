class CreateInsuranceApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :insurance_applications do |t|
      t.string :application_number, null: false
      t.string :insurance_type, null: false
      t.string :status, default: 'draft', null: false
      t.references :client, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.datetime :rejected_at
      t.references :rejected_by, null: true, foreign_key: { to_table: :users }
      t.text :rejection_reason
      t.json :application_data, default: {}
      t.decimal :sum_insured, precision: 12, scale: 2
      t.decimal :premium_amount, precision: 12, scale: 2
      t.decimal :commission_rate, precision: 5, scale: 2
      t.text :notes
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :insurance_applications, [ :application_number, :organization_id ], unique: true
    add_index :insurance_applications, [ :organization_id, :status ]
    add_index :insurance_applications, [ :insurance_type, :status ]
    add_index :insurance_applications, [ :client_id ], name: 'idx_insurance_applications_client_id'
    add_index :insurance_applications, [ :user_id ], name: 'idx_insurance_applications_user_id'
    add_index :insurance_applications, :discarded_at
    add_index :insurance_applications, :submitted_at
  end
end
