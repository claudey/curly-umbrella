class CreateFeatureFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :feature_flags do |t|
      t.string :key
      t.string :name
      t.text :description
      t.boolean :enabled
      t.integer :percentage
      t.text :user_groups
      t.text :conditions
      t.json :metadata
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.references :updated_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :feature_flags, :key, unique: true
  end
end
