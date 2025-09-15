class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: true, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.string :access_level, default: 'read_only'
      t.json :scopes, default: []
      t.integer :rate_limit
      t.datetime :expires_at
      t.boolean :active, default: true
      t.datetime :last_used_at
      t.datetime :last_rotated_at
      t.datetime :revoked_at
      t.text :revoked_reason

      t.timestamps
    end
    
    add_index :api_keys, :key, unique: true
    add_index :api_keys, [:user_id, :active]
    add_index :api_keys, [:organization_id, :active]
    add_index :api_keys, :expires_at
    add_index :api_keys, :last_used_at
  end
end
