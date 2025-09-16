# frozen_string_literal: true

class Api::V1::QuotesController < Api::V1::BaseController
  before_action :set_quote, only: [:show, :update, :accept, :generate_pdf]
  before_action :track_usage
  
  # GET /api/v1/quotes
  def index
    authorize_api_action!('read_quote')
    
    quotes = current_organization.quotes.includes(:insurance_company, :insurance_application)
    
    # Apply filters
    quotes = filter_quotes(quotes)
    
    # Order by most recent
    quotes = quotes.order(created_at: :desc)
    
    # Paginate results
    result = paginate_collection(quotes)
    
    render_success({
      quotes: serialize_quotes(result[:data]),
      pagination: result[:pagination],
      filters_applied: applied_filters
    })
  end
  
  # GET /api/v1/quotes/:id
  def show
    authorize_api_action!('read_quote', @quote)
    
    render_success({
      quote: serialize_quote(@quote, with_details: true)
    })
  end
  
  # POST /api/v1/quotes
  def create
    authorize_api_action!('create_quote')
    
    # Verify application and insurance company belong to organization
    application = current_organization.insurance_applications.find(quote_params[:application_id])
    insurance_company = current_organization.insurance_companies.find(quote_params[:insurance_company_id])
    
    @quote = current_organization.quotes.build(
      quote_params.merge(
        insurance_application: application,
        insurance_company: insurance_company,
        client: application.client,
        user: current_api_user,
        status: 'draft',
        quote_date: Date.current,
        source: 'api'
      )
    )
    
    # Set defaults
    @quote.base_premium ||= @quote.total_premium
    @quote.valid_until ||= 30.days.from_now.to_date
    @quote.taxes ||= 0
    @quote.fees ||= 0
    @quote.discounts ||= 0
    
    if @quote.save
      # Generate quote number if not set
      @quote.update(quote_number: "Q#{@quote.id.to_s.rjust(6, '0')}") unless @quote.quote_number
      
      log_quote_creation
      
      render_success(
        { quote: serialize_quote(@quote, with_details: true) },
        status: :created
      )
    else
      render_error(
        'Quote creation failed',
        details: @quote.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # PUT/PATCH /api/v1/quotes/:id
  def update
    authorize_api_action!('update_quote', @quote)
    
    # Prevent updates to accepted quotes unless admin
    if @quote.status == 'accepted' && !current_api_key.has_scope?('admin:access')
      return render_error(
        'Cannot update accepted quote',
        details: { current_status: @quote.status },
        status: :forbidden
      )
    end
    
    if @quote.update(update_quote_params)
      log_quote_update
      render_success({
        quote: serialize_quote(@quote, with_details: true)
      })
    else
      render_error(
        'Quote update failed',
        details: @quote.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # POST /api/v1/quotes/:id/accept
  def accept
    authorize_api_action!('update_quote', @quote)
    
    unless @quote.status == 'pending'
      return render_error(
        'Quote can only be accepted from pending status',
        details: { current_status: @quote.status },
        status: :bad_request
      )
    end
    
    # Check if quote is still valid
    if @quote.valid_until && @quote.valid_until < Date.current
      return render_error(
        'Quote has expired and cannot be accepted',
        details: { expired_on: @quote.valid_until },
        status: :bad_request
      )
    end
    
    if @quote.update(status: 'accepted', accepted_at: Time.current)
      # Trigger policy creation workflow
      PolicyCreationJob.perform_later(@quote) if defined?(PolicyCreationJob)
      
      log_quote_acceptance
      
      render_success({
        message: 'Quote accepted successfully',
        quote: serialize_quote(@quote),
        next_steps: [
          'Policy creation process has been initiated',
          'Payment arrangements will be processed',
          'Policy documents will be generated'
        ]
      })
    else
      render_error(
        'Failed to accept quote',
        details: @quote.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # POST /api/v1/quotes/:id/generate_pdf
  def generate_pdf
    authorize_api_action!('read_quote', @quote)
    
    # Generate PDF using quote service
    begin
      pdf_service = QuotePdfGenerationService.new(@quote)
      pdf_result = pdf_service.generate
      
      if pdf_result[:success]
        render_success({
          message: 'PDF generated successfully',
          download_url: "/api/v1/quotes/#{@quote.id}/download_pdf",
          expires_at: 24.hours.from_now.iso8601,
          file_size: pdf_result[:file_size]
        })
      else
        render_error(
          'Failed to generate PDF',
          details: pdf_result[:error],
          status: :internal_server_error
        )
      end
    rescue => e
      Rails.logger.error "PDF generation failed: #{e.message}"
      render_error(
        'PDF generation service unavailable',
        status: :service_unavailable
      )
    end
  end
  
  private
  
  def set_quote
    @quote = current_organization.quotes.find(params[:id])
  end
  
  def track_usage
    track_api_usage('quotes', action_name)
  end
  
  def quote_params
    params.require(:quote).permit(
      :application_id, :insurance_company_id, :total_premium, :coverage_amount,
      :base_premium, :taxes, :fees, :discounts, :deductible, :coverage_type,
      :valid_until, :quote_notes
    )
  end
  
  def update_quote_params
    params.require(:quote).permit(
      :total_premium, :coverage_amount, :base_premium, :taxes, :fees,
      :discounts, :deductible, :coverage_type, :valid_until, :quote_notes, :status
    )
  end
  
  def filter_quotes(quotes)
    quotes = quotes.where(status: params[:status]) if params[:status]
    quotes = quotes.where(insurance_application_id: params[:application_id]) if params[:application_id]
    quotes = quotes.where(insurance_company_id: params[:insurance_company_id]) if params[:insurance_company_id]
    quotes = quotes.where('created_at >= ?', params[:created_after]) if params[:created_after]
    quotes = quotes.where('created_at <= ?', params[:created_before]) if params[:created_before]
    quotes
  end
  
  def applied_filters
    {
      status: params[:status],
      application_id: params[:application_id],
      insurance_company_id: params[:insurance_company_id],
      date_range: {
        from: params[:created_after],
        to: params[:created_before]
      }
    }
  end
  
  def serialize_quotes(quotes)
    quotes.map { |quote| serialize_quote(quote) }
  end
  
  def serialize_quote(quote, with_details: false)
    base_data = {
      id: quote.id,
      quote_number: quote.quote_number,
      status: quote.status,
      total_premium: quote.total_premium,
      coverage_amount: quote.coverage_amount,
      quote_date: quote.quote_date,
      valid_until: quote.valid_until,
      created_at: quote.created_at,
      insurance_company: {
        id: quote.insurance_company.id,
        name: quote.insurance_company.name,
        code: quote.insurance_company.code
      },
      financial_details: {
        base_premium: quote.base_premium,
        taxes: quote.taxes,
        fees: quote.fees,
        discounts: quote.discounts,
        total_premium: quote.total_premium,
        currency: 'USD'
      },
      coverage_details: {
        coverage_type: quote.coverage_type,
        coverage_amount: quote.coverage_amount,
        deductible: quote.deductible,
        policy_term: quote.policy_term || '12 months'
      },
      validity_info: {
        valid_until: quote.valid_until,
        days_remaining: quote.valid_until ? (quote.valid_until - Date.current).to_i : nil,
        is_expired: quote.valid_until ? quote.valid_until < Date.current : false
      }
    }
    
    if with_details
      base_data.merge!(
        quote_notes: quote.quote_notes,
        application: {
          id: quote.insurance_application.id,
          reference_number: quote.insurance_application.reference_number,
          application_type: quote.insurance_application.application_type
        },
        client: {
          id: quote.client.id,
          full_name: quote.client.full_name,
          email: quote.client.email
        }
      )
    end
    
    base_data
  end
  
  def log_quote_creation
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'quote_created_via_api',
      category: 'quote_management',
      resource_type: 'Quote',
      resource_id: @quote.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        application_id: @quote.insurance_application_id,
        insurance_company_id: @quote.insurance_company_id,
        quote_number: @quote.quote_number,
        total_premium: @quote.total_premium
      }
    )
  end
  
  def log_quote_update
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'quote_updated_via_api',
      category: 'quote_management',
      resource_type: 'Quote',
      resource_id: @quote.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        updated_fields: update_quote_params.keys
      }
    )
  end
  
  def log_quote_acceptance
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'quote_accepted_via_api',
      category: 'quote_workflow',
      resource_type: 'Quote',
      resource_id: @quote.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        accepted_at: @quote.accepted_at,
        quote_number: @quote.quote_number,
        total_premium: @quote.total_premium
      }
    )
  end
end