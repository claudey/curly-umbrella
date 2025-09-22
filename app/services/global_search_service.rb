# frozen_string_literal: true

class GlobalSearchService
  attr_reader :current_user, :params

  VALID_SCOPES = %w[all clients applications quotes documents].freeze
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  
  def initialize(current_user, params = {})
    @current_user = current_user
    @params = params.with_indifferent_access
    @start_time = Time.current
  end

  def search
    return empty_results if query.blank?

    results = case scope
             when 'clients'
               search_clients_only
             when 'applications'
               search_applications_only
             when 'quotes'
               search_quotes_only
             when 'documents'
               search_documents_only
             when 'all'
               search_all_entities
             else
               empty_results
             end

    # Track the search
    track_search(results[:total_count])

    results.merge(
      query: query,
      scope: scope,
      search_time: calculate_search_time,
      pagination: pagination_info(results[:total_count])
    )
  end

  def suggestions
    return [] if query.blank? || query.length < 2

    suggestions = []
    
    # Client suggestions
    suggestions.concat(client_suggestions)
    
    # Application suggestions  
    suggestions.concat(application_suggestions)
    
    # Document suggestions
    suggestions.concat(document_suggestions)
    
    # Limit and return
    suggestions.uniq { |s| [s[:type], s[:value]] }.first(10)
  end

  def filters
    base_clients = organization_clients
    base_applications = organization_applications  
    base_quotes = organization_quotes
    base_documents = organization_documents

    if query.present?
      base_clients = apply_text_search(base_clients, [:first_name, :last_name, :email])
      base_applications = apply_text_search(base_applications, [:insurance_type, :status])
      base_quotes = apply_text_search(base_quotes, [:status])
      base_documents = apply_text_search(base_documents, [:name, :description])
    end

    {
      clients: client_filters(base_clients),
      applications: application_filters(base_applications),
      quotes: quote_filters(base_quotes),
      documents: document_filters(base_documents)
    }
  end

  def recent_searches
    current_user.search_histories
                .recent
                .limit(5)
                .pluck(:query, :results_count, :created_at)
                .map do |query, count, time|
                  {
                    query: query,
                    results_count: count,
                    searched_at: time.iso8601
                  }
                end
  end

  def save_search(results_count)
    return if query.blank?

    SearchAnalyticsService.track_search(
      user: current_user,
      query: query,
      scope: scope,
      results_count: results_count,
      search_time: calculate_search_time,
      filters: params[:filters],
      user_agent: params[:user_agent],
      ip_address: params[:ip_address]
    )
  end

  private

  def query
    @query ||= params[:query]&.strip
  end

  def scope
    @scope ||= VALID_SCOPES.include?(params[:scope]) ? params[:scope] : 'all'
  end

  def page
    @page ||= [params[:page].to_i, 1].max
  end

  def per_page
    @per_page ||= [[params[:per_page].to_i, DEFAULT_PER_PAGE].max, MAX_PER_PAGE].min
  end

  def offset
    (page - 1) * per_page
  end

  def search_all_entities
    clients_result = search_in_scope(organization_clients, :clients, [:first_name, :last_name, :email])
    applications_result = search_in_scope(organization_applications, :applications, [:insurance_type, :status])
    quotes_result = search_in_scope(organization_quotes, :quotes, [:status])
    documents_result = search_in_scope(organization_documents, :documents, [:name, :description])

    # Apply global pagination across all results
    all_results = [
      *clients_result[:results].map { |item| { entity: item, type: :clients } },
      *applications_result[:results].map { |item| { entity: item, type: :applications } },
      *quotes_result[:results].map { |item| { entity: item, type: :quotes } },
      *documents_result[:results].map { |item| { entity: item, type: :documents } }
    ]

    # Sort by relevance score or created_at
    all_results.sort_by! { |item| item[:entity].respond_to?(:created_at) ? -item[:entity].created_at.to_i : 0 }
    
    paginated_results = all_results[offset, per_page] || []
    
    # Group back by type
    grouped_results = paginated_results.group_by { |item| item[:type] }

    {
      clients: {
        results: grouped_results[:clients]&.map { |item| item[:entity] } || [],
        count: clients_result[:count]
      },
      applications: {
        results: grouped_results[:applications]&.map { |item| item[:entity] } || [],
        count: applications_result[:count]
      },
      quotes: {
        results: grouped_results[:quotes]&.map { |item| item[:entity] } || [],
        count: quotes_result[:count]
      },
      documents: {
        results: grouped_results[:documents]&.map { |item| item[:entity] } || [],
        count: documents_result[:count]
      },
      total_count: clients_result[:count] + applications_result[:count] + 
                   quotes_result[:count] + documents_result[:count]
    }
  end

  def search_clients_only
    result = search_in_scope(organization_clients, :clients, [:first_name, :last_name, :email], paginate: true)
    base_result.merge(
      clients: result,
      total_count: result[:count]
    )
  end

  def search_applications_only  
    result = search_in_scope(organization_applications, :applications, [:insurance_type, :status], paginate: true)
    base_result.merge(
      applications: result,
      total_count: result[:count]
    )
  end

  def search_quotes_only
    result = search_in_scope(organization_quotes, :quotes, [:status], paginate: true)
    base_result.merge(
      quotes: result,
      total_count: result[:count]
    )
  end

  def search_documents_only
    # Use the existing DocumentSearchService for documents
    document_service = DocumentSearchService.new(organization_documents, params, current_user)
    documents = document_service.search.limit(per_page).offset(offset)
    
    base_result.merge(
      documents: {
        results: documents.to_a,
        count: document_service.search.count
      },
      total_count: document_service.search.count
    )
  end

  def search_in_scope(base_scope, entity_type, search_fields, paginate: false)
    return { results: [], count: 0 } if query.blank?

    # Apply text search
    results = apply_text_search(base_scope, search_fields)
    
    # Apply filters if present
    results = apply_entity_filters(results, entity_type)
    
    # Get count before pagination
    total_count = results.count
    
    # Apply pagination if requested
    if paginate
      results = results.limit(per_page).offset(offset)
    else
      # For non-paginated, limit to a reasonable number for performance
      results = results.limit(50)
    end

    {
      results: results.to_a,
      count: total_count
    }
  end

  def apply_text_search(scope, fields)
    search_terms = query.split(/\s+/).reject(&:blank?)
    
    search_terms.inject(scope) do |current_scope, term|
      conditions = fields.map { |field| "#{field} ILIKE ?" }
      values = fields.map { "%#{term}%" }
      
      current_scope.where(conditions.join(' OR '), *values)
    end
  end

  def apply_entity_filters(scope, entity_type)
    filters = params[:filters] || {}
    
    case entity_type
    when :clients
      apply_client_filters(scope, filters)
    when :applications
      apply_application_filters(scope, filters)
    when :quotes
      apply_quote_filters(scope, filters)
    when :documents
      apply_document_filters(scope, filters)
    else
      scope
    end
  end

  def apply_client_filters(scope, filters)
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(client_type: filters[:client_type]) if filters[:client_type].present?
    scope
  end

  def apply_application_filters(scope, filters)
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(insurance_type: filters[:insurance_type]) if filters[:insurance_type].present?
    scope
  end

  def apply_quote_filters(scope, filters)
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where('total_premium >= ?', filters[:min_premium]) if filters[:min_premium].present?
    scope = scope.where('total_premium <= ?', filters[:max_premium]) if filters[:max_premium].present?
    scope
  end

  def apply_document_filters(scope, filters)
    scope = scope.where(document_type: filters[:document_type]) if filters[:document_type].present?
    scope = scope.where(category: filters[:category]) if filters[:category].present?
    scope = scope.where(access_level: filters[:access_level]) if filters[:access_level].present?
    scope
  end

  def base_result
    {
      clients: { results: [], count: 0 },
      applications: { results: [], count: 0 },
      quotes: { results: [], count: 0 },
      documents: { results: [], count: 0 }
    }
  end

  def empty_results
    base_result.merge(
      total_count: 0,
      query: query,
      scope: scope,
      search_time: 0.0
    )
  end

  def organization_clients
    current_user.organization.clients.includes(:user)
  end

  def organization_applications
    current_user.organization.insurance_applications.includes(:client, :user)
  end

  def organization_quotes
    current_user.organization.quotes.includes(:application, :insurance_company)
  end

  def organization_documents
    # Apply document access permissions
    documents = current_user.organization.documents.includes(:user)
    
    # Filter based on user permissions
    case current_user.role
    when 'brokerage_admin', 'admin'
      documents # Admins can see all
    else
      documents.where(
        '(access_level = ? AND is_public = ?) OR (access_level = ?) OR (user_id = ?)',
        'public', true, 'organization', current_user.id
      )
    end
  end

  def client_suggestions
    return [] if query.length < 2

    clients = organization_clients
              .where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", 
                     "%#{query}%", "%#{query}%", "%#{query}%")
              .limit(3)

    clients.map do |client|
      {
        type: 'client',
        value: client.id,
        label: "#{client.full_name} (#{client.email})",
        category: 'Clients'
      }
    end
  end

  def application_suggestions
    return [] if query.length < 2

    applications = organization_applications
                   .where("insurance_type ILIKE ? OR status ILIKE ?", "%#{query}%", "%#{query}%")
                   .limit(3)

    applications.map do |app|
      {
        type: 'application',
        value: app.id,
        label: "#{app.insurance_type.humanize} - #{app.client.full_name}",
        category: 'Applications'
      }
    end
  end

  def document_suggestions
    return [] if query.length < 2

    documents = organization_documents
                .where("name ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%")
                .limit(3)

    documents.map do |doc|
      {
        type: 'document',
        value: doc.id,
        label: "#{doc.name} (#{doc.document_type.humanize})",
        category: 'Documents'
      }
    end
  end

  def client_filters(scope)
    {
      statuses: build_filter_counts(scope, :status),
      client_types: build_filter_counts(scope, :client_type)
    }
  end

  def application_filters(scope)
    {
      statuses: build_filter_counts(scope, :status),
      insurance_types: build_filter_counts(scope, :insurance_type)
    }
  end

  def quote_filters(scope)
    {
      statuses: build_filter_counts(scope, :status)
    }
  end

  def document_filters(scope)
    {
      document_types: build_filter_counts(scope, :document_type),
      categories: build_filter_counts(scope, :category),
      access_levels: build_filter_counts(scope, :access_level)
    }
  end

  def build_filter_counts(scope, field)
    scope.group(field)
         .count
         .map { |value, count| { value: value, label: value&.humanize, count: count } }
         .select { |filter| filter[:count] > 0 }
         .sort_by { |filter| -filter[:count] }
  end

  def pagination_info(total_count)
    total_pages = (total_count.to_f / per_page).ceil
    
    {
      current_page: page,
      per_page: per_page,
      total_pages: total_pages,
      total_count: total_count,
      has_next_page: page < total_pages,
      has_prev_page: page > 1
    }
  end

  def calculate_search_time
    (Time.current - @start_time).round(3)
  end

  def track_search(results_count)
    save_search(results_count)
  end
end