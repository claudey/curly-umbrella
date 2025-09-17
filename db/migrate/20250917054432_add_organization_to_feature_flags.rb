class AddOrganizationToFeatureFlags < ActiveRecord::Migration[8.0]
  def change
    add_reference :feature_flags, :organization, null: true, foreign_key: true
  end
end
