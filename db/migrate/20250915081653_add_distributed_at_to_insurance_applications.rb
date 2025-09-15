class AddDistributedAtToInsuranceApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :insurance_applications, :distributed_at, :datetime
    add_column :insurance_applications, :distribution_count, :integer, default: 0
    
    add_index :insurance_applications, :distributed_at
    add_index :insurance_applications, :distribution_count
  end
end
