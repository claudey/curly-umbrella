# frozen_string_literal: true

module Entities
  class ApplicationEntity < Grape::Entity
    expose :id, documentation: { type: 'Integer', desc: 'Application ID' }
    expose :reference_number, documentation: { type: 'String', desc: 'Unique reference number' }
    expose :application_type, documentation: { type: 'String', desc: 'Type of insurance application' }
    expose :status, documentation: { type: 'String', desc: 'Current application status' }
    expose :effective_date, documentation: { type: 'Date', desc: 'Coverage effective date' }
    expose :expiry_date, documentation: { type: 'Date', desc: 'Coverage expiry date' }
    expose :sum_insured, documentation: { type: 'Float', desc: 'Sum insured amount' }
    expose :premium_amount, documentation: { type: 'Float', desc: 'Premium amount' }
    expose :broker_notes, documentation: { type: 'String', desc: 'Broker notes' }
    expose :created_at, documentation: { type: 'DateTime', desc: 'Creation timestamp' }
    expose :updated_at, documentation: { type: 'DateTime', desc: 'Last update timestamp' }
    expose :submitted_at, documentation: { type: 'DateTime', desc: 'Submission timestamp' }
    
    # Client information
    expose :client, using: ClientEntity, documentation: { type: 'Object', desc: 'Associated client information' }
    
    # User information
    expose :created_by, documentation: { type: 'Object', desc: 'User who created the application' } do |application|
      {
        id: application.user.id,
        name: application.user.full_name,
        email: application.user.email
      }
    end
    
    # Conditional detailed information
    expose :application_data, if: ->(application, options) { options[:with_details] },
           documentation: { type: 'Hash', desc: 'Application-specific data fields' }
    
    expose :documents_count, documentation: { type: 'Integer', desc: 'Number of attached documents' } do |application|
      application.documents.count
    end
    
    expose :quotes_count, documentation: { type: 'Integer', desc: 'Number of generated quotes' } do |application|
      application.quotes.count
    end
    
    # Detailed information only when requested
    expose :documents, using: DocumentEntity, if: ->(application, options) { options[:with_details] },
           documentation: { type: 'Array', desc: 'Associated documents' }
    
    expose :quotes, using: QuoteEntity, if: ->(application, options) { options[:with_details] },
           documentation: { type: 'Array', desc: 'Associated quotes' }
    
    # Status information
    expose :status_info, documentation: { type: 'Object', desc: 'Detailed status information' } do |application|
      {
        status: application.status,
        status_label: application.status.humanize,
        can_edit: application.status.in?(%w[draft]),
        can_submit: application.status == 'draft',
        workflow_stage: application.workflow_stage || 'initial'
      }
    end
    
    # Financial summary
    expose :financial_summary, documentation: { type: 'Object', desc: 'Financial information summary' } do |application|
      {
        sum_insured: application.sum_insured,
        premium_amount: application.premium_amount,
        currency: 'USD', # TODO: Make this configurable
        payment_frequency: application.payment_frequency || 'annual'
      }
    end
    
    # Risk assessment (if available)
    expose :risk_assessment, if: ->(application, options) { options[:with_details] && application.risk_score },
           documentation: { type: 'Object', desc: 'Risk assessment information' } do |application|
      {
        risk_score: application.risk_score,
        risk_level: application.risk_level,
        assessment_date: application.risk_assessed_at,
        factors: application.risk_factors || []
      }
    end
    
    # Workflow information
    expose :workflow_info, if: ->(application, options) { options[:with_details] },
           documentation: { type: 'Object', desc: 'Workflow and processing information' } do |application|
      {
        current_stage: application.workflow_stage || 'initial',
        next_actions: determine_next_actions(application),
        processing_time: calculate_processing_time(application),
        sla_status: calculate_sla_status(application)
      }
    end
    
    # API metadata
    expose :api_metadata, documentation: { type: 'Object', desc: 'API-specific metadata' } do |application|
      {
        created_via_api: application.source == 'api',
        last_api_update: application.updated_at,
        version: 'v1'
      }
    end
    
    private
    
    def self.determine_next_actions(application)
      case application.status
      when 'draft'
        ['Complete application details', 'Upload required documents', 'Submit for review']
      when 'submitted'
        ['Await underwriter review', 'Respond to any queries']
      when 'under_review'
        ['Provide additional information if requested']
      when 'approved'
        ['Review policy terms', 'Arrange payment', 'Issue policy']
      when 'rejected'
        ['Review rejection reasons', 'Resubmit with corrections']
      else
        []
      end
    end
    
    def self.calculate_processing_time(application)
      return nil unless application.submitted_at
      
      end_time = case application.status
                 when 'approved', 'rejected'
                   application.updated_at
                 else
                   Time.current
                 end
      
      {
        days: ((end_time - application.submitted_at) / 1.day).round(1),
        business_days: calculate_business_days(application.submitted_at, end_time),
        is_complete: application.status.in?(%w[approved rejected])
      }
    end
    
    def self.calculate_business_days(start_time, end_time)
      # Simple business days calculation (excluding weekends)
      total_days = (end_time - start_time) / 1.day
      weekends = (total_days / 7).floor * 2
      
      # Adjust for partial weeks
      remaining_days = total_days % 7
      start_day = start_time.wday
      
      weekend_days_in_partial_week = 0
      (0...remaining_days.ceil).each do |i|
        day = (start_day + i) % 7
        weekend_days_in_partial_week += 1 if day == 0 || day == 6 # Sunday or Saturday
      end
      
      (total_days - weekends - weekend_days_in_partial_week).round(1)
    end
    
    def self.calculate_sla_status(application)
      return nil unless application.submitted_at
      
      # SLA targets by application type
      sla_days = case application.application_type
                when 'motor' then 3
                when 'fire' then 5
                when 'liability' then 7
                when 'general_accident' then 5
                when 'bonds' then 10
                else 5
                end
      
      processing_time = calculate_processing_time(application)
      return nil unless processing_time
      
      {
        target_days: sla_days,
        actual_days: processing_time[:business_days],
        status: processing_time[:business_days] <= sla_days ? 'on_time' : 'overdue',
        overdue_by: [processing_time[:business_days] - sla_days, 0].max.round(1)
      }
    end
  end
end