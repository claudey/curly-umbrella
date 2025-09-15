class WeeklyDocumentDigestJob < ApplicationJob
  queue_as :default

  def perform
    Organization.find_each do |organization>
      send_weekly_digest_for_organization(organization)
    end
  end

  private

  def send_weekly_digest_for_organization(organization)
    users = organization.users.where(email_notifications_enabled: true)
    
    users.find_each do |user|
      # Skip if user has opted out of digest emails
      next unless user.notification_preferences&.weekly_digest_enabled?

      digest_data = prepare_digest_data(organization, user)
      
      # Only send if there's meaningful activity
      if digest_data[:has_activity]
        DocumentMailer.with(
          user: user,
          new_documents: digest_data[:new_documents],
          updated_documents: digest_data[:updated_documents],
          expiring_documents: digest_data[:expiring_documents]
        ).weekly_document_digest.deliver_now
      end
    end
  end

  def prepare_digest_data(organization, user)
    start_date = 1.week.ago
    end_date = Time.current

    # Get documents user can access
    accessible_documents = get_accessible_documents(organization, user)

    new_documents = accessible_documents
                   .where(created_at: start_date..end_date)
                   .includes(:user, file_attachment: :blob)
                   .order(created_at: :desc)
                   .limit(10)

    updated_documents = accessible_documents
                       .where(updated_at: start_date..end_date)
                       .where.not(created_at: start_date..end_date) # Exclude newly created
                       .includes(:user, file_attachment: :blob)
                       .order(updated_at: :desc)
                       .limit(10)

    expiring_documents = accessible_documents
                        .expiring_soon(14)
                        .includes(:user, file_attachment: :blob)
                        .order(:expires_at)
                        .limit(5)

    {
      new_documents: new_documents,
      updated_documents: updated_documents,
      expiring_documents: expiring_documents,
      has_activity: new_documents.any? || updated_documents.any? || expiring_documents.any?
    }
  end

  def get_accessible_documents(organization, user)
    documents = Document.where(organization: organization).not_archived

    # Filter based on user's access level
    case user.role
    when 'admin', 'brokerage_admin'
      documents # Admins can see all documents
    else
      # Regular users can see public documents and their own private documents
      documents.where(
        '(access_level = ? AND is_public = ?) OR (access_level = ?) OR (user_id = ?)',
        'public', true, 'organization', user.id
      )
    end
  end
end