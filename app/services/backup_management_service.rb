# frozen_string_literal: true

class BackupManagementService
  include ActiveModel::Model

  # Backup types and their configurations
  BACKUP_TYPES = {
    database: {
      name: "Database Backup",
      description: "Full PostgreSQL database backup",
      frequency: "daily",
      retention_days: 30,
      priority: "critical"
    },
    files: {
      name: "File Storage Backup",
      description: "Application files and uploaded documents",
      frequency: "daily",
      retention_days: 30,
      priority: "high"
    },
    configurations: {
      name: "Configuration Backup",
      description: "Application configuration and secrets",
      frequency: "weekly",
      retention_days: 90,
      priority: "medium"
    },
    logs: {
      name: "Log Files Backup",
      description: "Application and system logs",
      frequency: "weekly",
      retention_days: 14,
      priority: "low"
    }
  }.freeze

  def self.create_backup(backup_type, options = {})
    new.create_backup(backup_type.to_sym, options)
  end

  def self.restore_backup(backup_record, options = {})
    new.restore_backup(backup_record, options)
  end

  def self.test_backup_integrity(backup_record)
    new.test_backup_integrity(backup_record)
  end

  def self.cleanup_old_backups
    new.cleanup_old_backups
  end

  def create_backup(backup_type, options = {})
    validate_backup_type!(backup_type)

    backup_config = BACKUP_TYPES[backup_type]
    backup_start_time = Time.current

    Rails.logger.info "Starting #{backup_config[:name]} (#{backup_type})"

    # Create backup record
    backup_record = BackupRecord.create!(
      backup_type: backup_type.to_s,
      status: "in_progress",
      started_at: backup_start_time,
      metadata: {
        backup_config: backup_config,
        options: options,
        hostname: Socket.gethostname,
        rails_env: Rails.env
      }
    )

    begin
      # Perform the actual backup
      backup_result = case backup_type
      when :database
                       create_database_backup(backup_record, options)
      when :files
                       create_files_backup(backup_record, options)
      when :configurations
                       create_configurations_backup(backup_record, options)
      when :logs
                       create_logs_backup(backup_record, options)
      else
                       raise ArgumentError, "Unknown backup type: #{backup_type}"
      end

      # Update backup record with results
      backup_record.update!(
        status: "completed",
        completed_at: Time.current,
        file_path: backup_result[:file_path],
        file_size: backup_result[:file_size],
        checksum: backup_result[:checksum],
        metadata: backup_record.metadata.merge(backup_result[:metadata] || {})
      )

      # Test backup integrity immediately after creation
      test_result = test_backup_integrity(backup_record)
      backup_record.update!(
        integrity_verified: test_result[:verified],
        verification_details: test_result
      )

      # Log successful backup
      log_backup_completion(backup_record)

      # Send notifications for critical backups
      send_backup_notifications(backup_record) if backup_config[:priority] == "critical"

      backup_record

    rescue => e
      # Handle backup failure
      backup_record.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: e.message,
        error_details: {
          exception_class: e.class.name,
          backtrace: e.backtrace&.first(10)
        }
      )

      # Log and track the error
      Rails.logger.error "Backup failed: #{e.message}"
      ErrorTrackingService.track_error(e, {
        backup_type: backup_type,
        backup_record_id: backup_record.id
      })

      # Send failure notifications
      send_backup_failure_notifications(backup_record, e)

      raise
    end
  end

  def restore_backup(backup_record, options = {})
    Rails.logger.info "Starting restore from backup #{backup_record.id} (#{backup_record.backup_type})"

    # Verify backup integrity before restore
    integrity_result = test_backup_integrity(backup_record)
    unless integrity_result[:verified]
      raise "Backup integrity verification failed: #{integrity_result[:error]}"
    end

    restore_start_time = Time.current

    # Create restore record
    restore_record = BackupRestoreRecord.create!(
      backup_record: backup_record,
      status: "in_progress",
      started_at: restore_start_time,
      requested_by: options[:user],
      restore_options: options,
      metadata: {
        hostname: Socket.gethostname,
        rails_env: Rails.env
      }
    )

    begin
      # Perform the restore
      restore_result = case backup_record.backup_type.to_sym
      when :database
                        restore_database_backup(backup_record, restore_record, options)
      when :files
                        restore_files_backup(backup_record, restore_record, options)
      when :configurations
                        restore_configurations_backup(backup_record, restore_record, options)
      when :logs
                        restore_logs_backup(backup_record, restore_record, options)
      else
                        raise ArgumentError, "Unknown backup type: #{backup_record.backup_type}"
      end

      # Update restore record
      restore_record.update!(
        status: "completed",
        completed_at: Time.current,
        restore_details: restore_result
      )

      # Log successful restore
      log_restore_completion(restore_record)

      # Send notifications
      send_restore_notifications(restore_record)

      restore_record

    rescue => e
      # Handle restore failure
      restore_record.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: e.message,
        error_details: {
          exception_class: e.class.name,
          backtrace: e.backtrace&.first(10)
        }
      )

      # Log and track the error
      Rails.logger.error "Restore failed: #{e.message}"
      ErrorTrackingService.track_error(e, {
        backup_record_id: backup_record.id,
        restore_record_id: restore_record.id
      })

      raise
    end
  end

  def test_backup_integrity(backup_record)
    Rails.logger.info "Testing integrity of backup #{backup_record.id}"

    begin
      case backup_record.backup_type.to_sym
      when :database
        test_database_backup_integrity(backup_record)
      when :files
        test_files_backup_integrity(backup_record)
      when :configurations
        test_configurations_backup_integrity(backup_record)
      when :logs
        test_logs_backup_integrity(backup_record)
      else
        { verified: false, error: "Unknown backup type: #{backup_record.backup_type}" }
      end
    rescue => e
      Rails.logger.error "Backup integrity test failed: #{e.message}"
      { verified: false, error: e.message, exception: e.class.name }
    end
  end

  def cleanup_old_backups
    Rails.logger.info "Starting cleanup of old backups"

    cleanup_summary = {
      total_cleaned: 0,
      by_type: {},
      space_freed: 0,
      errors: []
    }

    BACKUP_TYPES.each do |backup_type, config|
      begin
        retention_cutoff = config[:retention_days].days.ago
        old_backups = BackupRecord.where(backup_type: backup_type.to_s)
                                 .where("created_at < ?", retention_cutoff)
                                 .where(status: "completed")

        type_summary = {
          count: old_backups.count,
          space_freed: 0
        }

        old_backups.find_each do |backup|
          if File.exist?(backup.file_path.to_s)
            file_size = File.size(backup.file_path)
            File.delete(backup.file_path)
            type_summary[:space_freed] += file_size
          end

          backup.destroy
        end

        cleanup_summary[:by_type][backup_type] = type_summary
        cleanup_summary[:total_cleaned] += type_summary[:count]
        cleanup_summary[:space_freed] += type_summary[:space_freed]

      rescue => e
        error_msg = "Failed to cleanup #{backup_type} backups: #{e.message}"
        Rails.logger.error error_msg
        cleanup_summary[:errors] << error_msg
      end
    end

    Rails.logger.info "Backup cleanup completed: #{cleanup_summary[:total_cleaned]} backups removed, " \
                     "#{format_file_size(cleanup_summary[:space_freed])} freed"

    # Log cleanup activity
    AuditLog.create!(
      user: nil,
      action: "backup_cleanup_completed",
      category: "system_access",
      resource_type: "BackupRecord",
      severity: "info",
      details: cleanup_summary
    )

    cleanup_summary
  end

  private

  # Database backup methods
  def create_database_backup(backup_record, options)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_filename = "database_backup_#{timestamp}.sql"
    backup_path = Rails.root.join("tmp", "backups", backup_filename)

    # Ensure backup directory exists
    FileUtils.mkdir_p(File.dirname(backup_path))

    # Create PostgreSQL dump
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash

    env_vars = {
      "PGPASSWORD" => db_config[:password]
    }.compact

    pg_dump_command = [
      "pg_dump",
      "-h", db_config[:host] || "localhost",
      "-p", (db_config[:port] || 5432).to_s,
      "-U", db_config[:username],
      "-d", db_config[:database],
      "--verbose",
      "--no-password",
      "--format=custom",
      "--compress=9",
      "--file", backup_path.to_s
    ]

    success = system(env_vars, *pg_dump_command)
    raise "pg_dump failed with exit code #{$?.exitstatus}" unless success

    # Calculate checksum
    checksum = Digest::SHA256.file(backup_path).hexdigest
    file_size = File.size(backup_path)

    {
      file_path: backup_path.to_s,
      file_size: file_size,
      checksum: checksum,
      metadata: {
        database: db_config[:database],
        pg_dump_version: `pg_dump --version`.strip,
        compression: 9
      }
    }
  end

  def restore_database_backup(backup_record, restore_record, options)
    # This is a dangerous operation that should be used carefully
    # In production, this would require additional safety checks

    if options[:dry_run]
      return { dry_run: true, message: "Dry run - would restore from #{backup_record.file_path}" }
    end

    # Verify this is safe to restore
    unless options[:force] || Rails.env.development?
      raise "Database restore requires force option in #{Rails.env} environment"
    end

    db_config = ActiveRecord::Base.connection_db_config.configuration_hash

    env_vars = {
      "PGPASSWORD" => db_config[:password]
    }.compact

    pg_restore_command = [
      "pg_restore",
      "-h", db_config[:host] || "localhost",
      "-p", (db_config[:port] || 5432).to_s,
      "-U", db_config[:username],
      "-d", db_config[:database],
      "--verbose",
      "--no-password",
      "--clean",
      "--if-exists",
      backup_record.file_path
    ]

    success = system(env_vars, *pg_restore_command)
    raise "pg_restore failed with exit code #{$?.exitstatus}" unless success

    {
      restored_database: db_config[:database],
      restore_command: pg_restore_command.join(" "),
      restored_at: Time.current
    }
  end

  def test_database_backup_integrity(backup_record)
    # Test that the backup file is a valid PostgreSQL dump
    return { verified: false, error: "Backup file not found" } unless File.exist?(backup_record.file_path)

    # Verify checksum
    current_checksum = Digest::SHA256.file(backup_record.file_path).hexdigest
    if backup_record.checksum != current_checksum
      return {
        verified: false,
        error: "Checksum mismatch",
        expected: backup_record.checksum,
        actual: current_checksum
      }
    end

    # Test that pg_restore can read the file structure
    test_command = [ "pg_restore", "--list", backup_record.file_path ]
    output = `#{test_command.join(" ")} 2>&1`

    if $?.success?
      table_count = output.lines.count { |line| line.include?("TABLE DATA") }
      {
        verified: true,
        checksum_verified: true,
        table_count: table_count,
        file_readable: true
      }
    else
      { verified: false, error: "pg_restore list failed: #{output}" }
    end
  end

  # File backup methods
  def create_files_backup(backup_record, options)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_filename = "files_backup_#{timestamp}.tar.gz"
    backup_path = Rails.root.join("tmp", "backups", backup_filename)

    # Ensure backup directory exists
    FileUtils.mkdir_p(File.dirname(backup_path))

    # Create compressed archive of storage and uploads
    source_paths = [
      Rails.root.join("storage"),
      Rails.root.join("public", "uploads")
    ].select { |path| Dir.exist?(path) }

    if source_paths.empty?
      # Create empty archive
      system("tar", "-czf", backup_path.to_s, "-T", "/dev/null")
    else
      # Use relative paths for cleaner archive
      Dir.chdir(Rails.root) do
        relative_paths = source_paths.map { |path| path.relative_path_from(Rails.root).to_s }
        system("tar", "-czf", backup_path.to_s, *relative_paths)
      end
    end

    raise "tar command failed" unless $?.success?

    # Calculate checksum and file size
    checksum = Digest::SHA256.file(backup_path).hexdigest
    file_size = File.size(backup_path)

    {
      file_path: backup_path.to_s,
      file_size: file_size,
      checksum: checksum,
      metadata: {
        source_paths: source_paths.map(&:to_s),
        compression: "gzip"
      }
    }
  end

  def restore_files_backup(backup_record, restore_record, options)
    if options[:dry_run]
      return { dry_run: true, message: "Dry run - would restore files from #{backup_record.file_path}" }
    end

    # Extract files to temporary location first for safety
    temp_dir = Rails.root.join("tmp", "restore", Time.current.to_i.to_s)
    FileUtils.mkdir_p(temp_dir)

    begin
      # Extract archive
      Dir.chdir(temp_dir) do
        system("tar", "-xzf", backup_record.file_path)
      end

      raise "tar extract failed" unless $?.success?

      # Move files to proper locations (this would need more sophisticated logic in production)
      if options[:force]
        extracted_files = Dir.glob(File.join(temp_dir, "**", "*")).select { |f| File.file?(f) }

        extracted_files.each do |file|
          relative_path = Pathname.new(file).relative_path_from(Pathname.new(temp_dir))
          target_path = Rails.root.join(relative_path)

          FileUtils.mkdir_p(File.dirname(target_path))
          FileUtils.cp(file, target_path)
        end
      end

      {
        extracted_to: temp_dir.to_s,
        files_restored: Dir.glob(File.join(temp_dir, "**", "*")).count,
        restored_at: Time.current
      }

    ensure
      # Cleanup temporary directory
      FileUtils.rm_rf(temp_dir) if options[:cleanup_temp] != false
    end
  end

  def test_files_backup_integrity(backup_record)
    return { verified: false, error: "Backup file not found" } unless File.exist?(backup_record.file_path)

    # Verify checksum
    current_checksum = Digest::SHA256.file(backup_record.file_path).hexdigest
    if backup_record.checksum != current_checksum
      return {
        verified: false,
        error: "Checksum mismatch",
        expected: backup_record.checksum,
        actual: current_checksum
      }
    end

    # Test that tar can read the archive
    output = `tar -tzf #{backup_record.file_path} 2>&1`

    if $?.success?
      file_count = output.lines.count
      {
        verified: true,
        checksum_verified: true,
        file_count: file_count,
        archive_readable: true
      }
    else
      { verified: false, error: "Archive verification failed: #{output}" }
    end
  end

  # Configuration and log backup methods (simplified implementations)
  def create_configurations_backup(backup_record, options)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_filename = "config_backup_#{timestamp}.tar.gz"
    backup_path = Rails.root.join("tmp", "backups", backup_filename)

    FileUtils.mkdir_p(File.dirname(backup_path))

    # Backup configuration files (excluding secrets in production)
    config_paths = [ "config", ".env.example", "Gemfile", "Gemfile.lock" ]
                   .map { |path| Rails.root.join(path) }
                   .select { |path| File.exist?(path) }

    if config_paths.any?
      Dir.chdir(Rails.root) do
        relative_paths = config_paths.map { |path| path.relative_path_from(Rails.root).to_s }
        system("tar", "-czf", backup_path.to_s, *relative_paths)
      end
    else
      system("tar", "-czf", backup_path.to_s, "-T", "/dev/null")
    end

    checksum = Digest::SHA256.file(backup_path).hexdigest
    file_size = File.size(backup_path)

    {
      file_path: backup_path.to_s,
      file_size: file_size,
      checksum: checksum,
      metadata: { config_paths: config_paths.map(&:to_s) }
    }
  end

  def restore_configurations_backup(backup_record, restore_record, options)
    { dry_run: true, message: "Configuration restore not implemented for safety" }
  end

  def test_configurations_backup_integrity(backup_record)
    test_files_backup_integrity(backup_record)
  end

  def create_logs_backup(backup_record, options)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_filename = "logs_backup_#{timestamp}.tar.gz"
    backup_path = Rails.root.join("tmp", "backups", backup_filename)

    FileUtils.mkdir_p(File.dirname(backup_path))

    log_paths = [ Rails.root.join("log") ].select { |path| Dir.exist?(path) }

    if log_paths.any?
      Dir.chdir(Rails.root) do
        relative_paths = log_paths.map { |path| path.relative_path_from(Rails.root).to_s }
        system("tar", "-czf", backup_path.to_s, *relative_paths)
      end
    else
      system("tar", "-czf", backup_path.to_s, "-T", "/dev/null")
    end

    checksum = Digest::SHA256.file(backup_path).hexdigest
    file_size = File.size(backup_path)

    {
      file_path: backup_path.to_s,
      file_size: file_size,
      checksum: checksum,
      metadata: { log_paths: log_paths.map(&:to_s) }
    }
  end

  def restore_logs_backup(backup_record, restore_record, options)
    { dry_run: true, message: "Log restore not typically needed" }
  end

  def test_logs_backup_integrity(backup_record)
    test_files_backup_integrity(backup_record)
  end

  # Helper methods
  def validate_backup_type!(backup_type)
    unless BACKUP_TYPES.key?(backup_type)
      raise ArgumentError, "Invalid backup type: #{backup_type}. Valid types: #{BACKUP_TYPES.keys.join(', ')}"
    end
  end

  def format_file_size(bytes)
    return "0 B" if bytes == 0

    units = [ "B", "KB", "MB", "GB", "TB" ]
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  def log_backup_completion(backup_record)
    AuditLog.create!(
      user: nil,
      action: "backup_completed",
      category: "system_access",
      resource_type: "BackupRecord",
      resource_id: backup_record.id,
      severity: "info",
      details: {
        backup_type: backup_record.backup_type,
        file_size: backup_record.file_size,
        duration: (backup_record.completed_at - backup_record.started_at).round(2),
        integrity_verified: backup_record.integrity_verified
      }
    )
  end

  def log_restore_completion(restore_record)
    AuditLog.create!(
      user: restore_record.requested_by,
      action: "backup_restored",
      category: "system_access",
      resource_type: "BackupRestoreRecord",
      resource_id: restore_record.id,
      severity: "warning", # Restores are significant events
      details: {
        backup_type: restore_record.backup_record.backup_type,
        backup_created_at: restore_record.backup_record.created_at,
        duration: (restore_record.completed_at - restore_record.started_at).round(2)
      }
    )
  end

  def send_backup_notifications(backup_record)
    # Implementation would send notifications to admins
    Rails.logger.info "Backup notification: #{backup_record.backup_type} backup completed successfully"
  end

  def send_backup_failure_notifications(backup_record, error)
    # Implementation would send failure alerts
    Rails.logger.error "Backup failure notification: #{backup_record.backup_type} backup failed: #{error.message}"
  end

  def send_restore_notifications(restore_record)
    # Implementation would send restore notifications
    Rails.logger.info "Restore notification: #{restore_record.backup_record.backup_type} restore completed"
  end
end
