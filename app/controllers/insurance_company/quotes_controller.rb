class InsuranceCompany::QuotesController < ApplicationController
  include AuthorizationController

  before_action :ensure_insurance_company_user
  before_action :set_insurance_company
  before_action :set_quote, only: [ :show, :edit, :update, :submit, :withdraw ]
  before_action :set_application, only: [ :new, :create ]

  def index
    @filter_params = filter_params
    @quotes = load_quotes
    @summary_stats = calculate_summary_stats
  end

  def show
    @application = @quote.insurance_application
    @client = @application.client
  end

  def new
    @quote = @insurance_company.quotes.build(insurance_application: @application)
    @quote.quoted_by = current_user

    # Set default values based on application
    set_quote_defaults
  end

  def create
    @quote = @insurance_company.quotes.build(quote_params)
    @quote.insurance_application = @application
    @quote.quoted_by = current_user
    @quote.organization = @application.organization

    if @quote.save
      # Mark distribution as quoted
      distribution = @insurance_company.application_distributions
                                      .find_by(insurance_application: @application)
      distribution&.mark_as_quoted!

      # Send notification to brokerage
      NotificationService.new_quote_submitted(@quote)

      redirect_to insurance_company_quote_path(@quote),
                  notice: "Quote submitted successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @application = @quote.insurance_application
    @client = @application.client
  end

  def update
    if @quote.update(quote_params)
      redirect_to insurance_company_quote_path(@quote),
                  notice: "Quote updated successfully"
    else
      @application = @quote.insurance_application
      @client = @application.client
      render :edit, status: :unprocessable_entity
    end
  end

  def submit
    if @quote.submit!
      redirect_to insurance_company_quote_path(@quote),
                  notice: "Quote submitted for review"
    else
      redirect_to insurance_company_quote_path(@quote),
                  alert: "Unable to submit quote"
    end
  end

  def withdraw
    if @quote.withdraw!
      redirect_to insurance_company_quotes_path,
                  notice: "Quote withdrawn successfully"
    else
      redirect_to insurance_company_quote_path(@quote),
                  alert: "Unable to withdraw quote"
    end
  end

  private

  def ensure_insurance_company_user
    unless current_user.insurance_company_id.present?
      redirect_to root_path, alert: "Access denied. Insurance company access required."
    end
  end

  def set_insurance_company
    @insurance_company = current_user.insurance_company
  end

  def set_quote
    @quote = @insurance_company.quotes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to insurance_company_quotes_path, alert: "Quote not found"
  end

  def set_application
    @application = InsuranceApplication.find(params[:application_id])

    # Verify this insurance company has access to this application
    unless @insurance_company.application_distributions
                             .exists?(insurance_application: @application)
      redirect_to insurance_company_applications_path,
                  alert: "Application not found or access denied"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to insurance_company_applications_path, alert: "Application not found"
  end

  def quote_params
    params.require(:quote).permit(
      :premium_amount, :coverage_amount, :commission_rate, :validity_period,
      :notes, :terms_conditions, coverage_details: {},
      coverage_limits: {}, deductibles: {}, exclusions: []
    )
  end

  def filter_params
    params.permit(:status, :insurance_type, :sort, :search, :date_range)
  end

  def load_quotes
    quotes = @insurance_company.quotes.includes(insurance_application: [ :client ])

    # Apply filters
    quotes = apply_status_filter(quotes)
    quotes = apply_insurance_type_filter(quotes)
    quotes = apply_search_filter(quotes)
    quotes = apply_date_filter(quotes)
    quotes = apply_sorting(quotes)

    quotes.limit(50)
  end

  def apply_status_filter(quotes)
    return quotes unless @filter_params[:status].present?

    case @filter_params[:status]
    when "draft"
      quotes.where(status: "draft")
    when "submitted"
      quotes.where(status: "submitted")
    when "approved"
      quotes.approved
    when "accepted"
      quotes.accepted
    when "rejected"
      quotes.rejected
    when "expired"
      quotes.expired
    else
      quotes
    end
  end

  def apply_insurance_type_filter(quotes)
    return quotes unless @filter_params[:insurance_type].present?

    quotes.joins(:insurance_application)
          .where(insurance_applications: { insurance_type: @filter_params[:insurance_type] })
  end

  def apply_search_filter(quotes)
    return quotes unless @filter_params[:search].present?

    search_term = "%#{@filter_params[:search]}%"
    quotes.joins(insurance_application: :client)
          .where(
            "clients.first_name ILIKE ? OR clients.last_name ILIKE ? OR quotes.quote_number ILIKE ?",
            search_term, search_term, search_term
          )
  end

  def apply_date_filter(quotes)
    return quotes unless @filter_params[:date_range].present?

    case @filter_params[:date_range]
    when "today"
      quotes.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
    when "week"
      quotes.where(created_at: 1.week.ago..Time.current)
    when "month"
      quotes.where(created_at: 1.month.ago..Time.current)
    else
      quotes
    end
  end

  def apply_sorting(quotes)
    case @filter_params[:sort]
    when "premium_desc"
      quotes.order(premium_amount: :desc)
    when "premium_asc"
      quotes.order(premium_amount: :asc)
    when "created_desc"
      quotes.order(created_at: :desc)
    when "created_asc"
      quotes.order(created_at: :asc)
    when "expires_soon"
      quotes.order(:expires_at)
    else
      quotes.order(created_at: :desc)
    end
  end

  def calculate_summary_stats
    all_quotes = @insurance_company.quotes

    {
      total: all_quotes.count,
      draft: all_quotes.where(status: "draft").count,
      submitted: all_quotes.where(status: "submitted").count,
      approved: all_quotes.approved.count,
      accepted: all_quotes.accepted.count,
      rejected: all_quotes.rejected.count,
      expired: all_quotes.expired.count,
      total_premium: all_quotes.accepted.sum(:premium_amount) || 0,
      avg_premium: all_quotes.where.not(premium_amount: nil).average(:premium_amount) || 0
    }
  end

  def set_quote_defaults
    case @application.insurance_type
    when "motor"
      set_motor_quote_defaults
    when "fire"
      set_fire_quote_defaults
    when "liability"
      set_liability_quote_defaults
    when "general_accident"
      set_general_accident_quote_defaults
    when "bonds"
      set_bonds_quote_defaults
    end
  end

  def set_motor_quote_defaults
    @quote.coverage_details = {
      "comprehensive" => true,
      "third_party" => true,
      "fire_theft" => true,
      "personal_accident" => false
    }
    @quote.deductibles = {
      "comprehensive" => 5000,
      "fire_theft" => 2500
    }
    @quote.validity_period = 30
  end

  def set_fire_quote_defaults
    @quote.coverage_details = {
      "fire_damage" => true,
      "lightning" => true,
      "explosion" => true,
      "earthquake" => false,
      "flood" => false
    }
    @quote.validity_period = 45
  end

  def set_liability_quote_defaults
    @quote.coverage_details = {
      "public_liability" => true,
      "product_liability" => false,
      "professional_indemnity" => false,
      "employers_liability" => false
    }
    @quote.validity_period = 30
  end

  def set_general_accident_quote_defaults
    @quote.coverage_details = {
      "personal_accident" => true,
      "medical_expenses" => true,
      "disability_benefit" => true,
      "death_benefit" => true
    }
    @quote.validity_period = 30
  end

  def set_bonds_quote_defaults
    @quote.coverage_details = {
      "performance_bond" => true,
      "payment_bond" => false,
      "bid_bond" => false,
      "maintenance_bond" => false
    }
    @quote.validity_period = 60
  end
end
