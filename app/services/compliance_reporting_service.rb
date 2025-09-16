# frozen_string_literal: true

class ComplianceReportingService
  include ActiveModel::Model
  
  # Standard compliance report types
  REPORT_TYPES = {
    daily_activity: {
      frequency: :daily,
      description: 'Daily activity and security events',
      retention: 7.years
    },
    weekly_summary: {
      frequency: :weekly, 
      description: 'Weekly activity summary and analytics',
      retention: 7.years
    },
    monthly_comprehensive: {
      frequency: :monthly,
      description: 'Comprehensive monthly compliance report',
      retention: 10.years
    },
    quarterly_audit: {
      frequency: :quarterly,
      description: 'Quarterly audit and compliance review',
      retention: 10.years
    },
    annual_compliance: {
      frequency: :annual,
      description: 'Annual compliance and regulatory report',
      retention: 15.years
    },
    incident_report: {
      frequency: :on_demand,
      description: 'Security incident and breach reports',
      retention: 10.years
    },
    user_access_review: {
      frequency: :monthly,
      description: 'User access rights and permissions review',
      retention: 7.years
    },
    data_retention_audit: {
      frequency: :quarterly,
      description: 'Data retention and deletion compliance',
      retention: 10.years
    }
  }.freeze
  
  def self.generate_report(report_type, organization = nil, start_date: nil, end_date: nil, **options)
    new.generate_report(report_type.to_sym, organization, start_date: start_date, end_date: end_date, **options)
  end
  
  def self.schedule_automated_reports
    new.schedule_automated_reports
  end
  
  def generate_report(report_type, organization = nil, start_date: nil, end_date: nil, **options)
    validate_report_type!(report_type)
    
    # Set default date range based on report type
    start_date, end_date = determine_date_range(report_type, start_date, end_date)
    
    # Generate the specific report
    report_data = case report_type
                 when :daily_activity
                   generate_daily_activity_report(organization, start_date, end_date)
                 when :weekly_summary
                   generate_weekly_summary_report(organization, start_date, end_date)
                 when :monthly_comprehensive
                   generate_monthly_comprehensive_report(organization, start_date, end_date)
                 when :quarterly_audit
                   generate_quarterly_audit_report(organization, start_date, end_date)
                 when :annual_compliance
                   generate_annual_compliance_report(organization, start_date, end_date)
                 when :incident_report
                   generate_incident_report(organization, start_date, end_date, options)
                 when :user_access_review
                   generate_user_access_review(organization, start_date, end_date)
                 when :data_retention_audit
                   generate_data_retention_audit(organization, start_date, end_date)
                 else
                   raise ArgumentError, "Unknown report type: #{report_type}"
                 end
    
    # Create compliance report record
    compliance_report = create_compliance_report_record(
      report_type,
      organization,
      start_date,
      end_date,
      report_data,
      options
    )
    
    # Generate files and notify stakeholders
    generate_report_files(compliance_report, report_data, options)
    notify_stakeholders(compliance_report, options)
    
    compliance_report
  end
  
  def schedule_automated_reports
    # Schedule daily reports for all organizations
    Organization.active.find_each do |org|
      ComplianceReportJob.perform_later(:daily_activity, org.id)
    end
    
    # Schedule weekly reports on Mondays
    if Date.current.monday?
      Organization.active.find_each do |org|
        ComplianceReportJob.perform_later(:weekly_summary, org.id)
      end
    end
    
    # Schedule monthly reports on the 1st
    if Date.current.day == 1
      Organization.active.find_each do |org|
        ComplianceReportJob.perform_later(:monthly_comprehensive, org.id)
        ComplianceReportJob.perform_later(:user_access_review, org.id)
      end
    end
    
    # Schedule quarterly reports
    if quarterly_report_date?
      Organization.active.find_each do |org|
        ComplianceReportJob.perform_later(:quarterly_audit, org.id)
        ComplianceReportJob.perform_later(:data_retention_audit, org.id)
      end
    end
    
    # Schedule annual reports on January 1st
    if Date.current.month == 1 && Date.current.day == 1
      Organization.active.find_each do |org|
        ComplianceReportJob.perform_later(:annual_compliance, org.id)
      end
    end
  end
  
  private
  
  def generate_daily_activity_report(organization, start_date, end_date)
    base_scope = organization ? AuditLog.where(organization: organization) : AuditLog.all
    audit_logs = base_scope.where(created_at: start_date..end_date)
    
    {
      report_period: "#{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}",
      total_events: audit_logs.count,
      events_by_category: audit_logs.group(:category).count,
      events_by_severity: audit_logs.group(:severity).count,
      events_by_hour: audit_logs.group_by_hour(:created_at).count,
      unique_users: audit_logs.joins(:user).distinct.count('users.id'),
      authentication_events: audit_logs.where(category: 'authentication').count,
      failed_logins: audit_logs.where(action: 'login_failure').count,
      data_access_events: audit_logs.where(category: 'data_access').count,
      security_events: audit_logs.where(category: 'security').count,
      compliance_events: audit_logs.where(category: 'compliance').count,
      financial_events: audit_logs.where(category: 'financial').count,
      critical_events: audit_logs.where(severity: 'critical').includes(:user, :auditable),
      top_active_users: get_top_active_users(audit_logs, 10),
      suspicious_activities: get_suspicious_activities(audit_logs),
      organization_summary: organization ? get_organization_summary(organization) : nil
    }
  end
  
  def generate_weekly_summary_report(organization, start_date, end_date)
    daily_data = generate_daily_activity_report(organization, start_date, end_date)
    
    # Add weekly-specific analytics
    daily_data.merge({
      week_over_week_comparison: get_week_over_week_comparison(organization, start_date),
      trend_analysis: get_trend_analysis(organization, start_date, end_date),
      security_metrics: get_security_metrics(organization, start_date, end_date),
      user_activity_patterns: get_user_activity_patterns(organization, start_date, end_date),
      document_activity: get_document_activity_summary(organization, start_date, end_date),
      application_metrics: get_application_metrics(organization, start_date, end_date)
    })
  end
  
  def generate_monthly_comprehensive_report(organization, start_date, end_date)
    # Build comprehensive monthly report
    {
      executive_summary: generate_executive_summary(organization, start_date, end_date),
      security_posture: assess_security_posture(organization, start_date, end_date),
      compliance_status: assess_compliance_status(organization, start_date, end_date),
      user_management: audit_user_management(organization, start_date, end_date),
      data_governance: audit_data_governance(organization, start_date, end_date),
      financial_oversight: audit_financial_activities(organization, start_date, end_date),
      document_lifecycle: audit_document_lifecycle(organization, start_date, end_date),
      incident_summary: summarize_incidents(organization, start_date, end_date),
      recommendations: generate_compliance_recommendations(organization, start_date, end_date),
      regulatory_alignment: assess_regulatory_alignment(organization, start_date, end_date)
    }
  end
  
  def generate_quarterly_audit_report(organization, start_date, end_date)
    {
      audit_scope: define_audit_scope(organization, start_date, end_date),
      control_effectiveness: assess_control_effectiveness(organization, start_date, end_date),
      risk_assessment: conduct_risk_assessment(organization, start_date, end_date),
      policy_compliance: audit_policy_compliance(organization, start_date, end_date),
      access_controls: audit_access_controls(organization, start_date, end_date),
      data_integrity: audit_data_integrity(organization, start_date, end_date),
      business_continuity: assess_business_continuity(organization, start_date, end_date),
      vendor_management: audit_vendor_management(organization, start_date, end_date),
      training_compliance: audit_training_compliance(organization, start_date, end_date),
      audit_findings: document_audit_findings(organization, start_date, end_date),
      corrective_actions: track_corrective_actions(organization, start_date, end_date)
    }
  end
  
  def generate_annual_compliance_report(organization, start_date, end_date)
    {
      regulatory_overview: get_regulatory_overview(organization),
      annual_metrics: calculate_annual_metrics(organization, start_date, end_date),
      compliance_framework: document_compliance_framework(organization),
      policy_updates: track_policy_updates(organization, start_date, end_date),
      training_records: compile_training_records(organization, start_date, end_date),
      incident_analysis: analyze_annual_incidents(organization, start_date, end_date),
      third_party_assessments: compile_third_party_assessments(organization, start_date, end_date),
      certification_status: track_certification_status(organization),
      budget_compliance: analyze_budget_compliance(organization, start_date, end_date),
      strategic_initiatives: document_strategic_initiatives(organization, start_date, end_date),
      forward_planning: develop_forward_planning(organization)
    }
  end
  
  def generate_incident_report(organization, start_date, end_date, options)
    incident_filter = options[:incident_type] || 'all'
    severity_filter = options[:severity] || 'all'
    
    base_scope = organization ? AuditLog.where(organization: organization) : AuditLog.all
    incidents = base_scope.where(created_at: start_date..end_date)
                         .where(severity: ['warning', 'error', 'critical'])
    
    incidents = incidents.where(severity: severity_filter) unless severity_filter == 'all'
    
    {
      incident_overview: summarize_incidents_overview(incidents),
      timeline: create_incident_timeline(incidents),
      impact_analysis: analyze_incident_impact(incidents),
      root_cause_analysis: perform_root_cause_analysis(incidents),
      response_metrics: calculate_response_metrics(incidents),
      lessons_learned: extract_lessons_learned(incidents),
      preventive_measures: recommend_preventive_measures(incidents),
      stakeholder_communication: document_stakeholder_communication(incidents)
    }
  end
  
  def generate_user_access_review(organization, start_date, end_date)
    users = organization ? organization.users : User.all
    
    {
      user_inventory: compile_user_inventory(users),
      role_assignments: audit_role_assignments(users),
      permission_analysis: analyze_permissions(users),
      access_patterns: analyze_access_patterns(users, start_date, end_date),
      dormant_accounts: identify_dormant_accounts(users, start_date, end_date),
      privileged_access: audit_privileged_access(users),
      access_violations: identify_access_violations(users, start_date, end_date),
      recommendations: generate_access_recommendations(users)
    }
  end
  
  def generate_data_retention_audit(organization, start_date, end_date)
    {
      retention_policies: document_retention_policies(organization),
      data_inventory: compile_data_inventory(organization),
      retention_compliance: assess_retention_compliance(organization),
      deletion_activities: audit_deletion_activities(organization, start_date, end_date),
      backup_integrity: assess_backup_integrity(organization),
      storage_analysis: analyze_storage_usage(organization),
      legal_holds: document_legal_holds(organization),
      recommendations: generate_retention_recommendations(organization)
    }
  end
  
  # Helper methods for report generation
  def get_top_active_users(audit_logs, limit)
    audit_logs.joins(:user)
             .group('users.email')
             .order(count: :desc)
             .limit(limit)
             .count
  end
  
  def get_suspicious_activities(audit_logs)
    suspicious = audit_logs.where(
      "action LIKE 'unauthorized_%' OR action LIKE '%_failure' OR severity = 'critical'"
    ).includes(:user, :auditable)
    
    suspicious.map do |log|
      {
        timestamp: log.created_at,
        user: log.user&.email || 'System',
        action: log.action,
        severity: log.severity,
        ip_address: log.ip_address,
        details: log.details
      }
    end
  end
  
  def get_organization_summary(organization)
    {
      name: organization.name,
      total_users: organization.users.count,
      active_users: organization.users.where('last_sign_in_at > ?', 30.days.ago).count,
      total_applications: organization.insurance_applications.count,
      total_documents: organization.documents.count,
      created_at: organization.created_at
    }
  end
  
  def create_compliance_report_record(report_type, organization, start_date, end_date, data, options)
    ComplianceReport.create!(
      organization: organization,
      report_type: report_type.to_s,
      period_start: start_date,
      period_end: end_date,
      generated_at: Time.current,
      generated_by: Current.user,
      data: data,
      metadata: {
        report_version: '1.0',
        generator: 'ComplianceReportingService',
        options: options
      }
    )
  end
  
  def generate_report_files(compliance_report, data, options)
    # Generate PDF report
    if options[:generate_pdf] != false
      pdf_content = ComplianceReportPdfGenerator.new(compliance_report, data).generate
      compliance_report.files.attach(
        io: StringIO.new(pdf_content),
        filename: "#{compliance_report.report_type}_#{compliance_report.id}.pdf",
        content_type: 'application/pdf'
      )
    end
    
    # Generate CSV export
    if options[:generate_csv]
      csv_content = ComplianceReportCsvGenerator.new(compliance_report, data).generate
      compliance_report.files.attach(
        io: StringIO.new(csv_content),
        filename: "#{compliance_report.report_type}_#{compliance_report.id}.csv",
        content_type: 'text/csv'
      )
    end
    
    # Generate JSON export
    if options[:generate_json]
      compliance_report.files.attach(
        io: StringIO.new(data.to_json),
        filename: "#{compliance_report.report_type}_#{compliance_report.id}.json",
        content_type: 'application/json'
      )
    end
  end
  
  def notify_stakeholders(compliance_report, options)
    return if options[:skip_notifications]
    
    # Determine recipients based on report type and organization
    recipients = determine_report_recipients(compliance_report)
    
    recipients.each do |user|
      ComplianceReportMailer.report_generated(user, compliance_report).deliver_later
      
      # Create in-app notification
      Notification.create!(
        user: user,
        organization: compliance_report.organization,
        title: "📊 Compliance Report Generated",
        message: "#{compliance_report.report_type.humanize} report for #{compliance_report.period_start.strftime('%Y-%m-%d')} to #{compliance_report.period_end.strftime('%Y-%m-%d')} is ready.",
        notification_type: 'compliance_report',
        data: {
          report_id: compliance_report.id,
          report_type: compliance_report.report_type
        }
      )
    end
  end
  
  def determine_report_recipients(compliance_report)
    organization = compliance_report.organization
    
    if organization
      # Organization-specific reports go to admins and compliance officers
      organization.users.joins(:user_roles)
                 .where(user_roles: { role: ['admin', 'compliance_officer', 'brokerage_admin'] })
                 .where(active: true)
    else
      # System-wide reports go to super admins
      User.joins(:user_roles)
          .where(user_roles: { role: 'super_admin' })
          .where(active: true)
    end
  end
  
  def validate_report_type!(report_type)
    unless REPORT_TYPES.key?(report_type)
      raise ArgumentError, "Invalid report type: #{report_type}. Valid types: #{REPORT_TYPES.keys.join(', ')}"
    end
  end
  
  def determine_date_range(report_type, start_date, end_date)
    return [start_date, end_date] if start_date && end_date
    
    case report_type
    when :daily_activity
      [1.day.ago.beginning_of_day, 1.day.ago.end_of_day]
    when :weekly_summary
      [1.week.ago.beginning_of_week, 1.week.ago.end_of_week]
    when :monthly_comprehensive, :user_access_review
      [1.month.ago.beginning_of_month, 1.month.ago.end_of_month]
    when :quarterly_audit, :data_retention_audit
      [3.months.ago.beginning_of_quarter, 3.months.ago.end_of_quarter]
    when :annual_compliance
      [1.year.ago.beginning_of_year, 1.year.ago.end_of_year]
    else
      [1.day.ago.beginning_of_day, Time.current]
    end
  end
  
  def quarterly_report_date?
    [1, 4, 7, 10].include?(Date.current.month) && Date.current.day == 1
  end
  
  # Placeholder methods for complex report sections
  # These would be implemented with detailed business logic
  
  def generate_executive_summary(organization, start_date, end_date)
    { summary: "Executive summary for #{organization&.name || 'System'} from #{start_date} to #{end_date}" }
  end
  
  def assess_security_posture(organization, start_date, end_date)
    { posture: "Security posture assessment" }
  end
  
  def assess_compliance_status(organization, start_date, end_date)
    { status: "Compliance status assessment" }
  end
  
  # Additional placeholder methods would follow the same pattern
  # Each method would implement specific compliance audit logic
  
  private_constant :REPORT_TYPES
end