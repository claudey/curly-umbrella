class AddDiscardedAtToBrokerageAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :brokerage_agents, :discarded_at, :datetime
    add_index :brokerage_agents, :discarded_at
  end
end
