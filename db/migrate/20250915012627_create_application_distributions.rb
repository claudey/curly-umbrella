class CreateApplicationDistributions < ActiveRecord::Migration[8.0]
  def change
    create_table :application_distributions do |t|
      t.references :motor_application, null: false, foreign_key: true
      t.references :insurance_company, null: false, foreign_key: true
      t.references :distributed_by, null: true, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'pending'
      t.string :distribution_method, null: false, default: 'automatic'
      t.decimal :match_score, precision: 5, scale: 2, default: 0.0
      t.datetime :viewed_at
      t.datetime :quoted_at
      t.datetime :ignored_at
      t.datetime :expired_at
      t.text :ignore_reason
      t.json :distribution_criteria, default: {}

      t.timestamps
    end

    add_index :application_distributions, [ :motor_application_id, :insurance_company_id ],
              unique: true, name: 'idx_unique_app_company_distribution'
    add_index :application_distributions, :status
    add_index :application_distributions, :distribution_method
    add_index :application_distributions, :match_score
    add_index :application_distributions, :created_at
  end
end
