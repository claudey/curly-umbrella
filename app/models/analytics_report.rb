# frozen_string_literal: true

class AnalyticsReport < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization
  audited

  belongs_to :organization
  belongs_to :created_by, class_name: 'User'
  belongs_to :scheduled_by, class_name: 'User', optional: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :frequency, inclusion: { in: FREQUENCIES }, allow_nil: true

  # Report type constants
  REPORT_TYPES = %w[
    executive_dashboard
    trend_analysis
    risk_assessment
    performance_metrics
    financial_summary
    client_analytics
    quote_analytics
    application_analytics
    custom_query
  ].freeze

  # Status constants
  STATUSES = %w[
    draft
    scheduled
    processing
    completed
    failed
    archived
  ].freeze

  # Frequency constants for scheduled reports
  FREQUENCIES = %w[
    daily
    weekly
    monthly
    quarterly
    yearly
    on_demand
  ].freeze

  # Data format constants
  DATA_FORMATS = %w[
    json
    pdf
    excel
    csv
    html
  ].freeze

  scope :active, -> { kept.where.not(status: 'archived') }
  scope :scheduled, -> { where(status: 'scheduled') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_type, ->(type) { where(report_type: type) }
  scope :by_frequency, ->(freq) { where(frequency: freq) }

  before_create :set_defaults
  after_create :schedule_generation_if_needed

  def executive_dashboard?
    report_type == 'executive_dashboard'
  end

  def scheduled?
    status == 'scheduled' && frequency.present? && frequency != 'on_demand'
  end

  def can_be_regenerated?
    %w[completed failed].include?(status)
  end

  def next_run_time
    return nil unless scheduled?
    return nil unless last_generated_at

    case frequency
    when 'daily' then last_generated_at + 1.day
    when 'weekly' then last_generated_at + 1.week
    when 'monthly' then last_generated_at + 1.month
    when 'quarterly' then last_generated_at + 3.months
    when 'yearly' then last_generated_at + 1.year
    else nil
    end
  end

  def overdue?
    return false unless scheduled?
    return true unless last_generated_at

    next_run = next_run_time
    next_run && next_run < Time.current
  end

  def configuration_valid?
    return false if configuration.blank?
    
    case report_type
    when 'executive_dashboard'
      validate_executive_dashboard_config
    when 'trend_analysis'
      validate_trend_analysis_config
    when 'risk_assessment'
      validate_risk_assessment_config
    when 'custom_query'
      validate_custom_query_config
    else
      true # Basic reports don't require special validation
    end
  end

  def generate_report!
    update!(status: 'processing', started_at: Time.current)
    
    begin
      result = AdvancedReportGenerationService.generate_report(self)
      
      update!(
        status: 'completed',
        completed_at: Time.current,
        last_generated_at: Time.current,
        data: result[:data],
        metadata: result[:metadata],
        file_size: result[:file_size],
        generation_time_seconds: (Time.current - started_at).round(2)
      )
      
      # Send notifications if configured
      send_completion_notifications if configuration.dig('notifications', 'on_completion')
      
      result
    rescue => e
      update!(
        status: 'failed',
        completed_at: Time.current,
        error_message: e.message,
        generation_time_seconds: (Time.current - started_at).round(2)
      )
      
      # Log error and send failure notifications
      Rails.logger.error "Report generation failed for #{name}: #{e.message}"
      send_failure_notifications if configuration.dig('notifications', 'on_failure')
      
      raise e
    end
  end

  def export_formats
    config_formats = configuration.dig('export', 'formats') || ['json']
    config_formats & DATA_FORMATS
  end

  def sharing_enabled?
    configuration.dig('sharing', 'enabled') == true
  end

  def sharing_permissions
    configuration.dig('sharing', 'permissions') || {}
  end

  def dashboard_widgets
    return [] unless executive_dashboard?
    configuration.dig('dashboard', 'widgets') || []
  end

  def refresh_interval_minutes
    interval = configuration.dig('dashboard', 'refresh_interval_minutes')
    interval.present? ? interval.to_i : 15 # Default 15 minutes
  end

  def data_retention_days
    retention = configuration.dig('retention', 'days')
    retention.present? ? retention.to_i : 90 # Default 90 days
  end

  def self.cleanup_old_reports!
    # Clean up old report data based on retention policies
    find_each do |report|
      next unless report.data.present?
      next unless report.last_generated_at
      
      retention_days = report.data_retention_days
      cutoff_date = retention_days.days.ago
      
      if report.last_generated_at < cutoff_date
        report.update!(data: nil, metadata: nil)
        Rails.logger.info "Cleaned up old data for report: #{report.name}"
      end
    end
  end

  def self.generate_scheduled_reports!
    scheduled.find_each do |report|
      next unless report.overdue?
      
      begin
        ReportGenerationJob.perform_later(report)
        Rails.logger.info "Queued scheduled report generation: #{report.name}"
      rescue => e
        Rails.logger.error "Failed to queue report generation for #{report.name}: #{e.message}"
      end
    end
  end

  private

  def set_defaults
    self.status ||= 'draft'
    self.configuration ||= {}
    self.data ||= {}
    self.metadata ||= {}
  end

  def schedule_generation_if_needed
    return unless scheduled?
    return if frequency == 'on_demand'
    
    # Schedule first generation
    ReportGenerationJob.perform_later(self)
  end

  def validate_executive_dashboard_config
    widgets = configuration.dig('dashboard', 'widgets')
    return false unless widgets.is_a?(Array)
    
    required_widget_fields = %w[type title size]
    widgets.all? do |widget|
      required_widget_fields.all? { |field| widget.key?(field) }
    end
  end

  def validate_trend_analysis_config
    metrics = configuration.dig('analysis', 'metrics')
    time_range = configuration.dig('analysis', 'time_range')
    
    metrics.present? && time_range.present?
  end

  def validate_risk_assessment_config
    risk_factors = configuration.dig('assessment', 'risk_factors')
    threshold = configuration.dig('assessment', 'threshold')
    
    risk_factors.is_a?(Array) && risk_factors.any? && threshold.present?
  end

  def validate_custom_query_config
    query = configuration.dig('query', 'sql')
    parameters = configuration.dig('query', 'parameters')
    
    query.present? && parameters.is_a?(Hash)
  end

  def send_completion_notifications
    recipients = configuration.dig('notifications', 'recipients') || []
    return if recipients.empty?
    
    ReportNotificationMailer.report_completed(self, recipients).deliver_later
  end

  def send_failure_notifications
    recipients = configuration.dig('notifications', 'recipients') || []
    admin_emails = organization.users.where(role: 'admin').pluck(:email)
    all_recipients = (recipients + admin_emails).uniq
    
    return if all_recipients.empty?
    
    ReportNotificationMailer.report_failed(self, all_recipients).deliver_later
  end
end