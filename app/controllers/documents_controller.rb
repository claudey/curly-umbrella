class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy, :download, :archive, :restore, :versions, :new_version]
  before_action :authorize_view, only: [:show, :download, :versions]
  before_action :authorize_edit, only: [:edit, :update, :new_version]
  before_action :authorize_delete, only: [:destroy, :archive, :restore]

  def index
    @documents = current_tenant_documents
    @documents = apply_filters(@documents)
    @documents = @documents.includes(:user, :archived_by, file_attachment: :blob)
                            .page(params[:page])
                            .per(20)
    
    @categories = Document::CATEGORIES
    @document_types = Document::DOCUMENT_TYPES
  end

  def archived
    @documents = current_tenant_documents.archived
    @documents = apply_filters(@documents)
    @documents = @documents.includes(:user, :archived_by, file_attachment: :blob)
                            .page(params[:page])
                            .per(20)
    
    render :index
  end

  def expiring
    @documents = current_tenant_documents.expiring_soon(30)
    @documents = apply_filters(@documents)
    @documents = @documents.includes(:user, :archived_by, file_attachment: :blob)
                            .page(params[:page])
                            .per(20)
    
    render :index
  end

  def show
    @version_history = @document.version_history.includes(:user, file_attachment: :blob)
  end

  def new
    @document = Document.new
    set_documentable_from_params
  end

  def create
    @document = Document.new(document_params)
    @document.organization = current_user.organization
    @document.user = current_user
    
    set_documentable_from_params

    if @document.save
      redirect_to @document, notice: 'Document was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document.update(document_params.except(:file))
      # Handle file update separately to create new version if file is changed
      if document_params[:file].present?
        new_document = @document.create_new_version!(
          document_params[:file], 
          current_user,
          document_params.except(:file).to_h
        )
        redirect_to new_document, notice: 'Document was updated with a new version.'
      else
        redirect_to @document, notice: 'Document was successfully updated.'
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @document.destroy
      redirect_to documents_path, notice: 'Document was successfully deleted.'
    else
      redirect_to @document, alert: 'Unable to delete document.'
    end
  end

  def download
    if @document.file_attached?
      redirect_to @document.download_url, allow_other_host: true
    else
      redirect_to @document, alert: 'No file attached to this document.'
    end
  end

  def archive
    reason = params[:reason]
    
    if @document.archive!(current_user, reason)
      redirect_to @document, notice: 'Document was successfully archived.'
    else
      redirect_to @document, alert: 'Unable to archive document.'
    end
  end

  def restore
    if @document.restore!(current_user)
      redirect_to @document, notice: 'Document was successfully restored.'
    else
      redirect_to @document, alert: 'Unable to restore document.'
    end
  end

  def versions
    @version_history = @document.version_history.includes(:user, file_attachment: :blob)
  end

  def new_version
    if params[:file].blank?
      redirect_to @document, alert: 'Please select a file for the new version.'
      return
    end

    new_document = @document.create_new_version!(
      params[:file],
      current_user,
      {
        description: params[:description],
        metadata: params[:metadata] || {}
      }
    )

    if new_document.persisted?
      DocumentNotificationService.notify_new_version_created(new_document)
      redirect_to new_document, notice: 'New version created successfully.'
    else
      redirect_to @document, alert: 'Unable to create new version.'
    end
  end

  def generate_pdf
    case params[:template]
    when 'document_info'
      result = PdfGenerationService.new(
        render_to_string(
          template: 'documents/pdf_templates/document_info',
          layout: 'pdf',
          locals: { document: @document }
        ),
        "document_info_#{@document.id}.pdf"
      ).stream_download
    when 'document_list'
      documents = [@document]
      result = PdfGenerationService.generate_document_list_pdf(documents, "Document: #{@document.name}")
    else
      redirect_to @document, alert: 'Invalid PDF template specified.'
      return
    end

    send_file result[:file_path],
              filename: result[:filename],
              type: result[:content_type],
              disposition: 'attachment'
              
    # Clean up after sending
    Thread.new { sleep(5); result[:cleanup].call }

  rescue PdfGenerationService::PdfGenerationError => e
    redirect_to @document, alert: "PDF generation failed: #{e.message}"
  end

  private

  def set_document
    @document = current_tenant_documents.find(params[:id])
  end

  def current_tenant_documents
    Document.where(organization: current_user.organization)
  end

  def authorize_view
    unless @document.can_be_viewed_by?(current_user)
      redirect_to documents_path, alert: 'You are not authorized to view this document.'
    end
  end

  def authorize_edit
    unless @document.can_be_edited_by?(current_user)
      redirect_to @document, alert: 'You are not authorized to edit this document.'
    end
  end

  def authorize_delete
    unless @document.can_be_deleted_by?(current_user)
      redirect_to @document, alert: 'You are not authorized to perform this action on this document.'
    end
  end

  def set_documentable_from_params
    if params[:documentable_type] && params[:documentable_id]
      documentable_class = params[:documentable_type].constantize
      @document.documentable = documentable_class.find(params[:documentable_id])
    end
  end

  def apply_filters(documents)
    documents = documents.by_category(params[:category]) if params[:category].present?
    documents = documents.by_type(params[:document_type]) if params[:document_type].present?
    documents = documents.by_tags(params[:tags]) if params[:tags].present?
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      documents = documents.where(
        "name ILIKE ? OR description ILIKE ?", 
        search_term, 
        search_term
      )
    end

    case params[:status]
    when 'archived'
      documents = documents.archived
    when 'expiring'
      documents = documents.expiring_soon
    when 'expired'
      documents = documents.expired
    else
      documents = documents.not_archived unless params[:action] == 'archived'
    end

    # Sort
    case params[:sort]
    when 'name'
      documents = documents.order(:name)
    when 'type'
      documents = documents.order(:document_type)
    when 'size'
      documents = documents.order(:file_size)
    when 'created_at'
      documents = documents.order(created_at: :desc)
    else
      documents = documents.recent
    end

    documents
  end

  def document_params
    params.require(:document).permit(
      :name, :description, :document_type, :category, :access_level, 
      :is_public, :expires_at, :file, :documentable_type, :documentable_id,
      tags: [], metadata: {}
    )
  end
end