class CreateResidentialApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :residential_applications do |t|
      t.references :client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :property_address
      t.decimal :property_value
      t.integer :dwelling_type
      t.integer :construction_year
      t.integer :roof_type
      t.string :heating_system
      t.text :security_features
      t.text :notes
      t.integer :status
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.datetime :approved_at
      t.datetime :rejected_at

      t.timestamps
    end
  end
end
