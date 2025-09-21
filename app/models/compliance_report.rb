# frozen_string_literal: true

class ComplianceReport < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :generated_by, class_name: "User", optional: true

  has_many_attached :files

  validates :report_type, presence: true
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :generated_at, presence: true

  validate :period_end_after_start
  validate :valid_report_type

  scope :recent, -> { order(generated_at: :desc) }
  scope :by_type, ->(type) { where(report_type: type) }
  scope :by_organization, ->(org) { where(organization: org) }
  scope :in_period, ->(start_date, end_date) { where(period_start: start_date..end_date) }

  enum status: {
    generating: "generating",
    completed: "completed",
    failed: "failed",
    archived: "archived"
  }, _default: "generating"

  # Store report data as JSON
  serialize :data, JSON
  serialize :metadata, JSON

  before_save :set_defaults
  after_create :log_creation

  def period_description
    if period_start.to_date == period_end.to_date
      period_start.strftime("%B %d, %Y")
    elsif period_start.year == period_end.year
      if period_start.month == period_end.month
        "#{period_start.strftime('%B %d')} - #{period_end.strftime('%d, %Y')}"
      else
        "#{period_start.strftime('%B %d')} - #{period_end.strftime('%B %d, %Y')}"
      end
    else
      "#{period_start.strftime('%B %d, %Y')} - #{period_end.strftime('%B %d, %Y')}"
    end
  end

  def report_type_description
    ComplianceReportingService::REPORT_TYPES.dig(report_type.to_sym, :description) || report_type.humanize
  end

  def retention_period
    retention_years = ComplianceReportingService::REPORT_TYPES.dig(report_type.to_sym, :retention) || 7.years
    generated_at + retention_years
  end

  def expired?
    retention_period < Time.current
  end

  def file_size_total
    files.sum(&:byte_size)
  end

  def human_file_size
    return "0 B" if file_size_total.zero?

    units = [ "B", "KB", "MB", "GB", "TB" ]
    size = file_size_total.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  def has_pdf?
    files.any? { |file| file.content_type == "application/pdf" }
  end

  def has_csv?
    files.any? { |file| file.content_type == "text/csv" }
  end

  def has_json?
    files.any? { |file| file.content_type == "application/json" }
  end

  def pdf_file
    files.find { |file| file.content_type == "application/pdf" }
  end

  def csv_file
    files.find { |file| file.content_type == "text/csv" }
  end

  def json_file
    files.find { |file| file.content_type == "application/json" }
  end

  def summary_stats
    return {} unless data.present?

    # Extract key metrics from report data
    stats = {}

    if data["total_events"]
      stats[:total_events] = data["total_events"]
    end

    if data["critical_events"]
      stats[:critical_events] = data["critical_events"].is_a?(Array) ? data["critical_events"].size : data["critical_events"]
    end

    if data["unique_users"]
      stats[:unique_users] = data["unique_users"]
    end

    if data["security_events"]
      stats[:security_events] = data["security_events"]
    end

    if data["compliance_events"]
      stats[:compliance_events] = data["compliance_events"]
    end

    stats
  end

  def compliance_score
    return nil unless data.present?

    # Calculate a compliance score based on the report data
    total_events = data["total_events"].to_i
    return 100 if total_events.zero?

    critical_events = data["critical_events"].is_a?(Array) ? data["critical_events"].size : data["critical_events"].to_i
    warning_events = data["events_by_severity"].is_a?(Hash) ? data["events_by_severity"]["warning"].to_i : 0
    error_events = data["events_by_severity"].is_a?(Hash) ? data["events_by_severity"]["error"].to_i : 0

    # Calculate score (100 is perfect, 0 is worst)
    penalty = (critical_events * 10) + (error_events * 5) + (warning_events * 1)
    score = [ 100 - (penalty.to_f / total_events * 100), 0 ].max

    score.round(1)
  end

  def security_incidents_count
    return 0 unless data.present?

    if data["suspicious_activities"].is_a?(Array)
      data["suspicious_activities"].size
    elsif data["incident_summary"].is_a?(Hash)
      data["incident_summary"]["total_incidents"].to_i
    else
      0
    end
  end

  def mark_as_completed!
    update!(status: "completed", completed_at: Time.current)
  end

  def mark_as_failed!(error_message = nil)
    update!(
      status: "failed",
      failed_at: Time.current,
      error_message: error_message
    )
  end

  def archive!
    update!(status: "archived", archived_at: Time.current)
  end

  def can_be_deleted?
    expired? && status == "archived"
  end

  # Class methods for management
  def self.cleanup_expired_reports
    expired_reports = where("generated_at + INTERVAL retention_years YEAR < ?", Time.current)

    expired_reports.find_each do |report|
      if report.can_be_deleted?
        report.files.purge
        report.destroy
      else
        report.archive! unless report.archived?
      end
    end
  end

  def self.generate_summary_for_period(start_date, end_date)
    reports = where(period_start: start_date..end_date)

    {
      total_reports: reports.count,
      by_type: reports.group(:report_type).count,
      by_status: reports.group(:status).count,
      by_organization: reports.joins(:organization).group("organizations.name").count,
      total_file_size: reports.sum { |r| r.file_size_total },
      average_compliance_score: reports.filter_map(&:compliance_score).sum / reports.count.to_f
    }
  end

  private

  def set_defaults
    self.generated_at ||= Time.current
    self.metadata ||= {}
    self.data ||= {}
  end

  def log_creation
    AuditLog.log_compliance_event(
      generated_by,
      "compliance_report_created",
      {
        report_id: id,
        report_type: report_type,
        organization_id: organization_id,
        period_start: period_start,
        period_end: period_end
      }
    )
  end

  def period_end_after_start
    return unless period_start && period_end

    if period_end < period_start
      errors.add(:period_end, "must be after period start")
    end
  end

  def valid_report_type
    valid_types = ComplianceReportingService::REPORT_TYPES.keys.map(&:to_s)
    unless valid_types.include?(report_type)
      errors.add(:report_type, "must be one of: #{valid_types.join(', ')}")
    end
  end
end
