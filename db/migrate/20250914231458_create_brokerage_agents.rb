class CreateBrokerageAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :brokerage_agents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :role, null: false, default: 'agent'
      t.boolean :active, null: false, default: true
      t.date :join_date, null: false

      t.timestamps
    end

    add_index :brokerage_agents, [:user_id, :organization_id], unique: true
    add_index :brokerage_agents, :active
  end
end
