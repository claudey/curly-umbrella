class AddAdminFieldsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :subdomain, :string
    add_column :organizations, :description, :text
    add_column :organizations, :active, :boolean, default: true, null: false
    add_column :organizations, :plan, :string
    add_column :organizations, :max_users, :integer
    add_column :organizations, :max_applications, :integer
    add_column :organizations, :billing_email, :string

    add_index :organizations, :subdomain, unique: true
    add_index :organizations, :active
  end
end
