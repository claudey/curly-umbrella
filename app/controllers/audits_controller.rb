# frozen_string_literal: true

class AuditsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  
  def index
    @audit_logs = AuditLog.for_organization(Current.organization)
                          .includes(:user, :auditable, :organization)
                          .recent
    
    # Apply filters
    @audit_logs = apply_filters(@audit_logs)
    
    # Pagination
    @audit_logs = @audit_logs.page(params[:page]).per(25)
    
    # Summary statistics
    @stats = calculate_audit_stats
    
    respond_to do |format|
      format.html
      format.json { render json: { logs: @audit_logs, stats: @stats } }
    end
  end

  def show
    @audit_log = AuditLog.for_organization(Current.organization).find(params[:id])
    
    respond_to do |format|
      format.html
      format.json { render json: @audit_log.to_compliance_hash }
    end
  end

  def dashboard
    @date_range = date_range_from_params
    @stats = calculate_dashboard_stats(@date_range)
    @activity_chart_data = activity_chart_data(@date_range)
    @recent_activities = recent_critical_activities
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          stats: @stats,
          activity_chart_data: @activity_chart_data,
          recent_activities: @recent_activities
        }
      end
    end
  end

  def export
    @date_range = date_range_from_params
    format = params[:format] || 'csv'
    
    case format
    when 'csv'
      export_csv
    when 'pdf'
      export_pdf
    when 'json'
      export_json
    else
      redirect_to audits_path, alert: "Unsupported export format: #{format}"
    end
  end

  def compliance_report
    @date_range = date_range_from_params
    @report_data = AuditLog.compliance_report(
      @date_range[:start], 
      @date_range[:end], 
      Current.organization
    )
    
    respond_to do |format|
      format.html
      format.json { render json: @report_data }
      format.pdf { render_compliance_pdf }
    end
  end

  private

  def ensure_admin_access
    unless current_user.super_admin? || current_user.brokerage_admin?
      redirect_to root_path, alert: 'Access denied. Administrator privileges required.'
    end
  end

  def apply_filters(logs)
    logs = logs.by_category(params[:category]) if params[:category].present?
    logs = logs.by_severity(params[:severity]) if params[:severity].present?
    logs = logs.by_action(params[:action]) if params[:action].present?
    logs = logs.for_user(User.find(params[:user_id])) if params[:user_id].present?
    logs = logs.search(params[:search]) if params[:search].present?
    
    if params[:start_date].present? && params[:end_date].present?
      logs = logs.in_date_range(
        Date.parse(params[:start_date]),
        Date.parse(params[:end_date])
      )
    end
    
    logs
  end

  def calculate_audit_stats
    base_logs = AuditLog.for_organization(Current.organization)
    
    {
      total_activities: base_logs.count,
      today_activities: base_logs.where(created_at: Date.current.all_day).count,
      suspicious_activities: base_logs.suspicious.count,
      failed_logins: base_logs.where(action: 'login_failure').count,
      data_modifications: base_logs.by_category('data_modification').count,
      compliance_events: base_logs.by_category('compliance').count
    }
  end

  def calculate_dashboard_stats(date_range)
    logs = AuditLog.for_organization(Current.organization)
                   .in_date_range(date_range[:start], date_range[:end])
    
    {
      total_activities: logs.count,
      by_category: logs.group(:category).count,
      by_severity: logs.group(:severity).count,
      by_user: logs.joins(:user).group('users.first_name', 'users.last_name').count,
      top_actions: logs.group(:action).count.sort_by { |k, v| -v }.first(10),
      daily_activity: daily_activity_data(logs, date_range)
    }
  end

  def activity_chart_data(date_range)
    logs = AuditLog.for_organization(Current.organization)
                   .in_date_range(date_range[:start], date_range[:end])
    
    # Group by day and category
    data = {}
    AuditLog.categories.keys.each do |category|
      data[category] = []
    end
    
    (date_range[:start].to_date..date_range[:end].to_date).each do |date|
      day_logs = logs.where(created_at: date.all_day)
      AuditLog.categories.keys.each do |category|
        count = day_logs.by_category(category).count
        data[category] << { date: date.strftime('%Y-%m-%d'), count: count }
      end
    end
    
    data
  end

  def daily_activity_data(logs, date_range)
    daily_data = {}
    
    (date_range[:start].to_date..date_range[:end].to_date).each do |date|
      daily_data[date.strftime('%Y-%m-%d')] = logs.where(created_at: date.all_day).count
    end
    
    daily_data
  end

  def recent_critical_activities
    AuditLog.for_organization(Current.organization)
            .where(severity: ['warning', 'error', 'critical'])
            .includes(:user, :auditable)
            .recent
            .limit(10)
  end

  def date_range_from_params
    start_date = if params[:start_date].present?
                   Date.parse(params[:start_date])
                 else
                   30.days.ago.to_date
                 end
    
    end_date = if params[:end_date].present?
                 Date.parse(params[:end_date])
               else
                 Date.current
               end
    
    { start: start_date, end: end_date }
  end

  def export_csv
    filename = "audit_logs_#{Current.organization.subdomain}_#{Date.current.strftime('%Y%m%d')}.csv"
    
    csv_data = AuditLog.export_for_compliance(
      @date_range[:start], 
      @date_range[:end], 
      format: 'csv'
    )
    
    send_data csv_data, 
              filename: filename,
              type: 'text/csv',
              disposition: 'attachment'
  end

  def export_json
    filename = "audit_logs_#{Current.organization.subdomain}_#{Date.current.strftime('%Y%m%d')}.json"
    
    json_data = AuditLog.export_for_compliance(
      @date_range[:start], 
      @date_range[:end], 
      format: 'json'
    )
    
    send_data json_data,
              filename: filename,
              type: 'application/json',
              disposition: 'attachment'
  end

  def export_pdf
    filename = "audit_report_#{Current.organization.subdomain}_#{Date.current.strftime('%Y%m%d')}.pdf"
    
    html = render_to_string(
      template: 'audits/compliance_report',
      layout: 'pdf',
      locals: { 
        date_range: @date_range,
        report_data: AuditLog.compliance_report(
          @date_range[:start], 
          @date_range[:end], 
          Current.organization
        )
      }
    )
    
    pdf = WickedPdf.new.pdf_from_string(html)
    
    send_data pdf,
              filename: filename,
              type: 'application/pdf',
              disposition: 'attachment'
  end

  def render_compliance_pdf
    respond_to do |format|
      format.pdf do
        render pdf: "compliance_report_#{Date.current.strftime('%Y%m%d')}",
               template: 'audits/compliance_report',
               layout: 'pdf',
               page_size: 'A4',
               margin: { top: 10, bottom: 10, left: 10, right: 10 }
      end
    end
  end
end