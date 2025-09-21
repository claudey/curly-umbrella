class CreateRolePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.datetime :granted_at, null: false
      t.references :granted_by, null: true, foreign_key: { to_table: :users }
      t.text :notes

      t.timestamps
    end

    add_index :role_permissions, [ :role_id, :permission_id ], unique: true, name: 'idx_role_permission_unique'
    add_index :role_permissions, [ :permission_id ], name: 'idx_role_permissions_permission_id'
  end
end
