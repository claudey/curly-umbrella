class CreateLifeApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :life_applications do |t|
      t.references :client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.decimal :coverage_amount
      t.string :beneficiary_name
      t.string :beneficiary_relationship
      t.text :medical_history
      t.text :lifestyle_factors
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
