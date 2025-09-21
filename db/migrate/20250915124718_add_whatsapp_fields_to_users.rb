class AddWhatsappFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :whatsapp_number, :string
    add_column :users, :whatsapp_enabled, :boolean, default: false, null: false

    add_index :users, :whatsapp_number
  end
end
