class DocumentNotificationService
  def self.notify_document_uploaded(document)
    new(document).notify_document_uploaded
  end

  def self.notify_document_updated(document)
    new(document).notify_document_updated
  end

  def self.notify_document_archived(document, archived_by)
    new(document).notify_document_archived(archived_by)
  end

  def self.notify_document_restored(document, restored_by)
    new(document).notify_document_restored(restored_by)
  end

  def self.notify_document_expiring(document)
    new(document).notify_document_expiring
  end

  def self.notify_document_expired(document)
    new(document).notify_document_expired
  end

  def self.notify_new_version_created(document)
    new(document).notify_new_version_created
  end

  def self.notify_document_shared(document, shared_with_user, shared_by_user)
    new(document).notify_document_shared(shared_with_user, shared_by_user)
  end

  def initialize(document)
    @document = document
    @organization = document.organization
  end

  def notify_document_uploaded
    # Notify organization members based on document access level
    recipients = determine_recipients_for_upload
    
    recipients.each do |user|
      create_notification(
        user: user,
        type: 'document_uploaded',
        title: "New Document: #{@document.name}",
        message: "#{@document.user.full_name} uploaded a new #{@document.document_type.humanize.downcase} document.",
        data: document_data
      )
    end

    # Send email notifications for important document types
    if important_document_type?
      send_email_notifications(recipients, :document_uploaded)
    end
  end

  def notify_document_updated
    # Notify interested parties about document updates
    recipients = determine_recipients_for_update
    
    recipients.each do |user|
      create_notification(
        user: user,
        type: 'document_updated',
        title: "Document Updated: #{@document.name}",
        message: "#{@document.user.full_name} updated the document \"#{@document.name}\".",
        data: document_data
      )
    end
  end

  def notify_document_archived(archived_by)
    # Notify organization members about archived documents
    recipients = organization_members - [archived_by]
    
    recipients.each do |user|
      create_notification(
        user: user,
        type: 'document_archived',
        title: "Document Archived: #{@document.name}",
        message: "#{archived_by.full_name} archived the document \"#{@document.name}\".",
        data: document_data.merge(archived_by: archived_by.full_name)
      )
    end
  end

  def notify_document_restored(restored_by)
    # Notify organization members about restored documents
    recipients = organization_members - [restored_by]
    
    recipients.each do |user|
      create_notification(
        user: user,
        type: 'document_restored',
        title: "Document Restored: #{@document.name}",
        message: "#{restored_by.full_name} restored the document \"#{@document.name}\".",
        data: document_data.merge(restored_by: restored_by.full_name)
      )
    end
  end

  def notify_document_expiring
    # Notify document owner and organization admins about expiring documents
    recipients = [
      @document.user,
      *organization_admins
    ].uniq

    recipients.each do |user|
      create_notification(
        user: user,
        type: 'document_expiring',
        title: "Document Expiring Soon: #{@document.name}",
        message: "The document \"#{@document.name}\" will expire on #{@document.expires_at.strftime('%B %d, %Y')}.",
        data: document_data.merge(expires_at: @document.expires_at)
      )
    end

    # Send urgent email notifications
    send_email_notifications(recipients, :document_expiring)
  end

  def notify_document_expired
    # Notify document owner and organization admins about expired documents
    recipients = [
      @document.user,
      *organization_admins
    ].uniq

    recipients.each do |user|
      create_notification(
        user: user,
        type: 'document_expired',
        title: "Document Expired: #{@document.name}",
        message: "The document \"#{@document.name}\" has expired and may need attention.",
        data: document_data.merge(expired_at: @document.expires_at)
      )
    end

    # Send urgent email notifications
    send_email_notifications(recipients, :document_expired)
  end

  def notify_new_version_created
    # Notify interested parties about new document versions
    recipients = determine_recipients_for_version
    
    recipients.each do |user|
      create_notification(
        user: user,
        type: 'document_version_created',
        title: "New Version: #{@document.name} (v#{@document.version})",
        message: "#{@document.user.full_name} created version #{@document.version} of \"#{@document.name}\".",
        data: document_data.merge(version: @document.version)
      )
    end
  end

  def notify_document_shared(shared_with_user, shared_by_user)
    create_notification(
      user: shared_with_user,
      type: 'document_shared',
      title: "Document Shared: #{@document.name}",
      message: "#{shared_by_user.full_name} shared the document \"#{@document.name}\" with you.",
      data: document_data.merge(shared_by: shared_by_user.full_name)
    )

    # Send email notification for shared documents
    send_email_notifications([shared_with_user], :document_shared)
  end

  private

  def create_notification(user:, type:, title:, message:, data: {})
    Notification.create_for_user(
      user,
      title: title,
      message: message,
      type: type,
      data: data
    )
  rescue => e
    Rails.logger.error "Failed to create notification: #{e.message}"
  end

  def document_data
    {
      document_id: @document.id,
      document_name: @document.name,
      document_type: @document.document_type,
      document_url: Rails.application.routes.url_helpers.document_path(@document),
      file_size: @document.human_file_size,
      created_by: @document.user.full_name
    }
  end

  def determine_recipients_for_upload
    case @document.access_level
    when 'private'
      [] # No notifications for private documents
    when 'organization'
      organization_members - [@document.user] # All org members except uploader
    when 'public'
      organization_members - [@document.user] # All org members except uploader
    else
      []
    end
  end

  def determine_recipients_for_update
    case @document.access_level
    when 'private'
      [] # No notifications for private document updates
    when 'organization'
      # Notify users who have interacted with this document
      interested_users = User.joins(:documents)
                             .where(organization: @organization)
                             .where.not(id: @document.user.id)
                             .distinct
                             .limit(10) # Limit to avoid spam

      interested_users.to_a
    when 'public'
      organization_members - [@document.user]
    else
      []
    end
  end

  def determine_recipients_for_version
    # Similar to update notifications but more targeted
    case @document.access_level
    when 'private'
      []
    when 'organization', 'public'
      # Only notify users who have viewed or worked with this document
      organization_members.select do |user|
        user != @document.user && user.admin? || user.brokerage_admin?
      end
    else
      []
    end
  end

  def organization_members
    @organization_members ||= User.where(organization: @organization).to_a
  end

  def organization_admins
    @organization_admins ||= User.where(organization: @organization, role: ['admin', 'brokerage_admin']).to_a
  end

  def important_document_type?
    %w[policy contract legal compliance certificate].include?(@document.document_type.downcase)
  end

  def send_email_notifications(recipients, event_type)
    return unless recipients.any?

    recipients.each do |user|
      next unless user.notification_preferences&.email_enabled?

      DocumentMailer.with(
        user: user,
        document: @document,
        event_type: event_type
      ).document_notification.deliver_later
    end
  rescue => e
    Rails.logger.error "Failed to send email notifications: #{e.message}"
  end
end