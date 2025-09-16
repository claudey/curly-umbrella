# frozen_string_literal: true

class ErrorReport < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :organization, optional: true
  
  validates :exception_class, presence: true
  validates :message, presence: true
  validates :severity, inclusion: { in: ErrorTrackingService::SEVERITY_LEVELS.values }
  validates :category, inclusion: { in: ErrorTrackingService::ERROR_CATEGORIES.values }
  validates :fingerprint, presence: true
  validates :occurred_at, presence: true
  
  scope :recent, -> { order(occurred_at: :desc) }
  scope :unresolved, -> { where(resolved: false) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_fingerprint, ->(fingerprint) { where(fingerprint: fingerprint) }
  scope :in_last_hours, ->(hours) { where('occurred_at > ?', hours.hours.ago) }
  scope :in_last_days, ->(days) { where('occurred_at > ?', days.days.ago) }
  
  # Store arrays and hashes as JSON
  serialize :backtrace, JSON
  serialize :context, JSON
  
  before_save :set_defaults
  after_create :update_occurrence_count
  
  def similar_errors
    self.class.where(fingerprint: fingerprint)
            .where.not(id: id)
            .recent
            .limit(10)
  end
  
  def occurrence_count
    self.class.where(fingerprint: fingerprint).count
  end
  
  def first_occurrence
    self.class.where(fingerprint: fingerprint).order(:occurred_at).first
  end
  
  def last_occurrence
    self.class.where(fingerprint: fingerprint).order(:occurred_at).last
  end
  
  def frequency_per_hour
    return 0 if occurred_at < 1.hour.ago
    
    hours_since = ((Time.current - first_occurrence.occurred_at) / 1.hour).ceil
    hours_since = 1 if hours_since == 0
    
    occurrence_count.to_f / hours_since
  end
  
  def is_recurring?
    occurrence_count > 1
  end
  
  def is_trending?
    # Check if error frequency is increasing
    recent_count = similar_errors.where('occurred_at > ?', 24.hours.ago).count
    older_count = similar_errors.where('occurred_at BETWEEN ? AND ?', 48.hours.ago, 24.hours.ago).count
    
    recent_count > older_count && recent_count > 3
  end
  
  def severity_level
    case severity
    when 'critical' then 4
    when 'high' then 3
    when 'medium' then 2
    when 'low' then 1
    else 0
    end
  end
  
  def display_severity
    severity.humanize
  end
  
  def display_category
    category.humanize.gsub('_', ' ')
  end
  
  def short_message
    message.truncate(100)
  end
  
  def app_backtrace
    return [] unless backtrace.is_a?(Array)
    
    backtrace.select { |line| !line.include?('gems/') && !line.include?('ruby/') }
  end
  
  def primary_backtrace_line
    app_backtrace.first || backtrace&.first
  end
  
  def affected_file
    return nil unless primary_backtrace_line
    
    match = primary_backtrace_line.match(/^([^:]+):(\d+)/)
    match ? match[1] : nil
  end
  
  def affected_line_number
    return nil unless primary_backtrace_line
    
    match = primary_backtrace_line.match(/^([^:]+):(\d+)/)
    match ? match[2].to_i : nil
  end
  
  def user_impact_score
    # Calculate how many users are affected by this error
    affected_users = self.class.where(fingerprint: fingerprint)
                             .where.not(user_id: nil)
                             .distinct
                             .count(:user_id)
    
    case affected_users
    when 0..1 then 1
    when 2..5 then 2
    when 6..20 then 3
    when 21..100 then 4
    else 5
    end
  end
  
  def business_impact_score
    # Calculate business impact based on category and affected functionality
    category_impact = case category
                     when 'authentication', 'authorization' then 4
                     when 'database', 'security' then 4
                     when 'business_logic', 'validation' then 3
                     when 'performance', 'external_service' then 2
                     else 1
                     end
    
    severity_impact = severity_level
    user_impact = user_impact_score
    
    # Weight the factors
    ((category_impact * 0.4) + (severity_impact * 0.4) + (user_impact * 0.2)).round(1)
  end
  
  def resolve!(resolved_by: nil, resolution_notes: nil)
    update!(
      resolved: true,
      resolved_at: Time.current,
      resolved_by: resolved_by,
      resolution_notes: resolution_notes
    )
    
    # Log the resolution
    AuditLog.create!(
      user: resolved_by,
      organization: organization,
      action: 'error_resolved',
      category: 'system_access',
      resource_type: 'ErrorReport',
      resource_id: id,
      severity: 'info',
      details: {
        error_fingerprint: fingerprint,
        resolution_notes: resolution_notes,
        occurrence_count: occurrence_count
      }
    )
  end
  
  def reopen!(reopened_by: nil, reason: nil)
    update!(
      resolved: false,
      resolved_at: nil,
      resolved_by: nil,
      resolution_notes: nil,
      reopened_at: Time.current,
      reopened_by: reopened_by,
      reopen_reason: reason
    )
  end
  
  def can_be_resolved?
    !resolved?
  end
  
  def can_be_reopened?
    resolved? && resolved_at > 30.days.ago
  end
  
  def time_to_resolution
    return nil unless resolved? && resolved_at
    
    ((resolved_at - occurred_at) / 1.hour).round(2)
  end
  
  # Class methods for analytics and reporting
  def self.error_trends(period: 7.days)
    start_date = period.ago
    
    {
      total_errors: where('occurred_at > ?', start_date).count,
      by_severity: where('occurred_at > ?', start_date).group(:severity).count,
      by_category: where('occurred_at > ?', start_date).group(:category).count,
      by_day: where('occurred_at > ?', start_date).group_by_day(:occurred_at).count,
      unique_errors: where('occurred_at > ?', start_date).distinct.count(:fingerprint),
      resolved_count: where('occurred_at > ? AND resolved = ?', start_date, true).count,
      resolution_rate: calculate_resolution_rate(start_date)
    }
  end
  
  def self.top_errors(limit: 10, period: 7.days)
    start_date = period.ago
    
    where('occurred_at > ?', start_date)
      .group(:fingerprint, :exception_class, :message)
      .order(count: :desc)
      .limit(limit)
      .count
      .map do |key, count|
        fingerprint, exception_class, message = key
        {
          fingerprint: fingerprint,
          exception_class: exception_class,
          message: message,
          count: count,
          latest_occurrence: where(fingerprint: fingerprint).maximum(:occurred_at)
        }
      end
  end
  
  def self.error_hotspots(limit: 5)
    # Find files/locations with the most errors
    joins_sql = %{
      SELECT 
        SPLIT_PART(backtrace_line, ':', 1) as file_path,
        COUNT(*) as error_count
      FROM error_reports, 
           jsonb_array_elements_text(backtrace) as backtrace_line
      WHERE occurred_at > NOW() - INTERVAL '7 days'
        AND backtrace_line NOT LIKE '%gems%'
        AND backtrace_line NOT LIKE '%ruby%'
      GROUP BY file_path
      ORDER BY error_count DESC
      LIMIT #{limit}
    }
    
    connection.execute(joins_sql).to_a
  rescue
    # Fallback for non-PostgreSQL databases
    []
  end
  
  def self.calculate_resolution_rate(start_date)
    total = where('occurred_at > ?', start_date).count
    return 0 if total.zero?
    
    resolved = where('occurred_at > ? AND resolved = ?', start_date, true).count
    ((resolved.to_f / total) * 100).round(2)
  end
  
  def self.cleanup_old_errors(retention_period: 90.days)
    # Archive old resolved errors
    cutoff_date = retention_period.ago
    old_errors = where('occurred_at < ? AND resolved = ?', cutoff_date, true)
    
    Rails.logger.info "Cleaning up #{old_errors.count} old error reports"
    old_errors.delete_all
  end
  
  def self.error_health_score
    # Calculate overall error health score (0-100)
    recent_errors = where('occurred_at > ?', 24.hours.ago)
    return 100 if recent_errors.empty?
    
    total_errors = recent_errors.count
    critical_errors = recent_errors.where(severity: 'critical').count
    high_errors = recent_errors.where(severity: 'high').count
    unresolved_errors = recent_errors.where(resolved: false).count
    
    # Penalize based on severity and resolution status
    penalty = (critical_errors * 20) + (high_errors * 10) + (unresolved_errors * 5)
    
    # Calculate score (max penalty of 100 points)
    score = [100 - (penalty.to_f / total_errors * 100), 0].max
    score.round(1)
  end
  
  private
  
  def set_defaults
    self.environment ||= Rails.env
    self.application_version ||= Rails.application.config.version rescue '1.0.0'
    self.occurred_at ||= Time.current
  end
  
  def update_occurrence_count
    # This could trigger a cache update for real-time dashboards
    Rails.cache.delete("error_count:#{fingerprint}")
  end
end