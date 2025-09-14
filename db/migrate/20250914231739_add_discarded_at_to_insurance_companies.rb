class AddDiscardedAtToInsuranceCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :insurance_companies, :discarded_at, :datetime
    add_index :insurance_companies, :discarded_at
  end
end
