class AddDiscardedAtToMotorApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_applications, :discarded_at, :datetime
    add_index :motor_applications, :discarded_at
  end
end
