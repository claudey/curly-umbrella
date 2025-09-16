# frozen_string_literal: true

class AuditNotificationMailer < ApplicationMailer
  def critical_audit_alert(user, audit_log)
    @user = user
    @audit_log = audit_log
    @organization = audit_log.organization
    @alert_details = format_audit_details(@audit_log)
    
    mail(
      to: @user.email,
      subject: "🚨 CRITICAL SECURITY ALERT - #{@audit_log.action.humanize}",
      template_name: 'critical_audit_alert'
    )
  end
  
  def high_priority_audit_alert(user, audit_log)
    @user = user
    @audit_log = audit_log
    @organization = audit_log.organization
    @alert_details = format_audit_details(@audit_log)
    
    mail(
      to: @user.email,
      subject: "⚠️ Security Alert - #{@audit_log.action.humanize}",
      template_name: 'high_priority_audit_alert'
    )
  end
  
  def audit_digest(user, audit_logs, period: 'daily')
    @user = user
    @audit_logs = audit_logs
    @organization = user.organization
    @period = period
    @summary = generate_digest_summary(@audit_logs)
    
    mail(
      to: @user.email,
      subject: "📊 #{period.capitalize} Audit Digest - #{@organization&.name}",
      template_name: 'audit_digest'
    )
  end
  
  def compliance_violation_alert(user, audit_log)
    @user = user
    @audit_log = audit_log
    @organization = audit_log.organization
    @violation_details = extract_compliance_details(@audit_log)
    
    mail(
      to: @user.email,
      subject: "🚨 Compliance Violation Alert - Immediate Action Required",
      template_name: 'compliance_violation_alert'
    )
  end
  
  def suspicious_activity_report(user, audit_logs, time_period)
    @user = user
    @audit_logs = audit_logs
    @organization = user.organization
    @time_period = time_period
    @suspicious_patterns = analyze_suspicious_patterns(@audit_logs)
    
    mail(
      to: @user.email,
      subject: "🕵️ Suspicious Activity Report - #{time_period}",
      template_name: 'suspicious_activity_report'
    )
  end
  
  private
  
  def format_audit_details(audit_log)
    {
      action: audit_log.display_action,
      category: audit_log.display_category,
      severity: audit_log.display_severity,
      user: audit_log.user&.email || 'System',
      resource: audit_log.resource_type,
      timestamp: audit_log.created_at.strftime('%Y-%m-%d at %H:%M:%S %Z'),
      ip_address: audit_log.ip_address,
      details: audit_log.formatted_details,
      organization: audit_log.organization&.name
    }
  end
  
  def generate_digest_summary(audit_logs)
    {
      total_events: audit_logs.count,
      by_severity: audit_logs.group(:severity).count,
      by_category: audit_logs.group(:category).count,
      by_user: audit_logs.joins(:user).group('users.email').count.first(10),
      critical_events: audit_logs.where(severity: 'critical').count,
      failed_actions: audit_logs.where("action LIKE '%_error' OR action LIKE 'unauthorized_%'").count,
      time_range: {
        start: audit_logs.minimum(:created_at)&.strftime('%Y-%m-%d %H:%M'),
        end: audit_logs.maximum(:created_at)&.strftime('%Y-%m-%d %H:%M')
      }
    }
  end
  
  def extract_compliance_details(audit_log)
    details = audit_log.details || {}
    
    {
      violation_type: determine_violation_type(audit_log),
      affected_data: details['resource_type'] || audit_log.resource_type,
      user_involved: audit_log.user&.email || 'Unknown',
      timestamp: audit_log.created_at,
      ip_address: audit_log.ip_address,
      potential_impact: assess_compliance_impact(audit_log),
      required_actions: generate_compliance_actions(audit_log)
    }
  end
  
  def determine_violation_type(audit_log)
    case audit_log.action
    when /unauthorized/
      'Unauthorized Access Attempt'
    when /export/, /bulk_download/
      'Potential Data Exfiltration'
    when /delete/, /destroy/
      'Data Retention Violation'
    when /financial/
      'Financial Compliance Issue'
    else
      'General Compliance Violation'
    end
  end
  
  def assess_compliance_impact(audit_log)
    case audit_log.severity
    when 'critical'
      'High - Immediate investigation required'
    when 'error'
      'Medium - Review within 24 hours'
    when 'warning'
      'Low - Monitor and document'
    else
      'Minimal - Log for audit trail'
    end
  end
  
  def generate_compliance_actions(audit_log)
    actions = [
      'Document the incident in compliance log',
      'Review user permissions and access controls'
    ]
    
    case audit_log.action
    when /unauthorized/
      actions << 'Verify user identity and intent'
      actions << 'Consider temporary access restriction'
    when /export/, /bulk_download/
      actions << 'Verify business justification for data export'
      actions << 'Ensure data handling policies were followed'
    when /delete/, /destroy/
      actions << 'Verify deletion was authorized and necessary'
      actions << 'Check if backup/retention requirements were met'
    end
    
    actions
  end
  
  def analyze_suspicious_patterns(audit_logs)
    patterns = {}
    
    # Analyze login patterns
    login_failures = audit_logs.where(action: 'login_failure')
    if login_failures.count > 10
      patterns[:excessive_login_failures] = {
        count: login_failures.count,
        unique_users: login_failures.joins(:user).distinct.count('users.id'),
        unique_ips: login_failures.distinct.count(:ip_address)
      }
    end
    
    # Analyze access patterns
    unauthorized_attempts = audit_logs.where("action LIKE 'unauthorized_%'")
    if unauthorized_attempts.count > 5
      patterns[:unauthorized_access_attempts] = {
        count: unauthorized_attempts.count,
        resources: unauthorized_attempts.group(:resource_type).count,
        users: unauthorized_attempts.joins(:user).group('users.email').count
      }
    end
    
    # Analyze data access patterns
    bulk_operations = audit_logs.where("action LIKE 'bulk_%' OR action LIKE 'mass_%'")
    if bulk_operations.any?
      patterns[:bulk_operations] = {
        count: bulk_operations.count,
        types: bulk_operations.group(:action).count,
        users: bulk_operations.joins(:user).group('users.email').count
      }
    end
    
    # Analyze time-based patterns
    off_hours_activity = audit_logs.where(
      "EXTRACT(hour FROM created_at) < 6 OR EXTRACT(hour FROM created_at) > 22"
    )
    if off_hours_activity.count > (audit_logs.count * 0.1) # More than 10% off-hours
      patterns[:off_hours_activity] = {
        count: off_hours_activity.count,
        percentage: ((off_hours_activity.count.to_f / audit_logs.count) * 100).round(1),
        users: off_hours_activity.joins(:user).group('users.email').count.first(5)
      }
    end
    
    patterns
  end
end