class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.string :display_name, null: false
      t.text :description
      t.integer :level, null: false, default: 1
      t.boolean :active, default: true, null: false
      t.references :organization, null: true, foreign_key: true
      t.boolean :system_role, default: false, null: false

      t.timestamps
    end
    
    add_index :roles, [:name, :organization_id], unique: true
    add_index :roles, [:organization_id, :active]
    add_index :roles, :level
    add_index :roles, :system_role
  end
end
