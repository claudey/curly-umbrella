class Client < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization

  belongs_to :organization

  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, 
            uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :phone, format: { with: /\A[\+]?[0-9\s\-\(\)]+\z/, message: "Invalid phone format" }, allow_blank: true
  validates :date_of_birth, presence: true
  validates :id_type, inclusion: { in: %w[national_id passport drivers_license voters_id], allow_blank: true }
  validates :marital_status, inclusion: { in: %w[single married divorced widowed separated], allow_blank: true }
  validates :preferred_contact_method, inclusion: { in: %w[email phone sms whatsapp] }

  scope :by_name, ->(name) { where("CONCAT(first_name, ' ', last_name) ILIKE ?", "%#{name}%") }
  scope :by_email, ->(email) { where("email ILIKE ?", "%#{email}%") }
  scope :by_phone, ->(phone) { where("phone ILIKE ?", "%#{phone}%") }

  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    full_name
  end

  def age
    return nil unless date_of_birth
    
    ((Date.current - date_of_birth) / 365.25).to_i
  end

  def primary_contact
    case preferred_contact_method
    when 'email'
      email
    when 'phone', 'sms', 'whatsapp'
      phone
    else
      email
    end
  end

  def to_s
    full_name
  end
end
