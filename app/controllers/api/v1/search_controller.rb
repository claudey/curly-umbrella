# frozen_string_literal: true

class Api::V1::SearchController < Api::V1::BaseController
  before_action :authenticate_api_user!
  before_action :validate_search_params, only: [:global]
  before_action :check_rate_limiting
  before_action :track_usage

  # GET /api/v1/search/global
  def global
    search_service = GlobalSearchService.new(current_api_user, search_params)
    results = search_service.search

    # Add cache headers
    response.headers['Cache-Control'] = 'public, max-age=300' # 5 minutes
    response.headers['ETag'] = generate_etag(results)
    response.headers['Vary'] = 'User, Authorization'

    render_success({
      **results,
      cached: false
    })
  rescue StandardError => e
    Rails.logger.error "Global search error: #{e.message}"
    render_error(
      'Search temporarily unavailable',
      status: :internal_server_error,
      details: { error_type: 'search_service_error' }
    )
  end

  # GET /api/v1/search/suggestions
  def suggestions
    return render_success({ suggestions: [] }) if suggestion_params[:query].blank?
    return render_success({ suggestions: [] }) if suggestion_params[:query].length < 2

    search_service = GlobalSearchService.new(current_api_user, suggestion_params)
    suggestions = search_service.suggestions

    render_success({ suggestions: suggestions })
  rescue StandardError => e
    Rails.logger.error "Search suggestions error: #{e.message}"
    render_success({ suggestions: [] }) # Fail gracefully
  end

  # GET /api/v1/search/filters
  def filters
    search_service = GlobalSearchService.new(current_api_user, filter_params)
    filter_data = search_service.filters

    render_success({ filters: filter_data })
  rescue StandardError => e
    Rails.logger.error "Search filters error: #{e.message}"
    render_error('Unable to load filters', status: :internal_server_error)
  end

  # GET /api/v1/search/history
  def history
    search_service = GlobalSearchService.new(current_api_user)
    recent_searches = search_service.recent_searches

    render_success({ recent_searches: recent_searches })
  end

  # GET /api/v1/search/analytics
  def analytics
    authorize_admin_access!

    period = analytics_params[:period] || '7d'
    start_date, end_date = parse_period(period)

    analytics_data = SearchAnalyticsService.organization_search_stats(
      current_organization,
      start_date,
      end_date
    )

    render_success({
      period: period,
      analytics: analytics_data,
      generated_at: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error "Search analytics error: #{e.message}"
    render_error('Unable to generate analytics', status: :internal_server_error)
  end

  # DELETE /api/v1/search/history
  def clear_history
    current_api_user.search_histories.delete_all
    
    render_success({ 
      message: 'Search history cleared successfully',
      cleared_at: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error "Clear search history error: #{e.message}"
    render_error('Unable to clear search history', status: :internal_server_error)
  end

  private

  def search_params
    params.permit(:query, :scope, :page, :per_page, :user_agent, filters: {}).tap do |permitted|
      permitted[:ip_address] = request.remote_ip
    end
  end

  def suggestion_params
    params.permit(:query)
  end

  def filter_params
    params.permit(:query, filters: {})
  end

  def analytics_params
    params.permit(:period)
  end

  def validate_search_params
    if params[:query].blank?
      return render_error(
        'Query parameter is required',
        status: :bad_request,
        details: { parameter: 'query' }
      )
    end

    if params[:scope].present? && !GlobalSearchService::VALID_SCOPES.include?(params[:scope])
      return render_error(
        'Invalid scope',
        status: :bad_request,
        details: { 
          provided_scope: params[:scope],
          valid_scopes: GlobalSearchService::VALID_SCOPES
        }
      )
    end

    # Validate pagination parameters
    if params[:page].present? && params[:page].to_i < 1
      return render_error(
        'Page must be greater than 0',
        status: :bad_request
      )
    end

    if params[:per_page].present? && (params[:per_page].to_i < 1 || params[:per_page].to_i > GlobalSearchService::MAX_PER_PAGE)
      return render_error(
        "Per page must be between 1 and #{GlobalSearchService::MAX_PER_PAGE}",
        status: :bad_request
      )
    end
  end

  def authorize_admin_access!
    unless current_api_user.can_manage_organization?(current_organization)
      render_error('Insufficient permissions', status: :forbidden)
    end
  end

  def check_rate_limiting
    unless RateLimitingService.check_request_rate_limit(
      current_api_user,
      "search:#{request.remote_ip}",
      limit: 100, # 100 searches per hour
      window: 1.hour
    )
      render_error(
        'Rate limit exceeded',
        status: :too_many_requests,
        details: { 
          limit: 100,
          window: '1 hour',
          retry_after: 3600
        }
      )
    end
  end

  def parse_period(period)
    case period
    when '1h'
      [1.hour.ago, Time.current]
    when '24h', '1d'
      [1.day.ago, Time.current]
    when '7d', '1w'
      [1.week.ago, Time.current]
    when '30d', '1m'
      [1.month.ago, Time.current]
    when '90d', '3m'
      [3.months.ago, Time.current]
    when '1y'
      [1.year.ago, Time.current]
    else
      [1.week.ago, Time.current] # Default to 1 week
    end
  end

  def generate_etag(results)
    content = "#{results[:query]}-#{results[:scope]}-#{results[:total_count]}-#{current_api_user.id}"
    Digest::MD5.hexdigest(content)
  end

  def track_usage
    # Track API usage for analytics
    ApiUsageTracker.track(
      user: current_api_user,
      organization: current_organization,
      endpoint: "#{controller_name}##{action_name}",
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  rescue StandardError => e
    Rails.logger.error "API usage tracking error: #{e.message}"
    # Don't fail the request if tracking fails
  end
end