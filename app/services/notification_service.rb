class NotificationService
  class << self
    # Send notification for new motor application
    def new_application_submitted(application)
      # Get all users in the organization who should be notified
      organization = application.organization
      
      # Find users who should receive new application notifications
      users_to_notify = organization.users.joins(:notification_preference)
                                          .where(notification_preferences: { email_new_applications: true })
      
      users_to_notify.each do |user|
        # Create in-app notification
        Notification.create_for_user(
          user,
          title: "New Motor Application Submitted",
          message: "A new motor insurance application has been submitted for #{application.client_name}. Policy Number: #{application.policy_number}",
          type: "new_application",
          data: {
            application_id: application.id,
            policy_number: application.policy_number,
            client_name: application.client_name
          }
        )

        # Send email notification if user preferences allow
        if user.notification_preference&.should_email_for?(:new_application)
          NotificationMailer.new_application_notification(user, application).deliver_later
        end
      end
    end

    # Send notification for application status update
    def application_status_updated(application, old_status, new_status)
      organization = application.organization
      
      # Find users who should receive status update notifications
      users_to_notify = organization.users.joins(:notification_preference)
                                          .where(notification_preferences: { email_status_updates: true })
      
      users_to_notify.each do |user|
        # Create in-app notification
        Notification.create_for_user(
          user,
          title: "Application Status Updated",
          message: "Application #{application.policy_number} status changed from #{old_status.humanize} to #{new_status.humanize}",
          type: "status_update",
          data: {
            application_id: application.id,
            policy_number: application.policy_number,
            old_status: old_status,
            new_status: new_status
          }
        )

        # Send email notification if user preferences allow
        if user.notification_preference&.should_email_for?(:status_update)
          NotificationMailer.status_update_notification(user, application, old_status, new_status).deliver_later
        end
      end
    end

    # Send notification for user invitation
    def user_invited(user, inviter, organization)
      # Create in-app notification
      Notification.create_for_user(
        user,
        title: "Organization Invitation",
        message: "You have been invited to join #{organization.name} by #{inviter.full_name}",
        type: "user_invitation",
        data: {
          inviter_id: inviter.id,
          inviter_name: inviter.full_name,
          organization_id: organization.id,
          organization_name: organization.name
        }
      )

      # Send email notification if user preferences allow
      if user.notification_preference&.should_email_for?(:user_invitation)
        NotificationMailer.user_invitation(user, inviter, organization).deliver_later
      end
    end

    # Send system alert
    def system_alert(user, title, message, data = {})
      # Create in-app notification
      Notification.create_for_user(
        user,
        title: title,
        message: message,
        type: "system_alert",
        data: data
      )

      # Always send email for system alerts
      NotificationMailer.system_alert(user, title, message).deliver_later
    end

    # Broadcast system-wide alert to all users in organization
    def broadcast_system_alert(organization, title, message, data = {})
      organization.users.each do |user|
        system_alert(user, title, message, data)
      end
    end

    # Send notifications for bulk actions
    def bulk_application_update(applications, action, performer)
      applications.group_by(&:organization).each do |organization, org_applications|
        users_to_notify = organization.users.joins(:notification_preference)
                                            .where(notification_preferences: { email_status_updates: true })
        
        users_to_notify.each do |user|
          next if user == performer # Don't notify the user who performed the action
          
          Notification.create_for_user(
            user,
            title: "Bulk Application Update",
            message: "#{performer.full_name} performed #{action} on #{org_applications.count} applications",
            type: "status_update",
            data: {
              performer_id: performer.id,
              performer_name: performer.full_name,
              action: action,
              application_count: org_applications.count,
              application_ids: org_applications.pluck(:id)
            }
          )
        end
      end
    end
  end
end