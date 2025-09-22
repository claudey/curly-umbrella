class AddUserAndClientTypeToClients < ActiveRecord::Migration[8.0]
  def change
    # Add columns allowing null initially
    add_reference :clients, :user, null: true, foreign_key: true
    add_column :clients, :client_type, :string, default: 'individual'
    add_column :clients, :status, :string, default: 'active'
    
    # Set default values for existing records
    reversible do |dir|
      dir.up do
        # Get the first user from each organization to assign to existing clients
        execute <<-SQL
          UPDATE clients 
          SET user_id = (
            SELECT users.id 
            FROM users 
            WHERE users.organization_id = clients.organization_id 
            LIMIT 1
          )
          WHERE user_id IS NULL;
        SQL
        
        # Now make user_id not null
        change_column_null :clients, :user_id, false
      end
    end
  end
end
