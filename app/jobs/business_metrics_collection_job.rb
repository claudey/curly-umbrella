# frozen_string_literal: true

class BusinessMetricsCollectionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform(organization_id = nil, period_hours: 24)
    organization = organization_id ? Organization.find_by(id: organization_id) : nil
    period = period_hours.hours

    Rails.logger.info "Collecting business metrics for #{organization&.name || 'Global'} (#{period_hours}h period)"

    # Collect metrics using the service
    snapshot = BusinessMetricsService.store_metric_snapshot(organization)

    # Log successful collection
    log_metrics_collection(snapshot, organization)

    # Send alerts if metrics are concerning
    check_metric_alerts(snapshot)

    # Cleanup old data if this is a daily job
    cleanup_old_data if period_hours == 24 && (organization.nil? || organization_id == Organization.first&.id)

    snapshot
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "BusinessMetricsCollectionJob: Organization #{organization_id} not found"
  rescue => e
    Rails.logger.error "BusinessMetricsCollectionJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Create error report
    ErrorTrackingService.track_error(e, {
      job_class: self.class.name,
      organization_id: organization_id,
      period_hours: period_hours
    })

    raise # Re-raise to trigger retry mechanism
  end

  # Class method to schedule regular collections
  def self.schedule_regular_collections
    Rails.logger.info "Scheduling regular business metrics collections"

    # Schedule global metrics collection
    perform_later(nil, period_hours: 24)

    # Schedule for each organization
    Organization.active.find_each do |organization|
      perform_later(organization.id, period_hours: 24)
    end
  end

  # Class method to schedule hourly collections for critical metrics
  def self.schedule_hourly_collections
    Rails.logger.info "Scheduling hourly business metrics collections"

    # Only collect critical metrics hourly
    Organization.active.find_each do |organization|
      perform_later(organization.id, period_hours: 1)
    end
  end

  private

  def log_metrics_collection(snapshot, organization)
    AuditLog.create!(
      user: nil, # System-generated
      organization: organization,
      action: "business_metrics_collected",
      category: "system_access",
      resource_type: "BusinessMetricSnapshot",
      resource_id: snapshot.id,
      severity: "info",
      details: {
        snapshot_id: snapshot.id,
        organization_id: organization&.id,
        total_metrics: snapshot.total_metrics_count,
        healthy_metrics: snapshot.healthy_metrics_count,
        health_percentage: snapshot.health_percentage,
        health_status: snapshot.health_status,
        period_hours: snapshot.period_hours
      }
    )
  rescue => e
    Rails.logger.error "Failed to create metrics collection audit log: #{e.message}"
  end

  def check_metric_alerts(snapshot)
    # Check for concerning metric values and send alerts
    concerning_metrics = identify_concerning_metrics(snapshot)

    if concerning_metrics.any?
      send_metric_alerts(snapshot, concerning_metrics)
    end

    # Check overall health
    if snapshot.health_percentage < 60
      send_health_alert(snapshot)
    end
  end

  def identify_concerning_metrics(snapshot)
    concerning = []

    snapshot.metrics_data.each do |metric_name, metric_data|
      next if metric_data.is_a?(Hash) && metric_data["error"]

      value = metric_data.is_a?(Hash) ? metric_data["value"] : metric_data
      next unless value.is_a?(Numeric)

      # Define concerning thresholds
      case metric_name
      when "application_approval_rate", "quote_conversion_rate"
        concerning << { metric: metric_name, value: value, reason: "Low conversion rate" } if value < 50
      when "system_uptime"
        concerning << { metric: metric_name, value: value, reason: "Low uptime" } if value < 95
      when "error_rate"
        concerning << { metric: metric_name, value: value, reason: "High error rate" } if value > 5
      when "user_activity_rate"
        concerning << { metric: metric_name, value: value, reason: "Low user engagement" } if value < 40
      when "average_processing_time"
        concerning << { metric: metric_name, value: value, reason: "Slow processing" } if value > 48 # More than 48 hours
      end

      # Check trends
      trend = metric_data.is_a?(Hash) ? metric_data["trend"] : nil
      if trend.is_a?(Numeric) && trend < -20 # More than 20% decline
        concerning << { metric: metric_name, value: value, reason: "Significant decline", trend: trend }
      end
    end

    concerning
  end

  def send_metric_alerts(snapshot, concerning_metrics)
    return unless concerning_metrics.any?

    # Get admin users for the organization
    recipients = if snapshot.organization
                   snapshot.organization.users.joins(:user_roles)
                           .where(user_roles: { role: [ "admin", "brokerage_admin" ] })
                           .where(active: true)
    else
                   User.joins(:user_roles)
                       .where(user_roles: { role: "super_admin" })
                       .where(active: true)
    end

    recipients.each do |user|
      # Send email notification
      BusinessMetricsMailer.concerning_metrics_alert(user, snapshot, concerning_metrics).deliver_later

      # Create in-app notification
      create_metrics_notification(user, snapshot, concerning_metrics)
    end
  end

  def send_health_alert(snapshot)
    # Send alert for overall poor health
    recipients = if snapshot.organization
                   snapshot.organization.users.joins(:user_roles)
                           .where(user_roles: { role: [ "admin", "brokerage_admin" ] })
                           .where(active: true)
    else
                   User.joins(:user_roles)
                       .where(user_roles: { role: "super_admin" })
                       .where(active: true)
    end

    recipients.each do |user|
      BusinessMetricsMailer.health_alert(user, snapshot).deliver_later

      Notification.create!(
        user: user,
        organization: snapshot.organization,
        title: "🚨 Business Metrics Health Alert",
        message: "Overall business metrics health has declined to #{snapshot.health_percentage.round(1)}%. Immediate attention required.",
        notification_type: "metrics_health_alert",
        priority: "high",
        data: {
          snapshot_id: snapshot.id,
          health_percentage: snapshot.health_percentage,
          health_status: snapshot.health_status
        }
      )
    end
  end

  def create_metrics_notification(user, snapshot, concerning_metrics)
    metric_names = concerning_metrics.map { |m| m[:metric] }.join(", ")

    Notification.create!(
      user: user,
      organization: snapshot.organization,
      title: "⚠️ Concerning Business Metrics",
      message: "The following metrics require attention: #{metric_names}",
      notification_type: "metrics_alert",
      priority: "medium",
      data: {
        snapshot_id: snapshot.id,
        concerning_metrics: concerning_metrics,
        metric_count: concerning_metrics.size
      }
    )
  rescue => e
    Rails.logger.error "Failed to create metrics notification: #{e.message}"
  end

  def cleanup_old_data
    Rails.logger.info "Cleaning up old business metrics data"

    begin
      # Cleanup old metric snapshots (keep 90 days)
      BusinessMetricSnapshot.cleanup_old_snapshots(90)

      # Cleanup old individual metrics (keep 1 year)
      BusinessMetric.cleanup_old_metrics(365)

      # Cleanup old error reports (keep 90 days for resolved, 1 year for unresolved)
      ErrorReport.where("occurred_at < ? AND resolved = ?", 90.days.ago, true).delete_all
      ErrorReport.where("occurred_at < ?", 1.year.ago).delete_all

      Rails.logger.info "Completed cleanup of old business metrics data"
    rescue => e
      Rails.logger.error "Failed to cleanup old metrics data: #{e.message}"
      # Don't raise here as cleanup failure shouldn't fail the main job
    end
  end
end
