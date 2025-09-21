# frozen_string_literal: true

class Api::V1::AnalyticsController < Api::V1::BaseController
  before_action :track_usage
  before_action :check_analytics_permissions

  # GET /api/v1/analytics/usage
  def usage
    time_period = params[:period] || "30d"

    usage_data = calculate_usage_analytics(time_period)

    render_success({
      time_period: time_period,
      usage_metrics: usage_data[:metrics],
      trends: usage_data[:trends],
      top_endpoints: usage_data[:top_endpoints],
      generated_at: Time.current.iso8601
    })
  end

  # GET /api/v1/analytics/dashboard
  def dashboard
    dashboard_data = {
      overview: calculate_overview_metrics,
      activity_timeline: calculate_activity_timeline,
      endpoint_performance: calculate_endpoint_performance,
      error_rates: calculate_error_rates,
      user_activity: calculate_user_activity_metrics
    }

    render_success({
      dashboard: dashboard_data,
      refresh_interval: 300, # 5 minutes
      generated_at: Time.current.iso8601
    })
  end

  # GET /api/v1/analytics/performance
  def performance
    time_range = params[:time_range] || "24h"

    performance_data = {
      response_times: calculate_response_time_metrics(time_range),
      throughput: calculate_throughput_metrics(time_range),
      error_analysis: calculate_error_analysis(time_range),
      slow_queries: identify_slow_endpoints(time_range),
      resource_usage: calculate_resource_usage(time_range)
    }

    render_success({
      time_range: time_range,
      performance: performance_data,
      recommendations: generate_performance_recommendations(performance_data),
      generated_at: Time.current.iso8601
    })
  end

  # GET /api/v1/analytics/export
  def export
    format = params[:format] || "json"
    time_period = params[:period] || "7d"

    unless %w[json csv xlsx].include?(format)
      return render_error(
        "Invalid export format",
        details: { supported_formats: %w[json csv xlsx] },
        status: :bad_request
      )
    end

    export_data = prepare_export_data(time_period)

    case format
    when "json"
      render_success(export_data)
    when "csv"
      send_csv_export(export_data, time_period)
    when "xlsx"
      send_xlsx_export(export_data, time_period)
    end
  end

  # GET /api/v1/analytics/top_endpoints
  def top_endpoints
    limit = params[:limit]&.to_i || 10
    time_period = params[:period] || "7d"

    endpoints_data = calculate_top_endpoints(time_period, limit)

    render_success({
      time_period: time_period,
      limit: limit,
      endpoints: endpoints_data,
      generated_at: Time.current.iso8601
    })
  end

  # GET /api/v1/analytics/trends
  def trends
    metric = params[:metric] || "requests"
    time_period = params[:period] || "30d"
    granularity = params[:granularity] || "daily"

    unless %w[requests errors response_time users].include?(metric)
      return render_error(
        "Invalid metric type",
        details: { supported_metrics: %w[requests errors response_time users] },
        status: :bad_request
      )
    end

    trends_data = calculate_metric_trends(metric, time_period, granularity)

    render_success({
      metric: metric,
      time_period: time_period,
      granularity: granularity,
      trends: trends_data,
      insights: generate_trend_insights(trends_data, metric),
      generated_at: Time.current.iso8601
    })
  end

  private

  def track_usage
    track_api_usage("analytics", action_name)
  end

  def check_analytics_permissions
    authorize_api_action!("analytics_access")
  end

  def calculate_usage_analytics(period)
    start_date = parse_time_period(period)

    api_logs = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current
    )

    {
      metrics: {
        total_requests: api_logs.count,
        unique_endpoints: api_logs.distinct.count(:endpoint),
        unique_users: api_logs.distinct.count(:user_id),
        successful_requests: api_logs.where(status_code: 200..299).count,
        failed_requests: api_logs.where(status_code: 400..599).count,
        average_response_time: api_logs.average(:response_time_ms)&.round(2),
        requests_per_day: api_logs.group_by_day(:created_at).count,
        peak_hour: find_peak_usage_hour(api_logs)
      },
      trends: calculate_usage_trends(api_logs),
      top_endpoints: calculate_top_endpoints_from_logs(api_logs, 5)
    }
  end

  def calculate_overview_metrics
    today = Date.current
    yesterday = today - 1.day

    today_logs = ApiUsageLog.where(organization: current_organization, created_at: today.beginning_of_day..today.end_of_day)
    yesterday_logs = ApiUsageLog.where(organization: current_organization, created_at: yesterday.beginning_of_day..yesterday.end_of_day)

    {
      requests_today: today_logs.count,
      requests_yesterday: yesterday_logs.count,
      change_percentage: calculate_percentage_change(yesterday_logs.count, today_logs.count),
      active_users_today: today_logs.distinct.count(:user_id),
      error_rate_today: calculate_error_rate(today_logs),
      average_response_time_today: today_logs.average(:response_time_ms)&.round(2)
    }
  end

  def calculate_activity_timeline
    start_time = 24.hours.ago

    ApiUsageLog.where(
      organization: current_organization,
      created_at: start_time..Time.current
    ).group_by_hour(:created_at).count.map do |hour, count|
      {
        timestamp: hour.iso8601,
        requests: count,
        hour_label: hour.strftime("%H:%M")
      }
    end
  end

  def calculate_endpoint_performance
    start_time = 24.hours.ago

    ApiUsageLog.where(
      organization: current_organization,
      created_at: start_time..Time.current
    ).group(:endpoint).group(:http_method).limit(10).calculate(:average, :response_time_ms).map do |(endpoint, method), avg_time|
      {
        endpoint: endpoint,
        method: method,
        average_response_time: avg_time&.round(2),
        request_count: ApiUsageLog.where(
          organization: current_organization,
          endpoint: endpoint,
          http_method: method,
          created_at: start_time..Time.current
        ).count
      }
    end
  end

  def calculate_error_rates
    start_time = 24.hours.ago

    logs = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_time..Time.current
    )

    total_requests = logs.count
    error_requests = logs.where(status_code: 400..599).count

    {
      total_requests: total_requests,
      error_requests: error_requests,
      error_rate: total_requests > 0 ? ((error_requests.to_f / total_requests) * 100).round(2) : 0,
      error_breakdown: logs.where(status_code: 400..599).group(:status_code).count
    }
  end

  def calculate_user_activity_metrics
    start_time = 24.hours.ago

    user_activity = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_time..Time.current
    ).joins(:user).group("users.email").count

    {
      active_users: user_activity.count,
      top_users: user_activity.sort_by { |_, count| -count }.first(5).map do |email, requests|
        { email: email, request_count: requests }
      end,
      user_distribution: {
        heavy_users: user_activity.count { |_, count| count > 100 },
        moderate_users: user_activity.count { |_, count| count.between?(10, 100) },
        light_users: user_activity.count { |_, count| count < 10 }
      }
    }
  end

  def calculate_response_time_metrics(time_range)
    start_date = parse_time_period(time_range)

    logs = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current
    )

    {
      average: logs.average(:response_time_ms)&.round(2),
      median: calculate_median_response_time(logs),
      p95: calculate_percentile_response_time(logs, 95),
      p99: calculate_percentile_response_time(logs, 99),
      min: logs.minimum(:response_time_ms),
      max: logs.maximum(:response_time_ms)
    }
  end

  def calculate_throughput_metrics(time_range)
    start_date = parse_time_period(time_range)

    logs = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current
    )

    duration_hours = ((Time.current - start_date) / 1.hour).round(2)

    {
      requests_per_hour: duration_hours > 0 ? (logs.count.to_f / duration_hours).round(2) : 0,
      requests_per_minute: duration_hours > 0 ? (logs.count.to_f / (duration_hours * 60)).round(2) : 0,
      peak_throughput: calculate_peak_throughput(logs),
      hourly_distribution: logs.group_by_hour(:created_at).count
    }
  end

  def calculate_error_analysis(time_range)
    start_date = parse_time_period(time_range)

    error_logs = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current,
      status_code: 400..599
    )

    {
      total_errors: error_logs.count,
      error_by_status: error_logs.group(:status_code).count,
      error_by_endpoint: error_logs.group(:endpoint).count.sort_by { |_, count| -count }.first(10),
      error_timeline: error_logs.group_by_hour(:created_at).count,
      common_error_patterns: identify_error_patterns(error_logs)
    }
  end

  def identify_slow_endpoints(time_range)
    start_date = parse_time_period(time_range)

    ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current
    ).group(:endpoint, :http_method)
     .having("AVG(response_time_ms) > ?", 1000) # Endpoints averaging over 1 second
     .average(:response_time_ms)
     .sort_by { |_, avg_time| -avg_time }
     .first(10)
     .map do |(endpoint, method), avg_time|
       {
         endpoint: endpoint,
         method: method,
         average_response_time: avg_time.round(2),
         recommendation: generate_endpoint_recommendation(avg_time)
       }
     end
  end

  def calculate_resource_usage(time_range)
    start_date = parse_time_period(time_range)

    # This would integrate with system metrics if available
    # For now, we'll calculate based on API usage patterns
    logs = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current
    )

    {
      api_calls_volume: logs.count,
      data_transfer_estimate: estimate_data_transfer(logs),
      peak_concurrent_users: estimate_peak_concurrent_users(logs),
      resource_intensity_score: calculate_resource_intensity(logs)
    }
  end

  def calculate_top_endpoints(period, limit)
    start_date = parse_time_period(period)

    ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current
    ).group(:endpoint, :http_method)
     .order("count_all DESC")
     .limit(limit)
     .count
     .map do |(endpoint, method), count|
       endpoint_logs = ApiUsageLog.where(
         organization: current_organization,
         endpoint: endpoint,
         http_method: method,
         created_at: start_date..Time.current
       )

       {
         endpoint: endpoint,
         method: method,
         request_count: count,
         average_response_time: endpoint_logs.average(:response_time_ms)&.round(2),
         error_rate: calculate_error_rate(endpoint_logs),
         last_accessed: endpoint_logs.maximum(:created_at)
       }
     end
  end

  def calculate_metric_trends(metric, period, granularity)
    start_date = parse_time_period(period)

    logs = ApiUsageLog.where(
      organization: current_organization,
      created_at: start_date..Time.current
    )

    case granularity
    when "hourly"
      group_method = :group_by_hour
    when "daily"
      group_method = :group_by_day
    when "weekly"
      group_method = :group_by_week
    else
      group_method = :group_by_day
    end

    case metric
    when "requests"
      logs.send(group_method, :created_at).count
    when "errors"
      logs.where(status_code: 400..599).send(group_method, :created_at).count
    when "response_time"
      logs.send(group_method, :created_at).average(:response_time_ms)
    when "users"
      logs.send(group_method, :created_at).distinct.count(:user_id)
    end.map do |time_point, value|
      {
        timestamp: time_point.iso8601,
        value: value&.round(2) || 0,
        formatted_time: format_time_point(time_point, granularity)
      }
    end
  end

  def parse_time_period(period)
    case period
    when "1h" then 1.hour.ago
    when "24h", "1d" then 1.day.ago
    when "7d" then 7.days.ago
    when "30d" then 30.days.ago
    when "90d" then 90.days.ago
    else
      7.days.ago
    end
  end

  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value.zero?
    ((new_value - old_value).to_f / old_value * 100).round(2)
  end

  def calculate_error_rate(logs)
    total = logs.count
    return 0 if total.zero?

    errors = logs.where(status_code: 400..599).count
    ((errors.to_f / total) * 100).round(2)
  end

  def find_peak_usage_hour(logs)
    hourly_usage = logs.group("EXTRACT(hour FROM created_at)").count
    peak_hour = hourly_usage.max_by { |_, count| count }&.first
    peak_hour ? "#{peak_hour.to_i}:00" : "N/A"
  end

  def calculate_usage_trends(logs)
    daily_counts = logs.group_by_day(:created_at, last: 7).count
    return {} if daily_counts.size < 2

    values = daily_counts.values
    trend = values.last - values.first

    {
      direction: trend > 0 ? "increasing" : trend < 0 ? "decreasing" : "stable",
      percentage_change: values.first > 0 ? ((trend.to_f / values.first) * 100).round(2) : 0,
      daily_average: (values.sum.to_f / values.size).round(2)
    }
  end

  def prepare_export_data(period)
    start_date = parse_time_period(period)

    {
      export_info: {
        period: period,
        start_date: start_date.iso8601,
        end_date: Time.current.iso8601,
        organization_id: current_organization.id,
        exported_by: current_api_user.email,
        exported_at: Time.current.iso8601
      },
      usage_summary: calculate_usage_analytics(period),
      detailed_logs: ApiUsageLog.where(
        organization: current_organization,
        created_at: start_date..Time.current
      ).limit(10000).map do |log|
        {
          timestamp: log.created_at.iso8601,
          endpoint: log.endpoint,
          method: log.http_method,
          status_code: log.status_code,
          response_time_ms: log.response_time_ms,
          user_email: log.user&.email,
          api_key_name: log.api_key&.name
        }
      end
    }
  end

  def send_csv_export(data, period)
    csv_content = generate_csv_content(data)

    send_data csv_content,
              filename: "api_analytics_#{period}_#{Date.current}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  def generate_csv_content(data)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "Timestamp", "Endpoint", "Method", "Status Code", "Response Time (ms)", "User Email", "API Key" ]

      data[:detailed_logs].each do |log|
        csv << [
          log[:timestamp],
          log[:endpoint],
          log[:method],
          log[:status_code],
          log[:response_time_ms],
          log[:user_email],
          log[:api_key_name]
        ]
      end
    end
  end

  def generate_performance_recommendations(performance_data)
    recommendations = []

    if performance_data[:response_times][:average] && performance_data[:response_times][:average] > 500
      recommendations << {
        type: "performance",
        priority: "high",
        issue: "High average response time",
        recommendation: "Consider optimizing database queries and implementing caching",
        impact: "Improved user experience and reduced server load"
      }
    end

    if performance_data[:error_analysis][:total_errors] > 100
      recommendations << {
        type: "reliability",
        priority: "high",
        issue: "High error rate detected",
        recommendation: "Review error logs and implement better error handling",
        impact: "Reduced error rates and improved API reliability"
      }
    end

    recommendations
  end

  def generate_trend_insights(trends_data, metric)
    return [] if trends_data.empty?

    values = trends_data.map { |point| point[:value] }
    recent_values = values.last(7)
    older_values = values.first(7)

    insights = []

    if recent_values.sum > older_values.sum * 1.2
      insights << "#{metric.humanize} has increased significantly in recent periods"
    elsif recent_values.sum < older_values.sum * 0.8
      insights << "#{metric.humanize} has decreased in recent periods"
    else
      insights << "#{metric.humanize} remains relatively stable"
    end

    insights
  end

  def calculate_median_response_time(logs)
    times = logs.pluck(:response_time_ms).compact.sort
    return 0 if times.empty?

    mid = times.length / 2
    times.length.odd? ? times[mid] : (times[mid - 1] + times[mid]) / 2.0
  end

  def calculate_percentile_response_time(logs, percentile)
    times = logs.pluck(:response_time_ms).compact.sort
    return 0 if times.empty?

    index = ((percentile / 100.0) * (times.length - 1)).round
    times[index]
  end

  def format_time_point(time_point, granularity)
    case granularity
    when "hourly"
      time_point.strftime("%m/%d %H:%M")
    when "daily"
      time_point.strftime("%m/%d/%Y")
    when "weekly"
      "Week of #{time_point.strftime('%m/%d/%Y')}"
    else
      time_point.strftime("%m/%d/%Y")
    end
  end
end
