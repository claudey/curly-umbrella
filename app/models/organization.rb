class Organization < ApplicationRecord
  audited

  has_many :users, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :motor_applications, dependent: :destroy
  has_many :insurance_applications, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :api_keys, dependent: :destroy

  validates :name, presence: true
  validates :license_number, presence: true, uniqueness: true
  validates :subdomain, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "can only contain lowercase letters, numbers, and hyphens" }
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # JSONB attributes are natively supported in PostgreSQL
  # No need for serialize with JSONB columns

  # Default values
  after_initialize :set_defaults

  # Insurance type methods
  def applications_by_type
    insurance_applications.group(:insurance_type).count
  end

  def applications_for_type(insurance_type)
    insurance_applications.where(insurance_type: insurance_type)
  end

  def active_applications_count
    insurance_applications.where.not(status: ['rejected', 'expired']).count
  end

  def monthly_applications_count
    insurance_applications.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
  end

  # Feature flag support
  def feature_enabled?(feature_name)
    settings.dig('features', feature_name.to_s) != false
  end

  def enable_feature!(feature_name)
    self.settings = settings.merge('features' => (settings['features'] || {}).merge(feature_name.to_s => true))
    save!
  end

  def disable_feature!(feature_name)
    self.settings = settings.merge('features' => (settings['features'] || {}).merge(feature_name.to_s => false))
    save!
  end

  private

  def set_defaults
    self.contact_info ||= {}
    self.settings ||= {
      'features' => {
        'motor_insurance' => true,
        'fire_insurance' => true,
        'liability_insurance' => true,
        'general_accident_insurance' => true,
        'bonds_insurance' => true,
        'real_time_notifications' => true,
        'advanced_reporting' => true,
        'api_access' => false
      }
    }
  end
end
