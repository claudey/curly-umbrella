class CreatePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :permissions do |t|
      t.string :name, null: false
      t.string :display_name, null: false
      t.text :description
      t.string :resource, null: false
      t.string :action, null: false
      t.boolean :system_permission, default: false, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :permissions, :name, unique: true
    add_index :permissions, [ :resource, :action ]
    add_index :permissions, :system_permission
    add_index :permissions, :active
  end
end
