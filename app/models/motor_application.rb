class MotorApplication < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization
  audited

  belongs_to :organization
  belongs_to :client
  belongs_to :reviewed_by, class_name: "User", optional: true
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :rejected_by, class_name: "User", optional: true

  has_many :quotes, dependent: :destroy
  has_many :documents, as: :documentable, dependent: :destroy
  has_many_attached :legacy_documents

  validates :application_number, presence: true, uniqueness: { scope: :organization_id }
  validates :status, presence: true, inclusion: { in: %w[draft submitted under_review approved rejected] }
  validates :vehicle_make, :vehicle_model, :vehicle_year, :vehicle_category, :vehicle_usage, presence: true
  validates :vehicle_year, numericality: { greater_than: 1900, less_than_or_equal_to: Date.current.year + 1 }
  validates :driver_license_number, :driver_license_expiry, presence: true
  validates :coverage_type, :coverage_start_date, :coverage_end_date, presence: true
  validates :driver_has_claims, inclusion: { in: [ true, false ] }

  validates :driver_claims_details, presence: true, if: :driver_has_claims?
  validates :rejection_reason, presence: true, if: :rejected?
  validates :sum_insured, :premium_amount, numericality: { greater_than: 0 }, allow_blank: true
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_blank: true

  validate :coverage_end_date_after_start_date
  validate :driver_license_not_expired

  before_validation :generate_application_number, on: :create
  before_validation :set_driver_age_from_client

  scope :by_status, ->(status) { where(status: status) }
  scope :submitted, -> { where(status: %w[submitted under_review approved rejected]) }
  scope :pending_review, -> { where(status: "submitted") }
  scope :under_review, -> { where(status: "under_review") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :recent, -> { order(created_at: :desc) }

  VEHICLE_CATEGORIES = %w[private commercial motorcycle truck].freeze
  VEHICLE_USAGE_TYPES = %w[personal business commercial ride_sharing delivery].freeze
  COVERAGE_TYPES = %w[comprehensive third_party fire_theft].freeze
  FUEL_TYPES = %w[petrol diesel hybrid electric].freeze
  TRANSMISSION_TYPES = %w[manual automatic cvt].freeze

  def draft?
    status == "draft"
  end

  def submitted?
    status == "submitted"
  end

  def under_review?
    status == "under_review"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def can_edit?
    draft? || submitted?
  end

  def can_submit?
    draft? && valid_for_submission?
  end

  def can_review?
    submitted?
  end

  def submit!
    return false unless can_submit?

    transaction do
      update!(
        status: "submitted",
        submitted_at: Time.current
      )

      # Send notification for new application
      NotificationService.new_application_submitted(self)
    end
  end

  def start_review!(user)
    return false unless can_review?

    old_status = status

    transaction do
      update!(
        status: "under_review",
        reviewed_at: Time.current,
        reviewed_by: user
      )

      # Send status update notification
      NotificationService.application_status_updated(self, old_status, "under_review")
    end
  end

  def approve!(user)
    return false unless under_review?

    old_status = status

    transaction do
      update!(
        status: "approved",
        approved_at: Time.current,
        approved_by: user
      )

      # Send status update notification
      NotificationService.application_status_updated(self, old_status, "approved")
    end
  end

  def reject!(user, reason)
    return false unless under_review?

    old_status = status

    transaction do
      update!(
        status: "rejected",
        rejected_at: Time.current,
        rejected_by: user,
        rejection_reason: reason
      )

      # Send status update notification
      NotificationService.application_status_updated(self, old_status, "rejected")
    end
  end

  def status_badge_class
    case status
    when "draft" then "badge-ghost"
    when "submitted" then "badge-info"
    when "under_review" then "badge-warning"
    when "approved" then "badge-success"
    when "rejected" then "badge-error"
    else "badge-ghost"
    end
  end

  def vehicle_display_name
    "#{vehicle_year} #{vehicle_make} #{vehicle_model}"
  end

  def coverage_period
    return nil unless coverage_start_date && coverage_end_date

    "#{coverage_start_date.strftime('%d/%m/%Y')} - #{coverage_end_date.strftime('%d/%m/%Y')}"
  end

  def total_premium_with_commission
    return premium_amount unless commission_rate && premium_amount

    premium_amount + (premium_amount * commission_rate / 100)
  end

  # Quote management methods
  def has_quotes?
    quotes.any?
  end

  def active_quotes
    quotes.active.includes(:insurance_company, :quoted_by)
  end

  def best_quote
    active_quotes.approved.order(:premium_amount).first
  end

  def accepted_quote
    quotes.accepted.first
  end

  def quotes_for_comparison
    active_quotes.approved.order(:premium_amount)
  end

  private

  def generate_application_number
    return if application_number.present?

    prefix = "MA#{Date.current.strftime('%Y%m')}"
    last_number = organization.motor_applications
                             .where("application_number LIKE ?", "#{prefix}%")
                             .maximum(:application_number)&.slice(-4..-1)&.to_i || 0

    self.application_number = "#{prefix}#{(last_number + 1).to_s.rjust(4, '0')}"
  end

  def set_driver_age_from_client
    return unless client&.date_of_birth

    self.driver_age = client.age
  end

  def coverage_end_date_after_start_date
    return unless coverage_start_date && coverage_end_date

    errors.add(:coverage_end_date, "must be after start date") if coverage_end_date <= coverage_start_date
  end

  def driver_license_not_expired
    return unless driver_license_expiry

    errors.add(:driver_license_expiry, "cannot be in the past") if driver_license_expiry < Date.current
  end

  def valid_for_submission?
    required_fields = %w[
      vehicle_make vehicle_model vehicle_year vehicle_category vehicle_usage
      driver_license_number driver_license_expiry coverage_type
      coverage_start_date coverage_end_date
    ]

    required_fields.all? { |field| send(field).present? }
  end
end
