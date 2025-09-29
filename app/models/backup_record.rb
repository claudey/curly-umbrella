# frozen_string_literal: true

class BackupRecord < ApplicationRecord
  has_many :backup_restore_records, dependent: :destroy

  validates :backup_type, presence: true, inclusion: { in: BackupManagementService::BACKUP_TYPES.keys.map(&:to_s) }
  validates :status, presence: true, inclusion: { in: %w[in_progress completed failed] }
  validates :started_at, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(backup_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :successful, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :completed_today, -> { where(status: "completed", completed_at: Time.current.beginning_of_day..Time.current.end_of_day) }

  # Store JSON data
  serialize :metadata, coder: JSON
  serialize :error_details, coder: JSON
  serialize :verification_details, coder: JSON

  before_save :calculate_duration
  after_create :log_backup_started

  def backup_config
    BackupManagementService::BACKUP_TYPES[backup_type.to_sym]
  end

  def display_name
    backup_config&.dig(:name) || backup_type.humanize
  end

  def priority
    backup_config&.dig(:priority) || "medium"
  end

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def duration_in_words
    return "N/A" unless duration

    if duration < 60
      "#{duration.round(1)} seconds"
    elsif duration < 3600
      "#{(duration / 60).round(1)} minutes"
    else
      "#{(duration / 3600).round(1)} hours"
    end
  end

  def formatted_file_size
    return "N/A" unless file_size

    units = [ "B", "KB", "MB", "GB", "TB" ]
    size = file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  def success?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def in_progress?
    status == "in_progress"
  end

  def can_be_restored?
    success? && integrity_verified? && File.exist?(file_path.to_s)
  end

  def integrity_verified?
    integrity_verified == true
  end

  def file_exists?
    file_path.present? && File.exist?(file_path)
  end

  def age_in_days
    (Time.current - created_at) / 1.day
  end

  def expired?
    retention_days = backup_config&.dig(:retention_days) || 30
    age_in_days > retention_days
  end

  def status_color
    case status
    when "completed" then integrity_verified? ? "green" : "yellow"
    when "failed" then "red"
    when "in_progress" then "blue"
    else "gray"
    end
  end

  def status_icon
    case status
    when "completed" then integrity_verified? ? "✅" : "⚠️"
    when "failed" then "❌"
    when "in_progress" then "🔄"
    else "❓"
    end
  end

  def test_integrity!
    result = BackupManagementService.test_backup_integrity(self)
    update!(
      integrity_verified: result[:verified],
      verification_details: result
    )
    result
  end

  def restore!(user, options = {})
    BackupManagementService.restore_backup(self, options.merge(user: user))
  end

  # Class methods for reporting and management
  def self.backup_health_summary
    {
      total_backups: count,
      successful_backups: successful.count,
      failed_backups: failed.count,
      in_progress_backups: where(status: "in_progress").count,
      backups_today: completed_today.count,
      average_backup_size: successful.average(:file_size)&.round(2) || 0,
      oldest_backup: minimum(:created_at),
      newest_backup: maximum(:created_at),
      by_type: group(:backup_type).count,
      integrity_status: {
        verified: where(integrity_verified: true).count,
        unverified: where(integrity_verified: [ false, nil ]).count
      }
    }
  end

  def self.daily_backup_status
    today = Time.current.beginning_of_day..Time.current.end_of_day

    BackupManagementService::BACKUP_TYPES.map do |backup_type, config|
      todays_backup = where(backup_type: backup_type.to_s, created_at: today).successful.first

      {
        backup_type: backup_type,
        name: config[:name],
        priority: config[:priority],
        expected_frequency: config[:frequency],
        completed_today: todays_backup.present?,
        last_successful: where(backup_type: backup_type.to_s).successful.recent.first&.created_at,
        status: determine_backup_status(backup_type, config, todays_backup)
      }
    end
  end

  def self.storage_usage_report
    successful_backups = successful.where("created_at > ?", 30.days.ago)

    {
      total_storage_used: successful_backups.sum(:file_size),
      by_type: successful_backups.group(:backup_type).sum(:file_size),
      by_day: successful_backups.group_by_day(:created_at).sum(:file_size),
      average_backup_size: successful_backups.average(:file_size)&.round(2) || 0,
      largest_backup: successful_backups.maximum(:file_size) || 0,
      backup_count: successful_backups.count
    }
  end

  def self.cleanup_expired_backups
    cleanup_count = 0
    space_freed = 0

    BackupManagementService::BACKUP_TYPES.each do |backup_type, config|
      retention_cutoff = config[:retention_days].days.ago
      expired_backups = where(backup_type: backup_type.to_s)
                       .where("created_at < ?", retention_cutoff)
                       .successful

      expired_backups.find_each do |backup|
        if backup.file_path.present? && File.exist?(backup.file_path)
          space_freed += File.size(backup.file_path)
          File.delete(backup.file_path)
        end

        backup.destroy
        cleanup_count += 1
      end
    end

    { cleaned_count: cleanup_count, space_freed: space_freed }
  end

  private

  def calculate_duration
    self.duration_seconds = duration&.round(2) if duration
  end

  def log_backup_started
    AuditLog.create!(
      user: nil,
      action: "backup_started",
      category: "system_access",
      resource_type: "BackupRecord",
      resource_id: id,
      severity: "info",
      details: {
        backup_type: backup_type,
        backup_id: id,
        priority: priority
      }
    )
  rescue => e
    Rails.logger.error "Failed to log backup start: #{e.message}"
  end

  def self.determine_backup_status(backup_type, config, todays_backup)
    if config[:frequency] == "daily"
      todays_backup ? "completed" : "missing"
    elsif config[:frequency] == "weekly"
      # Check if backup exists within the last week
      recent_backup = where(backup_type: backup_type.to_s)
                     .successful
                     .where("created_at > ?", 1.week.ago)
                     .exists?
      recent_backup ? "completed" : "overdue"
    else
      "unknown"
    end
  end
end
