class DocumentMailer < ApplicationMailer
  def document_notification
    @user = params[:user]
    @document = params[:document]
    @event_type = params[:event_type]
    @organization = @user.organization

    # Set email subject based on event type
    subject = case @event_type
    when :document_uploaded
                "New Document: #{@document.name}"
    when :document_updated
                "Document Updated: #{@document.name}"
    when :document_archived
                "Document Archived: #{@document.name}"
    when :document_restored
                "Document Restored: #{@document.name}"
    when :document_expiring
                "⚠️ Document Expiring Soon: #{@document.name}"
    when :document_expired
                "🚨 Document Expired: #{@document.name}"
    when :document_shared
                "Document Shared With You: #{@document.name}"
    when :document_version_created
                "New Version Available: #{@document.name}"
    else
                "Document Notification: #{@document.name}"
    end

    @subject = subject
    @action_url = document_url(@document)

    mail(
      to: @user.email,
      subject: "#{@organization.name} - #{subject}"
    )
  end

  def document_expiring_reminder
    @user = params[:user]
    @documents = params[:documents]
    @organization = @user.organization

    mail(
      to: @user.email,
      subject: "#{@organization.name} - Documents Expiring Soon (#{@documents.count})"
    )
  end

  def weekly_document_digest
    @user = params[:user]
    @organization = @user.organization
    @new_documents = params[:new_documents]
    @updated_documents = params[:updated_documents]
    @expiring_documents = params[:expiring_documents]

    mail(
      to: @user.email,
      subject: "#{@organization.name} - Weekly Document Activity Digest"
    )
  end

  private

  def document_url(document)
    Rails.application.routes.url_helpers.document_url(
      document,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )
  end
end
