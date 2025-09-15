class InsuranceCompany::DashboardController < ApplicationController
  include AuthorizationController
  
  before_action :ensure_insurance_company_user
  before_action :set_insurance_company
  
  def index
    @dashboard_data = build_dashboard_data
  end

  private

  def ensure_insurance_company_user
    unless current_user.insurance_company_id.present?
      redirect_to root_path, alert: 'Access denied. Insurance company access required.'
    end
  end

  def set_insurance_company
    @insurance_company = current_user.insurance_company
  end

  def build_dashboard_data
    {
      # Application statistics
      pending_applications: pending_applications_count,
      viewed_applications: viewed_applications_count,
      quoted_applications: quoted_applications_count,
      ignored_applications: ignored_applications_count,
      
      # Quote statistics
      total_quotes: total_quotes_count,
      pending_quotes: pending_quotes_count,
      approved_quotes: approved_quotes_count,
      accepted_quotes: accepted_quotes_count,
      
      # Performance metrics
      response_time: average_response_time,
      quote_acceptance_rate: quote_acceptance_rate,
      weekly_applications: weekly_applications_data,
      insurance_type_breakdown: insurance_type_breakdown,
      
      # Recent activity
      recent_applications: recent_applications,
      recent_quotes: recent_quotes,
      expiring_quotes: expiring_quotes,
      
      # Monthly targets
      monthly_target: monthly_quote_target,
      monthly_progress: monthly_quote_progress
    }
  end

  def pending_applications_count
    @insurance_company.application_distributions.pending.count
  end

  def viewed_applications_count
    @insurance_company.application_distributions.viewed.count
  end

  def quoted_applications_count
    @insurance_company.application_distributions.quoted.count
  end

  def ignored_applications_count
    @insurance_company.application_distributions.ignored.count
  end

  def total_quotes_count
    @insurance_company.quotes.count
  end

  def pending_quotes_count
    @insurance_company.quotes.where(status: ['submitted', 'pending_review']).count
  end

  def approved_quotes_count
    @insurance_company.quotes.approved.count
  end

  def accepted_quotes_count
    @insurance_company.quotes.accepted.count
  end

  def average_response_time
    distributions = @insurance_company.application_distributions.where.not(viewed_at: nil)
    return 0 if distributions.empty?
    
    total_time = distributions.sum { |d| (d.viewed_at - d.created_at).to_i }
    (total_time / distributions.count / 3600.0).round(1) # Convert to hours
  end

  def quote_acceptance_rate
    total = @insurance_company.quotes.where(status: ['approved', 'rejected', 'accepted']).count
    return 0 if total.zero?
    
    accepted = @insurance_company.quotes.accepted.count
    ((accepted.to_f / total) * 100).round(1)
  end

  def weekly_applications_data
    # Last 7 days of application distributions
    (6.days.ago.to_date..Date.current).map do |date|
      {
        date: date.strftime('%a'),
        count: @insurance_company.application_distributions
                                  .where(created_at: date.beginning_of_day..date.end_of_day)
                                  .count
      }
    end
  end

  def insurance_type_breakdown
    @insurance_company.application_distributions
                     .joins(:insurance_application)
                     .group('insurance_applications.insurance_type')
                     .count
                     .transform_keys { |k| InsuranceApplication.insurance_type_display_name(k) }
  end

  def recent_applications
    @insurance_company.application_distributions
                     .includes(insurance_application: [:client, :user])
                     .active
                     .order(created_at: :desc)
                     .limit(10)
  end

  def recent_quotes
    @insurance_company.quotes
                     .includes(insurance_application: [:client])
                     .order(created_at: :desc)
                     .limit(10)
  end

  def expiring_quotes
    @insurance_company.quotes
                     .where(expires_at: Date.current..7.days.from_now)
                     .where(status: ['submitted', 'pending_review', 'approved'])
                     .includes(insurance_application: [:client])
                     .order(:expires_at)
                     .limit(5)
  end

  def monthly_quote_target
    # This could be stored in company preferences or settings
    @insurance_company.monthly_quote_target || 50
  end

  def monthly_quote_progress
    @insurance_company.quotes
                     .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
                     .count
  end
end
