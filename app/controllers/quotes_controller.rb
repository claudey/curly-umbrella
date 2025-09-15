class QuotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_quote, only: [:show, :edit, :update, :destroy, :submit, :approve, :reject, :accept, :withdraw, :print]

  def index
    @quotes = current_user.organization.quotes
                         .includes(:motor_application, :insurance_company, :quoted_by)
                         .recent

    # Apply filters
    @quotes = @quotes.where(status: params[:status]) if params[:status].present?
    @quotes = @quotes.where(insurance_company_id: params[:insurance_company_id]) if params[:insurance_company_id].present?
    
    @insurance_companies = current_user.organization.quotes
                                      .joins(:insurance_company)
                                      .distinct
                                      .pluck(:insurance_company_id, 'insurance_companies.name')
                                      .map { |id, name| [name, id] }
  end

  def show
    @motor_application = @quote.motor_application
    @insurance_company = @quote.insurance_company
  end

  def new
    @motor_application = current_user.organization.motor_applications.find(params[:motor_application_id]) if params[:motor_application_id]
    @quote = Quote.new(motor_application: @motor_application)
    @insurance_companies = InsuranceCompany.approved.active
  end

  def create
    @quote = current_user.organization.quotes.build(quote_params)
    @quote.quoted_by = current_user

    if @quote.save
      redirect_to @quote, notice: 'Quote was successfully created.'
    else
      @motor_application = @quote.motor_application
      @insurance_companies = InsuranceCompany.approved.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @insurance_companies = InsuranceCompany.approved.active
  end

  def update
    if @quote.update(quote_params)
      redirect_to @quote, notice: 'Quote was successfully updated.'
    else
      @insurance_companies = InsuranceCompany.approved.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quote.discard
    redirect_to quotes_url, notice: 'Quote was successfully deleted.'
  end

  # Status actions
  def submit
    if @quote.submit!
      redirect_to @quote, notice: 'Quote submitted successfully.'
    else
      redirect_to @quote, alert: 'Unable to submit quote.'
    end
  end

  def approve
    if @quote.approve!
      redirect_to @quote, notice: 'Quote approved successfully.'
    else
      redirect_to @quote, alert: 'Unable to approve quote.'
    end
  end

  def reject
    reason = params[:reason]
    if @quote.reject!(reason)
      redirect_to @quote, notice: 'Quote rejected.'
    else
      redirect_to @quote, alert: 'Unable to reject quote.'
    end
  end

  def accept
    if @quote.accept!
      redirect_to @quote, notice: 'Quote accepted successfully!'
    else
      redirect_to @quote, alert: 'Unable to accept quote.'
    end
  end

  def withdraw
    if @quote.withdraw!
      redirect_to @quote, notice: 'Quote withdrawn.'
    else
      redirect_to @quote, alert: 'Unable to withdraw quote.'
    end
  end

  # Collection actions
  def pending
    @quotes = current_user.organization.quotes
                         .pending
                         .includes(:motor_application, :insurance_company, :quoted_by)
                         .recent
  end

  def expiring_soon
    @quotes = current_user.organization.quotes
                         .expiring_soon
                         .includes(:motor_application, :insurance_company, :quoted_by)
                         .recent
  end

  def compare
    @motor_application = current_user.organization.motor_applications.find(params[:motor_application_id])
    @quotes = @motor_application.quotes_for_comparison
    
    if @quotes.empty?
      redirect_to motor_application_path(@motor_application), 
                  alert: 'No approved quotes available for comparison.'
    end
  end

  def print
    render layout: 'print'
  end

  private

  def set_quote
    @quote = current_user.organization.quotes.find(params[:id])
  end

  def quote_params
    params.require(:quote).permit(
      :motor_application_id,
      :insurance_company_id,
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
