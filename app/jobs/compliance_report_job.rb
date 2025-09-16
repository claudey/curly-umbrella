# frozen_string_literal: true

class ComplianceReportJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 5.minutes, attempts: 3
  
  def perform(report_type, organization_id = nil, **options)
    organization = organization_id ? Organization.find_by(id: organization_id) : nil
    
    # Generate the compliance report
    report = ComplianceReportingService.generate_report(
      report_type,
      organization,
      **options.symbolize_keys
    )
    
    # Log successful generation
    log_report_generation(report, organization)
    
    report
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "ComplianceReportJob: Organization #{organization_id} not found"
  rescue => e
    Rails.logger.error "ComplianceReportJob failed for #{report_type}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Create audit log for the failure
    create_failure_audit_log(report_type, organization_id, e)
    
    raise # Re-raise to trigger retry mechanism
  end
  
  private
  
  def log_report_generation(report, organization)
    AuditLog.log_compliance_event(
      nil, # System-generated
      'compliance_report_generated',
      {
        report_id: report.id,
        report_type: report.report_type,
        organization_id: organization&.id,
        period_start: report.period_start,
        period_end: report.period_end,
        generated_at: report.generated_at
      }
    )
  end
  
  def create_failure_audit_log(report_type, organization_id, error)
    AuditLog.create!(
      user: nil, # System-generated
      organization_id: organization_id,
      action: 'compliance_report_generation_failed',
      category: 'compliance',
      resource_type: 'ComplianceReport',
      severity: 'error',
      details: {
        report_type: report_type,
        organization_id: organization_id,
        error_class: error.class.name,
        error_message: error.message,
        failed_at: Time.current,
        job_class: self.class.name
      }
    )
  rescue => nested_error
    Rails.logger.error "Failed to create compliance report failure log: #{nested_error.message}"
  end
end