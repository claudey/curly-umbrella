# frozen_string_literal: true

class ApiUsageTrackingService
  class << self
    # Track API request for analytics
    def track_request(api_key:, endpoint:, action:, request_data: {})
      # Create usage log entry
      usage_log = create_usage_log(api_key, endpoint, action, request_data)

      # Update real-time metrics
      update_real_time_metrics(api_key, endpoint, action)

      # Update API key last used timestamp
      api_key.touch(:last_used_at)

      # Check for usage patterns and alerts
      check_usage_patterns(api_key, endpoint, action)

      usage_log
    end

    # Get usage analytics for organization
    def organization_analytics(organization, period: 30.days)
      end_time = Time.current
      start_time = end_time - period

      api_keys = organization.api_keys.active
      logs = ApiUsageLog.joins(:api_key)
                       .where(api_keys: { organization: organization })
                       .where(created_at: start_time..end_time)

      {
        period: {
          start: start_time.iso8601,
          end: end_time.iso8601,
          days: period.in_days.round
        },
        summary: {
          total_requests: logs.count,
          total_api_keys: api_keys.count,
          active_api_keys: logs.distinct.count(:api_key_id),
          unique_endpoints: logs.distinct.count(:endpoint),
          success_rate: calculate_success_rate(logs),
          average_response_time: logs.average(:response_time)&.round(2)
        },
        breakdown: {
          by_day: logs.group_by_day(:created_at).count,
          by_endpoint: logs.group(:endpoint).count.sort_by { |_, count| -count }.first(10),
          by_action: logs.group(:action).count,
          by_api_key: logs.joins(:api_key).group("api_keys.name").count.sort_by { |_, count| -count }.first(10),
          by_status_code: logs.group(:status_code).count,
          by_hour: logs.group_by_hour_of_day(:created_at).count
        },
        performance: {
          response_time_percentiles: calculate_response_time_percentiles(logs),
          slowest_endpoints: logs.group(:endpoint)
                                .average(:response_time)
                                .sort_by { |_, time| -time.to_f }
                                .first(5)
                                .to_h,
          error_rate_by_endpoint: calculate_error_rates_by_endpoint(logs)
        },
        trends: {
          growth_rate: calculate_growth_rate(logs, period),
          peak_usage_hours: identify_peak_hours(logs),
          usage_forecast: forecast_usage(logs)
        }
      }
    end

    # Get usage analytics for specific API key
    def api_key_analytics(api_key, period: 30.days)
      end_time = Time.current
      start_time = end_time - period

      logs = api_key.api_usage_logs.where(created_at: start_time..end_time)

      {
        api_key: {
          id: api_key.id,
          name: api_key.name,
          tier: api_key.tier,
          created_at: api_key.created_at
        },
        period: {
          start: start_time.iso8601,
          end: end_time.iso8601,
          days: period.in_days.round
        },
        usage: {
          total_requests: logs.count,
          successful_requests: logs.where(status_code: 200..299).count,
          failed_requests: logs.where(status_code: 400..599).count,
          unique_endpoints: logs.distinct.count(:endpoint),
          average_requests_per_day: logs.count / period.in_days,
          last_activity: logs.maximum(:created_at)
        },
        patterns: {
          most_used_endpoints: logs.group(:endpoint).count.sort_by { |_, count| -count }.first(5),
          usage_by_day: logs.group_by_day(:created_at).count,
          usage_by_hour: logs.group_by_hour_of_day(:created_at).count,
          busiest_day: logs.group_by_day(:created_at).count.max_by { |_, count| count },
          quiet_periods: identify_quiet_periods(logs)
        },
        performance: {
          average_response_time: logs.average(:response_time)&.round(2),
          response_time_trend: logs.group_by_day(:created_at)
                                  .average(:response_time)
                                  .transform_values { |time| time&.round(2) },
          error_rate: calculate_error_rate(logs),
          rate_limit_hits: count_rate_limit_hits(api_key, start_time, end_time)
        },
        compliance: {
          rate_limit_compliance: calculate_rate_limit_compliance(api_key, logs),
          security_score: calculate_security_score(api_key, logs),
          data_access_patterns: analyze_data_access_patterns(logs)
        }
      }
    end

    # Get real-time API health dashboard
    def real_time_dashboard
      current_hour = Time.current.beginning_of_hour
      last_hour = 1.hour.ago.beginning_of_hour

      current_requests = ApiUsageLog.where(created_at: current_hour..Time.current)
      last_hour_requests = ApiUsageLog.where(created_at: last_hour..current_hour)

      {
        timestamp: Time.current.iso8601,
        current_hour: {
          total_requests: current_requests.count,
          success_rate: calculate_success_rate(current_requests),
          average_response_time: current_requests.average(:response_time)&.round(2),
          active_api_keys: current_requests.distinct.count(:api_key_id),
          top_endpoints: current_requests.group(:endpoint).count.sort_by { |_, count| -count }.first(5)
        },
        last_hour: {
          total_requests: last_hour_requests.count,
          success_rate: calculate_success_rate(last_hour_requests),
          average_response_time: last_hour_requests.average(:response_time)&.round(2)
        },
        comparison: {
          request_change: calculate_percentage_change(last_hour_requests.count, current_requests.count),
          response_time_change: calculate_response_time_change(last_hour_requests, current_requests)
        },
        system_health: {
          api_availability: calculate_api_availability,
          error_rate: calculate_current_error_rate,
          rate_limit_violations: count_recent_rate_limit_violations,
          security_alerts: count_recent_security_alerts
        },
        alerts: generate_real_time_alerts
      }
    end

    # Export usage data for external analysis
    def export_usage_data(organization, format: "csv", period: 30.days)
      end_time = Time.current
      start_time = end_time - period

      logs = ApiUsageLog.joins(:api_key)
                       .where(api_keys: { organization: organization })
                       .where(created_at: start_time..end_time)
                       .includes(:api_key)

      case format.to_s.downcase
      when "csv"
        generate_csv_export(logs)
      when "json"
        generate_json_export(logs)
      else
        raise ArgumentError, "Unsupported export format: #{format}"
      end
    end

    private

    def create_usage_log(api_key, endpoint, action, request_data)
      ApiUsageLog.create!(
        api_key: api_key,
        endpoint: endpoint,
        action: action,
        method: request_data[:method],
        status_code: request_data[:status_code] || 200,
        response_time: request_data[:response_time],
        ip_address: request_data[:ip_address],
        user_agent: request_data[:user_agent],
        request_size: request_data[:request_size],
        response_size: request_data[:response_size],
        metadata: request_data[:metadata] || {}
      )
    rescue => e
      Rails.logger.error "Failed to create API usage log: #{e.message}"
      nil
    end

    def update_real_time_metrics(api_key, endpoint, action)
      # Update Redis counters for real-time analytics
      current_hour = Time.current.strftime("%Y%m%d%H")

      Redis.current.multi do |redis|
        redis.incr("api_requests:#{current_hour}")
        redis.incr("api_requests:org:#{api_key.organization_id}:#{current_hour}")
        redis.incr("api_requests:key:#{api_key.id}:#{current_hour}")
        redis.incr("api_requests:endpoint:#{endpoint}:#{current_hour}")
        redis.expire("api_requests:#{current_hour}", 25.hours)
        redis.expire("api_requests:org:#{api_key.organization_id}:#{current_hour}", 25.hours)
        redis.expire("api_requests:key:#{api_key.id}:#{current_hour}", 25.hours)
        redis.expire("api_requests:endpoint:#{endpoint}:#{current_hour}", 25.hours)
      end
    rescue => e
      Rails.logger.error "Failed to update real-time metrics: #{e.message}"
    end

    def check_usage_patterns(api_key, endpoint, action)
      # Check for suspicious patterns or anomalies
      recent_requests = api_key.api_usage_logs.where(created_at: 1.hour.ago..Time.current).count

      # Check for unusual spike in requests
      if recent_requests > 100 # Configurable threshold
        create_usage_alert(api_key, "high_usage_spike", {
          recent_requests: recent_requests,
          endpoint: endpoint,
          timeframe: "1 hour"
        })
      end

      # Check for repeated failures
      recent_failures = api_key.api_usage_logs
                              .where(created_at: 10.minutes.ago..Time.current)
                              .where(status_code: 400..599)
                              .count

      if recent_failures > 10 # Configurable threshold
        create_usage_alert(api_key, "high_error_rate", {
          recent_failures: recent_failures,
          endpoint: endpoint,
          timeframe: "10 minutes"
        })
      end
    end

    def create_usage_alert(api_key, alert_type, details)
      # Create alert for unusual usage patterns
      SecurityAlert.create!(
        organization: api_key.organization,
        alert_type: alert_type,
        severity: "medium",
        source: "api_usage_monitoring",
        details: details.merge({
          api_key_id: api_key.id,
          api_key_name: api_key.name
        }),
        metadata: {
          auto_generated: true,
          monitoring_system: "api_analytics"
        }
      )
    rescue => e
      Rails.logger.error "Failed to create usage alert: #{e.message}"
    end

    def calculate_success_rate(logs)
      return 0 if logs.empty?

      successful = logs.where(status_code: 200..299).count
      total = logs.count
      ((successful.to_f / total) * 100).round(2)
    end

    def calculate_error_rate(logs)
      return 0 if logs.empty?

      errors = logs.where(status_code: 400..599).count
      total = logs.count
      ((errors.to_f / total) * 100).round(2)
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

    def calculate_error_rates_by_endpoint(logs)
      logs.group(:endpoint).group(:status_code).count
          .group_by { |(endpoint, _), _| endpoint }
          .transform_values do |status_counts|
            total = status_counts.values.sum
            errors = status_counts.select { |(_, status), _| status >= 400 }.values.sum
            ((errors.to_f / total) * 100).round(2)
          end
    end

    def calculate_growth_rate(logs, period)
      mid_point = period.ago / 2
      first_half = logs.where(created_at: period.ago..mid_point).count
      second_half = logs.where(created_at: mid_point..Time.current).count

      return 0 if first_half.zero?

      ((second_half - first_half).to_f / first_half * 100).round(2)
    end

    def identify_peak_hours(logs)
      logs.group_by_hour_of_day(:created_at)
          .count
          .sort_by { |_, count| -count }
          .first(3)
          .map { |hour, count| { hour: hour, requests: count } }
    end

    def forecast_usage(logs)
      # Simple linear regression for usage forecasting
      daily_counts = logs.group_by_day(:created_at).count.values
      return nil if daily_counts.length < 7

      # Calculate trend
      x_values = (1..daily_counts.length).to_a
      y_values = daily_counts

      n = x_values.length
      sum_x = x_values.sum
      sum_y = y_values.sum
      sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum
      sum_x2 = x_values.map { |x| x * x }.sum

      slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x2 - sum_x * sum_x)
      intercept = (sum_y - slope * sum_x).to_f / n

      # Forecast next 7 days
      next_week = (1..7).map do |day|
        next_x = daily_counts.length + day
        predicted = (slope * next_x + intercept).round
        {
          date: day.days.from_now.to_date,
          predicted_requests: [ predicted, 0 ].max
        }
      end

      {
        trend: slope > 0 ? "increasing" : (slope < 0 ? "decreasing" : "stable"),
        confidence: calculate_forecast_confidence(x_values, y_values, slope, intercept),
        next_7_days: next_week
      }
    end

    def calculate_forecast_confidence(x_values, y_values, slope, intercept)
      # Calculate R-squared for forecast confidence
      y_mean = y_values.sum.to_f / y_values.length

      ss_tot = y_values.map { |y| (y - y_mean) ** 2 }.sum
      ss_res = x_values.zip(y_values).map do |x, y|
        predicted = slope * x + intercept
        (y - predicted) ** 2
      end.sum

      r_squared = 1 - (ss_res.to_f / ss_tot)
      (r_squared * 100).round(2)
    end

    def generate_csv_export(logs)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [
          "Timestamp", "API Key", "Endpoint", "Action", "Method",
          "Status Code", "Response Time (ms)", "IP Address", "User Agent"
        ]

        logs.find_each do |log|
          csv << [
            log.created_at.iso8601,
            log.api_key.name,
            log.endpoint,
            log.action,
            log.method,
            log.status_code,
            log.response_time,
            log.ip_address,
            log.user_agent
          ]
        end
      end
    end

    def generate_json_export(logs)
      {
        export_timestamp: Time.current.iso8601,
        total_records: logs.count,
        data: logs.limit(10000).map do |log| # Limit for performance
          {
            timestamp: log.created_at.iso8601,
            api_key: log.api_key.name,
            endpoint: log.endpoint,
            action: log.action,
            method: log.method,
            status_code: log.status_code,
            response_time_ms: log.response_time,
            ip_address: log.ip_address,
            user_agent: log.user_agent,
            metadata: log.metadata
          }
        end
      }.to_json
    end

    def calculate_api_availability
      # Calculate API availability based on successful requests
      last_hour_logs = ApiUsageLog.where(created_at: 1.hour.ago..Time.current)
      return 100 if last_hour_logs.empty?

      success_rate = calculate_success_rate(last_hour_logs)
      success_rate
    end

    def calculate_current_error_rate
      last_15_min_logs = ApiUsageLog.where(created_at: 15.minutes.ago..Time.current)
      calculate_error_rate(last_15_min_logs)
    end

    def count_recent_rate_limit_violations
      # Count rate limit violations in the last hour
      AuditLog.where(
        action: "api_rate_limit_exceeded",
        created_at: 1.hour.ago..Time.current
      ).count
    end

    def count_recent_security_alerts
      SecurityAlert.where(
        source: "api_usage_monitoring",
        created_at: 1.hour.ago..Time.current,
        status: "active"
      ).count
    end

    def generate_real_time_alerts
      alerts = []

      # Check for high error rate
      current_error_rate = calculate_current_error_rate
      if current_error_rate > 10 # Configurable threshold
        alerts << {
          type: "high_error_rate",
          severity: "warning",
          message: "API error rate is #{current_error_rate}% in the last 15 minutes",
          threshold: 10
        }
      end

      # Check for low availability
      availability = calculate_api_availability
      if availability < 95 # Configurable threshold
        alerts << {
          type: "low_availability",
          severity: "critical",
          message: "API availability is #{availability}% in the last hour",
          threshold: 95
        }
      end

      alerts
    end
  end
end
