class AddMfaToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :mfa_enabled, :boolean, default: false, null: false
    add_column :users, :mfa_secret, :string
    add_column :users, :backup_codes, :text
    add_column :users, :mfa_setup_at, :datetime
    add_column :users, :last_mfa_code_used_at, :datetime

    add_index :users, :mfa_secret
  end
end
