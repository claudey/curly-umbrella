class Quote < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization

  belongs_to :motor_application
  belongs_to :insurance_company
  belongs_to :organization
  belongs_to :quoted_by, class_name: 'User'

  validates :quote_number, presence: true, uniqueness: true
  validates :premium_amount, presence: true, numericality: { greater_than: 0 }
  validates :coverage_amount, presence: true, numericality: { greater_than: 0 }
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_blank: true
  validates :validity_period, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { 
    in: %w[draft submitted pending_review approved rejected expired accepted withdrawn] 
  }

  before_validation :generate_quote_number, on: :create
  before_validation :calculate_commission_amount
  before_validation :set_expires_at

  scope :active, -> { where.not(status: ['expired', 'withdrawn']) }
  scope :pending, -> { where(status: ['submitted', 'pending_review']) }
  scope :approved, -> { where(status: 'approved') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :expired, -> { where(status: 'expired') }
  scope :recent, -> { order(created_at: :desc) }
  scope :expiring_soon, -> { where(expires_at: Date.current..7.days.from_now) }

  # Status checks
  def draft?
    status == 'draft'
  end

  def submitted?
    status == 'submitted'
  end

  def pending_review?
    status == 'pending_review'
  end

  def approved?
    status == 'approved'
  end

  def accepted?
    status == 'accepted'
  end

  def rejected?
    status == 'rejected'
  end

  def expired?
    status == 'expired' || (expires_at && expires_at < Time.current)
  end

  def withdrawn?
    status == 'withdrawn'
  end

  # Status transitions
  def submit!
    return false unless draft?
    
    update!(
      status: 'submitted',
      quoted_at: Time.current
    )
  end

  def start_review!
    return false unless submitted?
    
    update!(status: 'pending_review')
  end

  def approve!
    return false unless pending_review?
    
    update!(status: 'approved')
  end

  def reject!(reason = nil)
    return false unless %w[submitted pending_review].include?(status)
    
    update!(
      status: 'rejected',
      rejected_at: Time.current,
      notes: reason
    )
  end

  def accept!
    return false unless approved?
    
    transaction do
      update!(
        status: 'accepted',
        accepted_at: Time.current
      )
      
      # Mark other quotes for same application as rejected
      motor_application.quotes.where.not(id: id).update_all(
        status: 'rejected',
        rejected_at: Time.current,
        notes: 'Automatically rejected - another quote was accepted'
      )
    end
  end

  def withdraw!
    return false if %w[accepted expired].include?(status)
    
    update!(status: 'withdrawn')
  end

  def expire!
    return false if %w[accepted withdrawn].include?(status)
    
    update!(status: 'expired')
  end

  # Calculated fields
  def total_premium
    premium_amount + (commission_amount || 0)
  end

  def expires_in_days
    return 0 if expired?
    return nil unless expires_at
    
    ((expires_at - Time.current) / 1.day).ceil
  end

  def coverage_types
    coverage_details&.keys || []
  end

  def coverage_for(type)
    coverage_details&.dig(type)
  end

  # Status badge styling
  def status_badge_class
    case status
    when 'draft' then 'badge-ghost'
    when 'submitted' then 'badge-info'
    when 'pending_review' then 'badge-warning'
    when 'approved' then 'badge-success'
    when 'accepted' then 'badge-primary'
    when 'rejected' then 'badge-error'
    when 'expired' then 'badge-neutral'
    when 'withdrawn' then 'badge-ghost'
    else 'badge-ghost'
    end
  end

  # Class method to check for expiring quotes
  def self.check_expired_quotes!
    where('expires_at < ? AND status NOT IN (?)', Time.current, ['expired', 'accepted', 'withdrawn'])
      .update_all(status: 'expired')
  end

  private

  def generate_quote_number
    return if quote_number.present?
    
    prefix = "QT#{Date.current.strftime('%Y%m')}"
    last_number = organization.quotes
                             .where("quote_number LIKE ?", "#{prefix}%")
                             .maximum(:quote_number)&.slice(-4..-1)&.to_i || 0
    
    self.quote_number = "#{prefix}#{(last_number + 1).to_s.rjust(4, '0')}"
  end

  def calculate_commission_amount
    return unless premium_amount && commission_rate
    
    self.commission_amount = premium_amount * (commission_rate / 100.0)
  end

  def set_expires_at
    return if expires_at.present?
    return unless validity_period && (quoted_at || status != 'draft')
    
    base_date = quoted_at || Time.current
    self.expires_at = base_date + validity_period.days
  end
end
