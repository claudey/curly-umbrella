class UpdateQuotesForInsuranceApplications < ActiveRecord::Migration[8.0]
  def change
    # Add new column for insurance_application_id
    add_reference :quotes, :insurance_application, foreign_key: true, null: true
    
    # We'll migrate the motor applications to insurance applications in a separate data migration
    # For now, just prepare the schema
    
    # Remove the old motor_application_id column after data migration
    # remove_reference :quotes, :motor_application, foreign_key: true
    
    # Update indexes
    add_index :quotes, [:insurance_application_id, :status]
    add_index :quotes, [:insurance_application_id, :expires_at]
  end
end
