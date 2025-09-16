# frozen_string_literal: true

class Admin::SecurityDashboardController < ApplicationController
  before_action :ensure_super_admin
  
  def index
    @security_metrics = gather_security_metrics
    @recent_alerts = recent_security_alerts
    @blocked_ips = IpBlockingService.list_blocked_ips.first(10)
    @rate_limit_violations = RateLimitingService.get_violations_summary
    @audit_summary = recent_audit_summary
  end

  def alerts
    @alerts = SecurityAlert.includes(:organization, :resolved_by)
                          .recent
                          .page(params[:page])
                          .per(25)
    
    @alerts = @alerts.where(status: params[:status]) if params[:status].present?
    @alerts = @alerts.where(severity: params[:severity]) if params[:severity].present?
    @alerts = @alerts.where(alert_type: params[:alert_type]) if params[:alert_type].present?
  end

  def ip_blocks
    @blocked_ips = IpBlockingService.list_blocked_ips
    @whitelist = get_ip_whitelist
  end

  def rate_limits
    @violations = RateLimitingService.get_violations_summary(6.hours)
    @limit_types = RateLimitingService::RATE_LIMITS.keys
  end

  def audit_logs
    @audit_logs = AuditLog.includes(:user, :organization)
                         .where('created_at >= ?', 24.hours.ago)
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(50)
                         
    @audit_logs = @audit_logs.where(action: params[:action]) if params[:action].present?
    @audit_logs = @audit_logs.where(organization_id: params[:organization_id]) if params[:organization_id].present?
  end

  def metrics_api
    timeframe = params[:timeframe] || '24h'
    metrics = gather_metrics_for_timeframe(timeframe)
    
    render json: metrics
  end

  def block_ip
    ip_address = params[:ip_address]
    reason = params[:reason] || 'Manually blocked by admin'
    duration = params[:duration]&.to_i&.hours || 2.hours
    permanent = params[:permanent] == 'true'

    if IpBlockingService.block_ip(ip_address, reason, duration: duration, permanent: permanent)
      flash[:notice] = "IP #{ip_address} has been blocked successfully."
    else
      flash[:alert] = "Failed to block IP #{ip_address}."
    end

    redirect_to admin_security_dashboard_ip_blocks_path
  end

  def unblock_ip
    ip_address = params[:ip_address]
    reason = params[:reason] || 'Manually unblocked by admin'

    if IpBlockingService.unblock_ip(ip_address, reason)
      flash[:notice] = "IP #{ip_address} has been unblocked successfully."
    else
      flash[:alert] = "Failed to unblock IP #{ip_address}."
    end

    redirect_to admin_security_dashboard_ip_blocks_path
  end

  def whitelist_ip
    ip_address = params[:ip_address]
    reason = params[:reason] || 'Added to whitelist by admin'

    IpBlockingService.new.add_to_whitelist(ip_address, reason)
    flash[:notice] = "IP #{ip_address} has been added to whitelist."

    redirect_to admin_security_dashboard_ip_blocks_path
  end

  def resolve_alert
    alert = SecurityAlert.find(params[:id])
    notes = params[:resolution_notes]

    if alert.resolve!(current_user, notes)
      flash[:notice] = "Security alert has been resolved."
    else
      flash[:alert] = "Failed to resolve security alert."
    end

    redirect_to admin_security_dashboard_alerts_path
  end

  def dismiss_alert
    alert = SecurityAlert.find(params[:id])
    reason = params[:dismiss_reason]

    if alert.dismiss!(current_user, reason)
      flash[:notice] = "Security alert has been dismissed."
    else
      flash[:alert] = "Failed to dismiss security alert."
    end

    redirect_to admin_security_dashboard_alerts_path
  end

  private

  def ensure_super_admin
    redirect_to root_path unless current_user&.super_admin?
  end

  def gather_security_metrics
    {
      total_alerts_24h: SecurityAlert.where('triggered_at >= ?', 24.hours.ago).count,
      critical_alerts_24h: SecurityAlert.where('triggered_at >= ? AND severity = ?', 24.hours.ago, 'critical').count,
      unresolved_alerts: SecurityAlert.unresolved.count,
      blocked_ips: count_blocked_ips,
      rate_limit_violations_24h: count_rate_limit_violations,
      failed_logins_24h: count_failed_logins,
      suspicious_activities_24h: count_suspicious_activities,
      total_requests_24h: count_total_requests
    }
  end

  def recent_security_alerts
    SecurityAlert.includes(:organization)
                 .recent
                 .limit(10)
  end

  def recent_audit_summary
    {
      total_events_24h: AuditLog.where('created_at >= ?', 24.hours.ago).count,
      login_attempts_24h: AuditLog.where('created_at >= ? AND action = ?', 24.hours.ago, 'login_attempt').count,
      failed_logins_24h: AuditLog.where('created_at >= ? AND action = ?', 24.hours.ago, 'login_failure').count,
      data_exports_24h: AuditLog.where('created_at >= ? AND action LIKE ?', 24.hours.ago, '%export%').count
    }
  end

  def gather_metrics_for_timeframe(timeframe)
    case timeframe
    when '1h'
      time_range = 1.hour.ago..Time.current
      interval = 5.minutes
    when '6h'
      time_range = 6.hours.ago..Time.current
      interval = 30.minutes
    when '24h'
      time_range = 24.hours.ago..Time.current
      interval = 1.hour
    when '7d'
      time_range = 7.days.ago..Time.current
      interval = 6.hours
    else
      time_range = 24.hours.ago..Time.current
      interval = 1.hour
    end

    {
      alerts_timeline: generate_timeline_data(SecurityAlert, time_range, interval, 'triggered_at'),
      login_failures_timeline: generate_timeline_data(
        AuditLog.where(action: 'login_failure'), 
        time_range, 
        interval, 
        'created_at'
      ),
      request_volume_timeline: generate_request_volume_timeline(time_range, interval),
      alert_severity_distribution: SecurityAlert.where(triggered_at: time_range)
                                              .group(:severity)
                                              .count,
      alert_type_distribution: SecurityAlert.where(triggered_at: time_range)
                                           .group(:alert_type)
                                           .count
                                           .transform_keys(&:humanize)
    }
  end

  def generate_timeline_data(model, time_range, interval, timestamp_field)
    data = []
    current_time = time_range.begin
    
    while current_time < time_range.end
      next_time = current_time + interval
      count = model.where(timestamp_field => current_time..next_time).count
      
      data << {
        timestamp: current_time.to_i * 1000, # JavaScript timestamp
        value: count
      }
      
      current_time = next_time
    end
    
    data
  end

  def generate_request_volume_timeline(time_range, interval)
    # This would ideally come from request logs or metrics
    # For now, simulate based on audit logs as a proxy
    generate_timeline_data(AuditLog, time_range, interval, 'created_at')
  end

  def count_blocked_ips
    IpBlockingService.list_blocked_ips.count
  end

  def count_rate_limit_violations
    RateLimitingService.get_violations_summary.count
  end

  def count_failed_logins
    AuditLog.where('created_at >= ? AND action = ?', 24.hours.ago, 'login_failure').count
  end

  def count_suspicious_activities
    SecurityAlert.where('triggered_at >= ? AND severity IN (?)', 24.hours.ago, ['high', 'critical']).count
  end

  def count_total_requests
    # This would ideally come from application metrics
    # For now, estimate based on audit log activity
    AuditLog.where('created_at >= ?', 24.hours.ago).count * 10 # Rough estimate
  end

  def get_ip_whitelist
    whitelist = Rails.cache.fetch(IpBlockingService::WHITELIST_KEY, expires_in: nil) { {} }
    whitelist.map do |ip, data|
      {
        ip_address: ip,
        reason: data[:reason],
        added_at: Time.at(data[:added_at]),
        added_by: data[:added_by]
      }
    end
  rescue StandardError
    []
  end
end