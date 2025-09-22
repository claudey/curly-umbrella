class CreateFireApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :fire_applications do |t|
      t.references :client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :property_address
      t.decimal :property_value
      t.integer :building_type
      t.integer :construction_year
      t.text :security_features
      t.text :fire_safety_measures
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
