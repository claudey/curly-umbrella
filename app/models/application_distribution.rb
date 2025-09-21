class ApplicationDistribution < ApplicationRecord
  belongs_to :insurance_application
  belongs_to :insurance_company
  belongs_to :distributed_by, class_name: "User", optional: true

  validates :insurance_application_id, presence: true
  validates :insurance_company_id, presence: true
  validates :status, presence: true
  validates :distribution_method, presence: true

  enum status: {
    pending: "pending",
    viewed: "viewed",
    quoted: "quoted",
    ignored: "ignored",
    expired: "expired"
  }

  enum distribution_method: {
    automatic: "automatic",
    manual: "manual",
    broadcast: "broadcast"
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where.not(status: [ "ignored", "expired" ]) }
  scope :for_company, ->(company) { where(insurance_company: company) }

  after_create :send_distribution_notification
  after_update :track_status_change, if: :saved_change_to_status?

  def self.distribute_application(application, options = {})
    eligible_companies = find_eligible_companies(application, options)

    distributions = eligible_companies.map do |company|
      create!(
        insurance_application: application,
        insurance_company: company,
        distribution_method: options[:method] || "automatic",
        distributed_by: options[:distributed_by],
        match_score: calculate_match_score(application, company),
        distribution_criteria: build_criteria(application, company)
      )
    end

    # Track distribution analytics
    DistributionAnalytics.track_distribution(
      application: application,
      companies_count: eligible_companies.count,
      method: options[:method] || "automatic"
    )

    distributions
  end

  def self.find_eligible_companies(application, options = {})
    companies = InsuranceCompany.active.approved

    # Apply insurance type filter
    companies = companies.joins(:company_preferences)
                        .where(company_preferences: {
                          insurance_types: { application.insurance_type => true }
                        })

    # Apply geographical filter based on client location
    if application.client&.city.present?
      companies = companies.where(
        "service_areas @> ? OR service_areas IS NULL",
        [ application.client.city ].to_json
      )
    end

    # Apply insurance type specific filters
    case application.insurance_type
    when "motor"
      # Apply vehicle category filter for motor insurance
      if application.get_field("vehicle_category").present?
        companies = companies.joins(:company_preferences)
                            .where(company_preferences: {
                              vehicle_categories: { application.get_field("vehicle_category") => true }
                            })
      end
    when "fire"
      # Apply property type filter for fire insurance
      if application.get_field("property_type").present?
        companies = companies.joins(:company_preferences)
                            .where(company_preferences: {
                              property_types: { application.get_field("property_type") => true }
                            })
      end
    when "liability"
      # Apply business type filter for liability insurance
      if application.get_field("business_type").present?
        companies = companies.joins(:company_preferences)
                            .where(company_preferences: {
                              business_types: { application.get_field("business_type") => true }
                            })
      end
    end

    # Exclude companies that already have quotes for this application
    companies = companies.where.not(
      id: Quote.where(insurance_application: application).select(:insurance_company_id)
    )

    # Apply manual exclusions if specified
    if options[:exclude_companies].present?
      companies = companies.where.not(id: options[:exclude_companies])
    end

    # Apply manual inclusions if specified (overrides other filters)
    if options[:include_companies].present?
      companies = InsuranceCompany.where(id: options[:include_companies])
    end

    # Limit based on distribution preferences
    max_companies = options[:max_companies] || 5
    companies.limit(max_companies)
  end

  def self.calculate_match_score(application, company)
    score = 0.0

    # Coverage type match (40% weight)
    if company.company_preferences&.coverage_types&.dig(application.coverage_type)
      score += 40
    end

    # Vehicle category match (30% weight)
    if company.company_preferences&.vehicle_categories&.dig(application.vehicle_category)
      score += 30
    end

    # Historical performance (20% weight)
    acceptance_rate = company.quote_acceptance_rate_for_category(application.vehicle_category)
    score += (acceptance_rate * 20)

    # Risk appetite match (10% weight)
    risk_score = calculate_application_risk_score(application)
    if company.risk_appetite_matches?(risk_score)
      score += 10
    end

    score.round(2)
  end

  def self.calculate_application_risk_score(application)
    risk_score = 0

    # Driver age risk
    if application.driver_age
      case application.driver_age
      when 0..24
        risk_score += 30
      when 25..35
        risk_score += 10
      when 36..55
        risk_score += 0
      when 56..70
        risk_score += 15
      else
        risk_score += 25
      end
    end

    # Claims history risk
    risk_score += 40 if application.driver_has_claims?

    # Vehicle age risk
    if application.vehicle_year
      vehicle_age = Date.current.year - application.vehicle_year
      risk_score += (vehicle_age * 2) if vehicle_age > 5
    end

    # License experience
    if application.license_years
      risk_score -= 10 if application.license_years > 10
      risk_score += 20 if application.license_years < 2
    end

    [ risk_score, 100 ].min # Cap at 100
  end

  def self.build_criteria(application, company)
    {
      coverage_type_match: company.company_preferences&.coverage_types&.dig(application.coverage_type) || false,
      vehicle_category_match: company.company_preferences&.vehicle_categories&.dig(application.vehicle_category) || false,
      geographical_match: company.serves_location?(application.location),
      risk_appetite_match: company.risk_appetite_matches?(calculate_application_risk_score(application)),
      sum_insured_range_match: company.sum_insured_in_range?(application.sum_insured)
    }
  end

  # Instance methods
  def mark_as_viewed!
    update!(status: "viewed", viewed_at: Time.current) if pending?
  end

  def mark_as_quoted!
    update!(status: "quoted", quoted_at: Time.current) if %w[pending viewed].include?(status)
  end

  def mark_as_ignored!(reason = nil)
    update!(
      status: "ignored",
      ignored_at: Time.current,
      ignore_reason: reason
    )
  end

  def expire!
    update!(status: "expired", expired_at: Time.current) if active?
  end

  def active?
    !%w[ignored expired].include?(status)
  end

  def response_time
    return nil unless viewed_at

    (viewed_at - created_at).to_i
  end

  def time_to_quote
    return nil unless quoted_at

    (quoted_at - created_at).to_i
  end

  def days_since_distribution
    ((Time.current - created_at) / 1.day).to_i
  end

  def expires_in_days
    return nil unless quote_deadline

    ((quote_deadline - Time.current) / 1.day).ceil
  end

  def quote_deadline
    # Default 7 days from distribution
    created_at + 7.days
  end

  def deadline_expired?
    quote_deadline && quote_deadline < Time.current
  end

  def deadline_approaching?
    return false unless quote_deadline
    expires_in_days <= 2
  end

  def has_submitted_quote?
    insurance_application.quotes.exists?(insurance_company: insurance_company)
  end

  def high_match?
    match_score >= 70
  end

  def medium_match?
    match_score >= 40 && match_score < 70
  end

  def low_match?
    match_score < 40
  end

  private

  def send_distribution_notification
    # Send email notification to insurance company
    InsuranceCompanyMailer.new_application_available(self).deliver_later

    # Create in-app notification
    Notification.create!(
      recipient: insurance_company.primary_contact,
      title: "New Application Available",
      message: "A new #{motor_application.coverage_type} insurance application is available for quoting",
      notification_type: "application_distribution",
      metadata: {
        application_id: motor_application.id,
        distribution_id: id,
        match_score: match_score
      }
    )
  end

  def track_status_change
    DistributionAnalytics.track_status_change(
      distribution: self,
      previous_status: status_before_last_save,
      new_status: status
    )
  end
end
