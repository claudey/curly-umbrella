class InsuranceCompany < ApplicationRecord
  include Discard::Model

  belongs_to :approved_by, class_name: "User", optional: true

  has_many :quotes, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :business_registration_number, presence: true, uniqueness: { case_sensitive: false }
  validates :license_number, presence: true, uniqueness: { case_sensitive: false }
  validates :contact_person, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :phone, format: { with: /\A[\+]?[0-9\s\-\(\)]+\z/, message: "Invalid phone format" }, allow_blank: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "Invalid URL format" }, allow_blank: true
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :payment_terms, inclusion: { in: %w[net_15 net_30 net_45 net_60 immediate] }

  scope :active, -> { where(active: true) }
  scope :approved, -> { where(approved: true) }
  scope :pending_approval, -> { where(approved: false) }
  scope :by_insurance_type, ->(type) { where("insurance_types ILIKE ?", "%#{type}%") }

  def display_name
    name
  end

  def approval_status
    return "Approved" if approved?
    "Pending Approval"
  end

  def supported_insurance_types
    return [] if insurance_types.blank?

    insurance_types.split(",").map(&:strip)
  end

  def supports_insurance_type?(type)
    supported_insurance_types.include?(type.to_s)
  end

  def approve!(user)
    update!(
      approved: true,
      approved_at: Time.current,
      approved_by: user
    )
  end

  def revoke_approval!
    update!(
      approved: false,
      approved_at: nil,
      approved_by: nil
    )
  end

  def commission_percentage
    "#{commission_rate}%"
  end

  def rating_display
    return "Not Rated" if rating.zero?

    "#{rating}/5.0"
  end

  def to_s
    name
  end
end
