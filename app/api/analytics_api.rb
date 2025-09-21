# frozen_string_literal: true

class AnalyticsApi < Grape::API
  version "v1", using: :header, vendor: "brokersync"
  format :json

  resource :analytics do
    desc "Get API usage analytics", {
      summary: "Retrieve comprehensive API usage analytics",
      detail: "Returns detailed analytics about API usage patterns and performance",
      tags: [ "Analytics" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      optional :period_days, type: Integer, default: 30, desc: "Analysis period in days"
      optional :api_key_id, type: Integer, desc: "Filter by specific API key"
      optional :endpoint, type: String, desc: "Filter by specific endpoint"
    end
    get :usage do
      authenticate_api_request!
      authorize_api_action!("read_analytics")
      track_api_usage("analytics", "usage")

      period = params[:period_days].days

      if params[:api_key_id]
        # Single API key analytics
        api_key = current_organization.api_keys.find(params[:api_key_id])
        analytics = ApiUsageTrackingService.api_key_analytics(api_key, period: period)
      else
        # Organization-wide analytics
        analytics = ApiUsageTrackingService.organization_analytics(current_organization, period: period)
      end

      # Filter by endpoint if specified
      if params[:endpoint]
        analytics = filter_analytics_by_endpoint(analytics, params[:endpoint])
      end

      analytics
    end

    desc "Get real-time dashboard data", {
      summary: "Retrieve real-time API health and usage data",
      detail: "Returns current API performance metrics and system health indicators",
      tags: [ "Analytics" ],
      security: [ { bearer_token: [] } ]
    }
    get :dashboard do
      authenticate_api_request!
      authorize_api_action!("read_analytics")
      track_api_usage("analytics", "dashboard")

      dashboard_data = ApiUsageTrackingService.real_time_dashboard

      # Add organization-specific context
      org_context = {
        organization: {
          id: current_organization.id,
          name: current_organization.name,
          active_api_keys: current_organization.api_keys.active.count,
          total_api_keys: current_organization.api_keys.count
        },
        api_key_info: {
          current_key: {
            id: current_api_key.id,
            name: current_api_key.name,
            tier: current_api_key.tier,
            rate_limit: current_api_key.rate_limit_info
          }
        }
      }

      dashboard_data.merge(org_context)
    end

    desc "Get performance metrics", {
      summary: "Retrieve API performance metrics",
      detail: "Returns detailed performance analytics including response times and error rates",
      tags: [ "Analytics" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      optional :period_days, type: Integer, default: 7, desc: "Analysis period in days"
      optional :granularity, type: String, values: %w[hour day], default: "hour", desc: "Data granularity"
    end
    get :performance do
      authenticate_api_request!
      authorize_api_action!("read_analytics")
      track_api_usage("analytics", "performance")

      period = params[:period_days].days
      end_time = Time.current
      start_time = end_time - period

      logs = ApiUsageLog.joins(:api_key)
                       .where(api_keys: { organization: current_organization })
                       .where(created_at: start_time..end_time)

      granularity = params[:granularity] == "day" ? :day : :hour

      {
        period: {
          start: start_time.iso8601,
          end: end_time.iso8601,
          granularity: granularity
        },
        response_times: {
          timeline: logs.send("group_by_#{granularity}", :created_at)
                       .average(:response_time)
                       .transform_values { |time| time&.round(2) },
          percentiles: calculate_response_time_percentiles(logs),
          by_endpoint: logs.group(:endpoint)
                          .average(:response_time)
                          .transform_values { |time| time&.round(2) }
                          .sort_by { |_, time| -time.to_f }
                          .first(10)
                          .to_h
        },
        error_rates: {
          timeline: calculate_error_rate_timeline(logs, granularity),
          by_endpoint: calculate_error_rates_by_endpoint(logs),
          by_status_code: logs.group(:status_code).count
        },
        throughput: {
          timeline: logs.send("group_by_#{granularity}", :created_at).count,
          peak_periods: identify_peak_periods(logs, granularity),
          capacity_utilization: calculate_capacity_utilization(logs)
        }
      }
    end

    desc "Export usage data", {
      summary: "Export API usage data",
      detail: "Exports API usage data in various formats for external analysis",
      tags: [ "Analytics" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      optional :format, type: String, values: %w[csv json], default: "csv", desc: "Export format"
      optional :period_days, type: Integer, default: 30, desc: "Export period in days"
    end
    get :export do
      authenticate_api_request!
      authorize_api_action!("read_analytics")
      track_api_usage("analytics", "export")

      period = params[:period_days].days
      format = params[:format]

      # Log export activity
      AuditLog.create!(
        user: current_api_user,
        organization: current_organization,
        action: "api_analytics_exported",
        category: "data_export",
        severity: "info",
        details: {
          api_key_id: current_api_key.id,
          format: format,
          period_days: params[:period_days],
          exported_at: Time.current
        }
      )

      exported_data = ApiUsageTrackingService.export_usage_data(
        current_organization,
        format: format,
        period: period
      )

      {
        export_info: {
          format: format,
          period_days: params[:period_days],
          generated_at: Time.current.iso8601,
          organization: current_organization.name
        },
        download_url: "/api/v1/analytics/download/#{generate_download_token}",
        expires_at: 1.hour.from_now.iso8601,
        data: format == "json" ? JSON.parse(exported_data) : nil,
        csv_preview: format == "csv" ? exported_data.lines.first(5).join : nil
      }
    end

    desc "Get top performing endpoints", {
      summary: "Retrieve top performing API endpoints",
      detail: "Returns analytics for the most frequently used and best performing endpoints",
      tags: [ "Analytics" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      optional :period_days, type: Integer, default: 7, desc: "Analysis period in days"
      optional :limit, type: Integer, default: 10, desc: "Number of endpoints to return"
      optional :sort_by, type: String, values: %w[usage performance reliability], default: "usage", desc: "Sorting criteria"
    end
    get :top_endpoints do
      authenticate_api_request!
      authorize_api_action!("read_analytics")
      track_api_usage("analytics", "top_endpoints")

      period = params[:period_days].days
      limit = params[:limit]
      sort_by = params[:sort_by]

      end_time = Time.current
      start_time = end_time - period

      logs = ApiUsageLog.joins(:api_key)
                       .where(api_keys: { organization: current_organization })
                       .where(created_at: start_time..end_time)

      endpoint_stats = logs.group(:endpoint).group(:status_code).count
                          .group_by { |(endpoint, _), _| endpoint }
                          .map do |endpoint, status_counts|
        total_requests = status_counts.values.sum
        successful_requests = status_counts.select { |(_, status), _| status < 400 }.values.sum
        success_rate = ((successful_requests.to_f / total_requests) * 100).round(2)

        endpoint_logs = logs.where(endpoint: endpoint)
        avg_response_time = endpoint_logs.average(:response_time)&.round(2) || 0

        performance_score = calculate_performance_score(success_rate, avg_response_time)

        {
          endpoint: endpoint,
          total_requests: total_requests,
          success_rate: success_rate,
          average_response_time: avg_response_time,
          performance_score: performance_score,
          first_seen: endpoint_logs.minimum(:created_at),
          last_used: endpoint_logs.maximum(:created_at),
          unique_api_keys: endpoint_logs.distinct.count(:api_key_id)
        }
      end

      # Sort based on criteria
      sorted_endpoints = case sort_by
      when "performance"
                          endpoint_stats.sort_by { |stat| -stat[:performance_score] }
      when "reliability"
                          endpoint_stats.sort_by { |stat| -stat[:success_rate] }
      else # 'usage'
                          endpoint_stats.sort_by { |stat| -stat[:total_requests] }
      end

      {
        period: {
          start: start_time.iso8601,
          end: end_time.iso8601,
          days: period.in_days.round
        },
        sort_criteria: sort_by,
        endpoints: sorted_endpoints.first(limit)
      }
    end

    desc "Get API usage trends", {
      summary: "Retrieve API usage trends and forecasts",
      detail: "Returns trend analysis and usage forecasting data",
      tags: [ "Analytics" ],
      security: [ { bearer_token: [] } ]
    }
    params do
      optional :period_days, type: Integer, default: 30, desc: "Analysis period in days"
    end
    get :trends do
      authenticate_api_request!
      authorize_api_action!("read_analytics")
      track_api_usage("analytics", "trends")

      period = params[:period_days].days
      analytics = ApiUsageTrackingService.organization_analytics(current_organization, period: period)

      {
        trends: analytics[:trends],
        growth_analysis: {
          daily_growth: analytics[:trends][:growth_rate],
          peak_usage: analytics[:trends][:peak_usage_hours],
          forecast: analytics[:trends][:usage_forecast]
        },
        seasonal_patterns: analyze_seasonal_patterns(current_organization, period),
        recommendations: generate_usage_recommendations(analytics)
      }
    end

    private

    def filter_analytics_by_endpoint(analytics, endpoint)
      # Filter analytics data to show only the specified endpoint
      filtered = analytics.deep_dup

      if filtered[:breakdown]
        filtered[:breakdown][:by_endpoint] = { endpoint => filtered[:breakdown][:by_endpoint][endpoint] || 0 }
      end

      if filtered[:performance]
        filtered[:performance][:slowest_endpoints] = filtered[:performance][:slowest_endpoints].select { |ep, _| ep == endpoint }
        filtered[:performance][:error_rate_by_endpoint] = filtered[:performance][:error_rate_by_endpoint].select { |ep, _| ep == endpoint }
      end

      filtered
    end

    def calculate_response_time_percentiles(logs)
      response_times = logs.where.not(response_time: nil).pluck(:response_time).sort
      return {} if response_times.empty?

      {
        p50: percentile(response_times, 50),
        p75: percentile(response_times, 75),
        p90: percentile(response_times, 90),
        p95: percentile(response_times, 95),
        p99: percentile(response_times, 99)
      }
    end

    def percentile(array, percentile)
      return 0 if array.empty?

      index = (percentile / 100.0) * (array.length - 1)
      if index == index.to_i
        array[index.to_i]
      else
        lower = array[index.floor]
        upper = array[index.ceil]
        lower + (upper - lower) * (index - index.floor)
      end.round(2)
    end

    def calculate_error_rate_timeline(logs, granularity)
      logs.send("group_by_#{granularity}", :created_at)
          .group(:status_code)
          .count
          .group_by { |(time, _), _| time }
          .transform_values do |status_counts|
            total = status_counts.values.sum
            errors = status_counts.select { |(_, status), _| status >= 400 }.values.sum
            ((errors.to_f / total) * 100).round(2)
          end
    end

    def calculate_error_rates_by_endpoint(logs)
      logs.group(:endpoint).group(:status_code).count
          .group_by { |(endpoint, _), _| endpoint }
          .transform_values do |status_counts|
            total = status_counts.values.sum
            errors = status_counts.select { |(_, status), _| status >= 400 }.values.sum
            ((errors.to_f / total) * 100).round(2)
          end
    end

    def identify_peak_periods(logs, granularity)
      timeline = logs.send("group_by_#{granularity}", :created_at).count
      average = timeline.values.sum.to_f / timeline.size

      timeline.select { |_, count| count > average * 1.5 }
              .sort_by { |_, count| -count }
              .first(5)
              .map { |time, count| { time: time, requests: count, multiplier: (count / average).round(2) } }
    end

    def calculate_capacity_utilization(logs)
      # Estimate capacity utilization based on peak usage
      peak_hour_requests = logs.group_by_hour(:created_at).count.values.max || 0

      # Assume capacity based on tier (this should be configurable)
      tier_capacities = {
        "basic" => 1000,
        "standard" => 5000,
        "premium" => 20000,
        "enterprise" => 100000
      }

      max_capacity = tier_capacities[current_api_key.tier] || 1000
      utilization = ((peak_hour_requests.to_f / max_capacity) * 100).round(2)

      {
        peak_hour_requests: peak_hour_requests,
        estimated_capacity: max_capacity,
        utilization_percentage: utilization,
        status: case utilization
                when 0..50 then "low"
                when 50..75 then "moderate"
                when 75..90 then "high"
                else "critical"
                end
      }
    end

    def calculate_performance_score(success_rate, avg_response_time)
      # Calculate a performance score based on success rate and response time
      success_weight = 0.7
      speed_weight = 0.3

      # Normalize response time (assuming 1000ms as poor, 100ms as excellent)
      speed_score = [ 100 - (avg_response_time / 10), 0 ].max

      (success_rate * success_weight + speed_score * speed_weight).round(2)
    end

    def analyze_seasonal_patterns(organization, period)
      # Analyze usage patterns by day of week and hour
      logs = ApiUsageLog.joins(:api_key)
                       .where(api_keys: { organization: organization })
                       .where(created_at: period.ago..Time.current)

      {
        by_day_of_week: logs.group_by_day_of_week(:created_at).count,
        by_hour_of_day: logs.group_by_hour_of_day(:created_at).count,
        busiest_day: logs.group_by_day_of_week(:created_at).count.max_by { |_, count| count }&.first,
        busiest_hour: logs.group_by_hour_of_day(:created_at).count.max_by { |_, count| count }&.first,
        quietest_periods: identify_quiet_periods(logs)
      }
    end

    def identify_quiet_periods(logs)
      hourly_usage = logs.group_by_hour_of_day(:created_at).count
      average_usage = hourly_usage.values.sum.to_f / hourly_usage.size

      hourly_usage.select { |_, count| count < average_usage * 0.3 }
                  .sort_by { |_, count| count }
                  .first(3)
                  .map { |hour, count| { hour: hour, requests: count } }
    end

    def generate_usage_recommendations(analytics)
      recommendations = []

      # High error rate recommendation
      if analytics[:summary][:success_rate] < 95
        recommendations << {
          type: "error_rate",
          priority: "high",
          message: "API error rate is above 5%. Review error patterns and improve error handling.",
          action: "Review error logs and optimize endpoints with high failure rates"
        }
      end

      # Slow response time recommendation
      avg_response_time = analytics[:summary][:average_response_time] || 0
      if avg_response_time > 1000 # 1 second
        recommendations << {
          type: "performance",
          priority: "medium",
          message: "Average response time is above 1 second. Consider optimization.",
          action: "Optimize slow endpoints and consider caching strategies"
        }
      end

      # Usage growth recommendation
      if analytics[:trends][:growth_rate] > 50
        recommendations << {
          type: "scaling",
          priority: "medium",
          message: "API usage is growing rapidly. Plan for scaling.",
          action: "Review capacity planning and consider upgrading API tier"
        }
      end

      recommendations
    end

    def generate_download_token
      # Generate a secure token for file downloads
      SecureRandom.urlsafe_base64(32)
    end
  end
end
