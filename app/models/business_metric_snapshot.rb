# frozen_string_literal: true

class BusinessMetricSnapshot < ApplicationRecord
  belongs_to :organization, optional: true
  
  validates :snapshot_timestamp, presence: true
  validates :period_hours, presence: true, numericality: { greater_than: 0 }
  validates :metrics_data, presence: true
  
  scope :recent, -> { order(snapshot_timestamp: :desc) }
  scope :by_organization, ->(org) { where(organization: org) }
  scope :for_period, ->(hours) { where(period_hours: hours) }
  scope :in_timeframe, ->(start_time, end_time) { where(snapshot_timestamp: start_time..end_time) }
  
  # Store metrics data as JSON
  serialize :metrics_data, JSON
  
  before_save :calculate_summary_stats
  after_create :cache_latest_snapshot
  
  def healthy_metrics_count
    return 0 unless metrics_data.present?
    
    metrics_data.count do |_metric_name, metric_data|
      next false if metric_data.is_a?(Hash) && metric_data['error']
      
      # Determine if metric is healthy based on its value and type
      value = metric_data.is_a?(Hash) ? metric_data['value'] : metric_data
      next false unless value.is_a?(Numeric)
      
      # Use the same health logic as BusinessMetric
      true # Simplified for now
    end
  end
  
  def total_metrics_count
    return 0 unless metrics_data.present?
    
    metrics_data.count { |_name, data| data.is_a?(Hash) && !data['error'] }
  end
  
  def error_metrics_count
    return 0 unless metrics_data.present?
    
    metrics_data.count { |_name, data| data.is_a?(Hash) && data['error'] }
  end
  
  def health_percentage
    return 0 if total_metrics_count.zero?
    
    (healthy_metrics_count.to_f / total_metrics_count * 100).round(2)
  end
  
  def health_status
    case health_percentage
    when 90..100 then 'excellent'
    when 75..89 then 'good'
    when 60..74 then 'fair'
    when 40..59 then 'poor'
    else 'critical'
    end
  end
  
  def metrics_by_category
    return {} unless metrics_data.present?
    
    categorized = {}
    
    metrics_data.each do |metric_name, metric_data|
      next if metric_data.is_a?(Hash) && metric_data['error']
      
      category = BusinessMetricsService::BUSINESS_KPIS.dig(metric_name.to_sym, :category) || 'other'
      categorized[category] ||= {}
      categorized[category][metric_name] = metric_data
    end
    
    categorized
  end
  
  def get_metric_value(metric_name)
    metric_data = metrics_data[metric_name.to_s]
    return nil unless metric_data
    
    if metric_data.is_a?(Hash)
      metric_data['value']
    else
      metric_data
    end
  end
  
  def get_metric_trend(metric_name)
    metric_data = metrics_data[metric_name.to_s]
    return nil unless metric_data.is_a?(Hash)
    
    metric_data['trend']
  end
  
  def compare_with_previous
    previous_snapshot = self.class.where(organization: organization)
                                 .where(period_hours: period_hours)
                                 .where('snapshot_timestamp < ?', snapshot_timestamp)
                                 .recent
                                 .first
    
    return nil unless previous_snapshot
    
    comparison = {
      timeframe: "#{snapshot_timestamp} vs #{previous_snapshot.snapshot_timestamp}",
      metrics_comparison: {},
      summary: {
        improved_metrics: 0,
        declined_metrics: 0,
        stable_metrics: 0
      }
    }
    
    metrics_data.each do |metric_name, current_data|
      next if current_data.is_a?(Hash) && current_data['error']
      
      previous_data = previous_snapshot.metrics_data[metric_name]
      next if previous_data.is_a?(Hash) && previous_data['error']
      
      current_value = current_data.is_a?(Hash) ? current_data['value'] : current_data
      previous_value = previous_data.is_a?(Hash) ? previous_data['value'] : previous_data
      
      next unless current_value.is_a?(Numeric) && previous_value.is_a?(Numeric)
      
      change = current_value - previous_value
      change_percentage = previous_value.zero? ? 0 : (change / previous_value * 100).round(2)
      
      comparison[:metrics_comparison][metric_name] = {
        current_value: current_value,
        previous_value: previous_value,
        change: change.round(2),
        change_percentage: change_percentage,
        direction: case change
                  when 0 then 'stable'
                  when Float::INFINITY..-0.01 then 'declined'
                  else 'improved'
                  end
      }
      
      # Update summary counts
      case comparison[:metrics_comparison][metric_name][:direction]
      when 'improved'
        comparison[:summary][:improved_metrics] += 1
      when 'declined'
        comparison[:summary][:declined_metrics] += 1
      else
        comparison[:summary][:stable_metrics] += 1
      end
    end
    
    comparison
  end
  
  def export_to_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Metric Name', 'Category', 'Value', 'Unit', 'Trend', 'Metadata']
      
      metrics_data.each do |metric_name, metric_data|
        next if metric_data.is_a?(Hash) && metric_data['error']
        
        definition = BusinessMetricsService::BUSINESS_KPIS[metric_name.to_sym]
        value = metric_data.is_a?(Hash) ? metric_data['value'] : metric_data
        trend = metric_data.is_a?(Hash) ? metric_data['trend'] : nil
        metadata = metric_data.is_a?(Hash) ? metric_data['metadata'] : {}
        
        csv << [
          metric_name,
          definition&.dig(:category) || 'unknown',
          value,
          definition&.dig(:unit) || 'count',
          trend,
          metadata.to_json
        ]
      end
    end
  end
  
  def self.latest_for_organization(organization = nil)
    scope = organization ? by_organization(organization) : all
    scope.recent.first
  end
  
  def self.health_trend(organization = nil, days: 30)
    scope = organization ? by_organization(organization) : all
    snapshots = scope.where('snapshot_timestamp > ?', days.days.ago)
                    .order(:snapshot_timestamp)
    
    snapshots.map do |snapshot|
      {
        timestamp: snapshot.snapshot_timestamp,
        health_percentage: snapshot.health_percentage,
        total_metrics: snapshot.total_metrics_count,
        healthy_metrics: snapshot.healthy_metrics_count
      }
    end
  end
  
  def self.generate_executive_summary(organization = nil, period: 7.days)
    scope = organization ? by_organization(organization) : all
    snapshots = scope.where('snapshot_timestamp > ?', period.ago)
                    .order(:snapshot_timestamp)
    
    return nil if snapshots.empty?
    
    latest_snapshot = snapshots.last
    first_snapshot = snapshots.first
    
    {
      organization: organization&.name || 'Global',
      period: "#{period.ago.strftime('%Y-%m-%d')} to #{Time.current.strftime('%Y-%m-%d')}",
      current_health: {
        percentage: latest_snapshot.health_percentage,
        status: latest_snapshot.health_status,
        total_metrics: latest_snapshot.total_metrics_count
      },
      trend: {
        health_change: (latest_snapshot.health_percentage - first_snapshot.health_percentage).round(2),
        metric_count_change: latest_snapshot.total_metrics_count - first_snapshot.total_metrics_count
      },
      key_metrics: extract_key_metrics(latest_snapshot),
      recommendations: generate_executive_recommendations(snapshots)
    }
  end
  
  def self.cleanup_old_snapshots(retention_days: 90)
    cutoff_date = retention_days.days.ago
    old_snapshots = where('snapshot_timestamp < ?', cutoff_date)
    
    Rails.logger.info "Cleaning up #{old_snapshots.count} old metric snapshots"
    old_snapshots.delete_all
  end
  
  private
  
  def calculate_summary_stats
    return unless metrics_data.present?
    
    self.summary_stats = {
      total_metrics: total_metrics_count,
      healthy_metrics: healthy_metrics_count,
      error_metrics: error_metrics_count,
      health_percentage: health_percentage,
      health_status: health_status,
      categories: metrics_by_category.keys,
      calculated_at: Time.current
    }
  end
  
  def cache_latest_snapshot
    cache_key = "latest_metric_snapshot:#{organization_id || 'global'}"
    Rails.cache.write(cache_key, {
      id: id,
      timestamp: snapshot_timestamp,
      health_percentage: health_percentage,
      health_status: health_status,
      total_metrics: total_metrics_count
    }, expires_in: 1.hour)
  end
  
  def self.extract_key_metrics(snapshot)
    key_metric_names = [
      'application_volume',
      'application_approval_rate',
      'quote_conversion_rate',
      'user_activity_rate',
      'system_uptime'
    ]
    
    key_metrics = {}
    
    key_metric_names.each do |metric_name|
      value = snapshot.get_metric_value(metric_name)
      trend = snapshot.get_metric_trend(metric_name)
      
      if value
        definition = BusinessMetricsService::BUSINESS_KPIS[metric_name.to_sym]
        key_metrics[metric_name] = {
          value: value,
          trend: trend,
          unit: definition&.dig(:unit),
          name: definition&.dig(:name)
        }
      end
    end
    
    key_metrics
  end
  
  def self.generate_executive_recommendations(snapshots)
    recommendations = []
    
    return recommendations if snapshots.size < 2
    
    latest = snapshots.last
    previous = snapshots[-2]
    
    # Compare health trends
    health_change = latest.health_percentage - previous.health_percentage
    
    if health_change < -10
      recommendations << "Significant decline in overall metrics health. Immediate review recommended."
    elsif health_change < -5
      recommendations << "Metrics health is declining. Monitor closely and investigate root causes."
    elsif health_change > 10
      recommendations << "Excellent improvement in metrics health. Document successful practices."
    end
    
    # Analyze specific metric trends
    if latest.get_metric_value('application_approval_rate').to_f < 60
      recommendations << "Application approval rate is below target. Review approval criteria and application quality."
    end
    
    if latest.get_metric_value('system_uptime').to_f < 99
      recommendations << "System uptime is below target. Investigate infrastructure issues and implement improvements."
    end
    
    recommendations.uniq.first(5)
  end
end