# frozen_string_literal: true

class BusinessMetric < ApplicationRecord
  belongs_to :organization, optional: true

  validates :metric_name, presence: true
  validates :metric_value, presence: true, numericality: true
  validates :metric_unit, presence: true
  validates :metric_category, presence: true
  validates :recorded_at, presence: true
  validates :period_hours, presence: true, numericality: { greater_than: 0 }

  scope :recent, -> { order(recorded_at: :desc) }
  scope :by_metric, ->(name) { where(metric_name: name) }
  scope :by_category, ->(category) { where(metric_category: category) }
  scope :by_organization, ->(org) { where(organization: org) }
  scope :in_period, ->(start_time, end_time) { where(recorded_at: start_time..end_time) }
  scope :for_period_hours, ->(hours) { where(period_hours: hours) }

  # Store metadata as JSON
  serialize :metadata, JSON

  before_save :set_defaults
  after_create :update_metric_cache

  def metric_definition
    BusinessMetricsService::BUSINESS_KPIS[metric_name.to_sym]
  end

  def display_name
    metric_definition&.dig(:name) || metric_name.humanize
  end

  def description
    metric_definition&.dig(:description) || "#{metric_name.humanize} metric"
  end

  def formatted_value
    case metric_unit
    when "currency"
      "$#{format('%.2f', metric_value)}"
    when "percentage"
      "#{format('%.2f', metric_value)}%"
    when "hours"
      "#{format('%.1f', metric_value)} hours"
    when "minutes"
      "#{format('%.1f', metric_value)} minutes"
    when "count"
      metric_value.to_i.to_s
    else
      format("%.2f", metric_value)
    end
  end

  def trend_direction
    return "neutral" unless metadata.present? && metadata["trend"]

    trend_value = metadata["trend"].to_f
    case
    when trend_value > 5 then "up_strong"
    when trend_value > 0 then "up"
    when trend_value < -5 then "down_strong"
    when trend_value < 0 then "down"
    else "neutral"
    end
  end

  def trend_icon
    case trend_direction
    when "up_strong" then "📈"
    when "up" then "↗️"
    when "down_strong" then "📉"
    when "down" then "↘️"
    else "➡️"
    end
  end

  def is_kpi_healthy?
    # Define healthy ranges for different metrics
    case metric_name
    when "application_approval_rate", "quote_conversion_rate", "document_compliance_rate"
      metric_value >= 70 # Above 70% is good
    when "user_activity_rate"
      metric_value >= 60 # Above 60% is good
    when "system_uptime"
      metric_value >= 99.0 # Above 99% uptime is good
    when "error_rate"
      metric_value <= 1.0 # Below 1% error rate is good
    when "average_processing_time", "quote_response_time"
      metric_value <= 24 # Less than 24 hours is good
    else
      true # Default to healthy for unknown metrics
    end
  end

  def health_status
    if is_kpi_healthy?
      trend_direction.in?([ "down", "down_strong" ]) ? "warning" : "healthy"
    else
      "critical"
    end
  end

  def health_color
    case health_status
    when "healthy" then "green"
    when "warning" then "yellow"
    when "critical" then "red"
    else "gray"
    end
  end

  # Class methods for analytics
  def self.latest_for_metric(metric_name, organization = nil)
    scope = by_metric(metric_name)
    scope = scope.by_organization(organization) if organization
    scope.recent.first
  end

  def self.trend_for_metric(metric_name, organization = nil, days: 7)
    scope = by_metric(metric_name)
    scope = scope.by_organization(organization) if organization

    metrics = scope.where("recorded_at > ?", days.days.ago)
                  .order(:recorded_at)

    return [] if metrics.empty?

    metrics.map do |metric|
      {
        date: metric.recorded_at.strftime("%Y-%m-%d"),
        value: metric.metric_value,
        formatted_value: metric.formatted_value
      }
    end
  end

  def self.category_summary(category, organization = nil)
    scope = by_category(category)
    scope = scope.by_organization(organization) if organization

    # Get latest metrics for each metric name in category
    latest_metrics = scope.select("DISTINCT ON (metric_name) *")
                         .order(:metric_name, recorded_at: :desc)

    {
      category: category,
      metrics_count: latest_metrics.count,
      healthy_count: latest_metrics.count(&:is_kpi_healthy?),
      average_trend: calculate_average_trend(latest_metrics),
      last_updated: latest_metrics.maximum(:recorded_at)
    }
  end

  def self.dashboard_summary(organization = nil)
    scope = organization ? by_organization(organization) : all

    # Get latest metrics grouped by category
    categories = scope.distinct.pluck(:metric_category)

    summary = {
      total_metrics: scope.distinct.count(:metric_name),
      categories: {},
      overall_health: "healthy",
      last_updated: scope.maximum(:recorded_at)
    }

    categories.each do |category|
      summary[:categories][category] = category_summary(category, organization)
    end

    # Determine overall health
    all_latest = scope.select("DISTINCT ON (metric_name) *")
                     .order(:metric_name, recorded_at: :desc)

    critical_count = all_latest.reject(&:is_kpi_healthy?).count
    total_count = all_latest.count

    if total_count > 0
      critical_percentage = (critical_count.to_f / total_count * 100)
      summary[:overall_health] = case critical_percentage
      when 0...10 then "healthy"
      when 10...30 then "warning"
      else "critical"
      end
    end

    summary
  end

  def self.performance_report(organization = nil, days: 30)
    scope = organization ? by_organization(organization) : all
    metrics = scope.where("recorded_at > ?", days.days.ago)

    {
      period_days: days,
      organization: organization&.name || "Global",
      metric_categories: metrics.group(:metric_category).count,
      top_performing_metrics: identify_top_performers(metrics),
      declining_metrics: identify_declining_metrics(metrics),
      stability_analysis: analyze_metric_stability(metrics),
      recommendations: generate_performance_recommendations(metrics)
    }
  end

  def self.cleanup_old_metrics(retention_days: 365)
    cutoff_date = retention_days.days.ago
    old_metrics = where("recorded_at < ?", cutoff_date)

    Rails.logger.info "Cleaning up #{old_metrics.count} old business metrics"
    old_metrics.delete_all
  end

  private

  def set_defaults
    self.recorded_at ||= Time.current
    self.metadata ||= {}
  end

  def update_metric_cache
    # Update Redis cache for real-time dashboards
    cache_key = "business_metric:#{metric_name}:#{organization_id || 'global'}"
    Rails.cache.write(cache_key, {
      value: metric_value,
      formatted_value: formatted_value,
      unit: metric_unit,
      trend: trend_direction,
      health: health_status,
      recorded_at: recorded_at
    }, expires_in: 1.hour)
  end

  def self.calculate_average_trend(metrics)
    trends = metrics.filter_map { |m| m.metadata&.dig("trend")&.to_f }
    return 0 if trends.empty?

    (trends.sum / trends.size).round(2)
  end

  def self.identify_top_performers(metrics)
    # Logic to identify metrics that are performing well
    metrics.select(&:is_kpi_healthy?)
           .select { |m| m.trend_direction.in?([ "up", "up_strong" ]) }
           .group_by(&:metric_name)
           .map { |name, group| { metric: name, count: group.size } }
           .sort_by { |item| -item[:count] }
           .first(5)
  end

  def self.identify_declining_metrics(metrics)
    # Logic to identify metrics that are declining
    metrics.select { |m| m.trend_direction.in?([ "down", "down_strong" ]) }
           .group_by(&:metric_name)
           .map { |name, group| { metric: name, count: group.size } }
           .sort_by { |item| -item[:count] }
           .first(5)
  end

  def self.analyze_metric_stability(metrics)
    # Analyze how stable metrics are over time
    stability = {}

    metrics.group_by(&:metric_name).each do |name, metric_group|
      values = metric_group.map(&:metric_value)
      next if values.size < 2

      # Calculate coefficient of variation as stability measure
      mean = values.sum / values.size.to_f
      variance = values.map { |v| (v - mean) ** 2 }.sum / values.size.to_f
      std_dev = Math.sqrt(variance)

      coefficient_of_variation = mean.zero? ? 0 : (std_dev / mean * 100).round(2)

      stability[name] = {
        coefficient_of_variation: coefficient_of_variation,
        stability_rating: case coefficient_of_variation
                          when 0...10 then "very_stable"
                          when 10...20 then "stable"
                          when 20...50 then "moderate"
                          else "volatile"
                          end
      }
    end

    stability
  end

  def self.generate_performance_recommendations(metrics)
    recommendations = []

    # Analyze patterns and generate recommendations
    declining_metrics = identify_declining_metrics(metrics)

    declining_metrics.each do |item|
      case item[:metric]
      when "application_approval_rate"
        recommendations << "Consider reviewing application quality and approval criteria"
      when "quote_conversion_rate"
        recommendations << "Analyze quote pricing strategy and competitive positioning"
      when "user_activity_rate"
        recommendations << "Implement user engagement initiatives and feature improvements"
      when "system_uptime"
        recommendations << "Investigate infrastructure issues and implement monitoring improvements"
      end
    end

    recommendations.uniq.first(10)
  end
end
