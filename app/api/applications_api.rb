# frozen_string_literal: true

class ApplicationsApi < Grape::API
  version "v1", using: :header, vendor: "brokersync"
  format :json

  helpers BrokersyncApi::Helpers if defined?(BrokersyncApi::Helpers)

  resource :applications do
    desc "List all insurance applications", {
      summary: "Retrieve paginated list of insurance applications",
      detail: "Returns a paginated list of insurance applications accessible to the API key holder",
      tags: [ "Applications" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      optional :page, type: Integer, default: 1, desc: "Page number"
      optional :per_page, type: Integer, default: 25, desc: "Items per page (max 100)"
      optional :status, type: String, values: %w[draft submitted under_review approved rejected], desc: "Filter by status"
      optional :application_type, type: String, values: %w[motor fire liability general_accident bonds], desc: "Filter by application type"
      optional :created_after, type: DateTime, desc: "Filter applications created after this date"
      optional :created_before, type: DateTime, desc: "Filter applications created before this date"
      optional :search, type: String, desc: "Search in application details"
    end
    get do
      authenticate_api_request!
      authorize_api_action!("read_application")
      track_api_usage("applications", "list")

      # Base query scoped to organization
      applications = current_organization.insurance_applications.includes(:client, :user)

      # Apply filters
      applications = applications.where(status: params[:status]) if params[:status]
      applications = applications.where(application_type: params[:application_type]) if params[:application_type]
      applications = applications.where("created_at >= ?", params[:created_after]) if params[:created_after]
      applications = applications.where("created_at <= ?", params[:created_before]) if params[:created_before]

      # Search functionality
      if params[:search]
        search_term = "%#{params[:search]}%"
        applications = applications.joins(:client)
                                 .where("clients.full_name ILIKE ? OR insurance_applications.reference_number ILIKE ?",
                                       search_term, search_term)
      end

      # Order by most recent
      applications = applications.order(created_at: :desc)

      # Paginate results
      result = paginate(applications, per_page: params[:per_page])

      # Format response
      {
        applications: result[:data].map { |app| ApplicationEntity.represent(app) },
        pagination: result[:pagination],
        filters_applied: {
          status: params[:status],
          application_type: params[:application_type],
          search: params[:search],
          date_range: {
            from: params[:created_after],
            to: params[:created_before]
          }
        }
      }
    end

    desc "Get application by ID", {
      summary: "Retrieve a specific insurance application",
      detail: "Returns detailed information about a specific insurance application",
      tags: [ "Applications" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      requires :id, type: Integer, desc: "Application ID"
    end
    route_param :id do
      get do
        authenticate_api_request!
        authorize_api_action!("read_application")
        track_api_usage("applications", "show")

        application = current_organization.insurance_applications
                                        .includes(:client, :user, :documents, :quotes)
                                        .find(params[:id])

        authorize_api_action!("read_application", application)

        ApplicationEntity.represent(application, with_details: true)
      end
    end

    desc "Create new application", {
      summary: "Create a new insurance application",
      detail: "Creates a new insurance application with the provided details",
      tags: [ "Applications" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      requires :application_type, type: String, values: %w[motor fire liability general_accident bonds], desc: "Type of insurance application"
      requires :client_id, type: Integer, desc: "Client ID"
      optional :effective_date, type: Date, desc: "Effective date for coverage"
      optional :expiry_date, type: Date, desc: "Expiry date for coverage"
      optional :sum_insured, type: Float, desc: "Sum insured amount"
      optional :premium_amount, type: Float, desc: "Premium amount"
      optional :broker_notes, type: String, desc: "Broker notes"
      optional :application_data, type: Hash, desc: "Application-specific data fields"
    end
    post do
      authenticate_api_request!
      authorize_api_action!("create_application")
      track_api_usage("applications", "create")

      # Verify client belongs to organization
      client = current_organization.clients.find(params[:client_id])

      application = current_organization.insurance_applications.build(
        application_type: params[:application_type],
        client: client,
        user: current_api_user,
        effective_date: params[:effective_date],
        expiry_date: params[:expiry_date],
        sum_insured: params[:sum_insured],
        premium_amount: params[:premium_amount],
        broker_notes: params[:broker_notes],
        application_data: params[:application_data] || {},
        status: "draft",
        source: "api"
      )

      if application.save
        # Log creation
        AuditLog.create!(
          user: current_api_user,
          organization: current_organization,
          action: "application_created_via_api",
          category: "application_management",
          resource_type: "InsuranceApplication",
          resource_id: application.id,
          severity: "info",
          details: {
            api_key_id: current_api_key.id,
            application_type: application.application_type,
            client_id: client.id,
            reference_number: application.reference_number
          }
        )

        status 201
        ApplicationEntity.represent(application, with_details: true)
      else
        error!({
          error: "validation_error",
          message: "Application creation failed",
          details: application.errors.as_json
        }, 422)
      end
    end

    desc "Update application", {
      summary: "Update an existing insurance application",
      detail: "Updates an existing insurance application with the provided details",
      tags: [ "Applications" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      requires :id, type: Integer, desc: "Application ID"
      optional :effective_date, type: Date, desc: "Effective date for coverage"
      optional :expiry_date, type: Date, desc: "Expiry date for coverage"
      optional :sum_insured, type: Float, desc: "Sum insured amount"
      optional :premium_amount, type: Float, desc: "Premium amount"
      optional :broker_notes, type: String, desc: "Broker notes"
      optional :application_data, type: Hash, desc: "Application-specific data fields"
      optional :status, type: String, values: %w[draft submitted under_review approved rejected], desc: "Application status"
    end
    route_param :id do
      put do
        authenticate_api_request!
        authorize_api_action!("update_application")
        track_api_usage("applications", "update")

        application = current_organization.insurance_applications.find(params[:id])
        authorize_api_action!("update_application", application)

        # Prevent updates to submitted/approved applications unless admin
        if application.status.in?(%w[submitted approved]) && !current_api_key.has_scope?("admin:access")
          error!({
            error: "authorization_error",
            message: "Cannot update application in current status",
            current_status: application.status
          }, 403)
        end

        update_params = params.except(:id)

        if application.update(update_params)
          # Log update
          AuditLog.create!(
            user: current_api_user,
            organization: current_organization,
            action: "application_updated_via_api",
            category: "application_management",
            resource_type: "InsuranceApplication",
            resource_id: application.id,
            severity: "info",
            details: {
              api_key_id: current_api_key.id,
              updated_fields: update_params.keys,
              old_status: application.status_before_last_save,
              new_status: application.status
            }
          )

          ApplicationEntity.represent(application, with_details: true)
        else
          error!({
            error: "validation_error",
            message: "Application update failed",
            details: application.errors.as_json
          }, 422)
        end
      end
    end

    desc "Submit application for review", {
      summary: "Submit application for underwriting review",
      detail: "Changes application status to submitted and triggers review workflow",
      tags: [ "Applications" ],
      security: [ { bearer_token: [] } ]
    }
    route_param :id do
      post :submit do
        authenticate_api_request!
        authorize_api_action!("update_application")
        track_api_usage("applications", "submit")

        application = current_organization.insurance_applications.find(params[:id])
        authorize_api_action!("update_application", application)

        if application.status != "draft"
          error!({
            error: "invalid_status",
            message: "Application can only be submitted from draft status",
            current_status: application.status
          }, 400)
        end

        if application.update(status: "submitted", submitted_at: Time.current)
          # Trigger submission workflows
          ApplicationSubmissionJob.perform_later(application)

          # Log submission
          AuditLog.create!(
            user: current_api_user,
            organization: current_organization,
            action: "application_submitted_via_api",
            category: "application_workflow",
            resource_type: "InsuranceApplication",
            resource_id: application.id,
            severity: "info",
            details: {
              api_key_id: current_api_key.id,
              submitted_at: application.submitted_at,
              reference_number: application.reference_number
            }
          )

          {
            message: "Application submitted successfully",
            application: ApplicationEntity.represent(application),
            next_steps: [
              "Application will be reviewed by underwriters",
              "You will receive notifications about status updates",
              "Additional documentation may be requested"
            ]
          }
        else
          error!({
            error: "submission_failed",
            message: "Failed to submit application",
            details: application.errors.as_json
          }, 422)
        end
      end
    end

    desc "Get application documents", {
      summary: "Retrieve documents associated with an application",
      detail: "Returns a list of documents uploaded for the specified application",
      tags: [ "Applications" ],
      security: [ { bearer_token: [] } ]
    }
    route_param :id do
      get :documents do
        authenticate_api_request!
        authorize_api_action!("read_document")
        track_api_usage("applications", "list_documents")

        application = current_organization.insurance_applications.find(params[:id])
        authorize_api_action!("read_application", application)

        documents = application.documents.includes(:user)

        {
          application_id: application.id,
          reference_number: application.reference_number,
          documents: documents.map { |doc| DocumentEntity.represent(doc) }
        }
      end
    end

    desc "Get application quotes", {
      summary: "Retrieve quotes associated with an application",
      detail: "Returns a list of quotes generated for the specified application",
      tags: [ "Applications" ],
      security: [ { bearer_token: [] } ]
    }
    route_param :id do
      get :quotes do
        authenticate_api_request!
        authorize_api_action!("read_quote")
        track_api_usage("applications", "list_quotes")

        application = current_organization.insurance_applications.find(params[:id])
        authorize_api_action!("read_application", application)

        quotes = application.quotes.includes(:insurance_company)

        {
          application_id: application.id,
          reference_number: application.reference_number,
          quotes: quotes.map { |quote| QuoteEntity.represent(quote) }
        }
      end
    end
  end
end
