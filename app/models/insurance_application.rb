class InsuranceApplication < ApplicationRecord
  include Discard::Model
  include Auditable
  include Encryptable
  acts_as_tenant :organization

  belongs_to :organization
  belongs_to :client
  belongs_to :user
  belongs_to :reviewed_by, class_name: 'User', optional: true
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :rejected_by, class_name: 'User', optional: true

  has_many :quotes, dependent: :destroy
  has_many :application_distributions, dependent: :destroy
  has_many :insurance_companies, through: :application_distributions
  has_many_attached :documents

  validates :application_number, presence: true, uniqueness: { scope: :organization_id }
  validates :insurance_type, presence: true, inclusion: { in: INSURANCE_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :sum_insured, :premium_amount, numericality: { greater_than: 0 }, allow_blank: true
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_blank: true
  validates :rejection_reason, presence: true, if: :rejected?

  validate :validate_insurance_type_data
  validate :validate_status_transitions

  before_validation :generate_application_number, on: :create
  before_validation :set_default_application_data
  after_update :log_status_change, if: :saved_change_to_status?

  scope :by_status, ->(status) { where(status: status) }
  scope :by_insurance_type, ->(type) { where(insurance_type: type) }
  scope :submitted, -> { where(status: %w[submitted under_review approved rejected]) }
  scope :pending_review, -> { where(status: 'submitted') }
  scope :under_review, -> { where(status: 'under_review') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :recent, -> { order(created_at: :desc) }

  # Insurance types
  INSURANCE_TYPES = %w[fire motor liability general_accident bonds].freeze
  
  # Application statuses
  STATUSES = %w[draft submitted under_review approved rejected].freeze

  # Insurance type configurations
  INSURANCE_TYPE_CONFIG = {
    fire: {
      display_name: 'Fire Insurance',
      required_fields: %w[property_type property_value property_address risk_factors],
      optional_fields: %w[construction_type occupancy_type fire_safety_measures previous_claims],
      prefix: 'FI'
    },
    motor: {
      display_name: 'Motor Insurance',
      required_fields: %w[vehicle_make vehicle_model vehicle_year registration_number chassis_number engine_number driver_license_number],
      optional_fields: %w[vehicle_color fuel_type transmission previous_accidents modifications],
      prefix: 'MI'
    },
    liability: {
      display_name: 'Liability Insurance',
      required_fields: %w[business_type liability_type coverage_scope annual_turnover],
      optional_fields: %w[number_of_employees business_description previous_claims legal_disputes],
      prefix: 'LI'
    },
    general_accident: {
      display_name: 'General Accident Insurance',
      required_fields: %w[coverage_type occupation annual_income beneficiary_details],
      optional_fields: %w[medical_history lifestyle_factors sports_activities previous_policies],
      prefix: 'GA'
    },
    bonds: {
      display_name: 'Bonds Insurance',
      required_fields: %w[bond_type principal_amount contract_details project_description],
      optional_fields: %w[contractor_experience financial_statements performance_history surety_requirements],
      prefix: 'BI'
    }
  }.freeze

  def self.insurance_type_display_name(type)
    INSURANCE_TYPE_CONFIG.dig(type.to_sym, :display_name) || type.to_s.humanize
  end

  def self.required_fields_for_type(type)
    INSURANCE_TYPE_CONFIG.dig(type.to_sym, :required_fields) || []
  end

  def self.optional_fields_for_type(type)
    INSURANCE_TYPE_CONFIG.dig(type.to_sym, :optional_fields) || []
  end

  def insurance_type_display_name
    self.class.insurance_type_display_name(insurance_type)
  end

  # Status methods
  def draft?
    status == 'draft'
  end

  def submitted?
    status == 'submitted'
  end

  def under_review?
    status == 'under_review'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  # Action permission methods
  def can_edit?
    draft? || submitted?
  end

  def can_submit?
    draft? && valid_for_submission?
  end

  def can_review?
    submitted?
  end

  def can_approve?
    under_review?
  end

  def can_reject?
    under_review?
  end

  # Status transition methods
  def submit!
    return false unless can_submit?

    transaction do
      update!(
        status: 'submitted',
        submitted_at: Time.current
      )
      
      # Trigger distribution to insurance companies
      ApplicationDistributionService.new(self).distribute!
      
      # Send notification
      NotificationService.new_application_submitted(self)
    end
  end

  # Distribution methods
  def can_be_distributed?
    submitted? && distributed_at.nil?
  end

  def distributed?
    distributed_at.present?
  end

  def distribution_deadline
    return nil unless distributed_at
    distributed_at + 7.days
  end

  def days_until_distribution_deadline
    return nil unless distribution_deadline
    ((distribution_deadline - Time.current) / 1.day).ceil
  end

  def distribution_expired?
    return false unless distribution_deadline
    distribution_deadline < Time.current
  end

  def start_review!(user)
    return false unless can_review?

    old_status = status
    
    transaction do
      update!(
        status: 'under_review',
        reviewed_at: Time.current,
        reviewed_by: user
      )
      
      NotificationService.application_status_updated(self, old_status, 'under_review')
    end
  end

  def approve!(user)
    return false unless can_approve?

    old_status = status
    
    transaction do
      update!(
        status: 'approved',
        approved_at: Time.current,
        approved_by: user
      )
      
      NotificationService.application_status_updated(self, old_status, 'approved')
    end
  end

  def reject!(user, reason)
    return false unless can_reject?

    old_status = status
    
    transaction do
      update!(
        status: 'rejected',
        rejected_at: Time.current,
        rejected_by: user,
        rejection_reason: reason
      )
      
      NotificationService.application_status_updated(self, old_status, 'rejected')
    end
  end

  # UI helpers
  def status_badge_class
    case status
    when 'draft' then 'badge-ghost'
    when 'submitted' then 'badge-info'
    when 'under_review' then 'badge-warning'
    when 'approved' then 'badge-success'
    when 'rejected' then 'badge-error'
    else 'badge-ghost'
    end
  end

  def status_icon
    case status
    when 'draft' then 'ph-note-pencil'
    when 'submitted' then 'ph-paper-plane-tilt'
    when 'under_review' then 'ph-magnifying-glass'
    when 'approved' then 'ph-check-circle'
    when 'rejected' then 'ph-x-circle'
    else 'ph-circle'
    end
  end

  # Application data helpers
  def get_field(field_name)
    application_data[field_name.to_s]
  end

  def set_field(field_name, value)
    self.application_data = application_data.merge(field_name.to_s => value)
  end

  def required_fields
    self.class.required_fields_for_type(insurance_type)
  end

  def optional_fields
    self.class.optional_fields_for_type(insurance_type)
  end

  def all_fields
    required_fields + optional_fields
  end

  # Quote management
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

  # Risk assessment methods
  def risk_score
    case insurance_type
    when 'motor'
      calculate_motor_risk_score
    when 'fire'
      calculate_fire_risk_score
    when 'liability'
      calculate_liability_risk_score
    when 'general_accident'
      calculate_general_accident_risk_score
    when 'bonds'
      calculate_bonds_risk_score
    else
      50 # Default medium risk
    end
  end

  def risk_level
    score = risk_score
    case score
    when 0..30 then 'low'
    when 31..70 then 'medium'
    else 'high'
    end
  end

  def risk_level_color
    case risk_level
    when 'low' then 'text-green-600'
    when 'medium' then 'text-yellow-600'
    when 'high' then 'text-red-600'
    end
  end

  private

  def generate_application_number
    return if application_number.present?

    prefix = INSURANCE_TYPE_CONFIG.dig(insurance_type.to_sym, :prefix) || 'INS'
    date_part = Date.current.strftime('%Y%m')
    
    last_number = organization.insurance_applications
                             .where(insurance_type: insurance_type)
                             .where("application_number LIKE ?", "#{prefix}#{date_part}%")
                             .maximum(:application_number)&.slice(-4..-1)&.to_i || 0
    
    self.application_number = "#{prefix}#{date_part}#{(last_number + 1).to_s.rjust(4, '0')}"
  end

  def set_default_application_data
    self.application_data ||= {}
  end

  def validate_insurance_type_data
    return unless insurance_type.present?

    required_fields.each do |field|
      if get_field(field).blank?
        errors.add(:application_data, "#{field.humanize} is required for #{insurance_type_display_name}")
      end
    end
  end

  def validate_status_transitions
    return unless status_changed?

    old_status = status_was
    new_status = status

    valid_transitions = {
      'draft' => %w[submitted],
      'submitted' => %w[under_review rejected],
      'under_review' => %w[approved rejected],
      'approved' => [],
      'rejected' => %w[submitted] # Allow resubmission
    }

    unless valid_transitions[old_status]&.include?(new_status)
      errors.add(:status, "Invalid status transition from #{old_status} to #{new_status}")
    end
  end

  def valid_for_submission?
    return false unless insurance_type.present?
    
    required_fields.all? { |field| get_field(field).present? }
  end

  def log_status_change
    AuditLog.log_data_modification(
      Current.user,
      self,
      'status_changed',
      {
        old_status: status_was,
        new_status: status,
        changed_at: Time.current
      }
    )
  end

  # Risk calculation methods
  def calculate_motor_risk_score
    score = 50 # Base score
    
    # Age factor
    if client.age < 25
      score += 20
    elsif client.age > 65
      score += 10
    else
      score -= 5
    end
    
    # Vehicle age
    vehicle_age = Date.current.year - get_field('vehicle_year').to_i
    score += (vehicle_age * 2) if vehicle_age > 0
    
    # Usage type
    case get_field('vehicle_usage')
    when 'commercial' then score += 15
    when 'business' then score += 10
    when 'personal' then score -= 5
    end
    
    # Previous claims
    if application_data['previous_accidents'].present?
      score += 25
    end
    
    [score, 100].min
  end

  def calculate_fire_risk_score
    score = 50
    
    # Property type
    case get_field('property_type')
    when 'industrial' then score += 20
    when 'commercial' then score += 15
    when 'residential' then score -= 10
    end
    
    # Construction type
    case get_field('construction_type')
    when 'wood' then score += 25
    when 'mixed' then score += 10
    when 'concrete' then score -= 15
    end
    
    # Fire safety measures
    if get_field('fire_safety_measures').present?
      score -= 20
    end
    
    [score, 100].min
  end

  def calculate_liability_risk_score
    score = 50
    
    # Business type risk
    case get_field('business_type')
    when 'manufacturing' then score += 20
    when 'construction' then score += 25
    when 'retail' then score += 5
    when 'office' then score -= 10
    end
    
    # Annual turnover
    turnover = get_field('annual_turnover').to_f
    if turnover > 10_000_000
      score += 15
    elsif turnover > 1_000_000
      score += 10
    end
    
    [score, 100].min
  end

  def calculate_general_accident_risk_score
    score = 50
    
    # Occupation risk
    case get_field('occupation')
    when 'construction', 'mining' then score += 30
    when 'transport', 'security' then score += 20
    when 'office', 'education' then score -= 15
    end
    
    # Age factor
    if client.age > 60
      score += 15
    elsif client.age < 30
      score += 5
    end
    
    [score, 100].min
  end

  def calculate_bonds_risk_score
    score = 50
    
    # Bond type
    case get_field('bond_type')
    when 'performance' then score += 15
    when 'payment' then score += 10
    when 'bid' then score += 5
    end
    
    # Principal amount
    amount = get_field('principal_amount').to_f
    if amount > 10_000_000
      score += 20
    elsif amount > 1_000_000
      score += 10
    end
    
    [score, 100].min
  end
end
