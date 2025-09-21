class UpdateApplicationDistributionsForInsuranceApplications < ActiveRecord::Migration[8.0]
  def change
    # Add new column for insurance_application_id
    add_reference :application_distributions, :insurance_application, foreign_key: true, null: true

    # Update indexes
    add_index :application_distributions, [ :insurance_application_id, :insurance_company_id ],
              unique: true, name: "idx_unique_ins_app_company_distribution"
    add_index :application_distributions, [ :insurance_application_id, :status ]
  end
end
