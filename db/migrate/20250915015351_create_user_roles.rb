class CreateUserRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.boolean :active, default: true, null: false
      t.datetime :granted_at, null: false
      t.references :granted_by, null: true, foreign_key: { to_table: :users }
      t.datetime :expires_at
      t.text :notes

      t.timestamps
    end
    
    add_index :user_roles, [:user_id, :role_id], unique: true
    add_index :user_roles, [:user_id, :active]
    add_index :user_roles, [:role_id, :active]
    add_index :user_roles, :expires_at
  end
end
