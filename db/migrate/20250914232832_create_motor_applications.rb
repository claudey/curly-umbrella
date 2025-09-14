class CreateMotorApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :motor_applications do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :application_number, null: false
      t.string :status, null: false, default: 'draft'
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.datetime :rejected_at
      t.references :rejected_by, null: true, foreign_key: { to_table: :users }
      t.text :rejection_reason
      t.string :vehicle_make, null: false
      t.string :vehicle_model, null: false
      t.integer :vehicle_year, null: false
      t.string :vehicle_color
      t.string :vehicle_chassis_number
      t.string :vehicle_engine_number
      t.string :vehicle_registration_number
      t.decimal :vehicle_value, precision: 15, scale: 2
      t.string :vehicle_category, null: false
      t.string :vehicle_fuel_type
      t.string :vehicle_transmission
      t.integer :vehicle_seating_capacity
      t.string :vehicle_usage, null: false
      t.integer :vehicle_mileage
      t.string :driver_license_number, null: false
      t.date :driver_license_expiry, null: false
      t.string :driver_license_class
      t.integer :driver_years_experience
      t.integer :driver_age
      t.string :driver_occupation
      t.boolean :driver_has_claims, null: false, default: false
      t.text :driver_claims_details
      t.string :coverage_type, null: false
      t.date :coverage_start_date, null: false
      t.date :coverage_end_date, null: false
      t.decimal :sum_insured, precision: 15, scale: 2
      t.decimal :deductible, precision: 15, scale: 2
      t.decimal :premium_amount, precision: 15, scale: 2
      t.decimal :commission_rate, precision: 5, scale: 2
      t.text :notes

      t.timestamps
    end

    add_index :motor_applications, :application_number, unique: true
    add_index :motor_applications, :status
    add_index :motor_applications, :submitted_at
    add_index :motor_applications, :vehicle_registration_number
    add_index :motor_applications, :driver_license_number
  end
end
