class CreateInsuranceCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :insurance_companies do |t|
      t.string :name, null: false
      t.string :business_registration_number, null: false
      t.string :license_number, null: false
      t.string :contact_person, null: false
      t.string :email, null: false
      t.string :phone
      t.text :address
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: 'Ghana'
      t.string :website
      t.text :insurance_types
      t.decimal :rating, precision: 3, scale: 2, default: 0.0
      t.decimal :commission_rate, precision: 5, scale: 2, default: 0.0
      t.text :terms_and_conditions
      t.string :payment_terms, default: 'net_30'
      t.boolean :active, null: false, default: true
      t.boolean :approved, null: false, default: false
      t.datetime :approved_at
      t.references :approved_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :insurance_companies, :name
    add_index :insurance_companies, :email, unique: true
    add_index :insurance_companies, :business_registration_number, unique: true
    add_index :insurance_companies, :license_number, unique: true
    add_index :insurance_companies, :active
    add_index :insurance_companies, :approved
  end
end
