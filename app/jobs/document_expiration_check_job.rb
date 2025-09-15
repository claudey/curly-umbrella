class DocumentExpirationCheckJob < ApplicationJob
  queue_as :default

  def perform
    check_expiring_documents
    check_expired_documents
  end

  private

  def check_expiring_documents
    # Find documents expiring in the next 7 days
    expiring_documents = Document.not_archived
                                .where(expires_at: Time.current..7.days.from_now)
                                .includes(:user, :organization)

    expiring_documents.find_each do |document|
      # Skip if we've already notified about this document recently
      next if recently_notified_about_expiration?(document)

      DocumentNotificationService.notify_document_expiring(document)
      
      # Mark that we've notified about this document
      Rails.cache.write(
        "document_expiration_notified_#{document.id}",
        true,
        expires_in: 3.days
      )
    end

    Rails.logger.info "Checked #{expiring_documents.count} expiring documents"
  end

  def check_expired_documents
    # Find documents that expired in the last 24 hours
    expired_documents = Document.not_archived
                               .where(expires_at: 1.day.ago..Time.current)
                               .includes(:user, :organization)

    expired_documents.find_each do |document|
      # Skip if we've already notified about this document expiring
      next if recently_notified_about_expiration?(document, 'expired')

      DocumentNotificationService.notify_document_expired(document)
      
      # Mark that we've notified about this expired document
      Rails.cache.write(
        "document_expired_notified_#{document.id}",
        true,
        expires_in: 7.days
      )
    end

    Rails.logger.info "Checked #{expired_documents.count} expired documents"
  end

  def recently_notified_about_expiration?(document, type = 'expiring')
    Rails.cache.exist?("document_#{type}_notified_#{document.id}")
  end
end