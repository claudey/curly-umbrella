class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :license_number, null: false
      t.jsonb :contact_info, default: {}
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :organizations, :license_number, unique: true
    add_index :organizations, :name
  end
end
