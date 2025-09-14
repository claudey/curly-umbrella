class BrokerageAgent < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization

  belongs_to :user
  belongs_to :organization

  validates :role, presence: true, inclusion: { in: %w[agent senior_agent team_lead manager] }
  validates :active, inclusion: { in: [true, false] }
  validates :join_date, presence: true
  validates :user_id, uniqueness: { scope: :organization_id }

  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { where(role: role) }

  def display_name
    user.full_name
  end

  def can_manage_agents?
    %w[team_lead manager].include?(role)
  end
end
