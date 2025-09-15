# frozen_string_literal: true

class SecurityController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  
  def dashboard
    @date_range = date_range_from_params
    @security_stats = calculate_security_stats(@date_range)
    @recent_alerts = recent_security_alerts
    @blocked_ips = IpBlockingService.list_blocked_ips.first(10)
    @threat_map_data = threat_map_data(@date_range)
    @alert_trends = alert_trends_data(@date_range)
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          stats: @security_stats,
          recent_alerts: @recent_alerts.map { |alert| alert_json(alert) },
          blocked_ips: @blocked_ips,
          threat_map_data: @threat_map_data,
          alert_trends: @alert_trends
        }
      end
    end
  end

  def alerts
    @security_alerts = SecurityAlert.for_organization(Current.organization)
                                   .includes(:resolved_by)
                                   .recent
    
    # Apply filters
    @security_alerts = apply_alert_filters(@security_alerts)
    
    # Pagination
    @security_alerts = @security_alerts.page(params[:page]).per(20)
    
    respond_to do |format|
      format.html
      format.json { render json: { alerts: @security_alerts.map { |alert| alert_json(alert) } } }
    end
  end

  def alert_details
    @alert = SecurityAlert.for_organization(Current.organization).find(params[:id])
    @related_alerts = find_related_alerts(@alert)
    @ip_history = ip_history(@alert.ip_address) if @alert.ip_address
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          alert: alert_json(@alert),
          related_alerts: @related_alerts.map { |alert| alert_json(alert) },
          ip_history: @ip_history
        }
      end
    end
  end

  def resolve_alert
    @alert = SecurityAlert.for_organization(Current.organization).find(params[:id])
    
    if @alert.resolve!(current_user, params[:resolution_notes])
      render json: { status: 'success', message: 'Alert resolved successfully' }
    else
      render json: { status: 'error', message: 'Failed to resolve alert' }, status: 422
    end
  end

  def dismiss_alert
    @alert = SecurityAlert.for_organization(Current.organization).find(params[:id])
    
    if @alert.dismiss!(current_user, params[:reason])
      render json: { status: 'success', message: 'Alert dismissed successfully' }
    else
      render json: { status: 'error', message: 'Failed to dismiss alert' }, status: 422
    end
  end

  def investigate_alert
    @alert = SecurityAlert.for_organization(Current.organization).find(params[:id])
    
    if @alert.investigate!(current_user)
      render json: { status: 'success', message: 'Alert marked as under investigation' }
    else
      render json: { status: 'error', message: 'Failed to update alert status' }, status: 422
    end
  end

  def blocked_ips
    @blocked_ips = IpBlockingService.list_blocked_ips
    @blocked_ips = filter_blocked_ips(@blocked_ips) if params[:filter].present?
    
    respond_to do |format|
      format.html
      format.json { render json: { blocked_ips: @blocked_ips } }
    end
  end

  def block_ip
    ip_address = params[:ip_address]
    reason = params[:reason] || 'Manual block'
    duration = params[:duration]&.to_i&.hours || 1.hour
    permanent = params[:permanent] == 'true'
    
    if IpBlockingService.block_ip(ip_address, reason, duration: duration, permanent: permanent)
      render json: { status: 'success', message: "IP #{ip_address} blocked successfully" }
    else
      render json: { status: 'error', message: 'Failed to block IP address' }, status: 422
    end
  end

  def unblock_ip
    ip_address = params[:ip_address]
    reason = params[:reason] || 'Manual unblock'
    
    if IpBlockingService.unblock_ip(ip_address, reason)
      render json: { status: 'success', message: "IP #{ip_address} unblocked successfully" }
    else
      render json: { status: 'error', message: 'Failed to unblock IP address' }, status: 422
    end
  end

  def threat_intelligence
    @threat_stats = calculate_threat_intelligence
    @attack_patterns = recent_attack_patterns
    @geographic_threats = geographic_threat_distribution
    @threat_timeline = threat_timeline_data
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          threat_stats: @threat_stats,
          attack_patterns: @attack_patterns,
          geographic_threats: @geographic_threats,
          threat_timeline: @threat_timeline
        }
      end
    end
  end

  def security_settings
    @current_settings = current_security_settings
    @rate_limits = current_rate_limits
    @auto_block_settings = auto_block_settings
  end

  def update_security_settings
    settings = params.require(:security_settings).permit(
      :auto_block_enabled,
      :failed_login_threshold,
      :rate_limit_threshold,
      :suspicious_activity_threshold,
      :email_notifications,
      :slack_notifications
    )
    
    if update_security_configuration(settings)
      render json: { status: 'success', message: 'Security settings updated successfully' }
    else
      render json: { status: 'error', message: 'Failed to update security settings' }, status: 422
    end
  end

  def export_security_report
    format = params[:format] || 'pdf'
    start_date = Date.parse(params[:start_date]) rescue 30.days.ago.to_date
    end_date = Date.parse(params[:end_date]) rescue Date.current
    
    case format
    when 'pdf'
      export_security_pdf(start_date, end_date)
    when 'csv'
      export_security_csv(start_date, end_date)
    else
      render json: { error: 'Unsupported format' }, status: 400
    end
  end

  private

  def ensure_admin_access
    unless current_user.super_admin? || current_user.brokerage_admin?
      redirect_to root_path, alert: 'Access denied. Administrator privileges required.'
    end
  end

  def date_range_from_params
    start_date = if params[:start_date].present?
                   Date.parse(params[:start_date])
                 else
                   7.days.ago.to_date
                 end
    
    end_date = if params[:end_date].present?
                 Date.parse(params[:end_date])
               else
                 Date.current
               end
    
    { start: start_date, end: end_date }
  end

  def calculate_security_stats(date_range)
    alerts = SecurityAlert.for_organization(Current.organization)
                         .where(triggered_at: date_range[:start]..date_range[:end])
    
    {
      total_alerts: alerts.count,
      critical_alerts: alerts.where(severity: 'critical').count,
      resolved_alerts: alerts.where(status: 'resolved').count,
      blocked_ips: IpBlockingService.list_blocked_ips.count,
      failed_logins: AuditLog.for_organization(Current.organization)
                            .where(action: 'login_failure')
                            .where(created_at: date_range[:start]..date_range[:end])
                            .count,
      by_severity: alerts.group(:severity).count,
      by_type: alerts.group(:alert_type).count,
      resolution_rate: alerts.count > 0 ? (alerts.where(status: 'resolved').count.to_f / alerts.count * 100).round(1) : 0
    }
  end

  def recent_security_alerts(limit = 10)
    SecurityAlert.for_organization(Current.organization)
                 .unresolved
                 .order(triggered_at: :desc)
                 .limit(limit)
  end

  def threat_map_data(date_range)
    # Group alerts by IP address and get approximate locations
    ip_alerts = SecurityAlert.for_organization(Current.organization)
                            .where(triggered_at: date_range[:start]..date_range[:end])
                            .where.not("data->>'ip_address' IS NULL")
                            .group("data->>'ip_address'")
                            .count

    # In production, use GeoIP service to get actual locations
    ip_alerts.map do |ip, count|
      {
        ip: ip,
        count: count,
        latitude: 40.7128 + rand(-10..10), # Mock coordinates
        longitude: -74.0060 + rand(-10..10),
        city: 'Unknown',
        country: 'Unknown'
      }
    end
  end

  def alert_trends_data(date_range)
    alerts = SecurityAlert.for_organization(Current.organization)
                         .where(triggered_at: date_range[:start]..date_range[:end])
    
    daily_data = {}
    (date_range[:start]..date_range[:end]).each do |date|
      day_alerts = alerts.where(triggered_at: date.all_day)
      daily_data[date.strftime('%Y-%m-%d')] = {
        total: day_alerts.count,
        critical: day_alerts.where(severity: 'critical').count,
        high: day_alerts.where(severity: 'high').count,
        medium: day_alerts.where(severity: 'medium').count,
        low: day_alerts.where(severity: 'low').count
      }
    end
    
    daily_data
  end

  def apply_alert_filters(alerts)
    alerts = alerts.where(severity: params[:severity]) if params[:severity].present?
    alerts = alerts.where(status: params[:status]) if params[:status].present?
    alerts = alerts.where(alert_type: params[:alert_type]) if params[:alert_type].present?
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      alerts = alerts.where("message ILIKE ? OR data::text ILIKE ?", search_term, search_term)
    end
    
    alerts
  end

  def find_related_alerts(alert)
    return SecurityAlert.none unless alert.ip_address
    
    SecurityAlert.for_organization(Current.organization)
                 .where("data->>'ip_address' = ?", alert.ip_address)
                 .where.not(id: alert.id)
                 .order(triggered_at: :desc)
                 .limit(5)
  end

  def ip_history(ip_address)
    return [] unless ip_address
    
    # Get audit logs for this IP
    audit_logs = AuditLog.for_organization(Current.organization)
                        .where("details->>'ip_address' = ?", ip_address)
                        .order(created_at: :desc)
                        .limit(20)
    
    audit_logs.map do |log|
      {
        timestamp: log.created_at,
        action: log.action,
        user: log.user&.email,
        details: log.details
      }
    end
  end

  def alert_json(alert)
    {
      id: alert.id,
      alert_type: alert.alert_type,
      message: alert.message,
      severity: alert.severity,
      status: alert.status,
      triggered_at: alert.triggered_at,
      resolved_at: alert.resolved_at,
      ip_address: alert.ip_address,
      affected_user: alert.affected_user&.email,
      formatted_data: alert.formatted_data,
      time_since_triggered: time_ago_in_words(alert.triggered_at)
    }
  end

  def filter_blocked_ips(blocked_ips)
    case params[:filter]
    when 'permanent'
      blocked_ips.select { |ip| ip[:permanent] }
    when 'temporary'
      blocked_ips.reject { |ip| ip[:permanent] }
    when 'expired'
      blocked_ips.select { |ip| ip[:expires_at] && ip[:expires_at] < Time.current }
    else
      blocked_ips
    end
  end

  def calculate_threat_intelligence
    {
      attack_vectors: SecurityAlert.for_organization(Current.organization)
                                  .where(triggered_at: 7.days.ago..Time.current)
                                  .group(:alert_type)
                                  .count,
      repeat_offenders: repeat_offender_ips,
      attack_frequency: attack_frequency_by_hour,
      targeted_endpoints: most_targeted_endpoints
    }
  end

  def repeat_offender_ips
    SecurityAlert.for_organization(Current.organization)
                 .where(triggered_at: 30.days.ago..Time.current)
                 .where.not("data->>'ip_address' IS NULL")
                 .group("data->>'ip_address'")
                 .having('COUNT(*) >= ?', 5)
                 .count
                 .sort_by { |_, count| -count }
                 .first(10)
  end

  def attack_frequency_by_hour
    alerts = SecurityAlert.for_organization(Current.organization)
                         .where(triggered_at: 7.days.ago..Time.current)
    
    (0..23).map do |hour|
      count = alerts.where('EXTRACT(hour FROM triggered_at) = ?', hour).count
      { hour: hour, count: count }
    end
  end

  def most_targeted_endpoints
    AuditLog.for_organization(Current.organization)
            .where(created_at: 7.days.ago..Time.current)
            .where(category: 'authorization')
            .where("action LIKE 'unauthorized_%'")
            .group(:resource_type)
            .count
            .sort_by { |_, count| -count }
            .first(10)
  end

  def export_security_pdf(start_date, end_date)
    # Implementation for PDF export
    respond_to do |format|
      format.pdf do
        render pdf: "security_report_#{Date.current.strftime('%Y%m%d')}",
               template: 'security/reports/security_report',
               layout: 'pdf'
      end
    end
  end

  def export_security_csv(start_date, end_date)
    alerts = SecurityAlert.for_organization(Current.organization)
                         .where(triggered_at: start_date..end_date)
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Timestamp', 'Alert Type', 'Severity', 'Status', 'IP Address', 'Message', 'Resolution Notes']
      
      alerts.each do |alert|
        csv << [
          alert.triggered_at,
          alert.alert_type,
          alert.severity,
          alert.status,
          alert.ip_address,
          alert.message,
          alert.resolution_notes
        ]
      end
    end
    
    send_data csv_data,
              filename: "security_alerts_#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv'
  end

  def current_security_settings
    # In production, this would come from a configuration model
    {
      auto_block_enabled: true,
      failed_login_threshold: 5,
      rate_limit_threshold: 100,
      suspicious_activity_threshold: 10,
      email_notifications: true,
      slack_notifications: false
    }
  end

  def current_rate_limits
    {
      login_attempts: { limit: 5, window: 300 },
      api_requests: { limit: 100, window: 3600 },
      general_requests: { limit: 200, window: 3600 }
    }
  end

  def auto_block_settings
    {
      enabled: true,
      failed_login_threshold: 10,
      duration: 2.hours,
      repeat_offender_threshold: 5
    }
  end

  def update_security_configuration(settings)
    # In production, this would update a configuration model
    Rails.logger.info "Security settings updated: #{settings.inspect}"
    true
  end
end