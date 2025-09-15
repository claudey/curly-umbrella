class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Multi-tenant association
  acts_as_tenant :organization
  belongs_to :organization

  # Associations
  has_one :notification_preference, dependent: :destroy
  has_many :notifications, dependent: :destroy

  # User roles
  enum role: { 
    super_admin: 0, 
    brokerage_admin: 1, 
    agent: 2, 
    insurance_company: 3 
  }

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :phone, presence: true
  validates :role, presence: true

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    full_name.presence || email
  end

  # Notification preferences helper
  def notification_preferences
    super || build_notification_preference
  end

  # Create default notification preferences after user creation
  after_create :create_default_notification_preferences

  private

  def create_default_notification_preferences
    NotificationPreference.create_defaults_for_user(self, organization)
  end
end
