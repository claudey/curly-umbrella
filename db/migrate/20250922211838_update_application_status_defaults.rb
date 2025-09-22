class UpdateApplicationStatusDefaults < ActiveRecord::Migration[8.0]
  def change
    # Set default values for status enums (0 = draft)
    change_column_default :life_applications, :status, from: nil, to: 0
    change_column_default :fire_applications, :status, from: nil, to: 0
    change_column_default :residential_applications, :status, from: nil, to: 0
    
    # Set default values for existing records
    reversible do |dir|
      dir.up do
        execute "UPDATE life_applications SET status = 0 WHERE status IS NULL"
        execute "UPDATE fire_applications SET status = 0 WHERE status IS NULL"
        execute "UPDATE residential_applications SET status = 0 WHERE status IS NULL"
      end
    end
  end
end
