class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.date :date_of_birth
      t.text :address
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: 'Ghana'
      t.string :id_number
      t.string :id_type
      t.string :occupation
      t.string :employer
      t.decimal :annual_income, precision: 15, scale: 2
      t.string :marital_status
      t.string :next_of_kin
      t.string :next_of_kin_phone
      t.string :emergency_contact
      t.string :emergency_contact_phone
      t.string :preferred_contact_method, default: 'email'
      t.text :communication_preferences
      t.text :notes

      t.timestamps
    end

    add_index :clients, :email
    add_index :clients, [:first_name, :last_name]
    add_index :clients, :phone
    add_index :clients, :id_number
  end
end
