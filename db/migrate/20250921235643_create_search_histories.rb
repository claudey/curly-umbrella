class CreateSearchHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :search_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :query, null: false
      t.integer :results_count, null: false, default: 0
      t.decimal :search_time, precision: 8, scale: 3
      t.json :metadata, default: {}

      t.timestamps
    end

    # Add indexes for performance
    add_index :search_histories, :query
    add_index :search_histories, [:user_id, :created_at]
    add_index :search_histories, [:query, :created_at]
    add_index :search_histories, :results_count
    add_index :search_histories, :created_at
  end
end
