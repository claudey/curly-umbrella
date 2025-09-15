class CompanyPreference < ApplicationRecord
  belongs_to :insurance_company
  
  validates :insurance_company_id, presence: true, uniqueness: true
  
  # Default preferences structure
  DEFAULT_PREFERENCES = {
    coverage_types: {
      'comprehensive' => true,
      'third_party' => true,
      'fire_theft' => false
    },
    vehicle_categories: {
      'sedan' => true,
      'suv' => true,
      'hatchback' => true,
      'truck' => false,
      'motorcycle' => false,
      'commercial' => false
    },
    risk_appetite: {
      'low_risk' => true,
      'medium_risk' => true,
      'high_risk' => false
    },
    sum_insured_ranges: {
      'under_10k' => true,
      '10k_to_25k' => true,
      '25k_to_50k' => true,
      '50k_to_100k' => false,
      'over_100k' => false
    },
    driver_age_preferences: {
      'under_25' => false,
      '25_to_35' => true,
      '36_to_55' => true,
      '56_to_70' => true,
      'over_70' => false
    },
    geographical_preferences: {
      'urban' => true,
      'suburban' => true,
      'rural' => false
    }
  }.freeze
  
  before_create :set_default_preferences
  
  def self.for_company(company)
    find_or_create_by(insurance_company: company)
  end
  
  # Coverage type methods
  def accepts_coverage_type?(coverage_type)
    coverage_types&.dig(coverage_type.to_s) == true
  end
  
  def enabled_coverage_types
    coverage_types&.select { |_, enabled| enabled }&.keys || []
  end
  
  # Vehicle category methods
  def accepts_vehicle_category?(category)
    vehicle_categories&.dig(category.to_s) == true
  end
  
  def enabled_vehicle_categories
    vehicle_categories&.select { |_, enabled| enabled }&.keys || []
  end
  
  # Risk appetite methods
  def accepts_risk_level?(risk_level)
    risk_appetite&.dig(risk_level.to_s) == true
  end
  
  def risk_appetite_score
    return 50 unless risk_appetite
    
    score = 0
    score += 20 if risk_appetite['low_risk']
    score += 50 if risk_appetite['medium_risk'] 
    score += 80 if risk_appetite['high_risk']
    
    score / risk_appetite.count { |_, enabled| enabled }
  end
  
  # Sum insured methods
  def accepts_sum_insured?(amount)
    return true unless amount
    
    case amount
    when 0...10_000
      sum_insured_ranges&.dig('under_10k') == true
    when 10_000...25_000
      sum_insured_ranges&.dig('10k_to_25k') == true
    when 25_000...50_000
      sum_insured_ranges&.dig('25k_to_50k') == true
    when 50_000...100_000
      sum_insured_ranges&.dig('50k_to_100k') == true
    else
      sum_insured_ranges&.dig('over_100k') == true
    end
  end
  
  # Driver age methods
  def accepts_driver_age?(age)
    return true unless age
    
    case age
    when 0...25
      driver_age_preferences&.dig('under_25') == true
    when 25...36
      driver_age_preferences&.dig('25_to_35') == true
    when 36...56
      driver_age_preferences&.dig('36_to_55') == true
    when 56...71
      driver_age_preferences&.dig('56_to_70') == true
    else
      driver_age_preferences&.dig('over_70') == true
    end
  end
  
  # Geographical methods
  def accepts_location_type?(location_type)
    geographical_preferences&.dig(location_type.to_s) == true
  end
  
  # Distribution settings
  def max_daily_applications
    distribution_settings&.dig('max_daily_applications') || 20
  end
  
  def max_simultaneous_applications
    distribution_settings&.dig('max_simultaneous_applications') || 50
  end
  
  def auto_distribution_enabled?
    distribution_settings&.dig('auto_distribution_enabled') != false
  end
  
  def notification_preferences
    distribution_settings&.dig('notification_preferences') || {
      'email_notifications' => true,
      'sms_notifications' => false,
      'in_app_notifications' => true,
      'daily_digest' => true
    }
  end
  
  # Update methods
  def update_coverage_preference(coverage_type, enabled)
    new_preferences = coverage_types.dup
    new_preferences[coverage_type.to_s] = enabled
    update!(coverage_types: new_preferences)
  end
  
  def update_vehicle_category_preference(category, enabled)
    new_preferences = vehicle_categories.dup
    new_preferences[category.to_s] = enabled
    update!(vehicle_categories: new_preferences)
  end
  
  def update_risk_appetite(risk_level, enabled)
    new_preferences = risk_appetite.dup
    new_preferences[risk_level.to_s] = enabled
    update!(risk_appetite: new_preferences)
  end
  
  def update_distribution_setting(key, value)
    new_settings = distribution_settings.dup
    new_settings[key.to_s] = value
    update!(distribution_settings: new_settings)
  end
  
  # Analysis methods
  def compatibility_score_for_application(application)
    score = 0
    total_criteria = 0
    
    # Coverage type compatibility (30%)
    if application.coverage_type.present?
      total_criteria += 30
      score += 30 if accepts_coverage_type?(application.coverage_type)
    end
    
    # Vehicle category compatibility (25%)
    if application.vehicle_category.present?
      total_criteria += 25
      score += 25 if accepts_vehicle_category?(application.vehicle_category)
    end
    
    # Sum insured compatibility (20%)
    if application.sum_insured.present?
      total_criteria += 20
      score += 20 if accepts_sum_insured?(application.sum_insured)
    end
    
    # Driver age compatibility (15%)
    if application.driver_age.present?
      total_criteria += 15
      score += 15 if accepts_driver_age?(application.driver_age)
    end
    
    # Risk level compatibility (10%)
    if application.calculated_risk_score.present?
      total_criteria += 10
      risk_level = case application.calculated_risk_score
                   when 0...30 then 'low_risk'
                   when 30...70 then 'medium_risk'
                   else 'high_risk'
                   end
      score += 10 if accepts_risk_level?(risk_level)
    end
    
    return 0 if total_criteria == 0
    
    (score.to_f / total_criteria * 100).round(2)
  end
  
  def applications_received_today
    insurance_company.application_distributions
                    .where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
                    .count
  end
  
  def can_receive_more_applications?
    applications_received_today < max_daily_applications
  end
  
  private
  
  def set_default_preferences
    self.coverage_types ||= DEFAULT_PREFERENCES[:coverage_types]
    self.vehicle_categories ||= DEFAULT_PREFERENCES[:vehicle_categories]
    self.risk_appetite ||= DEFAULT_PREFERENCES[:risk_appetite]
    self.sum_insured_ranges ||= DEFAULT_PREFERENCES[:sum_insured_ranges]
    self.driver_age_preferences ||= DEFAULT_PREFERENCES[:driver_age_preferences]
    self.geographical_preferences ||= DEFAULT_PREFERENCES[:geographical_preferences]
    self.distribution_settings ||= {
      'max_daily_applications' => 20,
      'max_simultaneous_applications' => 50,
      'auto_distribution_enabled' => true,
      'notification_preferences' => {
        'email_notifications' => true,
        'sms_notifications' => false,
        'in_app_notifications' => true,
        'daily_digest' => true
      }
    }
  end
end