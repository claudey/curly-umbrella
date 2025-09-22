# frozen_string_literal: true

class SearchAnalyticsService
  include ActionView::Helpers::DateHelper

  def self.track_search(params)
    return unless params&.dig(:user) && params&.dig(:query).present?

    begin
      SearchHistory.create!(
        user: params[:user],
        query: params[:query],
        results_count: params[:results_count] || 0,
        search_time: params[:search_time],
        metadata: {
          scope: params[:scope],
          search_time: params[:search_time],
          filters: params[:filters] || {},
          user_agent: params[:user_agent],
          ip_address: params[:ip_address]
        }.compact
      )
    rescue StandardError => e
      Rails.logger.error "Failed to track search: #{e.message}"
      # Fail silently to not disrupt user experience
    end
  end

  def self.organization_search_stats(organization, start_date, end_date)
    return default_stats if organization.nil? || start_date > end_date

    user_ids = organization.users.pluck(:id)
    searches = SearchHistory.where(user_id: user_ids, created_at: start_date..end_date)

    {
      total_searches: searches.count,
      unique_users: searches.distinct.count(:user_id),
      average_results: searches.successful.average(:results_count)&.round(2) || 0,
      popular_queries: searches.popular_queries(10),
      daily_breakdown: daily_breakdown(searches, start_date, end_date),
      success_rate: calculate_success_rate(searches)
    }
  end

  def self.search_performance_metrics(start_date, end_date)
    searches = SearchHistory.where(created_at: start_date..end_date)
                           .where.not(search_time: nil)

    search_times = searches.pluck(:search_time).compact.map(&:to_f)

    return default_performance_metrics if search_times.empty?

    {
      average_search_time: (search_times.sum / search_times.size).round(3),
      median_search_time: calculate_median(search_times),
      percentile_95_time: calculate_percentile(search_times, 95),
      slow_searches_count: search_times.count { |time| time > 2.0 },
      slowest_queries: slowest_queries(searches, 10)
    }
  end

  def self.search_success_analysis(start_date, end_date)
    searches = SearchHistory.where(created_at: start_date..end_date)
    successful = searches.successful
    failed = searches.where(results_count: 0)

    {
      total_searches: searches.count,
      successful_searches: successful.count,
      success_rate: calculate_success_rate(searches),
      zero_result_queries: failed.group(:query)
                                 .order("count_query DESC")
                                 .limit(10)
                                 .count(:query)
                                 .map { |query, count| { query: query, count: count } },
      improvement_suggestions: generate_improvement_suggestions(failed)
    }
  end

  def self.user_search_behavior(user, start_date, end_date)
    searches = SearchHistory.where(user: user, created_at: start_date..end_date)
                           .order(:created_at)

    {
      total_searches: searches.count,
      unique_queries: searches.distinct.count(:query),
      search_frequency: calculate_search_frequency(searches),
      preferred_search_times: calculate_preferred_times(searches),
      query_refinement_patterns: detect_refinement_patterns(searches),
      average_session_length: calculate_average_session_length(searches),
      searches_per_session: calculate_searches_per_session(searches)
    }
  end

  def self.export_analytics(organization, start_date, end_date, format)
    return nil unless %w[csv json].include?(format)

    user_ids = organization.users.pluck(:id)
    searches = SearchHistory.where(user_id: user_ids, created_at: start_date..end_date)
                           .includes(:user)

    case format
    when "csv"
      generate_csv_export(searches)
    when "json"
      generate_json_export(searches, organization, start_date, end_date)
    end
  end

  def self.real_time_search_metrics(organization)
    user_ids = organization.users.pluck(:id)
    last_hour = SearchHistory.where(user_id: user_ids, created_at: 1.hour.ago..Time.current)
    last_5_minutes = SearchHistory.where(user_id: user_ids, created_at: 5.minutes.ago..Time.current)

    {
      searches_last_hour: last_hour.count,
      searches_last_5_minutes: last_5_minutes.count,
      active_users: last_hour.distinct.count(:user_id),
      success_rate_last_hour: calculate_success_rate(last_hour),
      trending_queries: last_hour.trending_searches(1.hour.ago)
    }
  end

  private

  def self.default_stats
    {
      total_searches: 0,
      unique_users: 0,
      average_results: 0,
      popular_queries: [],
      daily_breakdown: [],
      success_rate: 0
    }
  end

  def self.default_performance_metrics
    {
      average_search_time: 0,
      median_search_time: 0,
      percentile_95_time: 0,
      slow_searches_count: 0,
      slowest_queries: []
    }
  end

  def self.calculate_success_rate(searches)
    return 0 if searches.count == 0
    (searches.successful.count.to_f / searches.count * 100).round(2)
  end

  def self.daily_breakdown(searches, start_date, end_date)
    (start_date.to_date..end_date.to_date).map do |date|
      day_searches = searches.where(created_at: date.all_day)
      {
        date: date.to_s,
        total_searches: day_searches.count,
        successful_searches: day_searches.successful.count,
        unique_users: day_searches.distinct.count(:user_id)
      }
    end
  end

  def self.calculate_median(array)
    sorted = array.sort
    length = sorted.length
    return 0 if length == 0

    if length.odd?
      sorted[length / 2]
    else
      (sorted[length / 2 - 1] + sorted[length / 2]) / 2.0
    end.round(3)
  end

  def self.calculate_percentile(array, percentile)
    return 0 if array.empty?

    sorted = array.sort
    index = (percentile / 100.0 * (sorted.length - 1)).round
    sorted[index].round(3)
  end

  def self.slowest_queries(searches, limit)
    searches.group(:query)
            .average(:search_time)
            .sort_by { |_, avg_time| -avg_time.to_f }
            .first(limit)
            .map { |query, avg_time| { query: query, avg_time: avg_time.to_f.round(3) } }
  end

  def self.calculate_search_frequency(searches)
    return 0 if searches.count == 0

    time_span_hours = (searches.last.created_at - searches.first.created_at) / 1.hour
    return searches.count if time_span_hours < 1

    (searches.count / time_span_hours).round(2)
  end

  def self.calculate_preferred_times(searches)
    hours = searches.pluck(:created_at).map { |time| time.hour }
    hour_counts = hours.group_by(&:itself).transform_values(&:size)

    hour_counts.sort_by { |_, count| -count }
               .first(3)
               .map { |hour, count| { hour: hour, count: count } }
  end

  def self.detect_refinement_patterns(searches)
    refinements = []
    queries = searches.pluck(:query, :created_at).sort_by(&:last)

    queries.each_with_index do |(query, _), index|
      next if index == 0

      previous_query = queries[index - 1][0]
      if query.include?(previous_query) && query != previous_query
        refinements << {
          original: previous_query,
          refined: query,
          time_between: (queries[index][1] - queries[index - 1][1]).to_i
        }
      end
    end

    refinements
  end

  def self.calculate_average_session_length(searches)
    return 0 if searches.count < 2

    session_gaps = []
    searches.pluck(:created_at).each_cons(2) do |prev_time, curr_time|
      gap = curr_time - prev_time
      session_gaps << gap if gap < 1.hour # Consider gaps > 1 hour as new sessions
    end

    return 0 if session_gaps.empty?
    (session_gaps.sum / session_gaps.size).round(0)
  end

  def self.calculate_searches_per_session(searches)
    return 0 if searches.count == 0

    # Estimate sessions by gaps > 30 minutes
    sessions = 1
    searches.pluck(:created_at).each_cons(2) do |prev_time, curr_time|
      sessions += 1 if (curr_time - prev_time) > 30.minutes
    end

    (searches.count.to_f / sessions).round(2)
  end

  def self.generate_improvement_suggestions(failed_searches)
    suggestions = []

    common_failures = failed_searches.group(:query).count(:query)

    if common_failures.any?
      suggestions << "Consider adding search suggestions for commonly failed queries"
    end

    if failed_searches.joins(:user).group("metadata").count.any?
      suggestions << "Review search filters and scoping options"
    end

    suggestions << "Consider implementing fuzzy search for typo tolerance" if suggestions.empty?
    suggestions
  end

  def self.generate_csv_export(searches)
    CSV.generate(headers: true) do |csv|
      csv << [ "Query", "User Email", "Results Count", "Search Time", "Created At", "Scope" ]

      searches.find_each do |search|
        csv << [
          search.query,
          search.user.email,
          search.results_count,
          search.search_time,
          search.created_at.iso8601,
          search.metadata.dig("scope")
        ]
      end
    end
  end

  def self.generate_json_export(searches, organization, start_date, end_date)
    {
      organization: {
        id: organization.id,
        name: organization.name
      },
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      },
      summary: organization_search_stats(organization, start_date, end_date),
      searches: searches.limit(1000).map do |search|
        {
          query: search.query,
          user_id: search.user_id,
          results_count: search.results_count,
          search_time: search.search_time,
          created_at: search.created_at.iso8601,
          metadata: search.metadata
        }
      end,
      generated_at: Time.current.iso8601
    }.to_json
  end
end
