class CreateCompanyPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :company_preferences do |t|
      t.references :insurance_company, null: false, foreign_key: true, index: { unique: true }
      t.json :coverage_types, default: {}
      t.json :vehicle_categories, default: {}
      t.json :risk_appetite, default: {}
      t.json :sum_insured_ranges, default: {}
      t.json :driver_age_preferences, default: {}
      t.json :geographical_preferences, default: {}
      t.json :distribution_settings, default: {}

      t.timestamps
    end
  end
end
