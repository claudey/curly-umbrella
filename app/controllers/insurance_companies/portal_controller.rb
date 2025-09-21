class InsuranceCompanies::PortalController < ApplicationController
  layout "insurance_company_portal"

  before_action :authenticate_user!
  before_action :ensure_insurance_company_user
  before_action :set_insurance_company
  before_action :set_application, only: [ :show_application ]
  before_action :set_quote, only: [ :show_quote, :update_quote ]

  def dashboard
    @stats = {
      pending_applications: pending_applications.count,
      submitted_quotes: current_company_quotes.pending.count,
      accepted_quotes: current_company_quotes.accepted.count,
      total_premium_quoted: current_company_quotes.sum(:premium_amount)
    }

    @recent_applications = pending_applications.limit(5)
    @recent_quotes = current_company_quotes.recent.limit(5)
    @expiring_quotes = current_company_quotes.expiring_soon.limit(3)

    # Analytics data for charts
    prepare_analytics_data
  end

  def applications
    @applications = pending_applications
                   .includes(:client, :organization)
                   .page(params[:page])
                   .per(20)

    # Apply filters
    @applications = @applications.where("client_name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @applications = @applications.where(coverage_type: params[:coverage_type]) if params[:coverage_type].present?
  end

  def show_application
    @existing_quote = current_company_quotes.find_by(motor_application: @application)
  end

  def quotes
    @quotes = current_company_quotes
              .includes(:motor_application, :organization)
              .recent
              .page(params[:page])
              .per(20)

    # Apply filters
    @quotes = @quotes.where(status: params[:status]) if params[:status].present?
  end

  def new_quote
    @application = MotorApplication.find(params[:application_id])

    # Check if quote already exists for this application
    existing_quote = current_company_quotes.find_by(motor_application: @application)
    if existing_quote
      redirect_to insurance_companies_quote_path(existing_quote),
                  notice: "You already have a quote for this application."
      return
    end

    @quote = Quote.new(
      motor_application: @application,
      insurance_company: @insurance_company,
      commission_rate: @insurance_company.commission_rate,
      validity_period: 30
    )
  end

  def create_quote
    @application = MotorApplication.find(params[:motor_application_id])
    @quote = Quote.new(quote_params)
    @quote.motor_application = @application
    @quote.insurance_company = @insurance_company
    @quote.organization = @application.organization
    @quote.quoted_by = current_user

    if @quote.save
      # Automatically submit the quote
      @quote.submit!

      redirect_to insurance_companies_quote_path(@quote),
                  notice: "Quote submitted successfully."
    else
      render :new_quote, status: :unprocessable_entity
    end
  end

  def show_quote
    @application = @quote.motor_application
  end

  def update_quote
    if @quote.update(quote_params)
      redirect_to insurance_companies_quote_path(@quote),
                  notice: "Quote updated successfully."
    else
      render :show_quote, status: :unprocessable_entity
    end
  end

  private

  def prepare_analytics_data
    # Quote volume trend (last 30 days)
    @quote_volume_data = current_company_quotes
      .where(created_at: 30.days.ago..Time.current)
      .group_by_day(:created_at)
      .sum(:premium_amount)
      .map { |date, amount| { date: date.strftime("%Y-%m-%d"), value: amount.to_f } }

    # Quote status distribution
    @quote_status_data = current_company_quotes
      .group(:status)
      .count
      .map { |status, count| { label: status.humanize, value: count.to_f } }

    # Coverage type breakdown
    @coverage_type_data = current_company_quotes
      .joins(:motor_application)
      .group("motor_applications.coverage_type")
      .count
      .map { |type, count| { label: type&.humanize || "Unknown", value: count.to_f } }

    # Monthly premium comparison (last 6 months)
    @monthly_premium_data = current_company_quotes
      .where(created_at: 6.months.ago..Time.current)
      .group_by_month(:created_at)
      .sum(:premium_amount)
      .map { |month, amount| { label: month.strftime("%b %Y"), value: amount.to_f } }

    # Quote acceptance rate trend (last 12 weeks)
    @acceptance_rate_data = []
    12.times do |i|
      week_start = (11 - i).weeks.ago.beginning_of_week
      week_end = week_start.end_of_week

      total_quotes = current_company_quotes.where(created_at: week_start..week_end).count
      accepted_quotes = current_company_quotes.where(created_at: week_start..week_end, status: "accepted").count

      rate = total_quotes > 0 ? (accepted_quotes.to_f / total_quotes * 100) : 0

      @acceptance_rate_data << {
        date: week_start.strftime("%Y-%m-%d"),
        value: rate.round(1)
      }
    end
  end

  def ensure_insurance_company_user
    unless current_user.insurance_company?
      redirect_to root_path, alert: "Access denied. Insurance company users only."
    end
  end

  def set_insurance_company
    @insurance_company = current_user.organization_id ?
                        InsuranceCompany.find_by(id: current_user.organization_id) :
                        InsuranceCompany.find_by(email: current_user.email)

    unless @insurance_company
      redirect_to root_path, alert: "Insurance company profile not found."
    end
  end

  def pending_applications
    # Get applications that are submitted/under_review and don't have quotes from this company yet
    MotorApplication.joins("LEFT JOIN quotes ON quotes.motor_application_id = motor_applications.id
                           AND quotes.insurance_company_id = #{@insurance_company.id}")
                   .where(status: [ "submitted", "under_review" ])
                   .where(quotes: { id: nil })
                   .distinct
  end

  def current_company_quotes
    @insurance_company.quotes.includes(:motor_application, :organization, :quoted_by)
  end

  def set_application
    @application = MotorApplication.find(params[:id])
  end

  def set_quote
    @quote = current_company_quotes.find(params[:id])
  end

  def quote_params
    params.require(:quote).permit(
      :premium_amount,
      :coverage_amount,
      :commission_rate,
      :validity_period,
      :terms_conditions,
      :notes,
      coverage_details: {}
    )
  end
end
