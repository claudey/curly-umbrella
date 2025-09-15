class AddPhoneNumberToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone_number, :string
    add_column :users, :sms_enabled, :boolean, default: false, null: false
    
    add_index :users, :phone_number
  end
end
