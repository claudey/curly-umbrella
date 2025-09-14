class AddDiscardedAtToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :discarded_at, :datetime
    add_index :clients, :discarded_at
  end
end
