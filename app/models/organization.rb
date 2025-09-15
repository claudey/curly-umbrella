class Organization < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :motor_applications, dependent: :destroy

  validates :name, presence: true
  validates :license_number, presence: true, uniqueness: true

  # JSON attributes for flexible data storage
  serialize :contact_info, JSON
  serialize :settings, JSON

  # Default values
  after_initialize :set_defaults

  private

  def set_defaults
    self.contact_info ||= {}
    self.settings ||= {}
  end
end
