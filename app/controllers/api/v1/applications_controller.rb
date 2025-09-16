# frozen_string_literal: true

class Api::V1::ApplicationsController < Api::V1::BaseController
  before_action :set_application, only: [:show, :update, :submit, :documents, :quotes]
  before_action :track_usage
  
  # GET /api/v1/applications
  def index
    authorize_api_action!('read_application')
    
    applications = current_organization.insurance_applications.includes(:client, :user)
    
    # Apply filters
    applications = filter_applications(applications)
    
    # Order by most recent
    applications = applications.order(created_at: :desc)
    
    # Paginate results
    result = paginate_collection(applications)
    
    render_success({
      applications: serialize_applications(result[:data]),
      pagination: result[:pagination],
      filters_applied: applied_filters
    })
  end
  
  # GET /api/v1/applications/:id
  def show
    authorize_api_action!('read_application', @application)
    
    render_success({
      application: serialize_application(@application, with_details: true)
    })
  end
  
  # POST /api/v1/applications
  def create
    authorize_api_action!('create_application')
    
    # Verify client belongs to organization
    client = current_organization.clients.find(application_params[:client_id])
    
    @application = current_organization.insurance_applications.build(
      application_params.merge(
        user: current_api_user,
        status: 'draft',
        source: 'api'
      )
    )
    
    if @application.save
      log_application_creation
      render_success(
        { application: serialize_application(@application, with_details: true) },
        status: :created
      )
    else
      render_error(
        'Application creation failed',
        details: @application.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # PUT/PATCH /api/v1/applications/:id
  def update
    authorize_api_action!('update_application', @application)
    
    # Prevent updates to submitted/approved applications unless admin
    if @application.status.in?(%w[submitted approved]) && !current_api_key.has_scope?('admin:access')
      return render_error(
        'Cannot update application in current status',
        details: { current_status: @application.status },
        status: :forbidden
      )
    end
    
    if @application.update(update_application_params)
      log_application_update
      render_success({
        application: serialize_application(@application, with_details: true)
      })
    else
      render_error(
        'Application update failed',
        details: @application.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # POST /api/v1/applications/:id/submit
  def submit
    authorize_api_action!('update_application', @application)
    
    unless @application.status == 'draft'
      return render_error(
        'Application can only be submitted from draft status',
        details: { current_status: @application.status },
        status: :bad_request
      )
    end
    
    if @application.update(status: 'submitted', submitted_at: Time.current)
      # Trigger submission workflows
      ApplicationSubmissionJob.perform_later(@application) if defined?(ApplicationSubmissionJob)
      
      log_application_submission
      
      render_success({
        message: 'Application submitted successfully',
        application: serialize_application(@application),
        next_steps: [
          'Application will be reviewed by underwriters',
          'You will receive notifications about status updates',
          'Additional documentation may be requested'
        ]
      })
    else
      render_error(
        'Failed to submit application',
        details: @application.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end
  
  # GET /api/v1/applications/:id/documents
  def documents
    authorize_api_action!('read_document')
    
    documents = @application.documents.includes(:user)
    
    render_success({
      application_id: @application.id,
      reference_number: @application.reference_number,
      documents: serialize_documents(documents)
    })
  end
  
  # GET /api/v1/applications/:id/quotes
  def quotes
    authorize_api_action!('read_quote')
    
    quotes = @application.quotes.includes(:insurance_company)
    
    render_success({
      application_id: @application.id,
      reference_number: @application.reference_number,
      quotes: serialize_quotes(quotes)
    })
  end
  
  private
  
  def set_application
    @application = current_organization.insurance_applications.find(params[:id])
  end
  
  def track_usage
    track_api_usage('applications', action_name)
  end
  
  def application_params
    params.require(:application).permit(
      :application_type, :client_id, :effective_date, :expiry_date,
      :sum_insured, :premium_amount, :broker_notes, application_data: {}
    )
  end
  
  def update_application_params
    params.require(:application).permit(
      :effective_date, :expiry_date, :sum_insured, :premium_amount,
      :broker_notes, :status, application_data: {}
    )
  end
  
  def filter_applications(applications)
    applications = applications.where(status: params[:status]) if params[:status]
    applications = applications.where(application_type: params[:application_type]) if params[:application_type]
    applications = applications.where('created_at >= ?', params[:created_after]) if params[:created_after]
    applications = applications.where('created_at <= ?', params[:created_before]) if params[:created_before]
    
    if params[:search]
      search_term = "%#{params[:search]}%"
      applications = applications.joins(:client)
                               .where('clients.full_name ILIKE ? OR insurance_applications.reference_number ILIKE ?', 
                                     search_term, search_term)
    end
    
    applications
  end
  
  def applied_filters
    {
      status: params[:status],
      application_type: params[:application_type],
      search: params[:search],
      date_range: {
        from: params[:created_after],
        to: params[:created_before]
      }
    }
  end
  
  def serialize_applications(applications)
    applications.map { |app| serialize_application(app) }
  end
  
  def serialize_application(application, with_details: false)
    base_data = {
      id: application.id,
      reference_number: application.reference_number,
      application_type: application.application_type,
      status: application.status,
      effective_date: application.effective_date,
      expiry_date: application.expiry_date,
      sum_insured: application.sum_insured,
      premium_amount: application.premium_amount,
      broker_notes: application.broker_notes,
      created_at: application.created_at,
      updated_at: application.updated_at,
      submitted_at: application.submitted_at,
      client: serialize_client(application.client),
      created_by: {
        id: application.user.id,
        name: application.user.full_name,
        email: application.user.email
      },
      documents_count: application.documents.count,
      quotes_count: application.quotes.count,
      status_info: {
        status: application.status,
        status_label: application.status.humanize,
        can_edit: application.status.in?(%w[draft]),
        can_submit: application.status == 'draft',
        workflow_stage: application.workflow_stage || 'initial'
      },
      financial_summary: {
        sum_insured: application.sum_insured,
        premium_amount: application.premium_amount,
        currency: 'USD',
        payment_frequency: application.payment_frequency || 'annual'
      },
      api_metadata: {
        created_via_api: application.source == 'api',
        last_api_update: application.updated_at,
        version: 'v1'
      }
    }
    
    if with_details
      base_data.merge!(
        application_data: application.application_data,
        documents: serialize_documents(application.documents),
        quotes: serialize_quotes(application.quotes)
      )
    end
    
    base_data
  end
  
  def serialize_client(client)
    {
      id: client.id,
      full_name: client.full_name,
      email: client.email,
      phone: client.phone,
      client_type: client.client_type,
      created_at: client.created_at,
      address: {
        street: client.street_address,
        city: client.city,
        state: client.state,
        postal_code: client.postal_code,
        country: client.country
      }
    }
  end
  
  def serialize_documents(documents)
    documents.map do |doc|
      {
        id: doc.id,
        filename: doc.filename,
        document_type: doc.document_type,
        file_size: doc.file_size,
        content_type: doc.content_type,
        status: doc.status,
        created_at: doc.created_at,
        download_url: "/api/v1/documents/#{doc.id}/download"
      }
    end
  end
  
  def serialize_quotes(quotes)
    quotes.map do |quote|
      {
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
        }
      }
    end
  end
  
  def log_application_creation
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'application_created_via_api',
      category: 'application_management',
      resource_type: 'InsuranceApplication',
      resource_id: @application.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        application_type: @application.application_type,
        client_id: @application.client_id,
        reference_number: @application.reference_number
      }
    )
  end
  
  def log_application_update
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'application_updated_via_api',
      category: 'application_management',
      resource_type: 'InsuranceApplication',
      resource_id: @application.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        updated_fields: update_application_params.keys
      }
    )
  end
  
  def log_application_submission
    AuditLog.create!(
      user: current_api_user,
      organization: current_organization,
      action: 'application_submitted_via_api',
      category: 'application_workflow',
      resource_type: 'InsuranceApplication',
      resource_id: @application.id,
      severity: 'info',
      details: {
        api_key_id: current_api_key.id,
        submitted_at: @application.submitted_at,
        reference_number: @application.reference_number
      }
    )
  end
end