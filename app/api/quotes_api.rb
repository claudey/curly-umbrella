# frozen_string_literal: true

class QuotesApi < Grape::API
  version "v1", using: :header, vendor: "brokersync"
  format :json

  resource :quotes do
    desc "List all quotes", {
      summary: "Retrieve paginated list of insurance quotes",
      detail: "Returns a paginated list of insurance quotes accessible to the API key holder",
      tags: [ "Quotes" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      optional :page, type: Integer, default: 1, desc: "Page number"
      optional :per_page, type: Integer, default: 25, desc: "Items per page (max 100)"
      optional :status, type: String, values: %w[draft pending accepted rejected expired], desc: "Filter by status"
      optional :application_id, type: Integer, desc: "Filter by application ID"
      optional :insurance_company_id, type: Integer, desc: "Filter by insurance company"
      optional :created_after, type: DateTime, desc: "Filter quotes created after this date"
      optional :created_before, type: DateTime, desc: "Filter quotes created before this date"
    end
    get do
      authenticate_api_request!
      authorize_api_action!("read_quote")
      track_api_usage("quotes", "list")

      # Base query scoped to organization
      quotes = current_organization.quotes.includes(:insurance_company, :insurance_application)

      # Apply filters
      quotes = quotes.where(status: params[:status]) if params[:status]
      quotes = quotes.where(insurance_application_id: params[:application_id]) if params[:application_id]
      quotes = quotes.where(insurance_company_id: params[:insurance_company_id]) if params[:insurance_company_id]
      quotes = quotes.where("created_at >= ?", params[:created_after]) if params[:created_after]
      quotes = quotes.where("created_at <= ?", params[:created_before]) if params[:created_before]

      # Order by most recent
      quotes = quotes.order(created_at: :desc)

      # Paginate results
      result = paginate(quotes, per_page: params[:per_page])

      # Format response
      {
        quotes: result[:data].map { |quote| QuoteEntity.represent(quote) },
        pagination: result[:pagination],
        filters_applied: {
          status: params[:status],
          application_id: params[:application_id],
          insurance_company_id: params[:insurance_company_id],
          date_range: {
            from: params[:created_after],
            to: params[:created_before]
          }
        }
      }
    end

    desc "Get quote by ID", {
      summary: "Retrieve a specific insurance quote",
      detail: "Returns detailed information about a specific insurance quote",
      tags: [ "Quotes" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      requires :id, type: Integer, desc: "Quote ID"
    end
    route_param :id do
      get do
        authenticate_api_request!
        authorize_api_action!("read_quote")
        track_api_usage("quotes", "show")

        quote = current_organization.quotes
                                  .includes(:insurance_company, :insurance_application, :client)
                                  .find(params[:id])

        authorize_api_action!("read_quote", quote)

        QuoteEntity.represent(quote, with_details: true)
      end
    end

    desc "Create new quote", {
      summary: "Create a new insurance quote",
      detail: "Creates a new insurance quote for an application",
      tags: [ "Quotes" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      requires :application_id, type: Integer, desc: "Insurance application ID"
      requires :insurance_company_id, type: Integer, desc: "Insurance company ID"
      requires :total_premium, type: Float, desc: "Total premium amount"
      requires :coverage_amount, type: Float, desc: "Coverage amount"
      optional :base_premium, type: Float, desc: "Base premium before taxes and fees"
      optional :taxes, type: Float, desc: "Tax amount"
      optional :fees, type: Float, desc: "Fee amount"
      optional :discounts, type: Float, desc: "Discount amount"
      optional :deductible, type: Float, desc: "Deductible amount"
      optional :coverage_type, type: String, desc: "Type of coverage"
      optional :valid_until, type: Date, desc: "Quote expiration date"
      optional :quote_notes, type: String, desc: "Notes about the quote"
    end
    post do
      authenticate_api_request!
      authorize_api_action!("create_quote")
      track_api_usage("quotes", "create")

      # Verify application and insurance company belong to organization
      application = current_organization.insurance_applications.find(params[:application_id])
      insurance_company = current_organization.insurance_companies.find(params[:insurance_company_id])

      quote = current_organization.quotes.build(
        insurance_application: application,
        insurance_company: insurance_company,
        client: application.client,
        user: current_api_user,
        total_premium: params[:total_premium],
        coverage_amount: params[:coverage_amount],
        base_premium: params[:base_premium] || params[:total_premium],
        taxes: params[:taxes] || 0,
        fees: params[:fees] || 0,
        discounts: params[:discounts] || 0,
        deductible: params[:deductible],
        coverage_type: params[:coverage_type],
        valid_until: params[:valid_until] || 30.days.from_now.to_date,
        quote_notes: params[:quote_notes],
        status: "draft",
        quote_date: Date.current,
        source: "api"
      )

      if quote.save
        # Generate quote number if not set
        quote.update(quote_number: "Q#{quote.id.to_s.rjust(6, '0')}") unless quote.quote_number

        # Log creation
        AuditLog.create!(
          user: current_api_user,
          organization: current_organization,
          action: "quote_created_via_api",
          category: "quote_management",
          resource_type: "Quote",
          resource_id: quote.id,
          severity: "info",
          details: {
            api_key_id: current_api_key.id,
            application_id: application.id,
            insurance_company_id: insurance_company.id,
            quote_number: quote.quote_number,
            total_premium: quote.total_premium
          }
        )

        status 201
        QuoteEntity.represent(quote, with_details: true)
      else
        error!({
          error: "validation_error",
          message: "Quote creation failed",
          details: quote.errors.as_json
        }, 422)
      end
    end

    desc "Update quote", {
      summary: "Update an existing insurance quote",
      detail: "Updates an existing insurance quote with the provided details",
      tags: [ "Quotes" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      requires :id, type: Integer, desc: "Quote ID"
      optional :total_premium, type: Float, desc: "Total premium amount"
      optional :coverage_amount, type: Float, desc: "Coverage amount"
      optional :base_premium, type: Float, desc: "Base premium before taxes and fees"
      optional :taxes, type: Float, desc: "Tax amount"
      optional :fees, type: Float, desc: "Fee amount"
      optional :discounts, type: Float, desc: "Discount amount"
      optional :deductible, type: Float, desc: "Deductible amount"
      optional :coverage_type, type: String, desc: "Type of coverage"
      optional :valid_until, type: Date, desc: "Quote expiration date"
      optional :quote_notes, type: String, desc: "Notes about the quote"
      optional :status, type: String, values: %w[draft pending accepted rejected], desc: "Quote status"
    end
    route_param :id do
      put do
        authenticate_api_request!
        authorize_api_action!("update_quote")
        track_api_usage("quotes", "update")

        quote = current_organization.quotes.find(params[:id])
        authorize_api_action!("update_quote", quote)

        # Prevent updates to accepted quotes unless admin
        if quote.status == "accepted" && !current_api_key.has_scope?("admin:access")
          error!({
            error: "authorization_error",
            message: "Cannot update accepted quote",
            current_status: quote.status
          }, 403)
        end

        update_params = params.except(:id)

        if quote.update(update_params)
          # Log update
          AuditLog.create!(
            user: current_api_user,
            organization: current_organization,
            action: "quote_updated_via_api",
            category: "quote_management",
            resource_type: "Quote",
            resource_id: quote.id,
            severity: "info",
            details: {
              api_key_id: current_api_key.id,
              updated_fields: update_params.keys,
              old_status: quote.status_before_last_save,
              new_status: quote.status
            }
          )

          QuoteEntity.represent(quote, with_details: true)
        else
          error!({
            error: "validation_error",
            message: "Quote update failed",
            details: quote.errors.as_json
          }, 422)
        end
      end
    end

    desc "Accept quote", {
      summary: "Accept a quote and proceed with policy issuance",
      detail: "Changes quote status to accepted and triggers policy creation workflow",
      tags: [ "Quotes" ],
      security: [ { bearer_token: [] } ]
    }
    route_param :id do
      post :accept do
        authenticate_api_request!
        authorize_api_action!("update_quote")
        track_api_usage("quotes", "accept")

        quote = current_organization.quotes.find(params[:id])
        authorize_api_action!("update_quote", quote)

        if quote.status != "pending"
          error!({
            error: "invalid_status",
            message: "Quote can only be accepted from pending status",
            current_status: quote.status
          }, 400)
        end

        # Check if quote is still valid
        if quote.valid_until && quote.valid_until < Date.current
          error!({
            error: "quote_expired",
            message: "Quote has expired and cannot be accepted",
            expired_on: quote.valid_until
          }, 400)
        end

        if quote.update(status: "accepted", accepted_at: Time.current)
          # Trigger policy creation workflow
          PolicyCreationJob.perform_later(quote) if defined?(PolicyCreationJob)

          # Log acceptance
          AuditLog.create!(
            user: current_api_user,
            organization: current_organization,
            action: "quote_accepted_via_api",
            category: "quote_workflow",
            resource_type: "Quote",
            resource_id: quote.id,
            severity: "info",
            details: {
              api_key_id: current_api_key.id,
              accepted_at: quote.accepted_at,
              quote_number: quote.quote_number,
              total_premium: quote.total_premium
            }
          )

          {
            message: "Quote accepted successfully",
            quote: QuoteEntity.represent(quote),
            next_steps: [
              "Policy creation process has been initiated",
              "Payment arrangements will be processed",
              "Policy documents will be generated"
            ]
          }
        else
          error!({
            error: "acceptance_failed",
            message: "Failed to accept quote",
            details: quote.errors.as_json
          }, 422)
        end
      end
    end

    desc "Generate quote PDF", {
      summary: "Generate PDF document for a quote",
      detail: "Creates a downloadable PDF document for the specified quote",
      tags: [ "Quotes" ],
      security: [ { bearer_token: [] } ]
    }
    route_param :id do
      post :generate_pdf do
        authenticate_api_request!
        authorize_api_action!("read_quote")
        track_api_usage("quotes", "generate_pdf")

        quote = current_organization.quotes.find(params[:id])
        authorize_api_action!("read_quote", quote)

        # Generate PDF using quote service
        pdf_service = QuotePdfGenerationService.new(quote)
        pdf_result = pdf_service.generate

        if pdf_result[:success]
          {
            message: "PDF generated successfully",
            download_url: "/api/v1/quotes/#{quote.id}/download_pdf",
            expires_at: 24.hours.from_now.iso8601,
            file_size: pdf_result[:file_size]
          }
        else
          error!({
            error: "pdf_generation_failed",
            message: "Failed to generate PDF",
            details: pdf_result[:error]
          }, 500)
        end
      end
    end
  end
end
